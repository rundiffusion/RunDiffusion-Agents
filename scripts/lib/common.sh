#!/usr/bin/env bash

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${COMMON_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SCRIPTS_DIR}/.." && pwd)"

ROOT_ENV_FILE="${ROOT_ENV_FILE:-${REPO_ROOT}/.env}"
TENANT_REGISTRY_FILE="${REPO_ROOT}/deploy/tenants/tenants.yml"
TENANT_REGISTRY_EXAMPLE_FILE="${REPO_ROOT}/deploy/tenants/tenants.example.yml"
TENANT_COMPOSE_FILE="${REPO_ROOT}/deploy/tenant-stack.compose.yml"
SHARED_COMPOSE_FILE="${REPO_ROOT}/compose.prod.yml"
LAUNCHD_TEMPLATE_FILE="${REPO_ROOT}/deploy/cloudflared/com.rundiffusion.agents.cloudflared.plist.example"

VALID_TENANT_CONTAINER_SECURITY_PROFILES="restricted, tool-userns, privileged"
VALID_INGRESS_MODES="local, direct, cloudflare"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '%s\n' "$*"
}

is_truthy() {
  local normalized_value
  normalized_value="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  case "${normalized_value}" in
    1|true|yes|on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

require_file() {
  local path="$1"
  [[ -f "${path}" ]] || die "Missing required file: ${path}"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

ensure_tenant_registry_file() {
  if [[ -f "${TENANT_REGISTRY_FILE}" ]]; then
    return 0
  fi

  ensure_directory "$(dirname "${TENANT_REGISTRY_FILE}")"

  if [[ -f "${TENANT_REGISTRY_EXAMPLE_FILE}" ]]; then
    cp "${TENANT_REGISTRY_EXAMPLE_FILE}" "${TENANT_REGISTRY_FILE}"
  else
    printf 'tenants: []\n' > "${TENANT_REGISTRY_FILE}"
  fi
}

load_root_env() {
  require_file "${ROOT_ENV_FILE}"
  ensure_tenant_registry_file

  set -a
  # shellcheck disable=SC1090
  . "${ROOT_ENV_FILE}"
  set +a

  : "${COMPOSE_PROJECT_NAME:=rundiffusion-agents}"
  : "${BASE_DOMAIN:=agents.example.com}"
  : "${PUBLIC_URL_SCHEME:=}"
  : "${DATA_ROOT:=${HOME}/rundiffusion-agents/data}"
  : "${TENANT_ENV_ROOT:=${HOME}/rundiffusion-agents/secrets/tenants}"
  : "${TENANT_CONTROL_PLANE_CONFIG_PATH:=${TENANT_ENV_ROOT%/}/control-plane.yml}"
  : "${TRAEFIK_BIND_ADDRESS:=127.0.0.1}"
  : "${TRAEFIK_HTTP_PORT:=38080}"
  : "${TRAEFIK_NETWORK:=rundiffusion-public}"
  : "${TRAEFIK_IMAGE:=traefik:v3.4@sha256:06ddf61ee653caf4f4211a604e657f084f4727f762c16f826c97aafbefcb279e}"
  : "${TRAEFIK_LOG_LEVEL:=INFO}"
  : "${CLOUDFLARE_HOSTNAME_MODE:=wildcard}"
  : "${CLOUDFLARE_TUNNEL_METRICS:=127.0.0.1:20241}"
  : "${CLOUDFLARED_LAUNCHD_LABEL:=com.rundiffusion.agents.cloudflared}"
  : "${DEPLOY_MODE:=build}"
  : "${AUTO_ROLLBACK:=1}"
  : "${IMAGE_REPOSITORY:=local/openclaw-gateway}"
  : "${OPENCLAW_VERSION:=}"
  : "${GATEWAY_IMAGE_TAG:=}"
  : "${NODE_IMAGE_REF:=docker.io/library/node:22-bookworm-slim@sha256:d415caac2f1f77b98caaf9415c5f807e14bc8d7bdea62561ea2fef4fbd08a73c}"
  : "${FILEBROWSER_IMAGE_REF:=ghcr.io/gtsteffaniak/filebrowser:stable-slim@sha256:8e6f7d32f5f0b7a40cb3a80197ef27088f01828a132f5bfed337d77b10e0f1e2}"
  : "${CODEX_CLI_VERSION:=0.125.0}"
  : "${CLAUDE_CODE_VERSION:=2.1.119}"
  : "${GEMINI_CLI_VERSION:=0.39.1}"
  : "${PI_CODING_AGENT_VERSION:=0.70.5}"
  : "${HOMEBREW_INSTALL_REF:=d683ebc428169a5e0d60959e48a4c35d6f23ddd9}"
  : "${HOMEBREW_BREW_REF:=5.1.8}"
  : "${HERMES_REF:=v2026.4.23}"
  : "${HERMES_WEBUI_REF:=v0.50.236}"
  : "${DOCKER_BUILD_CONTEXT:=}"
  : "${DOCKER_BUILDER:=}"
  : "${DOCKER_BUILD_PLATFORM:=}"
  : "${TENANT_MEMORY_RESERVATION:=1536m}"
  : "${TENANT_MEMORY_LIMIT:=3072m}"
  : "${TENANT_PIDS_LIMIT:=512}"
  : "${TENANT_CONTAINER_SECURITY_PROFILE:=tool-userns}"
  : "${MAX_ALWAYS_ON_TENANTS:=8}"
  : "${BACKUP_ROOT:=${DATA_ROOT%/}/backups}"
  : "${RELEASE_ROOT:=${DATA_ROOT%/}/releases}"

  if [[ -z "${INGRESS_MODE:-}" ]]; then
    if [[ -n "${CLOUDFLARE_TUNNEL_ID:-}" || -n "${CLOUDFLARE_TUNNEL_CREDENTIALS_FILE:-}" ]]; then
      INGRESS_MODE="cloudflare"
    else
      INGRESS_MODE="local"
    fi
  fi

  validate_ingress_mode "${INGRESS_MODE}"

  export COMPOSE_PROJECT_NAME BASE_DOMAIN INGRESS_MODE PUBLIC_URL_SCHEME DATA_ROOT TENANT_ENV_ROOT TENANT_CONTROL_PLANE_CONFIG_PATH
  export TRAEFIK_BIND_ADDRESS TRAEFIK_HTTP_PORT TRAEFIK_NETWORK TRAEFIK_IMAGE TRAEFIK_LOG_LEVEL
  export CLOUDFLARE_HOSTNAME_MODE
  export CLOUDFLARE_TUNNEL_ID CLOUDFLARE_TUNNEL_CREDENTIALS_FILE
  export CLOUDFLARE_TUNNEL_METRICS CLOUDFLARED_LAUNCHD_LABEL
  export DEPLOY_MODE AUTO_ROLLBACK IMAGE_REPOSITORY OPENCLAW_VERSION GATEWAY_IMAGE_TAG
  export NODE_IMAGE_REF FILEBROWSER_IMAGE_REF
  export CODEX_CLI_VERSION CLAUDE_CODE_VERSION GEMINI_CLI_VERSION PI_CODING_AGENT_VERSION HOMEBREW_INSTALL_REF HOMEBREW_BREW_REF HERMES_REF HERMES_WEBUI_REF
  export DOCKER_BUILD_CONTEXT DOCKER_BUILDER DOCKER_BUILD_PLATFORM
  export TENANT_MEMORY_RESERVATION TENANT_MEMORY_LIMIT TENANT_PIDS_LIMIT TENANT_CONTAINER_SECURITY_PROFILE
  export MAX_ALWAYS_ON_TENANTS BACKUP_ROOT RELEASE_ROOT ROOT_ENV_FILE TENANT_REGISTRY_FILE TENANT_REGISTRY_EXAMPLE_FILE
}

validate_ingress_mode() {
  case "$1" in
    local|direct|cloudflare)
      ;;
    *)
      die "Unsupported INGRESS_MODE=$1. Allowed values: local, direct, cloudflare"
      ;;
  esac
}

