#!/usr/bin/env bash
set -euo pipefail

PI_WORKSPACE_DIR="${PI_WORKSPACE_DIR:-/data/workspaces/pi}"
PI_HOME="${PI_HOME:-/data/.pi}"
PI_CODING_AGENT_DIR="${PI_CODING_AGENT_DIR:-${PI_HOME}/agent}"
PI_OPENAI_API_KEY="${PI_OPENAI_API_KEY:-}"
PI_ANTHROPIC_API_KEY="${PI_ANTHROPIC_API_KEY:-}"
PI_GEMINI_API_KEY="${PI_GEMINI_API_KEY:-}"
PI_OPENROUTER_API_KEY="${PI_OPENROUTER_API_KEY:-}"
RUNTIME_HOME="${HOME:-/root}"

mkdir -p \
  "${PI_HOME}" \
  "${PI_CODING_AGENT_DIR}" \
  "${PI_WORKSPACE_DIR}" \
  "${RUNTIME_HOME}"

if [[ -e "${RUNTIME_HOME}/.pi" && ! -L "${RUNTIME_HOME}/.pi" ]]; then
  rmdir "${RUNTIME_HOME}/.pi" 2>/dev/null || true
fi
ln -sfn "${PI_HOME}" "${RUNTIME_HOME}/.pi"

cd "${PI_WORKSPACE_DIR}"

if ! command -v pi >/dev/null 2>&1; then
  echo "[pi] Pi coding agent is not installed in this image; opening a shell instead."
  exec /bin/bash
fi

export PI_CODING_AGENT_DIR

if [[ -n "${PI_OPENAI_API_KEY}" ]]; then
  export OPENAI_API_KEY="${PI_OPENAI_API_KEY}"
fi

if [[ -n "${PI_ANTHROPIC_API_KEY}" ]]; then
  export ANTHROPIC_API_KEY="${PI_ANTHROPIC_API_KEY}"
fi

if [[ -n "${PI_GEMINI_API_KEY}" ]]; then
  export GEMINI_API_KEY="${PI_GEMINI_API_KEY}"
fi

if [[ -n "${PI_OPENROUTER_API_KEY}" ]]; then
  export OPENROUTER_API_KEY="${PI_OPENROUTER_API_KEY}"
fi

echo "[pi] Starting Pi coding agent in ${PI_WORKSPACE_DIR}"
echo "[pi] PI_CODING_AGENT_DIR=${PI_CODING_AGENT_DIR}"
if [[ -z "${PI_OPENAI_API_KEY}${PI_ANTHROPIC_API_KEY}${PI_GEMINI_API_KEY}${PI_OPENROUTER_API_KEY}" ]]; then
  echo "[pi] No Pi provider keys were preconfigured. Use /login inside Pi, or set PI_* provider keys if you explicitly want non-interactive auth."
fi
echo "[pi] Exit Pi to return to a shell."

set +e
pi
status=$?
set -e

if [[ "${status}" -ne 0 ]]; then
  echo "[pi] Pi exited with status ${status}."
fi

echo "[pi] Opening a shell."
exec /bin/bash
