# OpenClaw Gateway Operator Notes

**Jump to:** [Auth & Access](#auth--access) · [Workspace & Tools](#workspace--tools) · [Operations](#operations) · [Notes](#notes)

---

## Auth & Access

This service supports two auth modes for `/openclaw`:

- `OPENCLAW_ACCESS_MODE=native`: OpenClaw's built-in gateway token + device pairing flow
- `OPENCLAW_ACCESS_MODE=trusted-proxy`: nginx Basic Auth in front of OpenClaw

The recommended mode is `native`.

This image is a one-service path router. Keep `/openclaw` on native auth and keep all sibling paths on the same host unless you are deliberately changing the service topology.

For browser origin and HTTPS requirements, see [OpenClaw Origin & Auth Expectations](../../docs/configuration.md#openclaw-origin--auth-expectations).

### Native Operator Flow

In native mode, the operator uses:

| Route | Purpose |
| --- | --- |
| `/dashboard` | Operator landing page for sibling tools and utilities |
| `/openclaw` | OpenClaw dashboard |
| `/terminal` | Shell access, recovery, and device approval |
| `/hermes` | Hermes delegated task engine |
| `/codex` | OpenAI Codex CLI |
| `/claude` | Claude Code CLI |
| `/gemini` | Gemini CLI |

Required env for the recommended standalone native deployment:

```env
OPENCLAW_ACCESS_MODE=native
OPENCLAW_GATEWAY_TOKEN=<long-random-secret>

TERMINAL_ENABLED=1
TERMINAL_BASIC_AUTH_USERNAME=<terminal-username>
TERMINAL_BASIC_AUTH_PASSWORD=<separate-terminal-password>
HERMES_ENABLED=1
CODEX_ENABLED=1
CLAUDE_ENABLED=1
GEMINI_ENABLED=0
```

`OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` is optional when `RAILWAY_PUBLIC_DOMAIN` matches the browser origin. Set it explicitly for custom domains, multiple origins, or any host where you prefer an exact allowlist. For the recommended local Docker path: `http://127.0.0.1:8080,http://localhost:8080`.

`/dashboard` and `/filebrowser` share the same Basic Auth credentials as `/terminal`.

### First Login to `/openclaw`

1. Open `/openclaw`
2. Paste the `OPENCLAW_GATEWAY_TOKEN` into the dashboard token field
3. Click `Connect`
4. If the dashboard says `pairing required`, do not keep retrying
5. Open `/terminal` and log in with Basic Auth credentials
6. Run `approve-device`
7. Select the most recent pending browser device and press Enter
8. Return to `/openclaw` and connect once

Repeated retries before approval can trigger rate limiting (`Too many unauthorized attempts`).

### Dashboard

`/dashboard` is a small embedded operator shell providing:

- Left sidebar: OpenClaw, Hermes, Codex, Claude Code, Gemini, Terminal, FileBrowser
- Same-origin embedded views for sibling tools
- "Open in new tab" escape hatches for every tool
- Utilities section with device approval and gateway restart helpers

Protected by the same Basic Auth as `/terminal` and `/filebrowser`.

---

## Workspace & Tools

### Workspace Layout

| Route | Workspace Dir | Config Home | Enable Var |
| --- | --- | --- | --- |
| `/terminal` | `/data/workspaces/openclaw` | — | `TERMINAL_ENABLED` |
| `/hermes` | `/data/workspaces/hermes` | `/data/.hermes` | `HERMES_ENABLED` |
| `/codex` | `/data/workspaces/codex` | `/data/.codex` | `CODEX_ENABLED` |
| `/claude` | `/data/workspaces/claude` | `/data/.claude` | `CLAUDE_ENABLED` |
| `/gemini` | `/data/workspaces/gemini` | `/data/.gemini` | `GEMINI_ENABLED` |

OpenClaw boots without a wrapper-selected model or provider profile. The wrapper only keeps the gateway auth/path/workspace contract in place. Use the OpenClaw UI for first model/provider onboarding.

### Tool Configuration

**Hermes (`/hermes`):**
- Uses `GEMINI_API_KEY` by default for Google's OpenAI-compatible endpoint
- `HERMES_OPENAI_API_KEY` for a different key than OpenClaw
- `OPENROUTER_API_KEY` for OpenRouter model switching
- When `OPENROUTER_API_KEY` is set, Hermes can switch to supported OpenRouter models

**Codex (`/codex`):**
- Interactive login by default, or `CODEX_OPENAI_API_KEY` for pre-auth

**Claude (`/claude`):**
- Interactive login by default, or `CLAUDE_ANTHROPIC_API_KEY` for pre-auth

**Gemini (`/gemini`):**
- Interactive login by default, or `GEMINI_CLI_API_KEY` for pre-auth

### FileBrowser

FileBrowser Quantum exposes these user-facing roots:

| Root | Maps To |
| --- | --- |
| Deployment Data | `/data` |
| OpenClaw Workspace | `/data/workspaces/openclaw` |
| Hermes Workspace | `/data/workspaces/hermes` |
| Codex Workspace | `/data/workspaces/codex` |
| Claude Workspace | `/data/workspaces/claude` |
| Gemini Workspace | `/data/workspaces/gemini` |
| Tool Files | `/data/tool-files` (aggregate: `.hermes`, `.codex`, `.claude`, `.gemini`, `.openclaw`, `.filebrowser`) |
| Container App | `/app` |

Proxy-authenticated FileBrowser users are provisioned with full operator permissions automatically, and existing `filebrowser-*` users are reconciled on startup.

### Terminal Behavior

- Each route logs into a separate shared `tmux` session
- Hermes runs with `TERMINAL_ENV=local` and `TERMINAL_CWD=$HERMES_WORKSPACE_DIR`
- Exiting any CLI returns you to `/bin/bash` in that session
- If no `HERMES_OPENAI_API_KEY` or `GEMINI_API_KEY` is present, `/hermes` falls back to a shell even when `OPENROUTER_API_KEY` is set
- Use FileBrowser's roots or `cd /data/workspaces/<name>` to switch between workspaces

### Terminal Rendering Defaults

All terminal routes share: `nginx` → `ttyd`/`xterm.js` → `tmux` → target shell/CLI

Defaults: `xterm-256color`, DOM renderer, system monospace font, size 14, 50k scrollback, `C.UTF-8`, truecolor.

Override these envs at deploy time instead of forking launcher scripts.

---

## Operations

### Reset and Capture

```bash
reset-openclaw-state          # Back up + remove OpenClaw state/workspace only
capture-openclaw-baseline     # Snapshot current state after successful onboarding
restart-openclaw-gateway      # In-place gateway restart, waits for /healthz
```

None of these touch Hermes, Codex, Claude, or Gemini home directories.

### Device Management

```bash
approve-device                                                    # Interactive picker for pending requests
openclaw devices list --token "$OPENCLAW_GATEWAY_TOKEN"           # List all devices
openclaw devices approve --latest --token "$OPENCLAW_GATEWAY_TOKEN"  # Approve latest
openclaw devices clear --yes --token "$OPENCLAW_GATEWAY_TOKEN"    # Clear all paired
```

### Recommended Commands

```bash
cd services/rundiffusion-agents
cp .env.example .env
docker compose up -d --build
docker compose logs -f
docker compose down
```

Recommended restart mode: `OPENCLAW_NO_RESPAWN=0` so full-process gateway restarts complete under wrapper supervision. Avoid `docker compose down` while debugging — keep the failed container inspectable.

---

## Notes

- `/openclaw` uses native auth in `native` mode — not protected by nginx Basic Auth
- `/terminal`, `/hermes`, `/codex`, `/claude`, `/gemini`, `/filebrowser` all share the same Basic Auth
- `openclaw onboard` should not be run inside this managed container — it can rewrite persisted gateway config in ways that drift from the deployment contract
- On multi-tenant hosts, if namespace-dependent tool calls fail, set `TENANT_CONTAINER_SECURITY_PROFILE=tool-userns` in the root `.env`, redeploy, and escalate to `privileged` only if `unshare -U true` still fails
