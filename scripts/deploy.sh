#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/deploy.sh [--tenant slug] [--shared-only] [--openclaw-version version] [--hermes-version ref]

Deploys shared infrastructure and then all enabled tenants unless a specific tenant is selected.
EOF
}

selected_slug=""
shared_only=0
openclaw_version_override=""
hermes_version_override=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant)
      selected_slug="$2"
      shift 2
      ;;
    --openclaw-version)
      openclaw_version_override="$2"
      shift 2
      ;;
    --hermes-version)
      hermes_version_override="$2"
      shift 2
      ;;
    --shared-only)
      shared_only=1
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
require_command docker

if [[ -n "${openclaw_version_override}" ]]; then
  validate_openclaw_version "${openclaw_version_override}"
  export OPENCLAW_VERSION_OVERRIDE="${openclaw_version_override}"
fi

if [[ -n "${hermes_version_override}" ]]; then
  export HERMES_VERSION_OVERRIDE="${hermes_version_override}"
fi

docker info >/dev/null 2>&1 || die "Docker Desktop is not running"

ensure_directory "${DATA_ROOT}"
ensure_directory "${TENANT_ENV_ROOT}"
ensure_directory "${BACKUP_ROOT}"
ensure_directory "${RELEASE_ROOT}"

release_id="$(date -u +%Y%m%d%H%M%S)"

cache_key_for_version() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9' '_'
}

cached_image_ref_for_version() {
  local version="$1"
  local suffix var_name
  suffix="$(cache_key_for_version "${version}")"
  var_name="OPENCLAW_IMAGE_CACHE_${suffix}"
  printf '%s\n' "${!var_name:-}"
}

cached_image_version_for_version() {
  local version="$1"
  local suffix var_name
  suffix="$(cache_key_for_version "${version}")"
  var_name="OPENCLAW_IMAGE_VERSION_CACHE_${suffix}"
  printf '%s\n' "${!var_name:-}"
}

cache_image_for_version() {
  local version="$1"
  local image_ref="$2"
  local resolved_version="$3"
  local suffix image_var version_var
  suffix="$(cache_key_for_version "${version}")"
  image_var="OPENCLAW_IMAGE_CACHE_${suffix}"
  version_var="OPENCLAW_IMAGE_VERSION_CACHE_${suffix}"
  printf -v "${image_var}" '%s' "${image_ref}"
  printf -v "${version_var}" '%s' "${resolved_version}"
}

release_image_ref_for_version() {
  local version="$1"
  printf '%s:%s-openclaw-%s\n' "${IMAGE_REPOSITORY}" "${release_id}" "${version}"
}

ensure_image_for_tenant() {
  local slug="$1"
  local image_ref image_reported_openclaw_version openclaw_source_tag target_openclaw_version target_hermes_ref resolved_image_openclaw_version version_source hermes_build_args

  target_openclaw_version="$(resolved_openclaw_version "${slug}")"
  version_source="$(resolved_openclaw_version_source "${slug}")"
  image_ref="$(cached_image_ref_for_version "${target_openclaw_version}")"
  resolved_image_openclaw_version="$(cached_image_version_for_version "${target_openclaw_version}")"

  if [[ -n "${image_ref}" ]]; then
    OPENCLAW_DEPLOYED_VERSION="${resolved_image_openclaw_version:-${target_openclaw_version}}"
    export OPENCLAW_DEPLOYED_VERSION
    OPENCLAW_IMAGE="${image_ref}"
    export OPENCLAW_IMAGE
    return 0
  fi

  image_ref="$(release_image_ref_for_version "${target_openclaw_version}")"
  case "${DEPLOY_MODE}" in
    build)
      openclaw_source_tag="$(openclaw_source_tag_for_version "${target_openclaw_version}")"
      target_hermes_ref="$(resolved_hermes_ref)"
      note "Building ${image_ref} with OpenClaw ${target_openclaw_version}, Hermes ${target_hermes_ref}" >&2
      hermes_build_args=()
      if [[ -n "${target_hermes_ref}" ]]; then
        hermes_build_args+=(--build-arg "HERMES_REF=${target_hermes_ref}")
      fi
      docker buildx build --load \
        --build-arg "OPENCLAW_VERSION=${target_openclaw_version}" \
        --build-arg "OPENCLAW_SOURCE_TAG=${openclaw_source_tag}" \
        "${hermes_build_args[@]}" \
        -t "${image_ref}" \
        -f "${REPO_ROOT}/services/rundiffusion-agents/Dockerfile" \
        "${REPO_ROOT}/services/rundiffusion-agents"
      docker tag "${image_ref}" "${IMAGE_REPOSITORY}:latest"
      ;;
    pull)
      [[ -n "${GATEWAY_IMAGE_TAG}" ]] || die "GATEWAY_IMAGE_TAG is required when DEPLOY_MODE=pull"
      image_ref="${IMAGE_REPOSITORY}:${GATEWAY_IMAGE_TAG}"
      if [[ -z "${OPENCLAW_IMAGE_PULL_READY:-}" ]]; then
        note "Pulling ${image_ref}" >&2
        docker pull "${image_ref}"
        OPENCLAW_IMAGE_PULL_READY=1
        export OPENCLAW_IMAGE_PULL_READY
      fi
      ;;
    *)
      die "Unsupported DEPLOY_MODE=${DEPLOY_MODE}"
      ;;
  esac

  image_reported_openclaw_version="$(image_openclaw_version "${image_ref}")"
  resolved_image_openclaw_version="${image_reported_openclaw_version:-${target_openclaw_version}}"

  if [[ "${DEPLOY_MODE}" == "pull" ]]; then
    case "${version_source}" in
      cli_override|tenant_control_plane)
        if [[ -z "${image_reported_openclaw_version}" ]]; then
          die "Requested OpenClaw ${target_openclaw_version} for tenant ${slug}, but pulled image ${image_ref} does not expose an OpenClaw version"
        fi
        if [[ "${image_reported_openclaw_version}" != "${target_openclaw_version}" ]]; then
          die "Requested OpenClaw ${target_openclaw_version} for tenant ${slug}, but pulled image ${image_ref} resolves to ${image_reported_openclaw_version}"
        fi
        ;;
    esac
  fi

  OPENCLAW_DEPLOYED_VERSION="${resolved_image_openclaw_version}"
  export OPENCLAW_DEPLOYED_VERSION
  OPENCLAW_IMAGE="${image_ref}"
  export OPENCLAW_IMAGE
  cache_image_for_version "${target_openclaw_version}" "${image_ref}" "${resolved_image_openclaw_version}"
}

