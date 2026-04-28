#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/update-tenant.sh <slug> [--display-name "Name"] [--hostname host] [--enable|--disable]
EOF
}

[[ $# -ge 1 ]] || {
  usage >&2
  exit 1
}

slug="$1"
shift

load_root_env
require_base_commands
if ingress_uses_cloudflare; then
  require_cloudflare_tunnel_config
fi
validate_slug "${slug}"
tenant_exists "${slug}" || die "Unknown tenant: ${slug}"
export SLUG="${slug}"

display_name=""
hostname=""
enabled=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --display-name)
      display_name="$2"
      shift 2
      ;;
    --hostname)
      hostname="$2"
      shift 2
      ;;
    --enable)
      enabled="true"
      shift
      ;;
    --disable)
      enabled="false"
      shift
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

[[ -n "${display_name}${hostname}${enabled}" ]] || die "No updates requested"

if [[ -n "${display_name}" ]]; then
  export VALUE="${display_name}"
  yq eval -i '(.tenants[] | select(.slug == strenv(SLUG)) | .display_name) = strenv(VALUE)' "${TENANT_REGISTRY_FILE}"
fi

if [[ -n "${hostname}" ]]; then
  public_origin="$(resolved_public_origin_for_hostname "${hostname}")"
  export VALUE="${hostname}"
  yq eval -i '(.tenants[] | select(.slug == strenv(SLUG)) | .hostname) = strenv(VALUE)' "${TENANT_REGISTRY_FILE}"

  env_file="$(tenant_env_file "${slug}")"
  if [[ -f "${env_file}" ]]; then
    perl -0pi -e 's/^TENANT_HOSTNAME=.*/TENANT_HOSTNAME='"${hostname//\//\\/}"'/m' "${env_file}"
    perl -0pi -e 's/^OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=.*/OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS='"${public_origin//\//\\/}"'/m' "${env_file}"
  fi
fi

if [[ -n "${enabled}" ]]; then
  export VALUE="${enabled}"
  yq eval -i '(.tenants[] | select(.slug == strenv(SLUG)) | .enabled) = (strenv(VALUE) == "true")' "${TENANT_REGISTRY_FILE}"
fi

if ingress_uses_cloudflare; then
  render_cloudflared_config >/dev/null
fi
render_traefik_dynamic_config >/dev/null
note "Updated tenant ${slug}"
