# Environment Contract

## Root Env

Read [`../../.env.example`](../../.env.example) first. It defines the shared host contract. Read [`../../.env`](../../.env) second for actual values.

**Root env keys:**

| Key | Purpose | Blank OK |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | Docker Compose project name | No |
| `BASE_DOMAIN` | Base domain for tenant hostnames | No |
| `INGRESS_MODE` | Routing mode: `local`, `direct`, `cloudflare` | No |
| `PUBLIC_URL_SCHEME` | Browser origin scheme; blank = auto-detect | Yes |
| `TRAEFIK_BIND_ADDRESS` | Interface Traefik listens on | No |
| `TRAEFIK_HTTP_PORT` | Port Traefik listens on | No |
| `TRAEFIK_NETWORK` | Docker network for Traefik | No |
| `TRAEFIK_LOG_LEVEL` | Traefik log verbosity | Yes |
| `CLOUDFLARE_HOSTNAME_MODE` | Cloudflare hostname strategy | Only for cloudflare mode |
| `CLOUDFLARE_TUNNEL_ID` | Tunnel ID | Only for cloudflare mode |
| `CLOUDFLARE_TUNNEL_CREDENTIALS_FILE` | Path to tunnel credentials JSON | Only for cloudflare mode |
| `CLOUDFLARE_TUNNEL_METRICS` | Metrics endpoint | Yes |
| `CLOUDFLARED_LAUNCHD_LABEL` | macOS launchd label | Yes |
| `DATA_ROOT` | Host path for tenant data volumes | No |
| `TENANT_ENV_ROOT` | Host path for tenant env files | No |
| `DEPLOY_MODE` | Deploy behavior mode | Yes |
| `AUTO_ROLLBACK` | Auto-rollback on deploy failure | Yes |
| `IMAGE_REPOSITORY` | Docker image repository | Yes |
| `OPENCLAW_VERSION` | Default OpenClaw version for all tenants | Yes (derived) |
| `GATEWAY_IMAGE_TAG` | Image tag override | Yes (derived) |
| `PI_CODING_AGENT_VERSION` | Pi Coding Agent version baked into gateway images | Yes (derived) |
| `TENANT_MEMORY_RESERVATION` | Container memory reservation | Yes |
| `TENANT_MEMORY_LIMIT` | Container memory limit | Yes |
| `TENANT_PIDS_LIMIT` | Container PID limit | Yes |
| `TENANT_CONTAINER_SECURITY_PROFILE` | Container security profile | No |
| `MAX_ALWAYS_ON_TENANTS` | Max always-on tenant count | Yes |
| `BACKUP_ROOT` | Host path for backups | Yes (derived) |
| `RELEASE_ROOT` | Host path for release history | Yes (derived) |

`OPENCLAW_VERSION` is the shared default. Tenant-specific overrides belong in the host control-plane YAML as `openclawVersion`. See [`../../docs/configuration.md`](../../docs/configuration.md) for precedence.

`TENANT_CONTAINER_SECURITY_PROFILE` controls Docker security for each tenant container. Use `restricted` (default), `tool-userns` (adds `SYS_ADMIN` + unconfined seccomp/apparmor for CLI tools), or `privileged` (fallback only). Recommended: start with `tool-userns`, validate with `unshare -U true`, escalate only if needed.

## Tenant Env

Template: [`../../deploy/tenants/templates/tenant.env.example`](../../deploy/tenants/templates/tenant.env.example)

Real files live under `TENANT_ENV_ROOT` (e.g., `/srv/rundiffusion-agents/secrets/tenants`). Tenant env files hold only tenant-specific values:

| Key | Purpose | Required |
| --- | --- | --- |
| `TENANT_SLUG` | Unique tenant identifier | Yes |
| `TENANT_HOSTNAME` | Public hostname | Yes |
| `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` | Exact browser origin ([auth rules](../../docs/configuration.md#openclaw-origin--auth-expectations)) | Yes |
| `OPENCLAW_ACCESS_MODE` | Auth mode: `native` or `trusted-proxy` | Yes |
| `OPENCLAW_GATEWAY_TOKEN` | Gateway auth token | Yes (native mode) |
| `TERMINAL_ENABLED` | Enable `/terminal` | Yes |
| `TERMINAL_BASIC_AUTH_USERNAME` | Terminal auth username | Yes |
| `TERMINAL_BASIC_AUTH_PASSWORD` | Terminal auth password | Yes |
| `HERMES_ENABLED` | Enable `/hermes` | Yes |
| `CODEX_ENABLED` | Enable `/codex` | Yes |
| `CLAUDE_ENABLED` | Enable `/claude` | Yes |
| `GEMINI_ENABLED` | Enable `/gemini` | Yes |
| `PI_ENABLED` | Enable `/pi` | Yes |
| `TAILSCALE_ENABLED` | Per-tenant Tailscale | No |
| `TAILSCALE_AUTHKEY` | Tailscale auth key | No |
| `TAILSCALE_HOSTNAME` | Tailscale hostname | No |
| Provider API keys | Tenant-specific credentials, including separate Pi provider keys | No |

## How Vars Reach Docker

Do not duplicate root vars into tenant env files.

The effective deploy flow:

1. `scripts/lib/common.sh` loads the root `.env`
2. Registry values in `deploy/tenants/tenants.yml` expand with root vars (`${DATA_ROOT}`, `${TENANT_ENV_ROOT}`)
3. `compose_tenant` exports derived values: `TENANT_SLUG`, `TENANT_HOSTNAME`, `TENANT_DATA_ROOT`, `TENANT_ENV_FILE`, `OPENCLAW_IMAGE`
4. `deploy/tenant-stack.compose.yml` uses those derived values plus root resource limits
5. The container receives the tenant env file through `env_file`
6. If `TAILSCALE_ENABLED=1`, adds `/dev/net/tun`, `NET_ADMIN`, `NET_RAW`, and a tenant-scoped bind mount

"Propagating vars" means: ensure root `.env` is complete, registry entry points at the right env file and data root, and tenant env file contains tenant-specific values. Not: copying every root var into every tenant env file.

For OpenClaw version selection, keep the shared default in root `.env`, use control-plane `openclawVersion` only when one tenant must diverge, and do not copy it into tenant env files.

## Safe Mutation Order

1. Validate root env against `.env.example`
2. Confirm registry entry and expanded paths
3. Confirm or edit tenant env values
4. Deploy
5. Smoke-test
