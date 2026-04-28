# Multi-Tenant Host Deployment

This guide covers the repo-root **multi-tenant host stack only** — Traefik ingress, per-tenant Docker isolation, and fleet-wide governance via the YAML control plane.

If you want a single tenant (even on a remote host), use the standalone package under `services/rundiffusion-agents/` and start with [`docs/standalone-host-quickstart.md`](../docs/standalone-host-quickstart.md) instead.

**Jump to:** [Architecture](#architecture) · [First-Time Setup](#first-time-setup) · [Host Layout](#recommended-host-layout) · [Environment & Secrets](#required-environment-and-secrets) · [Operations](#day-to-day-operations) · [Cloudflare Tunnel](#cloudflare-tunnel-setup)

---

## Architecture

The intended shape is:

- One shared **Traefik** ingress layer
- One isolated `openclaw-gateway` **Docker container** per tenant
- One tenant-specific hostname
- One tenant-specific data root on the host
- One tenant-specific env file outside git
- One optional host-only **control-plane YAML** for fleet-wide overrides

**App surface inside every tenant:**

`/openclaw` · `/dashboard` · `/filebrowser` · `/terminal` · `/hermes` · `/codex` · `/claude` · `/gemini` · `/pi`

Traefik and Cloudflare Tunnel are first-class, but the domain, tunnel, and credentials are always user-supplied.

---

## Ingress Modes

| Mode         | Bind Address                   | Use When                                  |
| ------------ | ------------------------------ | ----------------------------------------- |
| `local`      | `127.0.0.1` or LAN IP          | Same-host, LAN, or private-network access |
| `direct`     | `0.0.0.0` or interface IP      | Public host with your own DNS + HTTPS     |
| `cloudflare` | `127.0.0.1` (tunnel publishes) | Published through Cloudflare Tunnel       |

```env
# Local-only or LAN access
INGRESS_MODE=local
TRAEFIK_BIND_ADDRESS=127.0.0.1

# Direct host exposure
INGRESS_MODE=direct
TRAEFIK_BIND_ADDRESS=0.0.0.0

# Cloudflare Tunnel
INGRESS_MODE=cloudflare
TRAEFIK_BIND_ADDRESS=127.0.0.1
```

Multi-tenant routing relies on hostnames. Point those hostnames at the Traefik host through public DNS, private DNS, or hosts-file entries.

> **Heads up:** TLS automation for private-hostname LAN installs is outside the scope of this release. For native `/openclaw` on non-loopback hostnames, see [OpenClaw Origin & Auth Expectations](../docs/configuration.md#openclaw-origin--auth-expectations).

## LAN Expectations

Use `INGRESS_MODE=local` for several tenant instances on a private network.

**Works over plain HTTP on LAN:** `/dashboard`, `/terminal`, `/filebrowser`, `/hermes`, `/codex`, `/claude`, `/gemini`, `/pi`

**Does NOT work over plain HTTP:** Vanilla native `/openclaw` on a non-loopback hostname. Options: put HTTPS in front of the tenant hostname, keep native `/openclaw` on localhost, or use `OPENCLAW_ACCESS_MODE=trusted-proxy`.

> See [OpenClaw Origin & Auth Expectations](../docs/configuration.md#openclaw-origin--auth-expectations) for the full rules and common error fixes.

---

## First-Time Setup

1. **Clone the repo** onto the host you want to use.

2. **Copy the root env template:**

   ```bash
   cp .env.example .env
   ```

   Edit `.env` with your domain, host paths, ingress settings, and image settings.

3. **Create the local tenant registry:**

   ```bash
   cp deploy/tenants/tenants.example.yml deploy/tenants/tenants.yml
   ```

   > **Nice shortcut:** If you skip this step, the deploy scripts create `deploy/tenants/tenants.yml` automatically from the example.

4. **Install required host tooling**

### Required Host Tooling

The deploy scripts require: `bash`, `curl`, `docker`, `jq`, `yq`, `openssl`

**Recommended:** `python3` for validation and migration helpers

> **Platform note:** macOS and Linux are supported directly. Windows users should use WSL2 for this repo and the `scripts/*.sh` commands.

<details>
<summary><strong>macOS (Homebrew)</strong></summary>

```bash
brew install jq yq openssl
brew install --cask docker
```

Or run the all-in-one helper:

```bash
./scripts/bootstrap-mac-mini.sh
```

</details>

<details>
<summary><strong>Ubuntu / Debian</strong></summary>

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2 curl jq yq openssl python3
```

</details>

<details>
<summary><strong>Fedora</strong></summary>

```bash
sudo dnf install -y docker-cli docker-compose curl jq yq openssl python3
```

</details>

<details>
<summary><strong>Arch Linux</strong></summary>

```bash
sudo pacman -S --needed docker docker-compose curl jq yq openssl python
```

</details>

<details>
<summary><strong>Windows (WSL2)</strong></summary>

1. Install Docker Desktop.
2. Enable WSL2 integration for your Linux distro.
3. Install the Linux packages above inside WSL.

</details>

5. **Create your first tenant:**

   ```bash
   ./scripts/create-tenant.sh tenant-a "Tenant A"
   ```

6. **Deploy shared ingress and all enabled tenants:**

   ```bash
   ./scripts/deploy.sh
   ```

7. **Verify health:**

   ```bash
   ./scripts/status.sh
   ./scripts/smoke-test.sh --all
   ```

---

## Recommended Host Layout

Keep live runtime state in a host-managed tree outside the repo checkout.

```text
/srv/rundiffusion-agents/
  data/
    tenants/<slug>/
    backups/
    releases/
    traefik/
    cloudflared/
  secrets/
    tenants/<slug>.env
```

Maps to the root env contract:

```env
DATA_ROOT=/srv/rundiffusion-agents/data
TENANT_ENV_ROOT=/srv/rundiffusion-agents/secrets/tenants
```

If you have older repo-local state in `.data/` or `deploy/tenants/env/`, update `.env` first, then run:

```bash
./scripts/migrate-host-storage.sh
```

---

## Required Environment and Secrets

**Root `.env`** owns shared host and ingress settings:

| Variable                             | Purpose                                       |
| ------------------------------------ | --------------------------------------------- |
| `BASE_DOMAIN`                        | Base domain for tenant hostname generation    |
| `INGRESS_MODE`                       | Routing mode: `local`, `direct`, `cloudflare` |
| `PUBLIC_URL_SCHEME`                  | Browser origin scheme; blank = auto-detect    |
| `DATA_ROOT`                          | Host path for tenant data volumes             |
| `TENANT_ENV_ROOT`                    | Host path for tenant env files                |
| `TRAEFIK_BIND_ADDRESS`               | Interface Traefik listens on                  |
| `TRAEFIK_HTTP_PORT`                  | Port Traefik listens on                       |
| `TRAEFIK_NETWORK`                    | Docker network for Traefik                    |
| `CLOUDFLARE_HOSTNAME_MODE`           | Cloudflare hostname strategy                  |
| `CLOUDFLARE_TUNNEL_ID`               | Tunnel ID for Cloudflare ingress              |
| `CLOUDFLARE_TUNNEL_CREDENTIALS_FILE` | Path to tunnel credentials JSON               |
| `COMPOSE_PROJECT_NAME`               | Docker Compose project name                   |
| `OPENCLAW_VERSION`                   | Default OpenClaw version for all tenants      |
| `TENANT_CONTAINER_SECURITY_PROFILE`  | Container security profile                    |

**Tenant env files** own tenant-specific values:

| Variable                              | Purpose                                                                                          |
| ------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `TENANT_SLUG`                         | Unique tenant identifier                                                                         |
| `TENANT_HOSTNAME`                     | Public hostname for this tenant                                                                  |
| `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` | Exact browser origin ([auth rules](../docs/configuration.md#openclaw-origin--auth-expectations)) |
| `OPENCLAW_GATEWAY_TOKEN`              | Gateway authentication token                                                                     |
| `TERMINAL_BASIC_AUTH_USERNAME`        | Dashboard/terminal auth username                                                                 |
| `TERMINAL_BASIC_AUTH_PASSWORD`        | Dashboard/terminal auth password                                                                 |
| `TAILSCALE_ENABLED`                   | Optional per-tenant Tailscale toggle                                                             |
| `TAILSCALE_AUTHKEY`                   | Optional Tailscale auth key                                                                      |
| `TAILSCALE_HOSTNAME`                  | Optional Tailscale hostname                                                                      |
| Provider API keys                     | Optional tenant-specific keys                                                                    |

> **Exact-match rule:** `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` must be the **exact** public browser origin, including port when Traefik is on a non-default port (e.g., `http://tenant-a.example.com:38080`).

See [Configuration & Governance](../docs/configuration.md) for the full config matrix, control-plane overrides, and precedence rules.

<details>
<summary><h2>Tenant Container Security Profile</h2></summary>

`TENANT_CONTAINER_SECURITY_PROFILE` controls Docker security settings for each tenant's container.

| Value         | Behavior                                                               |
| ------------- | ---------------------------------------------------------------------- |
| `restricted`  | Default Docker profile                                                 |
| `tool-userns` | Adds `SYS_ADMIN` + unconfined seccomp/apparmor for CLI user namespaces |
| `privileged`  | Full `privileged: true` — use only as a fallback                       |

**Recommended escalation path:**

1. Set `TENANT_CONTAINER_SECURITY_PROFILE=tool-userns`
2. Redeploy the affected tenant
3. Validate: `docker exec <container> unshare -U true`
4. Escalate to `privileged` only if that still fails

</details>

<details>
<summary><h2>Per-Tenant Tailscale</h2></summary>

Tailscale is optional and enabled per tenant. Add to the tenant env file:

```env
TAILSCALE_ENABLED=1
TAILSCALE_AUTHKEY=
TAILSCALE_HOSTNAME=
```

When enabled, the tenant gets:

- `/dev/net/tun`
- `NET_ADMIN` and `NET_RAW`
- A persistent `${DATA_ROOT}/tenants/<slug>/tailscale` mount at `/var/lib/tailscale`

</details>

<details>
<summary><h2>Cloudflare Tunnel Setup</h2></summary>

Use this section only when `INGRESS_MODE=cloudflare`.

1. Create the named tunnel in Cloudflare.
2. Download the tunnel credentials JSON locally.
3. Render the local config from the tenant registry:

   ```bash
   ./scripts/render-cloudflared-config.sh
   ```

4. Create a wildcard DNS route:

   ```bash
   cloudflared tunnel route dns <tunnel-name> '*.example.com'
   ```

5. Optionally adapt [config.yml.example](cloudflared/config.yml.example).
6. On macOS hosts, install the launch agent:

   ```bash
   ./scripts/install-cloudflared-launchd.sh
   ```

</details>

---

## Day-To-Day Operations

```bash
# Create a tenant
./scripts/create-tenant.sh tenant-a "Tenant A"

# Update tenant metadata
./scripts/update-tenant.sh tenant-a --hostname tenant-a.example.com
./scripts/update-tenant.sh tenant-a --disable
./scripts/update-tenant.sh tenant-a --enable

# List tenants
./scripts/list-tenants.sh

# Deploy one tenant
./scripts/deploy.sh --tenant tenant-a

# Deploy all tenants
./scripts/deploy.sh

# Check health
./scripts/status.sh
./scripts/smoke-test.sh --all
```

See [Tenant Operations Runbook](../docs/tenant-operations.md) for the full operator runbook.
