# Configuration & Governance

RunDiffusion Agents uses a layered configuration model to give operators centralized control over their entire agent fleet. Each layer has a clear purpose, a clear owner, and a clear precedence — so you always know which value wins and why.

This is the governance surface of the platform. If you want to understand how version pins, model policy, secret injection, and route flags flow from a single YAML file to every tenant container, start here.

---

## Configuration Precedence

Higher layers override lower layers. The operator always has the last word.

```
┌─────────────────────────────────────────────────────┐
│  CLI flag  (--openclaw-version)                     │  ← Highest precedence
├─────────────────────────────────────────────────────┤
│  Host Control-Plane YAML  (per-tenant overrides)    │
├─────────────────────────────────────────────────────┤
│  Per-Tenant Env File  (tenant auth & secrets)       │
├─────────────────────────────────────────────────────┤
│  Root Host .env  (shared infra defaults)            │  ← Lowest precedence
├─────────────────────────────────────────────────────┤
│  Dockerfile defaults  (build-time fallbacks)        │
└─────────────────────────────────────────────────────┘
```

**Example: OpenClaw version resolution**

`./scripts/deploy.sh --openclaw-version ...` → tenant `openclawVersion` in control-plane YAML → root `.env` `OPENCLAW_VERSION` → Dockerfile default.

---

## Governance Principles

> **Ground rules:** These rules keep the configuration layers clean and predictable. Violating them creates merge-conflict-grade confusion at deploy time.

- **Do not copy root vars into tenant env files.** Each layer owns its own fields. Duplicating them creates ambiguity about which value wins.
- **Use the host control-plane YAML for managed keys and model overrides** when that layer is enabled. It exists specifically to centralize fleet-wide governance.
- **Do not put tenant secrets in `deploy/tenants/tenants.example.yml`.** The registry maps slugs to hostnames — that is all.
- **Keep `deploy/tenants/tenants.yml` local and ignored.** Real tenant metadata stays in the repo checkout without being committed.
- **Do not commit `.env` or real tenant env files.** Secrets never belong in git.
- **Keep runtime state outside the repo checkout.**
- **Start from the example file for the layer you are actually using.**

> **Best starting point:** When in doubt, start from the `.example` file for your layer. The examples ship with safe defaults and inline comments.

---

## Deployment Tracks

| Track | Package | Use When |
| --- | --- | --- |
| **Standalone single-tenant** | `services/rundiffusion-agents/` | One agent on localhost or one remote host. No Traefik. |
| **Multi-tenant host** | Repo root + Traefik | Shared-host architecture for LAN, cloud, or Cloudflare ingress. |

Choose the track first, then use the configuration layers for that track.

---

## What Each Layer Owns (Quick Reference)

| Field | Owning Layer | Applied |
| --- | --- | --- |
| Host paths (`DATA_ROOT`, `TENANT_ENV_ROOT`) | Root `.env` | Deploy-time |
| Ingress mode and bind address | Root `.env` | Deploy-time |
| Tenant resource limits | Root `.env` | Deploy-time |
| OpenClaw version pin (per-tenant) | Control-plane YAML | Deploy-time |
| API key injection (managed secrets) | Control-plane YAML | Deploy-time |
| Model allowlist, primary, fallbacks | Control-plane YAML | Deploy-time |
| Agent-to-model binding | Control-plane YAML | Deploy-time |
| Route feature flags (Gemini, etc.) | Control-plane YAML | Deploy-time |
| Tenant hostname and allowed origins | Tenant env file | Deploy-time |
| Gateway token and Basic Auth | Tenant env file | Deploy-time |
| Tool enablement (`TERMINAL_ENABLED`, etc.) | Tenant env file | Deploy-time |
| Tenant-specific provider keys | Tenant env file | Deploy-time |
| Tailscale settings | Tenant env file | Deploy-time |

---

## Layer 1: Root Host Config

**Source:** `.env.example`
**Track:** Multi-tenant only

Shared infrastructure defaults for the host stack.

