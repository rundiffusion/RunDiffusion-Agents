#!/usr/bin/env bash
set -euo pipefail

# Runs `hermes gateway run` as a long-lived daemon inside a tmux session.
# Hermes handles messaging-platform polling/webhooks (Telegram, Discord,
# Slack, WhatsApp) and cron scheduling when this process is alive. Without
# it, platform tokens configured via `hermes model` / /data/.hermes/.env
# are inert — no messages in or out.
#
# Managed by openclaw-gateway via ensure_hermes_gateway_session in
# entrypoint.sh when HERMES_GATEWAY_ENABLED=1 and HERMES_ENABLED=1.

HERMES_HOME="${HERMES_HOME:-/data/.hermes}"
HERMES_WORKSPACE_DIR="${HERMES_WORKSPACE_DIR:-/data/workspaces/hermes}"
export HERMES_HOME

if ! command -v hermes >/dev/null 2>&1; then
  echo "[hermes-gateway] Hermes is not installed in this image; exiting." >&2
  exec /bin/bash
fi

mkdir -p "${HERMES_HOME}/logs" "${HERMES_WORKSPACE_DIR}"
cd "${HERMES_WORKSPACE_DIR}"

echo "[hermes-gateway] Starting Hermes messaging/cron gateway"
echo "[hermes-gateway] HERMES_HOME=${HERMES_HOME}"
echo "[hermes-gateway] Logs: ${HERMES_HOME}/logs/agent.log"

# --replace auto-kills any stale instance from a prior container restart.
# Foreground execution; tmux session holds the process. Exits to a shell on
# error so an operator can attach to the tmux session and investigate.
set +e
hermes gateway run --replace
status=$?
set -e

if [[ "${status}" -ne 0 ]]; then
  echo "[hermes-gateway] Gateway exited with status ${status}."
fi

echo "[hermes-gateway] Opening a shell."
exec /bin/bash