require_base_commands() {
  require_command docker
  require_command jq
  require_command yq
}

dockerfile_default_openclaw_version() {
  awk -F= '/^ARG OPENCLAW_VERSION=/{print $2; exit}' "${REPO_ROOT}/services/rundiffusion-agents/Dockerfile"
}

validate_openclaw_version() {
  local version="$1"
  [[ "${version}" =~ ^[0-9]{4}\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]] ||
    die "Invalid OpenClaw version '${version}'. Use an exact version such as 2026.4.15 or 2026.4.15-beta.1"
}

openclaw_source_tag_for_version() {
  local version="$1"

  case "${version}" in
    2026.3.13)
      printf 'v2026.3.13-1\n'
      ;;
    *)
      printf 'v%s\n' "${version}"
      ;;
  esac
}

tenant_control_plane_openclaw_version() {
  local slug="$1"
  local config_path="${TENANT_CONTROL_PLANE_CONFIG_PATH:-}"
  local version=""

  [[ -n "${slug}" ]] || return 0
  validate_slug "${slug}"
  [[ -n "${config_path}" && -f "${config_path}" ]] || return 0

  export TENANT_LOOKUP_SLUG="${slug}"
  version="$(
    yq eval -o=json '.tenants // {}' "${config_path}" |
      jq -r '
        if type == "array" then
          (map(select(.slug == env.TENANT_LOOKUP_SLUG)) | .[0].openclawVersion // "")
        elif type == "object" then
          .[env.TENANT_LOOKUP_SLUG].openclawVersion // ""
        else
          ""
        end
      ' | head -n 1
  )"

  if [[ -n "${version}" ]]; then
    validate_openclaw_version "${version}"
  fi

  printf '%s\n' "${version}"
}

