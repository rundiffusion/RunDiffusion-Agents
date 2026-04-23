#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/data/workspaces/openclaw}"
HERMES_WORKSPACE_DIR="${HERMES_WORKSPACE_DIR:-/data/workspaces/hermes}"
HERMES_HOME="${HERMES_HOME:-/data/.hermes}"
HERMES_OPENAI_BASE_URL="${HERMES_OPENAI_BASE_URL:-https://generativelanguage.googleapis.com/v1beta/openai/}"
HERMES_MODEL_NAME="${HERMES_MODEL_NAME:-gemini-3-flash-preview}"
HERMES_OPENAI_API_KEY="${HERMES_OPENAI_API_KEY:-${GEMINI_API_KEY:-}}"
OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"
HERMES_PROVIDER_PASSTHROUGH="${HERMES_PROVIDER_PASSTHROUGH:-0}"
MANAGED_CONFIG_HEADER="# Managed by openclaw-gateway."
MANAGED_CONFIG_PATH="${HERMES_HOME}/config.yaml"
RUNTIME_HOME="${HOME:-/root}"

mkdir -p \
  "${HERMES_HOME}" \
  "${HERMES_HOME}/cron" \
  "${HERMES_HOME}/sessions" \
  "${HERMES_HOME}/logs" \
  "${HERMES_HOME}/memories" \
  "${HERMES_HOME}/skills" \
  "${HERMES_HOME}/pairing" \
  "${HERMES_HOME}/hooks" \
  "${HERMES_HOME}/image_cache" \
  "${HERMES_HOME}/audio_cache" \
  "${HERMES_HOME}/whatsapp/session"

mkdir -p "${RUNTIME_HOME}"
ln -sfn "${HERMES_HOME}" "${RUNTIME_HOME}/.hermes"

if [[ "${HERMES_PROVIDER_PASSTHROUGH}" != "1" ]]; then
  if [[ ! -f "${MANAGED_CONFIG_PATH}" ]] || { [ -f "${MANAGED_CONFIG_PATH}" ] && rg -q "^${MANAGED_CONFIG_HEADER}$" "${MANAGED_CONFIG_PATH}" && ! rg -q "^model:$" "${MANAGED_CONFIG_PATH}"; }; then
    cat > "${MANAGED_CONFIG_PATH}" <<EOF
# Managed by openclaw-gateway.
# Use the Hermes CLI inside the terminal to inspect or update this file.
model:
  default: "${HERMES_MODEL_NAME}"
compression:
  summary_model: "${HERMES_MODEL_NAME}"
  summary_provider: "auto"
auxiliary:
  vision:
    provider: "auto"
    model: "${HERMES_MODEL_NAME}"
  web_extract:
    provider: "auto"
    model: "${HERMES_MODEL_NAME}"
EOF
  fi

  if [[ ! -f "${HERMES_HOME}/.env" ]]; then
    cat > "${HERMES_HOME}/.env" <<EOF
# Managed by openclaw-gateway.
# Secrets stay in the container environment by default and do not need to be
# copied here unless you intentionally reconfigure Hermes from inside the CLI.
# OPENROUTER_API_KEY is exported by the launcher when present.
OPENAI_BASE_URL=${HERMES_OPENAI_BASE_URL}
HERMES_MODEL=${HERMES_MODEL_NAME}
LLM_MODEL=${HERMES_MODEL_NAME}
TERMINAL_ENV=local
TERMINAL_CWD=${HERMES_WORKSPACE_DIR}
EOF
    chmod 600 "${HERMES_HOME}/.env"
  fi
fi

mkdir -p "${HERMES_WORKSPACE_DIR}"
cd "${HERMES_WORKSPACE_DIR}"

if ! command -v hermes >/dev/null 2>&1; then
  echo "[hermes] Hermes is not installed in this image; opening a shell instead."
  exec /bin/bash
fi

if [[ "${HERMES_PROVIDER_PASSTHROUGH}" != "1" && -z "${HERMES_OPENAI_API_KEY}" ]]; then
  echo "[hermes] No API key found for Hermes. Set HERMES_OPENAI_API_KEY or GEMINI_API_KEY."
  echo "[hermes] Opening a shell instead."
  exec /bin/bash
fi

export HERMES_HOME
export OPENROUTER_API_KEY
export TERMINAL_ENV=local
export TERMINAL_CWD="${HERMES_WORKSPACE_DIR}"

if [[ "${HERMES_PROVIDER_PASSTHROUGH}" != "1" ]]; then
  export OPENAI_BASE_URL="${HERMES_OPENAI_BASE_URL}"
  export OPENAI_API_KEY="${HERMES_OPENAI_API_KEY}"
  export HERMES_MODEL="${HERMES_MODEL_NAME}"
  export LLM_MODEL="${HERMES_MODEL_NAME}"
fi

echo "[hermes] Starting Hermes in ${HERMES_WORKSPACE_DIR}"
echo "[hermes] HERMES_HOME=${HERMES_HOME}"
echo "[hermes] Exit Hermes to return to a shell."

set +e
hermes
status=$?
set -e

if [[ "${status}" -ne 0 ]]; then
  echo "[hermes] Hermes exited with status ${status}."
fi

echo "[hermes] Opening a shell."
exec /bin/bash
