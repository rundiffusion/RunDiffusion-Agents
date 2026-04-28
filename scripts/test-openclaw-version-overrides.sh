#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck disable=SC1091
. "${REPO_ROOT}/scripts/lib/common.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local label="$3"

  if [[ "${actual}" != "${expected}" ]]; then
    fail "${label}: expected '${expected}', got '${actual}'"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "${haystack}" != *"${needle}"* ]]; then
    fail "${label}: missing '${needle}'"
  fi
}

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/openclaw-version-tests.XXXXXX")"
trap 'rm -rf "${tmpdir}"' EXIT

ROOT_ENV_FILE="${tmpdir}/root.env"
TENANT_REGISTRY_FILE="${tmpdir}/tenants.yml"
TENANT_REGISTRY_EXAMPLE_FILE="${tmpdir}/tenants.example.yml"

cat > "${ROOT_ENV_FILE}" <<EOF
COMPOSE_PROJECT_NAME=test-agents
BASE_DOMAIN=example.com
DATA_ROOT=${tmpdir}/data
TENANT_ENV_ROOT=${tmpdir}/env
TENANT_CONTROL_PLANE_CONFIG_PATH=${tmpdir}/control-plane.yml
IMAGE_REPOSITORY=local/openclaw-gateway
OPENCLAW_VERSION=2026.4.15
DEPLOY_MODE=build
EOF

cat > "${TENANT_REGISTRY_FILE}" <<'EOF'
tenants:
  - slug: alpha
    display_name: Alpha
    hostname: alpha.example.com
    enabled: true
    project_name: test-agents-alpha
    data_root: ${DATA_ROOT}/tenants/alpha
    env_file: ${TENANT_ENV_ROOT}/alpha.env
EOF

cat > "${tmpdir}/control-plane.yml" <<'EOF'
tenants:
  alpha:
    openclawVersion: 2026.4.16
EOF

mkdir -p "${tmpdir}/env"
cat > "${tmpdir}/env/alpha.env" <<'EOF'
TENANT_SLUG=alpha
TENANT_HOSTNAME=alpha.example.com
OPENCLAW_GATEWAY_TOKEN=test-token
EOF

load_root_env

assert_eq "$(resolved_openclaw_version alpha)" "2026.4.16" "tenant override wins over root env"
assert_eq "$(resolved_openclaw_version_source alpha)" "tenant_control_plane" "tenant override source"
assert_eq "$(resolved_openclaw_version beta)" "2026.4.15" "root env is default without tenant override"
assert_eq "$(resolved_openclaw_version_source beta)" "root_env" "root env source"

export OPENCLAW_VERSION_OVERRIDE="2026.4.17"
assert_eq "$(resolved_openclaw_version alpha)" "2026.4.17" "cli override wins over tenant override"
assert_eq "$(resolved_openclaw_version_source alpha)" "cli_override" "cli override source"
unset OPENCLAW_VERSION_OVERRIDE

cat > "${ROOT_ENV_FILE}" <<EOF
COMPOSE_PROJECT_NAME=test-agents
BASE_DOMAIN=example.com
DATA_ROOT=${tmpdir}/data
TENANT_ENV_ROOT=${tmpdir}/env
TENANT_CONTROL_PLANE_CONFIG_PATH=${tmpdir}/control-plane.yml
IMAGE_REPOSITORY=local/openclaw-gateway
OPENCLAW_VERSION=
DEPLOY_MODE=build
EOF
load_root_env
assert_eq "$(resolved_openclaw_version beta)" "$(dockerfile_default_openclaw_version)" "dockerfile fallback"
assert_eq "$(resolved_openclaw_version_source beta)" "dockerfile" "dockerfile source"

cat > "${tmpdir}/invalid-control-plane.yml" <<'EOF'
tenants:
  alpha:
    openclawVersion: not-a-version
EOF

if python3 "${REPO_ROOT}/scripts/sync_tenant_control_plane.py" \
  --tenant-slug alpha \
  --tenant-env-file "${tmpdir}/env/alpha.env" \
  --tenant-managed-env-file "${tmpdir}/managed.env" \
  --tenant-data-root "${tmpdir}/tenant-data" \
  --control-plane-config-path "${tmpdir}/invalid-control-plane.yml" >/dev/null 2>&1; then
  fail "invalid openclawVersion should be rejected"
fi

runtime_repo="${tmpdir}/runtime-repo"
mkdir -p "${runtime_repo}/deploy/tenants" "${runtime_repo}/services/rundiffusion-agents" "${runtime_repo}/env"
ln -s "${REPO_ROOT}/services/rundiffusion-agents/Dockerfile" "${runtime_repo}/services/rundiffusion-agents/Dockerfile"
cat > "${runtime_repo}/.env" <<EOF
COMPOSE_PROJECT_NAME=test-agents
DATA_ROOT=${tmpdir}/data
TENANT_ENV_ROOT=${runtime_repo}/env
TENANT_CONTROL_PLANE_CONFIG_PATH=${tmpdir}/control-plane.yml
IMAGE_REPOSITORY=local/openclaw-gateway
OPENCLAW_VERSION=2026.4.15
TRAEFIK_NETWORK=test-network
TENANT_MEMORY_RESERVATION=1536m
TENANT_MEMORY_LIMIT=3072m
TENANT_PIDS_LIMIT=512
EOF
cat > "${runtime_repo}/deploy/tenants/tenants.yml" <<'EOF'
tenants:
  - slug: alpha
    display_name: Alpha
    hostname: alpha.example.com
    enabled: true
    project_name: test-agents-alpha
    data_root: ${DATA_ROOT}/tenants/alpha
    env_file: ${TENANT_ENV_ROOT}/alpha.env
EOF
cat > "${runtime_repo}/env/alpha.env" <<'EOF'
TENANT_SLUG=alpha
TENANT_HOSTNAME=alpha.example.com
OPENCLAW_GATEWAY_TOKEN=test-token
EOF

runtime_output="$(
  python3 "${REPO_ROOT}/skills/rundiffusion-host-agent-manager/scripts/tenant_runtime_context.py" \
    alpha \
    --repo-root "${runtime_repo}"
)"
assert_contains "${runtime_output}" "ROOT_OPENCLAW_VERSION=2026.4.15" "runtime context root version"
assert_contains "${runtime_output}" "TENANT_OPENCLAW_VERSION_OVERRIDE=2026.4.16" "runtime context tenant override"
assert_contains "${runtime_output}" "EFFECTIVE_OPENCLAW_VERSION=2026.4.16" "runtime context effective version"
assert_contains "${runtime_output}" "EFFECTIVE_OPENCLAW_VERSION_SOURCE=tenant_control_plane" "runtime context effective source"

printf 'PASS: openclaw version override checks\n'