resolve_openclaw_version() {
  local slug="${1:-}"
  local version=""
  local source=""

  if [[ -n "${OPENCLAW_VERSION_OVERRIDE:-}" ]]; then
    version="${OPENCLAW_VERSION_OVERRIDE}"
    source="cli_override"
  elif [[ -n "${slug}" ]]; then
    version="$(tenant_control_plane_openclaw_version "${slug}")"
    if [[ -n "${version}" ]]; then
      source="tenant_control_plane"
    fi
  fi

  if [[ -z "${version}" && -n "${OPENCLAW_VERSION:-}" ]]; then
    version="${OPENCLAW_VERSION}"
    source="root_env"
  fi

  if [[ -z "${version}" ]]; then
    version="$(dockerfile_default_openclaw_version)"
    source="dockerfile"
  fi

  [[ -n "${version}" ]] || die "Unable to resolve OpenClaw version from env or Dockerfile"
  validate_openclaw_version "${version}"
  printf '%s %s\n' "${version}" "${source}"
}

resolved_openclaw_version_source() {
  local slug="${1:-}"
  local resolved
  resolved="$(resolve_openclaw_version "${slug}")"
  printf '%s\n' "${resolved#* }"
}

resolved_openclaw_version() {
  local slug="${1:-}"
  local resolved
  resolved="$(resolve_openclaw_version "${slug}")"
  printf '%s\n' "${resolved%% *}"
}

ensure_directory() {
  mkdir -p "$1"
}

cloudflared_config_path() {
  printf '%s\n' "${DATA_ROOT%/}/cloudflared/config.yml"
}

cloudflared_log_dir() {
  printf '%s\n' "${DATA_ROOT%/}/cloudflared/logs"
}

cloudflared_log_path() {
  printf '%s\n' "$(cloudflared_log_dir)/cloudflared.log"
}

launch_agent_dir() {
  printf '%s\n' "${HOME}/Library/LaunchAgents"
}

launch_agent_path() {
  printf '%s\n' "$(launch_agent_dir)/${CLOUDFLARED_LAUNCHD_LABEL}.plist"
}

launchd_target() {
  printf 'gui/%s/%s\n' "$(id -u)" "${CLOUDFLARED_LAUNCHD_LABEL}"
}

cloudflared_metrics_url() {
  printf 'http://%s/metrics\n' "${CLOUDFLARE_TUNNEL_METRICS}"
}

ingress_uses_cloudflare() {
  [[ "${INGRESS_MODE}" == "cloudflare" ]]
}

resolved_public_url_scheme() {
  if [[ -n "${PUBLIC_URL_SCHEME}" ]]; then
    printf '%s\n' "${PUBLIC_URL_SCHEME}"
    return 0
  fi

  if ingress_uses_cloudflare; then
    printf 'https\n'
  else
    printf 'http\n'
  fi
}

resolved_public_origin_for_hostname() {
  local hostname="$1"
  local scheme port

  scheme="$(resolved_public_url_scheme)"
  port="${TRAEFIK_HTTP_PORT}"

  # Cloudflare publishes the browser-facing origin on the tunnel hostname,
  # not on Traefik's local bind port.
  if ingress_uses_cloudflare; then
    printf '%s://%s\n' "${scheme}" "${hostname}"
    return 0
  fi

  if [[ "${scheme}" == "http" && "${port}" == "80" ]] || [[ "${scheme}" == "https" && "${port}" == "443" ]]; then
    printf '%s://%s\n' "${scheme}" "${hostname}"
    return 0
  fi

  printf '%s://%s:%s\n' "${scheme}" "${hostname}" "${port}"
}

traefik_probe_host() {
  case "${TRAEFIK_BIND_ADDRESS}" in
    ""|0.0.0.0|::|"[::]")
      printf '127.0.0.1\n'
      ;;
    *)
      printf '%s\n' "${TRAEFIK_BIND_ADDRESS}"
      ;;
  esac
}

cloudflared_ready() {
  curl -fsS --max-time 5 "$(cloudflared_metrics_url)" >/dev/null
}

cloudflared_config_ready() {
  require_cloudflare_tunnel_config
  require_file "$(cloudflared_config_path)"
}

require_cloudflare_tunnel_config() {
  [[ -n "${CLOUDFLARE_TUNNEL_ID:-}" ]] ||
    die "CLOUDFLARE_TUNNEL_ID is required when INGRESS_MODE=cloudflare"
  [[ -n "${CLOUDFLARE_TUNNEL_CREDENTIALS_FILE:-}" ]] ||
    die "CLOUDFLARE_TUNNEL_CREDENTIALS_FILE is required when INGRESS_MODE=cloudflare"
  require_file "${CLOUDFLARE_TUNNEL_CREDENTIALS_FILE}"
}