| Variable | Purpose |
| --- | --- |
| `BASE_DOMAIN` | Base domain for tenant hostname generation |
| `INGRESS_MODE` | Routing mode: `local`, `direct`, or `cloudflare` |
| `PUBLIC_URL_SCHEME` | Browser origin scheme (`http`/`https`); blank = auto-detect |
| `DATA_ROOT` | Host path for tenant data volumes |
| `TENANT_ENV_ROOT` | Host path for tenant env files |
| `TRAEFIK_BIND_ADDRESS` | Interface Traefik listens on |
| `TRAEFIK_HTTP_PORT` | Port Traefik listens on |
| `CLOUDFLARE_TUNNEL_ID` | Tunnel ID for Cloudflare ingress |
| `OPENCLAW_VERSION` | Default OpenClaw version for all tenants |
| `TENANT_CONTAINER_SECURITY_PROFILE` | Container security profile |

**Ingress modes:**

| Mode | Bind Address | Use When |
| --- | --- | --- |
| `local` | `127.0.0.1` or LAN IP | Same-host or private-network deployments |
| `direct` | `0.0.0.0` or interface IP | Public host with your own DNS + HTTPS |
| `cloudflare` | `127.0.0.1` (tunnel publishes) | Published through Cloudflare Tunnel |

`PUBLIC_URL_SCHEME` controls the browser origin written into newly created tenant env files. The generated `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` value uses the exact browser origin, including `TRAEFIK_HTTP_PORT` when Traefik is not on `80` or `443`. Leave it blank to auto-pick `https` for Cloudflare and `http` for local/direct installs.

---

## Layer 2: Host Control-Plane Overrides

**Source:** `TENANT_CONTROL_PLANE_CONFIG_PATH` from root `.env`
**Schema reference:** `deploy/tenants/control-plane.example.yml`
**Track:** Multi-tenant only

This is the governance layer. One YAML file on the host centrally manages per-tenant overrides for versions, secrets, models, agents, and routes — without hand-editing individual tenant env files.

**Managed fields** are the specific fields that the control-plane YAML is authoritative for. At deploy time, `scripts/sync_tenant_control_plane.py` applies these values ahead of the tenant start. Fields outside the managed list still belong to the tenant env file.

<details>
<summary><strong>Full YAML example</strong></summary>

```yaml
tenants:
  tenant-a:
    openclawVersion: 2026.3.24
    secrets:
      GEMINI_API_KEY: ""
      HERMES_OPENAI_API_KEY: ""
    models:
      allowed:
        - openai-codex/gpt-5.4
      primary: openai-codex/gpt-5.4
      fallbacks: []
    agents:
      main:
        model: openai-codex/gpt-5.4
    providers:
      google:
        hydrateAuth: false
    routes:
      gemini:
        enabled: false
```

</details>

**Available managed fields:**

| Field | Purpose |
| --- | --- |
| `openclawVersion` | Pin one tenant to a specific OpenClaw build |
| `secrets.GEMINI_API_KEY` | Managed Gemini API key |
| `secrets.GEMINI_CLI_API_KEY` | Managed Gemini CLI API key |
| `secrets.HERMES_OPENAI_API_KEY` | Managed Hermes OpenAI key |
| `secrets.CODEX_OPENAI_API_KEY` | Managed Codex OpenAI key |
| `secrets.CLAUDE_ANTHROPIC_API_KEY` | Managed Claude Anthropic key |
| `secrets.OPENROUTER_API_KEY` | Managed OpenRouter key |
| `models.allowed` | Tenant-wide model allowlist |
| `models.primary` | Default model selection |
| `models.fallbacks` | Fallback model chain |
| `agents.main.model` | Startup model for the built-in `main` agent |
| `providers.google.hydrateAuth` | Google auth hydration behavior |
| `routes.gemini.enabled` | Deploy-time Gemini route enable flag |

**What the control-plane does NOT override:**

- Gateway token
- Terminal/Basic Auth credentials
- Hostname or allowed origins
- Tailscale settings
- Non-`main` agents
- Operator Codex auth/session/profile state

> **Host-only file:** This file is optional, should stay outside git on real hosts, and is applied at deploy time — not continuously on boot. Use the tracked example in `deploy/tenants/control-plane.example.yml` as the schema reference.

---

## Layer 3: Per-Tenant Config

**Source:** `deploy/tenants/templates/tenant.env.example`
**Track:** Multi-tenant only

Tenant-specific identity, auth, and provider keys. Keep tenant env files outside git.

