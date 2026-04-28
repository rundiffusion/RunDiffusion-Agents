#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "expected file: $1"
}

assert_not_exists() {
  [[ ! -e "$1" ]] || fail "expected path to be absent: $1"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "${haystack}" != *"${needle}"* ]]; then
    fail "${label}: missing '${needle}'"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "${haystack}" == *"${needle}"* ]]; then
    fail "${label}: unexpectedly found '${needle}'"
  fi
}

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/control-plane-hardening-tests.XXXXXX")"
trap 'rm -rf "${tmpdir}"' EXIT

fixture_repo="${tmpdir}/repo"
mkdir -p "${fixture_repo}/deploy/tenants" "${fixture_repo}/services/rundiffusion-agents"
cp -R "${REPO_ROOT}/scripts" "${fixture_repo}/scripts"
cp "${REPO_ROOT}/services/rundiffusion-agents/Dockerfile" "${fixture_repo}/services/rundiffusion-agents/Dockerfile"

cat > "${fixture_repo}/deploy/tenants/tenants.yml" <<'EOF'
tenants: []
EOF

cat > "${fixture_repo}/deploy/tenants/tenants.example.yml" <<'EOF'
tenants: []
EOF

cat > "${fixture_repo}/.env" <<EOF
COMPOSE_PROJECT_NAME=test-agents
BASE_DOMAIN=example.com
INGRESS_MODE=local
PUBLIC_URL_SCHEME=
DATA_ROOT=${tmpdir}/data
TENANT_ENV_ROOT=${tmpdir}/env
TENANT_CONTROL_PLANE_CONFIG_PATH=${tmpdir}/env/control-plane.yml
TRAEFIK_BIND_ADDRESS=127.0.0.1
TRAEFIK_HTTP_PORT=38080
TRAEFIK_NETWORK=test-network
TRAEFIK_LOG_LEVEL=INFO
CLOUDFLARE_HOSTNAME_MODE=wildcard
CLOUDFLARE_TUNNEL_ID=
CLOUDFLARE_TUNNEL_CREDENTIALS_FILE=
CLOUDFLARE_TUNNEL_METRICS=127.0.0.1:20241
CLOUDFLARED_LAUNCHD_LABEL=com.test.cloudflared
DEPLOY_MODE=build
AUTO_ROLLBACK=1
IMAGE_REPOSITORY=local/openclaw-gateway
OPENCLAW_VERSION=2026.3.24
GATEWAY_IMAGE_TAG=
CODEX_CLI_VERSION=0.125.0
CLAUDE_CODE_VERSION=2.1.119
GEMINI_CLI_VERSION=0.39.1
HOMEBREW_INSTALL_REF=HEAD
HOMEBREW_BREW_REF=5.1.8
DOCKER_BUILD_CONTEXT=
DOCKER_BUILDER=
DOCKER_BUILD_PLATFORM=
TENANT_MEMORY_RESERVATION=1536m
TENANT_MEMORY_LIMIT=3072m
TENANT_PIDS_LIMIT=512
TENANT_CONTAINER_SECURITY_PROFILE=tool-userns
MAX_ALWAYS_ON_TENANTS=8
BACKUP_ROOT=
RELEASE_ROOT=
EOF

(
  cd "${fixture_repo}"
  ./scripts/create-tenant.sh alpha "Alpha Tenant" >/dev/null
)

assert_file "${tmpdir}/env/alpha.env"
assert_file "${tmpdir}/env/managed/alpha.env"
assert_not_exists "${fixture_repo}/gateway"

managed_stub="$(cat "${tmpdir}/env/managed/alpha.env")"
assert_contains "${managed_stub}" "# Managed by the RunDiffusion Agents control plane." "managed stub is created"
assert_not_contains "${managed_stub}" "GEMINI_API_KEY=" "no-entry managed env does not seed secrets"

assert_not_exists "${tmpdir}/data/tenants/alpha/gateway/.openclaw/openclaw.json"
assert_not_exists "${tmpdir}/data/tenants/alpha/gateway/.codex/config.toml"