launchd_loaded() {
  launchctl print "$(launchd_target)" >/dev/null 2>&1
}

expand_registry_value() {
  local value="$1"
  value="${value//\$\{DATA_ROOT\}/${DATA_ROOT}}"
  value="${value//\$\{TENANT_ENV_ROOT\}/${TENANT_ENV_ROOT}}"
  value="${value//\$\{BASE_DOMAIN\}/${BASE_DOMAIN}}"
  value="${value//\$\{COMPOSE_PROJECT_NAME\}/${COMPOSE_PROJECT_NAME}}"
  printf '%s\n' "${value}"
}

tenant_field_raw() {
  local slug="$1"
  local field="$2"

  validate_slug "${slug}"
  validate_registry_field "${field}"

  export TENANT_LOOKUP_SLUG="${slug}"
  yq eval -r '.tenants[]? | select(.slug == strenv(TENANT_LOOKUP_SLUG)) | .[strenv(TENANT_LOOKUP_FIELD)] // ""' "${TENANT_REGISTRY_FILE}" | head -n 1
}

tenant_exists() {
  [[ -n "$(tenant_field_raw "$1" "slug")" ]]
}

tenant_slugs_all() {
  yq eval -r '.tenants[]?.slug' "${TENANT_REGISTRY_FILE}"
}

tenant_slugs_enabled() {
  yq eval -r '.tenants[]? | select(.enabled == true) | .slug' "${TENANT_REGISTRY_FILE}"
}

tenant_enabled() {
  [[ "$(tenant_field_raw "$1" "enabled")" == "true" ]]
}

tenant_display_name() {
  expand_registry_value "$(tenant_field_raw "$1" "display_name")"
}

tenant_hostname() {
  expand_registry_value "$(tenant_field_raw "$1" "hostname")"
}

tenant_project_name() {
  expand_registry_value "$(tenant_field_raw "$1" "project_name")"
}

tenant_data_root() {
  expand_registry_value "$(tenant_field_raw "$1" "data_root")"
}

tenant_env_file() {
  expand_registry_value "$(tenant_field_raw "$1" "env_file")"
}

tenant_managed_env_file() {
  printf '%s\n' "${TENANT_ENV_ROOT%/}/managed/$1.env"
}

tenant_release_root() {
  printf '%s\n' "${RELEASE_ROOT%/}/$1"
}

tenant_history_file() {
  printf '%s\n' "$(tenant_release_root "$1")/history.log"
}

tenant_current_release_file() {
  printf '%s\n' "$(tenant_release_root "$1")/current_release"
}

tenant_current_release() {
  local file
  file="$(tenant_current_release_file "$1")"
  if [[ -f "${file}" ]]; then
    cat "${file}"
  fi
  return 0
}

tenant_previous_release() {
  local slug="$1"
  local history_file current_release

  history_file="$(tenant_history_file "${slug}")"
  current_release="$(tenant_current_release "${slug}")"
  [[ -f "${history_file}" ]] || return 0

  awk -v current="${current_release}" '
    NF { lines[++count] = $0 }
    END {
      for (i = count; i >= 1; i -= 1) {
        if (lines[i] != current) {
          print lines[i]
          exit
        }
      }
    }
  ' "${history_file}"
}

tenant_release_dir() {
  printf '%s\n' "$(tenant_release_root "$1")/$2"
}

tenant_release_image_ref() {
  local path
  path="$(tenant_release_dir "$1" "$2")/image_ref.txt"
  if [[ -f "${path}" ]]; then
    cat "${path}"
  fi
  return 0
}

tenant_release_openclaw_version() {
  local path image_ref
  path="$(tenant_release_dir "$1" "$2")/openclaw_version.txt"
  if [[ -f "${path}" ]]; then
    cat "${path}"
    return 0
  fi

  image_ref="$(tenant_release_image_ref "$1" "$2")"
  if [[ -n "${image_ref}" ]]; then
    image_openclaw_version "${image_ref}"
  fi

  return 0
}

tenant_current_openclaw_version() {
  local current_release
  current_release="$(tenant_current_release "$1")"
  [[ -n "${current_release}" ]] || return 0
  tenant_release_openclaw_version "$1" "${current_release}"
}

