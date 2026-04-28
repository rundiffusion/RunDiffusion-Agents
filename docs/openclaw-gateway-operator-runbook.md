# OpenClaw Gateway Operator Runbook

This runbook covers the standalone single-tenant package under `services/rundiffusion-agents`.

**Who should read this:** Operators managing the standalone OpenClaw gateway — inspecting boot behavior, performing resets, capturing baselines, and recovering from broken state.

**What this is NOT:** A deployment guide. For deployment, use [`docs/standalone-host-quickstart.md`](./standalone-host-quickstart.md). For browser origin and auth rules, see [OpenClaw Origin & Auth Expectations](./configuration.md#openclaw-origin--auth-expectations).

**When to use this runbook:**

- Gateway is not starting or `/healthz` is failing
- You need to reset OpenClaw to a clean first-boot state
- You need to capture a known-good baseline after manual onboarding
- You need to verify the runtime contract after an env change
- You need to recover from a broken `openclaw.json` or missing reconcile summary

---

## Runtime Contract

> **Boundary rule:** These rules define the boundary between what the wrapper manages and what OpenClaw owns.

- **Env** owns the wrapper contract: ports, auth mode, proxy credentials, workspace paths, and Control UI origin policy
- **Disk** owns OpenClaw user state: model selection, provider auth, onboarding artifacts, and other upstream-created files under `/data/.openclaw`
- **Boot** only writes the minimum gateway/workspace config needed for the wrapper to start OpenClaw cleanly
- Boot does **not** pick a model, build provider-specific model lists, or seed OpenClaw auth profiles from env

---

## Required Env

For the full env reference, see [Standalone Gateway Config](./configuration.md#layer-4-standalone-gateway-config).

Key variables:

| Variable | Purpose |
| --- | --- |
| `OPENCLAW_ACCESS_MODE` | `native` (default) for built-in token/device auth; `trusted-proxy` for proxy Basic Auth |
| `OPENCLAW_GATEWAY_TOKEN` | Gateway auth token (required for native mode) |
| `TERMINAL_BASIC_AUTH_USERNAME` / `PASSWORD` | Required when any operator tty route is enabled |
| `TERMINAL_ENABLED` | Set to `1` to expose `/terminal` |
| `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` | Explicit browser-origin allowlist |

Optional env for sibling tools:

- `GEMINI_API_KEY` or `HERMES_OPENAI_API_KEY` for `/hermes`
- `OPENROUTER_API_KEY` for Hermes model switching
- `CODEX_OPENAI_API_KEY`, `CLAUDE_ANTHROPIC_API_KEY`, `GEMINI_CLI_API_KEY`, and `PI_*` provider keys for pre-authenticated tool routes

---

## What Boot Touches

Every startup may write:

1. `/data/.openclaw/openclaw.json`
2. `/data/.openclaw/reconcile-summary.json`

The wrapper-managed `openclaw.json` fields are limited to:

- `gateway.mode`, `gateway.port`, `gateway.bind`, `gateway.auth`
- `gateway.controlUi`
- `agents.defaults.workspace`

Everything else inside `openclaw.json` is treated as user-owned state and left alone. Before rewriting, the runtime creates a timestamped `.bak-*` backup.

---

## Readiness and Health

**Readiness:** HTTP gateway serves `/healthz` after OpenClaw, FileBrowser, and enabled tty listeners have bound their internal ports. The bootstrap summary exists at `/data/.openclaw/reconcile-summary.json`.

**Deeper wrapper health:** `globalConfigAligned=true`, expected gateway auth mode applied, expected Control UI origin policy applied.

> **Readiness note:** Readiness no longer depends on model/provider detection. OpenClaw model auth is intentionally left to the upstream onboarding flow and later runtime behavior.

---

## Reset Procedure

Use the built-in reset command for a clean OpenClaw first boot without touching Hermes or other operator homes:

```bash
reset-openclaw-state
```

This command:

- Loads `services/rundiffusion-agents/.env` when available (unless disabled)
- Backs up `/data/.openclaw` and `/data/workspaces/openclaw`
- Removes only OpenClaw-owned paths
- Leaves `/data/.hermes`, `/data/.codex`, `/data/.claude`, `/data/.gemini`, `/data/.pi` alone

Default backup root: `/data/openclaw-reset-backups/<timestamp>`

---

## Capture the Known-Good Baseline

After completing manual OpenClaw onboarding and confirming chat works:

```bash
capture-openclaw-baseline
```

Copies `/data/.openclaw` and `/data/workspaces/openclaw` to `/data/openclaw-baselines/<timestamp>-manual-onboarding`. Use as the reference input for later merge/purge repair tooling.

---

<details>
<summary><strong>FileBrowser Runtime</strong></summary>

- **Public path:** `/filebrowser`
- **Auth:** Same proxy Basic Auth as `/terminal`
- **Sources:** `/data`, `/data/workspaces/openclaw`, `/data/workspaces/hermes`, per-tool workspaces (`codex`, `claude`, `gemini`, `pi`), `/data/tool-files`, `/app`

`/data/tool-files` is a browse-only aggregate view grouping: `/data/.hermes`, `/data/.codex`, `/data/.claude`, `/data/.gemini`, `/data/.pi`, `/data/.openclaw`, `/data/.filebrowser`

</details>

<details>
<summary><strong>Web Terminal Runtime</strong></summary>

- **Public path:** `/terminal`
- **Enable:** `TERMINAL_ENABLED=1`
- **Auth:** Proxy Basic Auth (required even if `/openclaw` uses native auth)
- **Backend:** `ttyd`
- **Persistence:** Shared `tmux` session named by `TERMINAL_SESSION_NAME`
- **Working directory:** `/data/workspaces/openclaw`

The terminal route is intentionally blocked unless proxy Basic Auth is configured.

</details>

---

## Recovery Checklist

1. Confirm `OPENCLAW_ACCESS_MODE` matches the intended auth strategy
2. Confirm `OPENCLAW_GATEWAY_TOKEN` is set for native mode
3. If `trusted-proxy`, confirm both `OPENCLAW_BASIC_AUTH_USERNAME` and `OPENCLAW_BASIC_AUTH_PASSWORD` are set
4. Confirm terminal Basic Auth credentials are set when tty routes are enabled
5. If browser shows auth errors, check [OpenClaw Origin & Auth Expectations](./configuration.md#openclaw-origin--auth-expectations)
6. Redeploy the service if you changed env or routing
7. Check startup logs and the wrapper summary artifact

---

## Log Signals

Look for the startup summary line:

```text
[reconcile] gatewayAuthMode=... openClawProxyAuthEnabled=... globalConfigChanged=... globalConfigAligned=...
```

Healthy deploys show the expected `gatewayAuthMode` and `globalConfigAligned=true`.

---

## Summary Artifact

Boot writes `/data/.openclaw/reconcile-summary.json` with: gateway access/auth mode, trusted-proxy status, allowed Control UI origins, config change status, alignment status, repaired files, and backup paths.

> **Quick check:** For a compact operator view inside the runtime: `node /app/print_reconcile_summary.js`

For automation:

```bash
/app/check_reconcile_status.sh
```

Exit codes: `0` = healthy, `1` = warning, `2` = broken or missing artifact.

---

## Normal Inspection Checklist

- Target `/healthz` for standalone deploy health
- Inspect current env values on the host or platform
- Inspect startup logs for the `[reconcile]` summary
- Inspect startup logs for the proxy auth enabled/disabled line from `entrypoint`
- Inspect startup logs for the `[filebrowser]` config line
- Inspect startup logs for `ttyd` and `tmux` startup lines for every enabled route
- Inspect `/data/.openclaw/openclaw.json` and `/data/.openclaw/reconcile-summary.json`
- Visit `/filebrowser` — confirm both `/data` and `/app` sources are visible
- Visit `/terminal` — confirm operator Basic Auth credentials work