runtime_output="$(
  python3 "${REPO_ROOT}/skills/rundiffusion-host-agent-manager/scripts/tenant_runtime_context.py" \
    alpha \
    --repo-root "${fixture_repo}"
)"
assert_contains "${runtime_output}" "OPENCLAW_GATEWAY_TOKEN=<redacted>" "runtime context redacts gateway token"
assert_contains "${runtime_output}" "TERMINAL_BASIC_AUTH_PASSWORD=<redacted>" "runtime context redacts terminal password"
assert_not_contains "${runtime_output}" "$(awk -F= '$1 == "OPENCLAW_GATEWAY_TOKEN" {print $2}' "${tmpdir}/env/alpha.env")" "runtime context hides token value"

runtime_output_with_secrets="$(
  python3 "${REPO_ROOT}/skills/rundiffusion-host-agent-manager/scripts/tenant_runtime_context.py" \
    alpha \
    --repo-root "${fixture_repo}" \
    --show-secrets
)"
assert_contains "${runtime_output_with_secrets}" "$(awk -F= '$1 == "OPENCLAW_GATEWAY_TOKEN" {print $2}' "${tmpdir}/env/alpha.env")" "show-secrets prints token value"

if python3 "${REPO_ROOT}/scripts/sync_tenant_control_plane.py" \
  --tenant-slug beta \
  --tenant-env-file relative.env \
  --tenant-managed-env-file "${tmpdir}/managed.env" \
  --tenant-data-root "${tmpdir}/tenant-data" \
  --control-plane-config-path "${tmpdir}/missing-control-plane.yml" >/dev/null 2>&1; then
  fail "sync should reject relative tenant env paths"
fi

(
  # shellcheck disable=SC1091
  . "${fixture_repo}/scripts/lib/common.sh"
  load_root_env

  release_dir="$(tenant_release_dir alpha 20260428000000)"
  ensure_directory "${release_dir}"
  printf 'TENANT_SLUG=alpha\nROLLBACK_MARKER=tenant\n' > "${release_dir}/tenant.env"
  printf 'GEMINI_ENABLED=1\n' > "${release_dir}/tenant.managed.env"
  printf 'TENANT_SLUG=alpha\nROLLBACK_MARKER=current\n' > "$(tenant_env_file alpha)"
  printf 'GEMINI_ENABLED=0\n' > "$(tenant_managed_env_file alpha)"

  restore_tenant_env_snapshots alpha "${release_dir}"
  restored_env="$(cat "$(tenant_env_file alpha)")"
  restored_managed="$(cat "$(tenant_managed_env_file alpha)")"
  assert_contains "${restored_env}" "ROLLBACK_MARKER=tenant" "rollback restores tenant env snapshot"
  assert_contains "${restored_managed}" "GEMINI_ENABLED=1" "rollback restores managed env snapshot"

  rm -f "${release_dir}/tenant.managed.env"
  printf 'GEMINI_ENABLED=0\n' > "$(tenant_managed_env_file alpha)"
  restore_tenant_env_snapshots alpha "${release_dir}"
  assert_not_exists "$(tenant_managed_env_file alpha)"

  ensure_directory "$(tenant_data_root alpha)"
  ensure_directory "$(tenant_backup_root alpha)"
  ensure_directory "$(tenant_release_root alpha)"
  printf 'TENANT_SLUG=alpha\n' > "$(tenant_env_file alpha)"
  printf '# managed\n' > "$(tenant_managed_env_file alpha)"
  purge_tenant_state alpha
  assert_not_exists "$(tenant_env_file alpha)"
  assert_not_exists "$(tenant_managed_env_file alpha)"
  assert_not_exists "$(tenant_data_root alpha)"
  assert_not_exists "$(tenant_backup_root alpha)"
  assert_not_exists "$(tenant_release_root alpha)"
)

printf 'PASS: control-plane hardening checks\n'