deploy_shared() {
  local shared_dir rendered_cloudflared rendered_traefik rendered_shared_compose
  local traefik_static_config

  rendered_cloudflared=""
  if ingress_uses_cloudflare; then
    rendered_cloudflared="$(render_cloudflared_config)"
  fi
  rendered_traefik="$(render_traefik_dynamic_config)"
  rendered_shared_compose="$(render_shared_compose_config)"
  traefik_static_config="${REPO_ROOT}/deploy/traefik/traefik.yml"

  if shared_traefik_restart_required "${rendered_shared_compose}" "${traefik_static_config}"; then
    note "Shared static config changed; recreating Traefik"
    compose_shared up -d --force-recreate traefik
  else
    note "Shared ingress config unchanged; ensuring Traefik is running without recreation"
    compose_shared up -d traefik
  fi

  smoke_test_shared_local

  shared_dir="$(shared_release_dir "${release_id}")"
  ensure_directory "${shared_dir}"
  cp "${ROOT_ENV_FILE}" "${shared_dir}/root.env.snapshot"
  if [[ -n "${rendered_cloudflared}" ]]; then
    cp "${rendered_cloudflared}" "${shared_dir}/cloudflared.config.yml"
  fi
  cp "${rendered_traefik}" "${shared_dir}/traefik.generated-tenants.yml"
  cp "${REPO_ROOT}/compose.prod.yml" "${shared_dir}/compose.prod.yml"
  cp "${REPO_ROOT}/deploy/traefik/traefik.yml" "${shared_dir}/traefik.yml"
  cp "${REPO_ROOT}/deploy/traefik/dynamic.yml" "${shared_dir}/dynamic.yml"
  cp "${rendered_shared_compose}" "$(shared_release_resolved_compose_file "${release_id}")"
  rm -f "${rendered_shared_compose}"
  record_shared_release_success "${release_id}"
}

deploy_tenant() {
  local slug="$1"
  local previous_release env_file data_root hostname

  tenant_exists "${slug}" || die "Unknown tenant: ${slug}"
  env_file="$(tenant_env_file "${slug}")"
  data_root="$(tenant_data_root "${slug}")"
  hostname="$(tenant_hostname "${slug}")"
  [[ -f "${env_file}" ]] || die "Missing tenant env file: ${env_file}"

  ensure_image_for_tenant "${slug}"
  ensure_tenant_layout "${slug}"
  sync_tenant_control_plane_state "${slug}" >/dev/null
  previous_release="$(tenant_current_release "${slug}")"
  render_traefik_dynamic_config >/dev/null

  if ! compose_tenant "${slug}" up -d; then
    die "Failed to start tenant ${slug}"
  fi

  if ! wait_for_tenant_healthy "${slug}" || ! smoke_test_tenant_local "${slug}"; then
    if [[ "${AUTO_ROLLBACK}" == "1" && -n "${previous_release}" ]]; then
      note "Smoke test failed for ${slug}; rolling back to ${previous_release}"
      "${SCRIPT_DIR}/rollback.sh" --tenant "${slug}" --release "${previous_release}"
    fi
    die "Tenant ${slug} failed smoke tests"
  fi

  record_tenant_release_snapshot \
    "${slug}" \
    "${release_id}" \
    "${env_file}" \
    "${OPENCLAW_IMAGE}" \
    "${data_root}" \
    "${hostname}" \
    "${OPENCLAW_DEPLOYED_VERSION:-}"
}

deploy_shared

if [[ "${shared_only}" -eq 1 ]]; then
  note "Shared infrastructure deployed"
  exit 0
fi

if [[ -n "${selected_slug}" ]]; then
  deploy_tenant "${selected_slug}"
else
  while IFS= read -r slug; do
    [[ -n "${slug}" ]] || continue
    deploy_tenant "${slug}"
  done <<EOF
$(tenant_slugs_enabled)
EOF
fi

note "Deployment finished with release ${release_id}"
