# Standalone Host Quickstart

Use this guide for the single-tenant package under `services/rundiffusion-agents`.

This is the right path when you want:

- Local single-tenant on `localhost`
- Remote single-tenant on one VM or bare-metal host
- Remote single-tenant published through Cloudflare Tunnel

If you need multiple tenant hostnames behind shared ingress, use the repo-root multi-tenant host stack instead — see [Multi-Tenant Host Deployment](../deploy/README.md).

> **Before you deploy:** Use at your own risk. This is bleeding-edge operator software. You are responsible for credentials, access control, backups, data protection, third-party API usage, and the consequences of any deployment or configuration mistake. Test in a non-production environment first. Read [`DISCLAIMER.md`](../DISCLAIMER.md).

---

## Prerequisites

- Docker with Compose support
- This repo checked out on the host that will run the container

---

## Quick Start

From the repo root:

```bash
cd services/rundiffusion-agents
cp .env.example .env
```

Set at least:

- `OPENCLAW_ACCESS_MODE=native`
- `OPENCLAW_GATEWAY_TOKEN=<long-random-secret>`
- `TERMINAL_BASIC_AUTH_USERNAME=<username>`
- `TERMINAL_BASIC_AUTH_PASSWORD=<strong-password>`
- `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=<exact browser origin>`

Then start:

```bash
docker compose up -d --build
```

Useful day-two commands:

```bash
docker compose logs -f
docker compose down
```

---

## Compose Helper Vars

The standalone `.env` includes helper vars for host-side packaging. These are Docker Compose helpers, not part of the gateway runtime contract.

| Variable | Default | Purpose |
| --- | --- | --- |
| `STANDALONE_BIND_ADDRESS` | `127.0.0.1` | Interface the container listens on |
| `STANDALONE_PUBLIC_PORT` | `8080` | Port exposed to the host |
| `STANDALONE_CONTAINER_NAME` | `rundiffusion-agent` | Docker container name |
| `STANDALONE_DATA_VOLUME` | `rundiffusion-agent-data` | Named volume for persistent data |

---

## Local Single Tenant

> **Clean localhost path:** This is the clean vanilla native `/openclaw` path — the browser origin stays on `localhost`, so no HTTPS is needed.

```env
STANDALONE_BIND_ADDRESS=127.0.0.1
STANDALONE_PUBLIC_PORT=8080
OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=http://127.0.0.1:8080,http://localhost:8080
```

Open:

- `http://127.0.0.1:8080/dashboard`
- `http://127.0.0.1:8080/openclaw`

---

## Remote Single Tenant — Direct DNS + HTTPS

Use the same package under `services/rundiffusion-agents`.

```env
STANDALONE_BIND_ADDRESS=0.0.0.0
STANDALONE_PUBLIC_PORT=8080
OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=https://agent.example.com
```

- Point your DNS at the host
- Terminate TLS with your own load balancer, reverse proxy, or external edge

---

## Remote Single Tenant — Cloudflare Tunnel

Use the same standalone package when you want one service published through Cloudflare.

```env
STANDALONE_BIND_ADDRESS=127.0.0.1
STANDALONE_PUBLIC_PORT=8080
OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=https://agent.example.com
```

1. Start the standalone package locally with `docker compose up -d --build`
2. Create a Cloudflare Tunnel outside this repo
3. Route `agent.example.com` through that tunnel to `http://127.0.0.1:8080`
4. Open the HTTPS hostname and confirm it matches `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS`

This repo does not ship a dedicated single-tenant `cloudflared` sidecar. Treat the tunnel as host-managed infrastructure.

---

## OpenClaw Auth

For the full rules on browser origins, HTTPS requirements, and common error fixes, see [OpenClaw Origin & Auth Expectations](./configuration.md#openclaw-origin--auth-expectations).

**Quick reference:**

- `localhost` — native `/openclaw` works without HTTPS
- Non-loopback hostnames — need HTTPS for native `/openclaw`
- `origin not allowed` error — fix `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS`
- Device-identity error — move browser origin to HTTPS or localhost

---

## When to Switch Tracks

Move to the multi-tenant host stack when you need:

- More than one tenant hostname
- Shared Traefik ingress
- Per-tenant env files and tenant registry entries
- Repo-root deploy scripts (`./scripts/create-tenant.sh`, `./scripts/deploy.sh`)

See [Multi-Tenant Host Deployment](../deploy/README.md) for that path.