record_tenant_release_snapshot() {
  local slug="$1"
  local release_id="$2"
  local env_file="$3"
  local image_ref="$4"
  local data_root="$5"
  local hostname="$6"
  local openclaw_version="$7"
  local tenant_release_dir

  tenant_release_dir="$(tenant_release_dir "${slug}" "${release_id}")"
  ensure_directory "${tenant_release_dir}"
  cp "${env_file}" "${tenant_release_dir}/tenant.env"
  if [[ -f "$(tenant_managed_env_file "${slug}")" ]]; then
    cp "$(tenant_managed_env_file "${slug}")" "${tenant_release_dir}/tenant.managed.env"
  fi
  printf '%s\n' "${image_ref}" > "${tenant_release_dir}/image_ref.txt"
  printf '%s\n' "${data_root}" > "${tenant_release_dir}/data_root.txt"
  printf '%s\n' "${hostname}" > "${tenant_release_dir}/hostname.txt"
  if [[ -n "${openclaw_version}" ]]; then
    printf '%s\n' "${openclaw_version}" > "${tenant_release_dir}/openclaw_version.txt"
  fi
  record_release_success "${slug}" "${release_id}"
}

restore_tenant_env_snapshots() {
  local slug="$1"
  local release_dir="$2"
  local env_snapshot managed_env_snapshot managed_env_file

  env_snapshot="${release_dir}/tenant.env"
  managed_env_snapshot="${release_dir}/tenant.managed.env"
  managed_env_file="$(tenant_managed_env_file "${slug}")"

  require_file "${env_snapshot}"
  cp "${env_snapshot}" "$(tenant_env_file "${slug}")"
  if [[ -f "${managed_env_snapshot}" ]]; then
    cp "${managed_env_snapshot}" "${managed_env_file}"
  else
    rm -f "${managed_env_file}"
  fi
}

purge_tenant_state() {
  local slug="$1"

  rm -rf \
    "$(tenant_env_file "${slug}")" \
    "$(tenant_managed_env_file "${slug}")" \
    "$(tenant_data_root "${slug}")" \
    "$(tenant_release_root "${slug}")" \
    "$(tenant_backup_root "${slug}")"
}

image_env_value() {
  local image_ref="$1"
  local key="$2"

  docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "${image_ref}" 2>/dev/null |
    awk -F= -v key="${key}" '$1 == key { print substr($0, index($0, "=") + 1); exit }'
}

image_openclaw_version() {
  local image_ref="$1"
  local version

  version="$(image_env_value "${image_ref}" "OPENCLAW_EXPECTED_VERSION")"
  if [[ -z "${version}" ]]; then
    version="$(image_env_value "${image_ref}" "OPENCLAW_VERSION")"
  fi

  printf '%s\n' "${version}"
}

set_current_release() {
  local slug="$1"
  local release_id="$2"
  local current_file

  current_file="$(tenant_current_release_file "${slug}")"
  ensure_directory "$(dirname "${current_file}")"
  printf '%s\n' "${release_id}" > "${current_file}"
}

record_release_success() {
  local slug="$1"
  local release_id="$2"
  local history_file

  history_file="$(tenant_history_file "${slug}")"
  ensure_directory "$(dirname "${history_file}")"

  if ! grep -Fxq "${release_id}" "${history_file}" 2>/dev/null; then
    printf '%s\n' "${release_id}" >> "${history_file}"
  fi

  set_current_release "${slug}" "${release_id}"
}

shared_release_root() {
  printf '%s\n' "${RELEASE_ROOT%/}/shared"
}

shared_history_file() {
  printf '%s\n' "$(shared_release_root)/history.log"
}

shared_current_release_file() {
  printf '%s\n' "$(shared_release_root)/current_release"
}

shared_current_release() {
  local file
  file="$(shared_current_release_file)"
  if [[ -f "${file}" ]]; then
    cat "${file}"
  fi
  return 0
}

shared_previous_release() {
  local history_file current_release

  history_file="$(shared_history_file)"
  current_release="$(shared_current_release)"
  [[ -f "${history_file}" ]] || return 0

  awk -v current="${current_release}" '
    NF { lines[++count] = $0 }
    END {
      for (i = count; i >= 1; i -= 1) {
        if (lines[i] != current) {
          print lines[i]
          exit
        }
      }
    }
  ' "${history_file}"
}

shared_release_dir() {
  printf '%s\n' "$(shared_release_root)/$1"
}

shared_release_resolved_compose_file() {
  printf '%s\n' "$(shared_release_dir "$1")/compose.resolved.yml"
}

record_shared_release_success() {
  local release_id="$1"
  local history_file current_file

  history_file="$(shared_history_file)"
  current_file="$(shared_current_release_file)"

  ensure_directory "$(dirname "${history_file}")"
  if ! grep -Fxq "${release_id}" "${history_file}" 2>/dev/null; then
    printf '%s\n' "${release_id}" >> "${history_file}"
  fi

  printf '%s\n' "${release_id}" > "${current_file}"
}

tenant_backup_root() {
  printf '%s\n' "${BACKUP_ROOT%/}/$1"
}