| Variable | Purpose |
| --- | --- |
| `TENANT_SLUG` | Unique tenant identifier |
| `TENANT_HOSTNAME` | Public hostname for this tenant |
| `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` | Exact browser origin (see [Auth Expectations](#openclaw-origin--auth-expectations)) |
| `OPENCLAW_GATEWAY_TOKEN` | Gateway authentication token |
| `TERMINAL_BASIC_AUTH_USERNAME` | Dashboard/terminal auth username |
| `TERMINAL_BASIC_AUTH_PASSWORD` | Dashboard/terminal auth password |
| `GEMINI_API_KEY` | Tenant-specific Gemini key (if not managed via control-plane) |
| `OPENROUTER_API_KEY` | Tenant-specific OpenRouter key |
| `TAILSCALE_ENABLED` | Per-tenant Tailscale toggle |

> **Exact-origin rule:** `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` must match the **exact** browser origin — including scheme, hostname, and port. Example: `http://tenant-a.example.com:38080` when Traefik is on port `38080`.

---

## Layer 4: Standalone Gateway Config

**Source:** `services/rundiffusion-agents/.env.example`
**Track:** Standalone single-tenant only

Single-service deployment without the multi-tenant orchestration layer.

| Variable | Purpose |
| --- | --- |
| `OPENCLAW_ACCESS_MODE` | Auth mode: `native` or `trusted-proxy` |
| `OPENCLAW_GATEWAY_TOKEN` | Gateway authentication token |
| `TERMINAL_ENABLED` | Enable/disable terminal |
| `TERMINAL_BASIC_AUTH_USERNAME` | Terminal auth username |
| `TERMINAL_BASIC_AUTH_PASSWORD` | Terminal auth password |
| Tool-specific API keys | Optional provider credentials |

> **Easiest local setup:** For the recommended local path, bind to `localhost` and use `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=http://127.0.0.1:8080,http://localhost:8080`. If you later move to a non-loopback hostname, native `/openclaw` needs HTTPS or a switch to `trusted-proxy`.

---

## Tenant Registry

**Tracked template:** `deploy/tenants/tenants.example.yml`
**Local working file:** `deploy/tenants/tenants.yml` (gitignored)

Maps tenant slugs to hostnames, env files, and data roots. Determines which tenants are enabled.

The example file ships with `tenants: []` and is intentionally public-safe. The local `tenants.yml` is ignored so operators can keep real tenant metadata without committing it.

Real tenant secrets belong in external tenant env files, not in the registry.

---

## OpenClaw Origin & Auth Expectations

This section is the single source of truth for OpenClaw's browser origin and authentication requirements. Other docs in this repo link here rather than repeating these rules.

**The core rule:** Vanilla native `/openclaw` requires a **secure context** — meaning the browser origin must be either `localhost` / `127.0.0.1` (any port) or an HTTPS hostname.

**What works:**

| Browser Origin | Native `/openclaw` | Dashboard, Terminal, Other Tools |
| --- | --- | --- |
| `http://127.0.0.1:8080` | Works | Works |
| `http://localhost:8080` | Works | Works |
| `https://agent.example.com` | Works | Works |
| `http://agent.local:38080` (LAN) | Does NOT work | Works |
| `http://192.168.1.50:38080` (LAN IP) | Does NOT work | Works |

**Common errors and fixes:**

| Error | Cause | Fix |
| --- | --- | --- |
| `origin not allowed` | `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` does not match the browser URL | Set it to the **exact** origin the browser opens (scheme + host + port) |
| `control ui requires device identity` | Browser is on plain HTTP with a non-loopback hostname | Move to HTTPS (Cloudflare Tunnel, reverse proxy with TLS, or direct cert) or use `localhost` |
| `Too many unauthorized attempts` | Repeated failed device approval | Wait for the rate limit to expire, then retry |

**Paths to HTTPS for non-loopback hostnames:**

- **Cloudflare Tunnel** — easiest, no cert management
- **Reverse proxy with TLS termination** — nginx, Caddy, etc. in front of the service
- **Direct certificate** — Let's Encrypt or similar, applied to the host

> **LAN nuance:** Plain HTTP on LAN hostnames is fine for `/dashboard`, `/terminal`, `/filebrowser`, `/hermes`, `/codex`, `/claude`, and `/gemini`. Only vanilla native `/openclaw` requires the secure context. If you use `OPENCLAW_ACCESS_MODE=trusted-proxy`, the secure-context requirement shifts to your proxy layer.
