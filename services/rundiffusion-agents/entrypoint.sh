#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8080}"
OPENCLAW_INTERNAL_PORT="${OPENCLAW_INTERNAL_PORT:-8081}"
OPENCLAW_ACCESS_MODE="${OPENCLAW_ACCESS_MODE:-native}"
OPENCLAW_GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND:-loopback}"
OPENCLAW_EXPECTED_VERSION="${OPENCLAW_EXPECTED_VERSION:-}"
OPENCLAW_RUNTIME_DIR="${OPENCLAW_RUNTIME_DIR:-/usr/local/lib/node_modules/openclaw}"
OPENCLAW_PRISTINE_DIR="${OPENCLAW_PRISTINE_DIR:-/opt/openclaw-pristine/openclaw}"
OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/data/workspaces/openclaw}"
OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-${OPENCLAW_STATE_DIR}/openclaw.json}"
NODE_COMPILE_CACHE="${NODE_COMPILE_CACHE:-/var/tmp/openclaw-compile-cache}"
OPENCLAW_NO_RESPAWN="${OPENCLAW_NO_RESPAWN:-0}"
FILEBROWSER_INTERNAL_PORT="${FILEBROWSER_INTERNAL_PORT:-8082}"
FILEBROWSER_BASE_URL="${FILEBROWSER_BASE_URL:-/filebrowser}"
DASHBOARD_INTERNAL_PORT="${DASHBOARD_INTERNAL_PORT:-8094}"
DASHBOARD_BIND="${DASHBOARD_BIND:-127.0.0.1}"
DASHBOARD_BASE_URL="${DASHBOARD_BASE_URL:-/dashboard}"
DASHBOARD_API_BASE_URL="${DASHBOARD_API_BASE_URL:-/dashboard-api}"
TERMINAL_ENABLED="${TERMINAL_ENABLED:-0}"
TERMINAL_INTERNAL_PORT="${TERMINAL_INTERNAL_PORT:-8083}"
TERMINAL_BASE_URL="${TERMINAL_BASE_URL:-/terminal}"
TERMINAL_SESSION_NAME="${TERMINAL_SESSION_NAME:-openclaw}"
TTYD_INTERFACE="${TTYD_INTERFACE:-127.0.0.1}"
TTYD_TERMINAL_TYPE="${TTYD_TERMINAL_TYPE:-xterm-256color}"
TTYD_CLIENT_RENDERER_TYPE="${TTYD_CLIENT_RENDERER_TYPE:-dom}"
TTYD_CLIENT_FONT_FAMILY="${TTYD_CLIENT_FONT_FAMILY:-ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace}"
TTYD_CLIENT_FONT_SIZE="${TTYD_CLIENT_FONT_SIZE:-14}"
TTYD_CLIENT_SCROLLBACK="${TTYD_CLIENT_SCROLLBACK:-50000}"
TERMINAL_LANG="${TERMINAL_LANG:-C.UTF-8}"
TERMINAL_LC_ALL="${TERMINAL_LC_ALL:-C.UTF-8}"
TERMINAL_COLORTERM="${TERMINAL_COLORTERM:-truecolor}"
OPENCLAW_TTY_TERM_PROGRAM="${OPENCLAW_TTY_TERM_PROGRAM:-OpenClawTTYD}"
TERMINAL_BASIC_AUTH_USERNAME="${TERMINAL_BASIC_AUTH_USERNAME:-${OPENCLAW_BASIC_AUTH_USERNAME:-}}"
TERMINAL_BASIC_AUTH_PASSWORD="${TERMINAL_BASIC_AUTH_PASSWORD:-${OPENCLAW_BASIC_AUTH_PASSWORD:-}}"
HERMES_ENABLED="${HERMES_ENABLED:-1}"
HERMES_AUTO_LAUNCH="${HERMES_AUTO_LAUNCH:-1}"
HERMES_INTERNAL_PORT="${HERMES_INTERNAL_PORT:-8090}"
HERMES_BASE_URL="${HERMES_BASE_URL:-/hermes}"
HERMES_SESSION_NAME="${HERMES_SESSION_NAME:-hermes}"
HERMES_HOME="${HERMES_HOME:-/data/.hermes}"
HERMES_WORKSPACE_DIR="${HERMES_WORKSPACE_DIR:-/data/workspaces/hermes}"
HERMES_OPENAI_BASE_URL="${HERMES_OPENAI_BASE_URL:-https://generativelanguage.googleapis.com/v1beta/openai/}"
HERMES_MODEL_NAME="${HERMES_MODEL_NAME:-gemini-3-flash-preview}"
HERMES_OPENAI_API_KEY="${HERMES_OPENAI_API_KEY:-${GEMINI_API_KEY:-}}"
HERMES_PROVIDER_PASSTHROUGH="${HERMES_PROVIDER_PASSTHROUGH:-0}"
HERMES_GATEWAY_ENABLED="${HERMES_GATEWAY_ENABLED:-0}"
CODEX_ENABLED="${CODEX_ENABLED:-1}"
CODEX_INTERNAL_PORT="${CODEX_INTERNAL_PORT:-8091}"
CODEX_BASE_URL="${CODEX_BASE_URL:-/codex}"
CODEX_SESSION_NAME="${CODEX_SESSION_NAME:-codex}"
CODEX_HOME="${CODEX_HOME:-/data/.codex}"
CODEX_WORKSPACE_DIR="${CODEX_WORKSPACE_DIR:-/data/workspaces/codex}"
CODEX_OPENAI_API_KEY="${CODEX_OPENAI_API_KEY:-}"
CLAUDE_ENABLED="${CLAUDE_ENABLED:-1}"
CLAUDE_INTERNAL_PORT="${CLAUDE_INTERNAL_PORT:-8192}"
CLAUDE_BASE_URL="${CLAUDE_BASE_URL:-/claude}"
CLAUDE_SESSION_NAME="${CLAUDE_SESSION_NAME:-claude}"
CLAUDE_HOME="${CLAUDE_HOME:-/data/.claude}"
CLAUDE_WORKSPACE_DIR="${CLAUDE_WORKSPACE_DIR:-/data/workspaces/claude}"
CLAUDE_ANTHROPIC_API_KEY="${CLAUDE_ANTHROPIC_API_KEY:-}"
GEMINI_ENABLED="${GEMINI_ENABLED:-0}"
GEMINI_INTERNAL_PORT="${GEMINI_INTERNAL_PORT:-8093}"
GEMINI_BASE_URL="${GEMINI_BASE_URL:-/gemini}"
GEMINI_SESSION_NAME="${GEMINI_SESSION_NAME:-gemini}"
GEMINI_HOME="${GEMINI_HOME:-/data/.gemini}"
GEMINI_WORKSPACE_DIR="${GEMINI_WORKSPACE_DIR:-/data/workspaces/gemini}"
GEMINI_CLI_API_KEY="${GEMINI_CLI_API_KEY:-}"
OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"
TAILSCALE_ENABLED="${TAILSCALE_ENABLED:-0}"
TAILSCALE_STATE_DIR="${TAILSCALE_STATE_DIR:-/var/lib/tailscale}"
TAILSCALE_RUN_DIR="${TAILSCALE_RUN_DIR:-/var/run/tailscale}"
TAILSCALE_SOCKET="${TAILSCALE_SOCKET:-${TAILSCALE_RUN_DIR}/tailscaled.sock}"
TAILSCALE_LOG_PATH="${TAILSCALE_LOG_PATH:-/var/log/tailscaled.log}"
TAILSCALE_AUTHKEY="${TAILSCALE_AUTHKEY:-}"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-}"
FILEBROWSER_DATA_DIR="${FILEBROWSER_DATA_DIR:-/data/.filebrowser}"
FILEBROWSER_CONFIG_PATH="${FILEBROWSER_CONFIG_PATH:-/tmp/filebrowser-config.yaml}"
FILEBROWSER_DATABASE_PATH="${FILEBROWSER_DATABASE_PATH:-${FILEBROWSER_DATA_DIR}/database.db}"
FILEBROWSER_CACHE_DIR="${FILEBROWSER_CACHE_DIR:-${FILEBROWSER_DATA_DIR}/cache}"
FILEBROWSER_TOOL_FILES_DIR="${FILEBROWSER_TOOL_FILES_DIR:-/data/tool-files}"
OPENCLAW_RECONCILE_SUMMARY_PATH="${OPENCLAW_RECONCILE_SUMMARY_PATH:-${OPENCLAW_STATE_DIR}/reconcile-summary.json}"
NGINX_CONFIG_PATH="${NGINX_CONFIG_PATH:-/tmp/openclaw-gateway-nginx.conf}"
OPENCLAW_ROUTE_AUTH_INCLUDE_PATH="${OPENCLAW_ROUTE_AUTH_INCLUDE_PATH:-/tmp/openclaw-gateway-openclaw-auth.inc}"
TERMINAL_ROUTE_AUTH_INCLUDE_PATH="${TERMINAL_ROUTE_AUTH_INCLUDE_PATH:-/tmp/openclaw-gateway-terminal-auth.inc}"
OPENCLAW_PROXY_AUTH_USER_FILE_PATH="${OPENCLAW_PROXY_AUTH_USER_FILE_PATH:-/tmp/openclaw-gateway-openclaw-auth.htpasswd}"
TERMINAL_PROXY_AUTH_USER_FILE_PATH="${TERMINAL_PROXY_AUTH_USER_FILE_PATH:-/tmp/openclaw-gateway-terminal-auth.htpasswd}"
GATEWAY_READY_FILE="${GATEWAY_READY_FILE:-/tmp/openclaw-gateway-ready}"
GATEWAY_HEALTH_POLL_INTERVAL_SECONDS=2
GATEWAY_HEALTH_READY_GRACE_SECONDS=15
GATEWAY_HEALTH_FATAL_GRACE_SECONDS=120