tenant_env_value() {
  local slug="$1"
  local key="$2"
  local env_file

  env_file="$(tenant_env_file "${slug}")"
  [[ -f "${env_file}" ]] || return 0

  awk -F= -v key="${key}" '$1 == key { print substr($0, index($0, "=") + 1) }' "${env_file}" | tail -n 1
}

tenant_env_value_is_true() {
  local slug="$1"
  local key="$2"
  local value

  value="$(tenant_env_value "${slug}" "${key}")"
  is_truthy "${value}"
}

tenant_tailscale_enabled() {
  tenant_env_value_is_true "$1" "TAILSCALE_ENABLED"
}

default_image_ref() {
  local slug="${1:-}"
  local current_release current_image

  if [[ -n "${OPENCLAW_IMAGE:-}" ]]; then
    printf '%s\n' "${OPENCLAW_IMAGE}"
    return 0
  fi

  if [[ -n "${GATEWAY_IMAGE_TAG:-}" ]]; then
    printf '%s\n' "${IMAGE_REPOSITORY}:${GATEWAY_IMAGE_TAG}"
    return 0
  fi

  if [[ -n "${slug}" ]]; then
    current_release="$(tenant_current_release "${slug}")"
    current_image="$(tenant_release_image_ref "${slug}" "${current_release}")"
    if [[ -n "${current_image}" ]]; then
      printf '%s\n' "${current_image}"
      return 0
    fi
  fi

  printf '%s\n' "${IMAGE_REPOSITORY}:latest"
}

ensure_tenant_layout() {
  local slug="$1"
  local data_root env_file

  data_root="$(tenant_data_root "${slug}")"
  env_file="$(tenant_env_file "${slug}")"

  ensure_directory "${data_root}/gateway"
  if tenant_tailscale_enabled "${slug}"; then
    ensure_directory "${data_root}/tailscale"
  fi
  ensure_directory "$(dirname "${env_file}")"
  ensure_directory "$(dirname "$(tenant_managed_env_file "${slug}")")"
  ensure_directory "$(tenant_release_root "${slug}")"
  ensure_directory "$(tenant_backup_root "${slug}")"
}

sync_tenant_control_plane_state() {
  local slug="$1"

  python3 "${REPO_ROOT}/scripts/sync_tenant_control_plane.py" \
    --tenant-slug "${slug}" \
    --tenant-env-file "$(tenant_env_file "${slug}")" \
    --tenant-managed-env-file "$(tenant_managed_env_file "${slug}")" \
    --tenant-data-root "$(tenant_data_root "${slug}")" \
    --control-plane-config-path "${TENANT_CONTROL_PLANE_CONFIG_PATH}"
}

compose_shared() {
  docker compose -f "${SHARED_COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" "$@"
}

render_shared_compose_config() {
  local output_path="${1:-}"

  if [[ -z "${output_path}" ]]; then
    output_path="$(mktemp "${TMPDIR:-/tmp}/openclaw-shared-compose.XXXXXX")"
  fi

  compose_shared config > "${output_path}"
  printf '%s\n' "${output_path}"
}

shared_traefik_restart_required_for_files() {
  local current_compose_file="$1"
  local current_traefik_file="$2"
  local previous_shared_dir="$3"
  local previous_compose_file previous_traefik_file

  [[ -n "${previous_shared_dir}" && -d "${previous_shared_dir}" ]] || return 0

  previous_compose_file="${previous_shared_dir}/compose.resolved.yml"
  previous_traefik_file="${previous_shared_dir}/traefik.yml"

  [[ -f "${previous_compose_file}" ]] || return 0
  [[ -f "${previous_traefik_file}" ]] || return 0

  cmp -s "${current_compose_file}" "${previous_compose_file}" || return 0
  cmp -s "${current_traefik_file}" "${previous_traefik_file}" || return 0

  return 1
}

shared_traefik_restart_required() {
  local current_compose_file="$1"
  local current_traefik_file="$2"
  local current_release

  current_release="$(shared_current_release)"
  if [[ -z "${current_release}" ]]; then
    return 0
  fi

  shared_traefik_restart_required_for_files \
    "${current_compose_file}" \
    "${current_traefik_file}" \
    "$(shared_release_dir "${current_release}")"
}

require_valid_tenant_container_security_profile() {
  case "${TENANT_CONTAINER_SECURITY_PROFILE}" in
    restricted|tool-userns|privileged)
      ;;
    *)
      die "Unsupported TENANT_CONTAINER_SECURITY_PROFILE=${TENANT_CONTAINER_SECURITY_PROFILE}. Allowed values: ${VALID_TENANT_CONTAINER_SECURITY_PROFILES}"
      ;;
  esac
}

