#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/create-tenant.sh <slug> "<Display Name>" [hostname]

Creates a tenant registry entry and a tenant env file with unique secrets.
EOF
}

[[ $# -ge 2 ]] || {
  usage >&2
  exit 1
}

load_root_env
require_base_commands
require_command openssl
if ingress_uses_cloudflare; then
  require_cloudflare_tunnel_config
fi

slug="$1"
display_name="$2"
hostname="${3:-${slug}.${BASE_DOMAIN}}"
public_origin="$(resolved_public_origin_for_hostname "${hostname}")"
project_name="${COMPOSE_PROJECT_NAME}-${slug}"
data_root="${DATA_ROOT%/}/tenants/${slug}"
env_file="${TENANT_ENV_ROOT%/}/${slug}.env"

validate_slug "${slug}"
tenant_exists "${slug}" && die "Tenant ${slug} already exists"

ensure_directory "$(dirname "${env_file}")"
ensure_directory "${data_root}/gateway"

cat > "${env_file}" <<EOF
TENANT_SLUG=${slug}
TENANT_HOSTNAME=${hostname}
OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=${public_origin}

OPENCLAW_ACCESS_MODE=native
OPENCLAW_GATEWAY_TOKEN=$(random_hex 32)

TERMINAL_ENABLED=1
TERMINAL_BASIC_AUTH_USERNAME=${slug}-operator
TERMINAL_BASIC_AUTH_PASSWORD=$(random_password)

HERMES_ENABLED=1
HERMES_WEBUI_ENABLED=0
CODEX_ENABLED=1
CLAUDE_ENABLED=1
GEMINI_ENABLED=0
PI_ENABLED=1

GEMINI_API_KEY=
HERMES_OPENAI_API_KEY=
CODEX_OPENAI_API_KEY=
CLAUDE_ANTHROPIC_API_KEY=
GEMINI_CLI_API_KEY=
OPENROUTER_API_KEY=
PI_OPENAI_API_KEY=
PI_ANTHROPIC_API_KEY=
PI_GEMINI_API_KEY=
PI_OPENROUTER_API_KEY=

TAILSCALE_ENABLED=0
TAILSCALE_AUTHKEY=
TAILSCALE_HOSTNAME=
EOF
chmod 600 "${env_file}"

export SLUG="${slug}"
export DISPLAY_NAME="${display_name}"
export HOSTNAME_VALUE="${hostname}"
export PROJECT_NAME_VALUE="${project_name}"
export DATA_ROOT_VALUE="\${DATA_ROOT}/tenants/${slug}"
export ENV_FILE_VALUE="\${TENANT_ENV_ROOT}/${slug}.env"

yq eval -i '
  .tenants += [{
    "slug": strenv(SLUG),
    "display_name": strenv(DISPLAY_NAME),
    "hostname": strenv(HOSTNAME_VALUE),
    "enabled": true,
    "project_name": strenv(PROJECT_NAME_VALUE),
    "data_root": strenv(DATA_ROOT_VALUE),
    "env_file": strenv(ENV_FILE_VALUE)
  }]
' "${TENANT_REGISTRY_FILE}"

ensure_tenant_layout "${slug}"
sync_tenant_control_plane_state "${slug}" >/dev/null

if ingress_uses_cloudflare; then
  render_cloudflared_config >/dev/null
fi
render_traefik_dynamic_config >/dev/null

note "Created tenant ${slug}"
note "Env file: ${env_file}"
note "Data root: ${data_root}"
