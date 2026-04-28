#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/rollback.sh --tenant slug [--release id]
       ./scripts/rollback.sh --shared [--release id]
EOF
}

tenant_slug=""
release_id=""
shared=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant)
      tenant_slug="$2"
      shift 2
      ;;
    --release)
      release_id="$2"
      shift 2
      ;;
    --shared)
      shared=1
      shift
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

load_root_env
require_base_commands
require_command curl

if [[ "${shared}" -eq 1 ]]; then
  target_release="${release_id:-$(shared_previous_release)}"
  [[ -n "${target_release}" ]] || die "No previous shared release is available"

  shared_dir="$(shared_release_dir "${target_release}")"
  require_file "${shared_dir}/traefik.generated-tenants.yml"
  ensure_directory "${DATA_ROOT}/traefik/dynamic"
  if [[ -f "${shared_dir}/cloudflared.config.yml" ]]; then
    ensure_directory "${DATA_ROOT}/cloudflared"
    cp "${shared_dir}/cloudflared.config.yml" "${DATA_ROOT}/cloudflared/config.yml"
  fi
  cp "${shared_dir}/traefik.generated-tenants.yml" "${DATA_ROOT}/traefik/dynamic/generated-tenants.yml"
  compose_shared up -d
  smoke_test_shared_local
  record_shared_release_success "${target_release}"
  note "Rolled shared infrastructure back to ${target_release}"
  exit 0
fi

[[ -n "${tenant_slug}" ]] || die "A tenant slug is required unless --shared is used"
tenant_exists "${tenant_slug}" || die "Unknown tenant: ${tenant_slug}"

target_release="${release_id:-$(tenant_previous_release "${tenant_slug}")}"
[[ -n "${target_release}" ]] || die "No rollback target is available for ${tenant_slug}"

release_dir="$(tenant_release_dir "${tenant_slug}" "${target_release}")"
image_ref="$(tenant_release_image_ref "${tenant_slug}" "${target_release}")"

[[ -n "${image_ref}" ]] || die "Missing image reference for ${tenant_slug} release ${target_release}"

ensure_tenant_layout "${tenant_slug}"
restore_tenant_env_snapshots "${tenant_slug}" "${release_dir}"
export OPENCLAW_IMAGE="${image_ref}"
render_traefik_dynamic_config >/dev/null

compose_tenant "${tenant_slug}" up -d
wait_for_tenant_healthy "${tenant_slug}"
smoke_test_tenant_local "${tenant_slug}"
set_current_release "${tenant_slug}" "${target_release}"

note "Rolled ${tenant_slug} back to ${target_release}"