render_tenant_security_compose_override() {
  local output_path="$1"

  require_valid_tenant_container_security_profile

  case "${TENANT_CONTAINER_SECURITY_PROFILE}" in
    restricted)
      cat > "${output_path}" <<'EOF'
services:
  openclaw-gateway: {}
EOF
      ;;
    tool-userns)
      cat > "${output_path}" <<'EOF'
services:
  openclaw-gateway:
    cap_add:
      - SYS_ADMIN
    security_opt:
      - seccomp=unconfined
      - apparmor=unconfined
EOF
      ;;
    privileged)
      cat > "${output_path}" <<'EOF'
services:
  openclaw-gateway:
    privileged: true
EOF
      ;;
  esac
}

render_tenant_tailscale_compose_override() {
  local slug="$1"
  local output_path="$2"

  if ! tenant_tailscale_enabled "${slug}"; then
    cat > "${output_path}" <<'EOF'
services:
  openclaw-gateway: {}
EOF
    return 0
  fi

  cat > "${output_path}" <<'EOF'
services:
  openclaw-gateway:
    devices:
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - type: bind
        source: ${TENANT_DATA_ROOT}/tailscale
        target: /var/lib/tailscale
EOF
}

compose_tenant() {
  local slug="$1"
  local security_override_path tailscale_override_path status
  shift

  export TENANT_SLUG="${slug}"
  export TENANT_HOSTNAME="$(tenant_hostname "${slug}")"
  export TENANT_DATA_ROOT="$(tenant_data_root "${slug}")"
  export TENANT_ENV_FILE="$(tenant_env_file "${slug}")"
  export TENANT_MANAGED_ENV_FILE="$(tenant_managed_env_file "${slug}")"
  export OPENCLAW_IMAGE="${OPENCLAW_IMAGE:-$(default_image_ref "${slug}")}"
  require_valid_tenant_container_security_profile
  security_override_path="$(mktemp "${TMPDIR:-/tmp}/openclaw-tenant-security-compose.XXXXXX")"
  tailscale_override_path="$(mktemp "${TMPDIR:-/tmp}/openclaw-tenant-tailscale-compose.XXXXXX")"
  render_tenant_security_compose_override "${security_override_path}"
  render_tenant_tailscale_compose_override "${slug}" "${tailscale_override_path}"

  if docker compose -f "${TENANT_COMPOSE_FILE}" -f "${security_override_path}" -f "${tailscale_override_path}" --project-name "$(tenant_project_name "${slug}")" "$@"; then
    status=0
  else
    status=$?
  fi

  rm -f "${security_override_path}"
  rm -f "${tailscale_override_path}"
  return "${status}"
}

tenant_container_id() {
  compose_tenant "$1" ps -q openclaw-gateway | head -n 1
}

wait_for_container_health() {
  local container_id="$1"
  local timeout_seconds="${2:-180}"
  local started_at now status

  started_at="$(date +%s)"

  while true; do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${container_id}")"
    case "${status}" in
      healthy|running)
        return 0
        ;;
      unhealthy|exited|dead)
        return 1
        ;;
    esac

    now="$(date +%s)"
    if (( now - started_at >= timeout_seconds )); then
      return 1
    fi
    sleep 2
  done
}

wait_for_tenant_healthy() {
  local slug="$1"
  local container_id

  container_id="$(tenant_container_id "${slug}")"
  [[ -n "${container_id}" ]] || die "Tenant ${slug} does not have a running container"

  wait_for_container_health "${container_id}" 240 || die "Tenant ${slug} failed health checks"
}

render_cloudflared_config() {
  local output_path

  ingress_uses_cloudflare || die "INGRESS_MODE=${INGRESS_MODE} does not use cloudflared"
  require_cloudflare_tunnel_config

  output_path="$(cloudflared_config_path)"
  ensure_directory "$(dirname "${output_path}")"

  {
    printf 'tunnel: %s\n' "${CLOUDFLARE_TUNNEL_ID}"
    printf 'credentials-file: %s\n' "${CLOUDFLARE_TUNNEL_CREDENTIALS_FILE}"
    printf 'metrics: %s\n\n' "${CLOUDFLARE_TUNNEL_METRICS}"
    printf 'ingress:\n'

    if [[ "${CLOUDFLARE_HOSTNAME_MODE}" == "wildcard" ]]; then
      printf '  - hostname: "*.%s"\n' "${BASE_DOMAIN}"
      printf '    service: http://127.0.0.1:%s\n' "${TRAEFIK_HTTP_PORT}"
    else
      local slug hostname
      while IFS= read -r slug; do
        [[ -n "${slug}" ]] || continue
        hostname="$(tenant_hostname "${slug}")"
        printf '  - hostname: %s\n' "${hostname}"
        printf '    service: http://127.0.0.1:%s\n' "${TRAEFIK_HTTP_PORT}"
      done <<EOF
$(tenant_slugs_enabled)
EOF
    fi

    printf '  - service: http_status:404\n'
  } > "${output_path}"

  printf '%s\n' "${output_path}"
}

