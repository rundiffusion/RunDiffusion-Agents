#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/delete-tenant.sh <slug> [--purge]

Removes the tenant from the registry and stops its stack.
Use --purge to also delete env, release metadata, backups, and tenant data.
EOF
}

[[ $# -ge 1 ]] || {
  usage >&2
  exit 1
}

slug="$1"
shift
purge=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge)
      purge=1
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
if ingress_uses_cloudflare; then
  require_cloudflare_tunnel_config
fi
validate_slug "${slug}"
tenant_exists "${slug}" || die "Unknown tenant: ${slug}"
export SLUG="${slug}"

compose_tenant "${slug}" down --remove-orphans || true
if [[ "${purge}" -eq 1 ]]; then
  purge_tenant_state "${slug}"
  if [[ -f "${TENANT_CONTROL_PLANE_CONFIG_PATH}" ]]; then
    note "Control-plane config may still contain tenant ${slug}: ${TENANT_CONTROL_PLANE_CONFIG_PATH}"
  fi
fi

yq eval -i 'del(.tenants[] | select(.slug == strenv(SLUG)))' "${TENANT_REGISTRY_FILE}"

if ingress_uses_cloudflare; then
  render_cloudflared_config >/dev/null
fi
render_traefik_dynamic_config >/dev/null
note "Deleted tenant ${slug}"