rm -f "${GATEWAY_READY_FILE}"

ensure_workspace_shortcut() {
  local workspace_dir="$1"
  local shortcut_name="$2"
  local target_dir="$3"

  if [[ -z "${workspace_dir}" || -z "${shortcut_name}" || -z "${target_dir}" ]]; then
    return 0
  fi

  mkdir -p "${workspace_dir}"
  if [[ "${workspace_dir}" == "${target_dir}" ]]; then
    return 0
  fi

  ln -sfn "${target_dir}" "${workspace_dir}/${shortcut_name}"
}

ensure_directory_shortcut() {
  ensure_workspace_shortcut "$@"
}

remove_workspace_shortcut_if_symlink() {
  local workspace_dir="$1"
  local shortcut_name="$2"
  local shortcut_path

  if [[ -z "${workspace_dir}" || -z "${shortcut_name}" ]]; then
    return 0
  fi

  shortcut_path="${workspace_dir}/${shortcut_name}"
  if [[ -L "${shortcut_path}" ]]; then
    rm -f "${shortcut_path}"
  fi
}

ensure_visible_directory_readme() {
  local target_dir="$1"
  local title="$2"
  local readme_path="${target_dir}/README.md"
  local entry_name
  local has_visible_entry=0

  if [[ -z "${target_dir}" || -z "${title}" ]]; then
    return 0
  fi

  mkdir -p "${target_dir}"

  shopt -s nullglob
  for entry_path in "${target_dir}"/*; do
    entry_name="$(basename "${entry_path}")"
    if [[ "${entry_name}" == "README.md" ]]; then
      continue
    fi
    has_visible_entry=1
    break
  done
  shopt -u nullglob

  if [[ "${has_visible_entry}" -eq 1 || -f "${readme_path}" ]]; then
    return 0
  fi

  cat > "${readme_path}" <<EOF
# ${title}

This directory is managed by the OpenClaw gateway deployment.

It will stay empty until this route or tool writes files here.
EOF
}

normalize_base_url() {
  local label="$1"
  local value="$2"

  if [[ -z "${value}" || "${value:0:1}" != "/" ]]; then
    echo "[entrypoint] ${label} must start with /"
    exit 1
  fi

  if [[ "${value}" != "/" ]]; then
    value="${value%/}"
  fi

  printf '%s' "${value}"
}

TERMINAL_BASE_URL="$(normalize_base_url TERMINAL_BASE_URL "${TERMINAL_BASE_URL}")"
HERMES_BASE_URL="$(normalize_base_url HERMES_BASE_URL "${HERMES_BASE_URL}")"
CODEX_BASE_URL="$(normalize_base_url CODEX_BASE_URL "${CODEX_BASE_URL}")"
CLAUDE_BASE_URL="$(normalize_base_url CLAUDE_BASE_URL "${CLAUDE_BASE_URL}")"
GEMINI_BASE_URL="$(normalize_base_url GEMINI_BASE_URL "${GEMINI_BASE_URL}")"
DASHBOARD_BASE_URL="$(normalize_base_url DASHBOARD_BASE_URL "${DASHBOARD_BASE_URL}")"
DASHBOARD_API_BASE_URL="$(normalize_base_url DASHBOARD_API_BASE_URL "${DASHBOARD_API_BASE_URL}")"

export OPENCLAW_INTERNAL_PORT
export OPENCLAW_ACCESS_MODE
export OPENCLAW_GATEWAY_BIND
export OPENCLAW_EXPECTED_VERSION
export OPENCLAW_RUNTIME_DIR
export OPENCLAW_PRISTINE_DIR
export OPENCLAW_RECONCILE_SUMMARY_PATH
export NODE_COMPILE_CACHE
export OPENCLAW_NO_RESPAWN
export FILEBROWSER_BASE_URL
export DASHBOARD_INTERNAL_PORT
export DASHBOARD_BIND
export DASHBOARD_BASE_URL
export DASHBOARD_API_BASE_URL
export TERMINAL_BASE_URL
export TERMINAL_ENABLED
export TERMINAL_INTERNAL_PORT
export TTYD_INTERFACE
export TTYD_TERMINAL_TYPE
export TTYD_CLIENT_RENDERER_TYPE
export TTYD_CLIENT_FONT_FAMILY
export TTYD_CLIENT_FONT_SIZE
export TTYD_CLIENT_SCROLLBACK
export TERMINAL_BASIC_AUTH_USERNAME
export HERMES_ENABLED
export HERMES_AUTO_LAUNCH
export HERMES_BASE_URL
export HERMES_INTERNAL_PORT
export HERMES_HOME
export HERMES_WORKSPACE_DIR
export HERMES_OPENAI_BASE_URL
export HERMES_MODEL_NAME
export HERMES_OPENAI_API_KEY
export HERMES_PROVIDER_PASSTHROUGH
export HERMES_GATEWAY_ENABLED
export CODEX_ENABLED
export CODEX_BASE_URL
export CODEX_INTERNAL_PORT
export CODEX_SESSION_NAME
export CODEX_HOME
export CODEX_WORKSPACE_DIR
export CODEX_OPENAI_API_KEY
export CLAUDE_ENABLED
export CLAUDE_BASE_URL
export CLAUDE_INTERNAL_PORT
export CLAUDE_SESSION_NAME
export CLAUDE_HOME
export CLAUDE_WORKSPACE_DIR
export CLAUDE_ANTHROPIC_API_KEY
export GEMINI_ENABLED
export GEMINI_BASE_URL
export GEMINI_INTERNAL_PORT
export GEMINI_SESSION_NAME
export GEMINI_HOME
export GEMINI_WORKSPACE_DIR
export GEMINI_CLI_API_KEY
export OPENROUTER_API_KEY
export TAILSCALE_SOCKET
export TAILSCALE_STATE_DIR
export TAILSCALE_LOG_PATH
export FILEBROWSER_CONFIG_PATH
export FILEBROWSER_DATA_DIR
export FILEBROWSER_DATABASE_PATH
export FILEBROWSER_CACHE_DIR
export FILEBROWSER_INTERNAL_PORT
export FILEBROWSER_TOOL_FILES_DIR
export LANG="${TERMINAL_LANG}"
export LC_ALL="${TERMINAL_LC_ALL}"
export COLORTERM="${TERMINAL_COLORTERM}"
export TERM_PROGRAM="${OPENCLAW_TTY_TERM_PROGRAM}"

OPENCLAW_MAIN_AGENT_DIR="${OPENCLAW_STATE_DIR}/agents/main"
OPENCLAW_MAIN_AGENT_STATE_DIR="${OPENCLAW_MAIN_AGENT_DIR}/agent"
OPENCLAW_MAIN_AGENT_SESSION_DIR="${OPENCLAW_MAIN_AGENT_DIR}/sessions"

# Pre-create the standard on-disk layout doctor expects so repairs work on
# first boot, even before the user has created sessions or agent state.
mkdir -p \
  "${OPENCLAW_STATE_DIR}" \
  "${OPENCLAW_MAIN_AGENT_STATE_DIR}" \
  "${OPENCLAW_MAIN_AGENT_SESSION_DIR}" \
  "${OPENCLAW_WORKSPACE_DIR}/skills" \
  "${HERMES_HOME}" \
  "${HERMES_WORKSPACE_DIR}" \
  "${CODEX_HOME}" \
  "${CODEX_WORKSPACE_DIR}" \
  "${CLAUDE_HOME}" \
  "${CLAUDE_WORKSPACE_DIR}" \
  "${GEMINI_HOME}" \
  "${GEMINI_WORKSPACE_DIR}" \
  "${FILEBROWSER_DATA_DIR}" \
  "${FILEBROWSER_CACHE_DIR}" \
  "${FILEBROWSER_TOOL_FILES_DIR}" \
  "${NODE_COMPILE_CACHE}"
chmod 700 \
  "${OPENCLAW_STATE_DIR}" \
  "${OPENCLAW_STATE_DIR}/agents" \
  "${OPENCLAW_MAIN_AGENT_DIR}" \
  "${OPENCLAW_MAIN_AGENT_STATE_DIR}" \
  "${OPENCLAW_MAIN_AGENT_SESSION_DIR}" \
  "${HERMES_HOME}" \
  "${CODEX_HOME}" \
  "${CLAUDE_HOME}" \
  "${GEMINI_HOME}" || true

for workspace_dir in "${CODEX_WORKSPACE_DIR}" "${CLAUDE_WORKSPACE_DIR}" "${GEMINI_WORKSPACE_DIR}"; do
  remove_workspace_shortcut_if_symlink "${workspace_dir}" "openclaw-workspace"
  remove_workspace_shortcut_if_symlink "${workspace_dir}" "hermes-workspace"
done

ensure_directory_shortcut "${FILEBROWSER_TOOL_FILES_DIR}" "Hermes Home" "${HERMES_HOME}"
ensure_directory_shortcut "${FILEBROWSER_TOOL_FILES_DIR}" "Codex Home" "${CODEX_HOME}"
ensure_directory_shortcut "${FILEBROWSER_TOOL_FILES_DIR}" "Claude Home" "${CLAUDE_HOME}"
ensure_directory_shortcut "${FILEBROWSER_TOOL_FILES_DIR}" "Gemini Home" "${GEMINI_HOME}"
ensure_directory_shortcut "${FILEBROWSER_TOOL_FILES_DIR}" "OpenClaw State" "${OPENCLAW_STATE_DIR}"
ensure_directory_shortcut "${FILEBROWSER_TOOL_FILES_DIR}" "FileBrowser State" "${FILEBROWSER_DATA_DIR}"

ensure_visible_directory_readme "${OPENCLAW_WORKSPACE_DIR}" "OpenClaw Workspace"
ensure_visible_directory_readme "${HERMES_WORKSPACE_DIR}" "Hermes Workspace"
ensure_visible_directory_readme "${CODEX_WORKSPACE_DIR}" "Codex Workspace"
ensure_visible_directory_readme "${CLAUDE_WORKSPACE_DIR}" "Claude Workspace"
ensure_visible_directory_readme "${GEMINI_WORKSPACE_DIR}" "Gemini Workspace"
ensure_visible_directory_readme "${HERMES_HOME}" "Hermes Home"
ensure_visible_directory_readme "${CODEX_HOME}" "Codex Home"
ensure_visible_directory_readme "${CLAUDE_HOME}" "Claude Home"
ensure_visible_directory_readme "${GEMINI_HOME}" "Gemini Home"

TOKEN_PATH="${OPENCLAW_STATE_DIR}/gateway.token"

if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  if [[ -s "${TOKEN_PATH}" ]]; then
    OPENCLAW_GATEWAY_TOKEN="$(cat "${TOKEN_PATH}")"
  else
    OPENCLAW_GATEWAY_TOKEN="$(node -e 'process.stdout.write(require("crypto").randomBytes(32).toString("hex"))')"
    printf '%s' "${OPENCLAW_GATEWAY_TOKEN}" > "${TOKEN_PATH}"
    chmod 600 "${TOKEN_PATH}"
  fi
fi

export OPENCLAW_GATEWAY_TOKEN

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'
}

is_true() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

terminal_enabled() {
  is_true "${TERMINAL_ENABLED}"
}

hermes_enabled() {
  is_true "${HERMES_ENABLED}"
}

hermes_gateway_enabled() {
  hermes_enabled && is_true "${HERMES_GATEWAY_ENABLED}"
}

codex_enabled() {
  is_true "${CODEX_ENABLED}"
}

claude_enabled() {
  is_true "${CLAUDE_ENABLED}"
}

gemini_enabled() {
  is_true "${GEMINI_ENABLED}"
}

tailscale_enabled() {
  is_true "${TAILSCALE_ENABLED}"
}

operator_tty_enabled() {
  terminal_enabled || hermes_enabled || codex_enabled || claude_enabled || gemini_enabled
}

resolve_openclaw_access_mode() {
  local requested_mode
  requested_mode="$(printf '%s' "${OPENCLAW_ACCESS_MODE:-}" | tr '[:upper:]' '[:lower:]')"

  case "${requested_mode}" in
    trusted-proxy|proxy)
      printf '%s' "trusted-proxy"
      ;;
    native|token|"")
      printf '%s' "native"
      ;;
    *)
      echo "[entrypoint] OPENCLAW_ACCESS_MODE=${OPENCLAW_ACCESS_MODE} is unsupported; falling back to native."
      printf '%s' "native"
      ;;
  esac
}

openclaw_proxy_auth_enabled() {
  [[ "$(resolve_openclaw_access_mode)" == "trusted-proxy" ]] &&
    [[ -n "${OPENCLAW_BASIC_AUTH_USERNAME:-}" ]] &&
    [[ -n "${OPENCLAW_BASIC_AUTH_PASSWORD:-}" ]]
}

terminal_proxy_auth_enabled() {
  [[ -n "${TERMINAL_BASIC_AUTH_USERNAME:-}" ]] && [[ -n "${TERMINAL_BASIC_AUTH_PASSWORD:-}" ]]
}

wait_for_tcp_listener() {
  local label="$1"
  local port="$2"
  local attempts="${3:-60}"
  local attempt

  for ((attempt = 1; attempt <= attempts; attempt += 1)); do
    if nc -z 127.0.0.1 "${port}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo "[entrypoint] Timed out waiting for ${label} on internal port ${port}."
  exit 1
}

write_gateway_ready_file() {
  printf 'ok\n' > "${GATEWAY_READY_FILE}"
}

clear_gateway_ready_file() {
  rm -f "${GATEWAY_READY_FILE}"
}

openclaw_runtime_report() {
  node /app/openclaw_runtime.js check
}

repair_openclaw_runtime() {
  node /app/openclaw_runtime.js repair
}

start_gateway_health_monitor() {
  (
    local last_healthy_epoch now unhealthy_for
    last_healthy_epoch="$(date +%s)"

    while true; do
      if ! openclaw_runtime_report >/dev/null 2>&1; then
        echo "[entrypoint] OpenClaw runtime drift detected while the container is running; restoring the pinned runtime and restarting the container."
        clear_gateway_ready_file
        if ! repair_openclaw_runtime >/dev/null; then
          echo "[entrypoint] OpenClaw runtime repair failed; restarting the container so Docker can retry."
        fi
        kill -TERM "$$"
        return 1
      fi

      if nc -z 127.0.0.1 "${OPENCLAW_INTERNAL_PORT}" >/dev/null 2>&1; then
        last_healthy_epoch="$(date +%s)"
        if [[ ! -s "${GATEWAY_READY_FILE}" ]]; then
          write_gateway_ready_file
        fi
      else
        now="$(date +%s)"
        unhealthy_for=$((now - last_healthy_epoch))

        if (( unhealthy_for >= GATEWAY_HEALTH_READY_GRACE_SECONDS )); then
          clear_gateway_ready_file
        fi

        if (( unhealthy_for >= GATEWAY_HEALTH_FATAL_GRACE_SECONDS )); then
          echo "[entrypoint] OpenClaw gateway has been unavailable for ${unhealthy_for}s; restarting the container."
          kill -TERM "$$"
          return 1
        fi
      fi

      sleep "${GATEWAY_HEALTH_POLL_INTERVAL_SECONDS}"
    done
  ) &
  HEALTH_MONITOR_PID=$!
}

validate_unique_operator_routes() {
  local -n labels_ref=$1
  local -n ports_ref=$2
  local -n base_urls_ref=$3
  local -n sessions_ref=$4
  local i j

  for ((i = 0; i < ${#labels_ref[@]}; i += 1)); do
    for ((j = i + 1; j < ${#labels_ref[@]}; j += 1)); do
      if [[ "${ports_ref[$i]}" == "${ports_ref[$j]}" ]]; then
        echo "[entrypoint] ${labels_ref[$i]} and ${labels_ref[$j]} must use different internal ports."
        exit 1
      fi

      if [[ "${base_urls_ref[$i]}" == "${base_urls_ref[$j]}" ]]; then
        echo "[entrypoint] ${labels_ref[$i]} and ${labels_ref[$j]} must use different base URLs."
        exit 1
      fi

      if [[ "${sessions_ref[$i]}" == "${sessions_ref[$j]}" ]]; then
        echo "[entrypoint] ${labels_ref[$i]} and ${labels_ref[$j]} must use different tmux session names."
        exit 1
      fi
    done
  done
}

assert_unique_internal_port() {
  local label="$1"
  local candidate_port="$2"
  shift 2
  local existing_port

  for existing_port in "$@"; do
    if [[ "${candidate_port}" == "${existing_port}" ]]; then
      echo "[entrypoint] ${label}=${candidate_port} conflicts with another internal port."
      exit 1
    fi
  done
}

assert_unique_base_url() {
  local label="$1"
  local candidate_url="$2"
  shift 2
  local existing_url

  for existing_url in "$@"; do
    if [[ "${candidate_url}" == "${existing_url}" ]]; then
      echo "[entrypoint] ${label}=${candidate_url} conflicts with another base URL."
      exit 1
    fi
  done
}

validate_terminal_config() {
  local route_labels=()
  local route_ports=()
  local route_base_urls=()
  local route_sessions=()

  if [[ -z "${TERMINAL_BASIC_AUTH_USERNAME:-}" || -z "${TERMINAL_BASIC_AUTH_PASSWORD:-}" ]]; then
    echo "[entrypoint] FileBrowser and operator routes require TERMINAL_BASIC_AUTH_USERNAME and TERMINAL_BASIC_AUTH_PASSWORD (or OPENCLAW_BASIC_AUTH_* fallback values)."
    exit 1
  fi

  if terminal_enabled && [[ "${TERMINAL_BASE_URL}" == "/" ]]; then
    echo "[entrypoint] TERMINAL_BASE_URL cannot be /"
    exit 1
  fi

  if terminal_enabled; then
    route_labels+=("TERMINAL")
    route_ports+=("${TERMINAL_INTERNAL_PORT}")
    route_base_urls+=("${TERMINAL_BASE_URL}")
    route_sessions+=("${TERMINAL_SESSION_NAME}")
  fi

  if hermes_enabled && [[ "${HERMES_BASE_URL}" == "/" ]]; then
    echo "[entrypoint] HERMES_BASE_URL cannot be / when HERMES_ENABLED=1."
    exit 1
  fi

  if hermes_enabled; then
    route_labels+=("HERMES")
    route_ports+=("${HERMES_INTERNAL_PORT}")
    route_base_urls+=("${HERMES_BASE_URL}")
    route_sessions+=("${HERMES_SESSION_NAME}")
  fi

  if codex_enabled && [[ "${CODEX_BASE_URL}" == "/" ]]; then
    echo "[entrypoint] CODEX_BASE_URL cannot be / when CODEX_ENABLED=1."
    exit 1
  fi

  if codex_enabled; then
    route_labels+=("CODEX")
    route_ports+=("${CODEX_INTERNAL_PORT}")
    route_base_urls+=("${CODEX_BASE_URL}")
    route_sessions+=("${CODEX_SESSION_NAME}")
  fi

  if claude_enabled && [[ "${CLAUDE_BASE_URL}" == "/" ]]; then
    echo "[entrypoint] CLAUDE_BASE_URL cannot be / when CLAUDE_ENABLED=1."
    exit 1
  fi

  if claude_enabled; then
    route_labels+=("CLAUDE")
    route_ports+=("${CLAUDE_INTERNAL_PORT}")
    route_base_urls+=("${CLAUDE_BASE_URL}")
    route_sessions+=("${CLAUDE_SESSION_NAME}")
  fi

  if gemini_enabled && [[ "${GEMINI_BASE_URL}" == "/" ]]; then
    echo "[entrypoint] GEMINI_BASE_URL cannot be / when GEMINI_ENABLED=1."
    exit 1
  fi

  if gemini_enabled; then
    route_labels+=("GEMINI")
    route_ports+=("${GEMINI_INTERNAL_PORT}")
    route_base_urls+=("${GEMINI_BASE_URL}")
    route_sessions+=("${GEMINI_SESSION_NAME}")
  fi

  validate_unique_operator_routes route_labels route_ports route_base_urls route_sessions
}

validate_dashboard_config() {
  if [[ "${DASHBOARD_BASE_URL}" == "/" ]]; then
    echo "[entrypoint] DASHBOARD_BASE_URL cannot be /."
    exit 1
  fi

  if [[ "${DASHBOARD_API_BASE_URL}" == "/" ]]; then
    echo "[entrypoint] DASHBOARD_API_BASE_URL cannot be /."
    exit 1
  fi

  if [[ "${DASHBOARD_BASE_URL}" == "${DASHBOARD_API_BASE_URL}" ]]; then
    echo "[entrypoint] DASHBOARD_BASE_URL and DASHBOARD_API_BASE_URL must be different."
    exit 1
  fi

  assert_unique_internal_port \
    "DASHBOARD_INTERNAL_PORT" \
    "${DASHBOARD_INTERNAL_PORT}" \
    "${OPENCLAW_INTERNAL_PORT}" \
    "${FILEBROWSER_INTERNAL_PORT}" \
    "${TERMINAL_INTERNAL_PORT}" \
    "${HERMES_INTERNAL_PORT}" \
    "${CODEX_INTERNAL_PORT}" \
    "${CLAUDE_INTERNAL_PORT}" \
    "${GEMINI_INTERNAL_PORT}"

  assert_unique_base_url \
    "DASHBOARD_BASE_URL" \
    "${DASHBOARD_BASE_URL}" \
    "/openclaw" \
    "${FILEBROWSER_BASE_URL}" \
    "${TERMINAL_BASE_URL}" \
    "${HERMES_BASE_URL}" \
    "${CODEX_BASE_URL}" \
    "${CLAUDE_BASE_URL}" \
    "${GEMINI_BASE_URL}"

  assert_unique_base_url \
    "DASHBOARD_API_BASE_URL" \
    "${DASHBOARD_API_BASE_URL}" \
    "/openclaw" \
    "${FILEBROWSER_BASE_URL}" \
    "${TERMINAL_BASE_URL}" \
    "${HERMES_BASE_URL}" \
    "${CODEX_BASE_URL}" \
    "${CLAUDE_BASE_URL}" \
    "${GEMINI_BASE_URL}" \
    "${DASHBOARD_BASE_URL}"
}

write_nginx_config() {
  local esc_public_port esc_openclaw_port esc_filebrowser_port esc_dashboard_port esc_dashboard_base_url esc_dashboard_api_base_url esc_terminal_port esc_terminal_base_url esc_hermes_port esc_hermes_base_url esc_codex_port esc_codex_base_url esc_claude_port esc_claude_base_url esc_gemini_port esc_gemini_base_url terminal_enabled_flag hermes_enabled_flag codex_enabled_flag claude_enabled_flag gemini_enabled_flag
  esc_public_port="$(escape_sed "${PORT}")"
  esc_openclaw_port="$(escape_sed "${OPENCLAW_INTERNAL_PORT}")"
  esc_filebrowser_port="$(escape_sed "${FILEBROWSER_INTERNAL_PORT}")"
  esc_dashboard_port="$(escape_sed "${DASHBOARD_INTERNAL_PORT}")"
  esc_dashboard_base_url="$(escape_sed "${DASHBOARD_BASE_URL}")"
  esc_dashboard_api_base_url="$(escape_sed "${DASHBOARD_API_BASE_URL}")"
  esc_terminal_port="$(escape_sed "${TERMINAL_INTERNAL_PORT}")"
  esc_terminal_base_url="$(escape_sed "${TERMINAL_BASE_URL}")"
  esc_hermes_port="$(escape_sed "${HERMES_INTERNAL_PORT}")"
  esc_hermes_base_url="$(escape_sed "${HERMES_BASE_URL}")"
  esc_codex_port="$(escape_sed "${CODEX_INTERNAL_PORT}")"
  esc_codex_base_url="$(escape_sed "${CODEX_BASE_URL}")"
  esc_claude_port="$(escape_sed "${CLAUDE_INTERNAL_PORT}")"
  esc_claude_base_url="$(escape_sed "${CLAUDE_BASE_URL}")"
  esc_gemini_port="$(escape_sed "${GEMINI_INTERNAL_PORT}")"
  esc_gemini_base_url="$(escape_sed "${GEMINI_BASE_URL}")"
  if terminal_enabled; then
    terminal_enabled_flag="1"
  else
    terminal_enabled_flag="0"
  fi
  if hermes_enabled; then
    hermes_enabled_flag="1"
  else
    hermes_enabled_flag="0"
  fi
  if codex_enabled; then
    codex_enabled_flag="1"
  else
    codex_enabled_flag="0"
  fi
  if claude_enabled; then
    claude_enabled_flag="1"
  else
    claude_enabled_flag="0"
  fi
  if gemini_enabled; then
    gemini_enabled_flag="1"
  else
    gemini_enabled_flag="0"
  fi

  sed \
    -e "s|__PUBLIC_PORT__|${esc_public_port}|g" \
    -e "s|__OPENCLAW_INTERNAL_PORT__|${esc_openclaw_port}|g" \
    -e "s|__FILEBROWSER_INTERNAL_PORT__|${esc_filebrowser_port}|g" \
    -e "s|__DASHBOARD_INTERNAL_PORT__|${esc_dashboard_port}|g" \
    -e "s|__DASHBOARD_BASE_URL__|${esc_dashboard_base_url}|g" \
    -e "s|__DASHBOARD_API_BASE_URL__|${esc_dashboard_api_base_url}|g" \
    -e "s|__TERMINAL_INTERNAL_PORT__|${esc_terminal_port}|g" \
    -e "s|__TERMINAL_BASE_URL__|${esc_terminal_base_url}|g" \
    -e "s|__TERMINAL_ENABLED__|${terminal_enabled_flag}|g" \
    -e "s|__HERMES_INTERNAL_PORT__|${esc_hermes_port}|g" \
    -e "s|__HERMES_BASE_URL__|${esc_hermes_base_url}|g" \
    -e "s|__HERMES_ENABLED__|${hermes_enabled_flag}|g" \
    -e "s|__CODEX_INTERNAL_PORT__|${esc_codex_port}|g" \
    -e "s|__CODEX_BASE_URL__|${esc_codex_base_url}|g" \
    -e "s|__CODEX_ENABLED__|${codex_enabled_flag}|g" \
    -e "s|__CLAUDE_INTERNAL_PORT__|${esc_claude_port}|g" \
    -e "s|__CLAUDE_BASE_URL__|${esc_claude_base_url}|g" \
    -e "s|__CLAUDE_ENABLED__|${claude_enabled_flag}|g" \
    -e "s|__GEMINI_INTERNAL_PORT__|${esc_gemini_port}|g" \
    -e "s|__GEMINI_BASE_URL__|${esc_gemini_base_url}|g" \
    -e "s|__GEMINI_ENABLED__|${gemini_enabled_flag}|g" \
    /app/nginx.template.conf > "${NGINX_CONFIG_PATH}"
}

write_basic_auth_include() {
  local include_path user_file_path enabled
  include_path="$1"
  user_file_path="$2"
  enabled="$3"

  if [[ "${enabled}" != "1" ]]; then
    printf '%s\n' 'auth_basic off;' > "${include_path}"
    chmod 644 "${include_path}"
    return
  fi

  {
    printf '%s\n' 'auth_basic "OpenClaw";'
    printf 'auth_basic_user_file %s;\n' "${user_file_path}"
  } > "${include_path}"
  chmod 644 "${include_path}"
}

write_htpasswd_file() {
  local username password output_path
  username="$1"
  password="$2"
  output_path="$3"

  node - "${username}" "${password}" "${output_path}" <<'NODE'
const crypto = require("crypto");
const fs = require("fs");

const [, , username, password, outputPath] = process.argv;

if (!username || username.includes(":") || /[\r\n]/.test(username)) {
  console.error("[entrypoint] OPENCLAW_BASIC_AUTH_USERNAME must not be empty or contain ':' or newlines.");
  process.exit(1);
}

function buildSshaHash(secret) {
  const salt = crypto.randomBytes(8);
  const digest = crypto.createHash("sha1").update(Buffer.from(secret, "utf8")).update(salt).digest();
  return `{SSHA}${Buffer.concat([digest, salt]).toString("base64")}`;
}

fs.writeFileSync(outputPath, `${username}:${buildSshaHash(password)}\n`, { mode: 0o600 });
NODE
  chmod 644 "${output_path}"
}

write_proxy_auth_config() {
  local openclaw_username openclaw_password terminal_username terminal_password
  openclaw_username="${OPENCLAW_BASIC_AUTH_USERNAME:-}"
  openclaw_password="${OPENCLAW_BASIC_AUTH_PASSWORD:-}"
  terminal_username="${TERMINAL_BASIC_AUTH_USERNAME:-}"
  terminal_password="${TERMINAL_BASIC_AUTH_PASSWORD:-}"

  if [[ -n "${openclaw_username}" && -z "${openclaw_password}" ]] || [[ -z "${openclaw_username}" && -n "${openclaw_password}" ]]; then
    echo "[entrypoint] OPENCLAW_BASIC_AUTH_USERNAME and OPENCLAW_BASIC_AUTH_PASSWORD must both be set or both be omitted."
    exit 1
  fi

  if [[ -n "${terminal_username}" && -z "${terminal_password}" ]] || [[ -z "${terminal_username}" && -n "${terminal_password}" ]]; then
    echo "[entrypoint] TERMINAL_BASIC_AUTH_USERNAME and TERMINAL_BASIC_AUTH_PASSWORD must both be set or both be omitted."
    exit 1
  fi

  if openclaw_proxy_auth_enabled; then
    write_htpasswd_file "${openclaw_username}" "${openclaw_password}" "${OPENCLAW_PROXY_AUTH_USER_FILE_PATH}"
    write_basic_auth_include "${OPENCLAW_ROUTE_AUTH_INCLUDE_PATH}" "${OPENCLAW_PROXY_AUTH_USER_FILE_PATH}" 1
    echo "[entrypoint] OpenClaw routes protected by proxy Basic Auth for username ${openclaw_username}."
  else
    write_basic_auth_include "${OPENCLAW_ROUTE_AUTH_INCLUDE_PATH}" "${OPENCLAW_PROXY_AUTH_USER_FILE_PATH}" 0
    rm -f "${OPENCLAW_PROXY_AUTH_USER_FILE_PATH}"
    echo "[entrypoint] OpenClaw routes using native OpenClaw auth."
  fi

  if terminal_proxy_auth_enabled; then
    write_htpasswd_file "${terminal_username}" "${terminal_password}" "${TERMINAL_PROXY_AUTH_USER_FILE_PATH}"
    write_basic_auth_include "${TERMINAL_ROUTE_AUTH_INCLUDE_PATH}" "${TERMINAL_PROXY_AUTH_USER_FILE_PATH}" 1
    echo "[entrypoint] Terminal route protected by proxy Basic Auth for username ${terminal_username}."
  else
    write_basic_auth_include "${TERMINAL_ROUTE_AUTH_INCLUDE_PATH}" "${TERMINAL_PROXY_AUTH_USER_FILE_PATH}" 0
    rm -f "${TERMINAL_PROXY_AUTH_USER_FILE_PATH}"
  fi
}

configure_filebrowser() {
  node /app/configure_filebrowser.js
}

reconcile_filebrowser_permissions() {
  if ! node /app/reconcile_filebrowser_permissions.js; then
    echo "[entrypoint] Warning: FileBrowser permission reconciliation failed; continuing startup."
  fi
}

ensure_tmux_session() {
  local label="$1"
  local session_name="$2"
  local workspace_dir="$3"
  local launch_command="$4"

  if tmux has-session -t "${session_name}" 2>/dev/null; then
    echo "[entrypoint] Reusing tmux session ${session_name}."
  else
    echo "[entrypoint] Creating ${label} tmux session ${session_name} in ${workspace_dir}."
    TMUX="" tmux new-session -d -s "${session_name}" -c "${workspace_dir}" "${launch_command}"
  fi

  configure_tmux_server
}

ensure_terminal_session() {
  if ! terminal_enabled; then
    return 0
  fi

  ensure_tmux_session "terminal" "${TERMINAL_SESSION_NAME}" "${OPENCLAW_WORKSPACE_DIR}" "/bin/bash"
}

ensure_hermes_session() {
  if ! hermes_enabled; then
    return 0
  fi

  ensure_tmux_session "Hermes" "${HERMES_SESSION_NAME}" "${HERMES_WORKSPACE_DIR}" "/app/launch_hermes_terminal.sh"
}

ensure_hermes_gateway_session() {
  if ! hermes_gateway_enabled; then
    return 0
  fi

  ensure_tmux_session "Hermes Gateway" "hermes-gateway" "${HERMES_WORKSPACE_DIR}" "/app/launch_hermes_gateway.sh"
}

ensure_codex_session() {
  if ! codex_enabled; then
    return 0
  fi

  ensure_tmux_session "Codex" "${CODEX_SESSION_NAME}" "${CODEX_WORKSPACE_DIR}" "/app/launch_codex_terminal.sh"
}

ensure_claude_session() {
  if ! claude_enabled; then
    return 0
  fi

  ensure_tmux_session "Claude" "${CLAUDE_SESSION_NAME}" "${CLAUDE_WORKSPACE_DIR}" "/app/launch_claude_terminal.sh"
}

ensure_gemini_session() {
  if ! gemini_enabled; then
    return 0
  fi

  ensure_tmux_session "Gemini" "${GEMINI_SESSION_NAME}" "${GEMINI_WORKSPACE_DIR}" "/app/launch_gemini_terminal.sh"
}

configure_tmux_server() {
  tmux set-option -g default-terminal "tmux-256color"
  tmux set-option -g terminal-overrides ",${TTYD_TERMINAL_TYPE}:RGB,tmux-256color:RGB,screen-256color:RGB"
  tmux set-option -g mouse on
  tmux set-option -g history-limit 50000
  tmux set-environment -g LANG "${TERMINAL_LANG}"
  tmux set-environment -g LC_ALL "${TERMINAL_LC_ALL}"
  tmux set-environment -g COLORTERM "${TERMINAL_COLORTERM}"
  tmux set-environment -g TERM_PROGRAM "${OPENCLAW_TTY_TERM_PROGRAM}"
  tmux bind-key m run-shell 'current="$(tmux show -gv mouse)"; if [ "$current" = "on" ]; then tmux set -g mouse off; tmux display-message "Mouse off: normal drag-select enabled, wheel scroll disabled"; else tmux set -g mouse on; tmux display-message "Mouse on: wheel scroll enabled, press F6 to copy/select"; fi'
  tmux bind-key -n F6 run-shell 'current="$(tmux show -gv mouse)"; if [ "$current" = "on" ]; then tmux set -g mouse off; tmux display-message "Mouse off: normal drag-select enabled, wheel scroll disabled"; else tmux set -g mouse on; tmux display-message "Mouse on: wheel scroll enabled, press F6 to copy/select"; fi'
}

validate_terminal_config
validate_dashboard_config
repair_openclaw_runtime >/dev/null
echo "[entrypoint] OpenClaw runtime integrity verified."

TAILSCALE_PID=""

start_tailscale() {
  local tailscale_state_file effective_hostname attempt

  if ! tailscale_enabled; then
    echo "[entrypoint] Tailscale disabled."
    return 0
  fi

  if [[ ! -c /dev/net/tun ]]; then
    echo "[entrypoint] Tailscale is enabled but /dev/net/tun is unavailable. Redeploy this tenant with the TUN device mounted."
    exit 1
  fi

  mkdir -p "${TAILSCALE_STATE_DIR}" "${TAILSCALE_RUN_DIR}" "$(dirname "${TAILSCALE_LOG_PATH}")"
  chmod 700 "${TAILSCALE_STATE_DIR}" || true

  tailscale_state_file="${TAILSCALE_STATE_DIR}/tailscaled.state"

  echo "[entrypoint] Starting tailscaled with state ${tailscale_state_file}"
  /usr/sbin/tailscaled \
    --state="${tailscale_state_file}" \
    --socket="${TAILSCALE_SOCKET}" \
    >> "${TAILSCALE_LOG_PATH}" 2>&1 &
  TAILSCALE_PID=$!

  for ((attempt = 1; attempt <= 30; attempt += 1)); do
    if [[ -S "${TAILSCALE_SOCKET}" ]] && kill -0 "${TAILSCALE_PID}" >/dev/null 2>&1; then
      if [[ -n "${TAILSCALE_AUTHKEY}" ]]; then
        effective_hostname="${TAILSCALE_HOSTNAME:-${TENANT_SLUG:-$(hostname)}}"
        echo "[entrypoint] Running tailscale up for hostname ${effective_hostname}"
        tailscale --socket="${TAILSCALE_SOCKET}" up \
          --auth-key="${TAILSCALE_AUTHKEY}" \
          --hostname="${effective_hostname}"
      else
        echo "[entrypoint] tailscaled is ready; authenticate with: tailscale --socket=${TAILSCALE_SOCKET} up"
      fi
      return 0
    fi
    sleep 1
  done

  echo "[entrypoint] Timed out waiting for tailscaled to become ready. See ${TAILSCALE_LOG_PATH}."
  exit 1
}

reconcile_gateway_state() {
  node /app/reconcile_openclaw_state.js
}

reconcile_gateway_state
echo "[entrypoint] Gateway config reconciliation complete."

if hermes_enabled && ! is_true "${HERMES_AUTO_LAUNCH}"; then
  echo "[entrypoint] HERMES_AUTO_LAUNCH is deprecated and ignored; use HERMES_ENABLED=0 to disable /hermes."
fi

if hermes_enabled && [[ -z "${HERMES_OPENAI_API_KEY:-}" ]]; then
  echo "[entrypoint] Hermes is enabled but no HERMES_OPENAI_API_KEY or GEMINI_API_KEY was provided; /hermes will fall back to a shell."
fi

if codex_enabled && [[ -z "${CODEX_OPENAI_API_KEY:-}" ]]; then
  echo "[entrypoint] Codex is enabled without CODEX_OPENAI_API_KEY; /codex will expect interactive login until the user authenticates."
fi

if claude_enabled && [[ -z "${CLAUDE_ANTHROPIC_API_KEY:-}" ]]; then
  echo "[entrypoint] Claude is enabled without CLAUDE_ANTHROPIC_API_KEY; /claude will expect interactive login until the user authenticates."
fi

if gemini_enabled && [[ -z "${GEMINI_CLI_API_KEY:-}" ]]; then
  echo "[entrypoint] Gemini is enabled without GEMINI_CLI_API_KEY; /gemini will expect interactive login until the user authenticates."
fi

start_tailscale
write_proxy_auth_config
write_nginx_config
configure_filebrowser
ensure_terminal_session
ensure_hermes_session
ensure_hermes_gateway_session
ensure_codex_session
ensure_claude_session
ensure_gemini_session

OPENCLAW_PID=""
FILEBROWSER_PID=""
DASHBOARD_PID=""
TERMINAL_PID=""
HERMES_PID=""
CODEX_PID=""
CLAUDE_PID=""
GEMINI_PID=""
NGINX_PID=""
HEALTH_MONITOR_PID=""

cleanup() {
  local exit_code=$?
  trap - EXIT INT TERM

  clear_gateway_ready_file

  for pid in "${HEALTH_MONITOR_PID:-}" "${NGINX_PID:-}" "${GEMINI_PID:-}" "${CLAUDE_PID:-}" "${CODEX_PID:-}" "${HERMES_PID:-}" "${TERMINAL_PID:-}" "${DASHBOARD_PID:-}" "${FILEBROWSER_PID:-}" "${OPENCLAW_PID:-}" "${TAILSCALE_PID:-}"; do
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
    fi
  done

  wait || true
  exit "${exit_code}"
}

trap cleanup EXIT INT TERM

echo "[entrypoint] Starting OpenClaw gateway on internal port ${OPENCLAW_INTERNAL_PORT} with bind ${OPENCLAW_GATEWAY_BIND}"
openclaw gateway --port "${OPENCLAW_INTERNAL_PORT}" --bind "${OPENCLAW_GATEWAY_BIND}" &
OPENCLAW_PID=$!

echo "[entrypoint] Starting FileBrowser Quantum on internal port ${FILEBROWSER_INTERNAL_PORT}"
(
  cd /opt/filebrowser
  exec ./filebrowser -c "${FILEBROWSER_CONFIG_PATH}"
) &
FILEBROWSER_PID=$!

echo "[entrypoint] Starting dashboard server on internal port ${DASHBOARD_INTERNAL_PORT}${DASHBOARD_BASE_URL}"
node /app/dashboard_server.js &
DASHBOARD_PID=$!

start_ttyd_route() {
  local enabled_fn="$1"
  local pid_var_name="$2"
  local log_label="$3"
  local internal_port="$4"
  local base_url="$5"
  local session_name="$6"
  local tty_title="$7"
  local disabled_message="$8"

  if ! "${enabled_fn}"; then
    echo "${disabled_message}"
    return 0
  fi

  local -a ttyd_args=(
    --interface "${TTYD_INTERFACE}"
    --port "${internal_port}"
    --base-path "${base_url}"
    --writable
    --terminal-type "${TTYD_TERMINAL_TYPE}"
    --ping-interval 30
    --client-option "titleFixed=${tty_title}"
    --client-option "fontFamily=${TTYD_CLIENT_FONT_FAMILY}"
    --client-option "fontSize=${TTYD_CLIENT_FONT_SIZE}"
    --client-option "scrollback=${TTYD_CLIENT_SCROLLBACK}"
    --client-option "rendererType=${TTYD_CLIENT_RENDERER_TYPE}"
    --client-option macOptionClickForcesSelection=true
    --client-option altClickMovesCursor=false
  )

  echo "[entrypoint] Starting ${log_label} ttyd on internal port ${internal_port}${base_url}"
  ttyd "${ttyd_args[@]}" tmux attach-session -t "${session_name}" &
  printf -v "${pid_var_name}" '%s' "$!"
}

build_tty_title() {
  local route_title="$1"
  local tenant_label="${TENANT_SLUG:-${TERMINAL_BASIC_AUTH_USERNAME:-operator}}"
  printf '%s | %s | RunDiffusion Agents' "${route_title}" "${tenant_label}"
}

start_ttyd_route terminal_enabled TERMINAL_PID "terminal" "${TERMINAL_INTERNAL_PORT}" "${TERMINAL_BASE_URL}" "${TERMINAL_SESSION_NAME}" "$(build_tty_title "Terminal")" "[entrypoint] Terminal route disabled."
start_ttyd_route hermes_enabled HERMES_PID "Hermes" "${HERMES_INTERNAL_PORT}" "${HERMES_BASE_URL}" "${HERMES_SESSION_NAME}" "$(build_tty_title "Hermes")" "[entrypoint] Hermes route disabled."
start_ttyd_route codex_enabled CODEX_PID "Codex" "${CODEX_INTERNAL_PORT}" "${CODEX_BASE_URL}" "${CODEX_SESSION_NAME}" "$(build_tty_title "Codex")" "[entrypoint] Codex route disabled."
start_ttyd_route claude_enabled CLAUDE_PID "Claude" "${CLAUDE_INTERNAL_PORT}" "${CLAUDE_BASE_URL}" "${CLAUDE_SESSION_NAME}" "$(build_tty_title "Claude")" "[entrypoint] Claude route disabled."
start_ttyd_route gemini_enabled GEMINI_PID "Gemini" "${GEMINI_INTERNAL_PORT}" "${GEMINI_BASE_URL}" "${GEMINI_SESSION_NAME}" "$(build_tty_title "Gemini")" "[entrypoint] Gemini route disabled."

wait_for_tcp_listener "OpenClaw gateway" "${OPENCLAW_INTERNAL_PORT}"
wait_for_tcp_listener "FileBrowser Quantum" "${FILEBROWSER_INTERNAL_PORT}"
reconcile_filebrowser_permissions
wait_for_tcp_listener "dashboard server" "${DASHBOARD_INTERNAL_PORT}"

if terminal_enabled; then
  wait_for_tcp_listener "terminal ttyd" "${TERMINAL_INTERNAL_PORT}"
fi

if hermes_enabled; then
  wait_for_tcp_listener "Hermes ttyd" "${HERMES_INTERNAL_PORT}"
fi

if codex_enabled; then
  wait_for_tcp_listener "Codex ttyd" "${CODEX_INTERNAL_PORT}"
fi

if claude_enabled; then
  wait_for_tcp_listener "Claude ttyd" "${CLAUDE_INTERNAL_PORT}"
fi

if gemini_enabled; then
  wait_for_tcp_listener "Gemini ttyd" "${GEMINI_INTERNAL_PORT}"
fi

write_gateway_ready_file
echo "[entrypoint] Gateway readiness file written to ${GATEWAY_READY_FILE}"
start_gateway_health_monitor

echo "[entrypoint] Starting nginx proxy on public port ${PORT}"
nginx -c "${NGINX_CONFIG_PATH}" -g 'daemon off;' &
NGINX_PID=$!

WAIT_PIDS=("${FILEBROWSER_PID}" "${DASHBOARD_PID}" "${NGINX_PID}" "${HEALTH_MONITOR_PID}")
if is_true "${OPENCLAW_NO_RESPAWN}"; then
  WAIT_PIDS=("${OPENCLAW_PID}" "${WAIT_PIDS[@]}")
else
  echo "[entrypoint] OPENCLAW_NO_RESPAWN is disabled; not binding container lifecycle to the initial gateway pid so full-process restarts can complete."
fi
if [[ -n "${TAILSCALE_PID}" ]]; then
  WAIT_PIDS=("${TAILSCALE_PID}" "${WAIT_PIDS[@]}")
fi
for pid in "${TERMINAL_PID}" "${HERMES_PID}" "${CODEX_PID}" "${CLAUDE_PID}" "${GEMINI_PID}"; do
  if [[ -n "${pid}" ]]; then
    WAIT_PIDS+=("${pid}")
  fi
done

wait -n "${WAIT_PIDS[@]}"