render_traefik_dynamic_config() {
  local output_path
  local temp_path
  local slug
  local hostname
  local wrote_routes=0

  output_path="${DATA_ROOT%/}/traefik/dynamic/generated-tenants.yml"
  ensure_directory "$(dirname "${output_path}")"
  temp_path="$(mktemp "${output_path}.XXXXXX")"

  {
    printf 'http:\n'
    printf '  routers:\n'

    while IFS= read -r slug; do
      [[ -n "${slug}" ]] || continue
      hostname="$(tenant_hostname "${slug}")"
      wrote_routes=1
      printf '    %s-gateway:\n' "${slug}"
      printf '      entryPoints:\n'
      printf '        - web\n'
      printf '      rule: Host(`%s`)\n' "${hostname}"
      printf '      middlewares:\n'
      printf '        - tenant-defaults\n'
      printf '      service: %s-gateway\n' "${slug}"
    done <<EOF
$(tenant_slugs_enabled)
EOF

    if [[ "${wrote_routes}" -eq 0 ]]; then
      printf '    noop:\n'
      printf '      entryPoints:\n'
      printf '        - web\n'
      printf '      rule: Host(`invalid.local`)\n'
      printf '      service: noop@internal\n'
    fi

    printf '  services:\n'

    wrote_routes=0
    while IFS= read -r slug; do
      [[ -n "${slug}" ]] || continue
      wrote_routes=1
      printf '    %s-gateway:\n' "${slug}"
      printf '      loadBalancer:\n'
      printf '        passHostHeader: true\n'
      printf '        servers:\n'
      printf '          - url: http://%s-gateway:8080\n' "${slug}"
    done <<EOF
$(tenant_slugs_enabled)
EOF

    if [[ "${wrote_routes}" -eq 0 ]]; then
      printf '    noop:\n'
      printf '      loadBalancer:\n'
      printf '        servers:\n'
      printf '          - url: http://127.0.0.1:65535\n'
    fi
  } > "${temp_path}"

  if [[ -f "${output_path}" ]]; then
    cat "${temp_path}" > "${output_path}"
    rm -f "${temp_path}"
  else
    mv "${temp_path}" "${output_path}"
  fi

  printf '%s\n' "${output_path}"
}

shared_container_id() {
  compose_shared ps -q traefik | head -n 1
}

smoke_test_shared_local() {
  local container_id

  container_id="$(shared_container_id)"
  [[ -n "${container_id}" ]] || return 1

  wait_for_container_health "${container_id}" 120
}

smoke_test_tunnel_local() {
  cloudflared_ready
}

smoke_test_tenant_local() {
  local slug="$1"
  local hostname user password probe_host
  local attempt

  hostname="$(tenant_hostname "${slug}")"
  probe_host="$(traefik_probe_host)"
  for attempt in 1 2 3 4 5 6; do
    if curl -fsS --max-time 10 -H "Host: ${hostname}" "http://${probe_host}:${TRAEFIK_HTTP_PORT}/healthz" >/dev/null; then
      break
    fi
    sleep 2
  done
  curl -fsS --max-time 10 -H "Host: ${hostname}" "http://${probe_host}:${TRAEFIK_HTTP_PORT}/healthz" >/dev/null

  user="$(tenant_env_value "${slug}" "TERMINAL_BASIC_AUTH_USERNAME")"
  password="$(tenant_env_value "${slug}" "TERMINAL_BASIC_AUTH_PASSWORD")"
  if [[ -n "${user}" && -n "${password}" ]]; then
    for attempt in 1 2 3 4 5 6; do
      if curl -fsS --max-time 10 -u "${user}:${password}" -H "Host: ${hostname}" "http://${probe_host}:${TRAEFIK_HTTP_PORT}/dashboard-api/config" >/dev/null; then
        return 0
      fi
      sleep 2
    done
    curl -fsS --max-time 10 -u "${user}:${password}" -H "Host: ${hostname}" "http://${probe_host}:${TRAEFIK_HTTP_PORT}/dashboard-api/config" >/dev/null
  fi

  return 0
}

random_hex() {
  local bytes="${1:-32}"
  openssl rand -hex "${bytes}"
}

random_password() {
  openssl rand -base64 36 | tr -d '\n=+/' | cut -c1-32
}

validate_slug() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "Invalid slug '$1'. Use lowercase letters, numbers, and hyphens."
}

validate_registry_field() {
  [[ "$1" =~ ^[a-z_][a-z0-9_]*$ ]] || die "Invalid registry field '$1'."
  export TENANT_LOOKUP_FIELD="$1"
}
