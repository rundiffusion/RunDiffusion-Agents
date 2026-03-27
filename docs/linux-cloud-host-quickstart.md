# Linux Host Quickstart

Use this guide to run the **multi-tenant host stack** on a Linux server, cloud VM, or bare-metal host.

This guide assumes: one Linux host, Docker installed, the repo checked out, and one or more tenant containers behind Traefik.

> **Before you deploy:** Use at your own risk. This stack is intended for capable operators managing Docker, ingress, secrets, and tenant isolation. You are responsible for protecting credentials and data, complying with third-party service terms, and validating the deployment before putting it anywhere near production. Read [`DISCLAIMER.md`](../DISCLAIMER.md).

If you want a single-tenant install, use the standalone package under `services/rundiffusion-agents/` and start with [`docs/standalone-host-quickstart.md`](./standalone-host-quickstart.md) instead.

---

## Choose Your Public Path

| Mode | Recommendation | Notes |
| --- | --- | --- |
| `cloudflare` | **Recommended** | HTTPS browser origin without exposing Traefik directly |
| `direct` | Use when you have your own DNS + HTTPS | This repo does not automate public TLS issuance |
| `local` | Private networks, VPNs, internal-only | HTTP is fine for sibling tools; native `/openclaw` still needs HTTPS or localhost |

> **Recommended path:** Cloudflare Tunnel is the fastest path to a secure public deployment. No cert management, no exposed ports.

---

## Host Prerequisites

See [Required Host Tooling](../deploy/README.md#required-host-tooling) for the full list and platform-specific install commands.

**Quick install (Ubuntu / Debian):**

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2 curl jq yq openssl python3
```

---

## Provider-Neutral Host Notes

These checks apply on any Linux cloud host or bare-metal server:

- Reserve a stable public IP if the host will be public
- Allow SSH only from trusted admin IPs
- For `direct` mode: allow inbound traffic only to the port you expose for Traefik
- For `cloudflare` mode: no public inbound traffic to Traefik needed; outbound `443` is the critical path for `cloudflared`
- Keep data and secret roots on attached persistent storage, not inside the repo checkout

**Supported hosts:** Google Cloud, AWS, Azure, DigitalOcean, Hetzner, on-prem bare-metal Linux, and any Docker-capable Linux environment.

---

## Root Host Setup

```bash
cp .env.example .env
cp deploy/tenants/tenants.example.yml deploy/tenants/tenants.yml
```

Set at least:

```env
BASE_DOMAIN=agents.example.com
DATA_ROOT=/srv/rundiffusion-agents/data
TENANT_ENV_ROOT=/srv/rundiffusion-agents/secrets/tenants
```

See [Recommended Host Layout](../deploy/README.md#recommended-host-layout) for the full directory tree.

### Direct Host Exposure

Use this only when you already have HTTPS handled outside the repo.

```env
INGRESS_MODE=direct
PUBLIC_URL_SCHEME=https
TRAEFIK_BIND_ADDRESS=0.0.0.0
TRAEFIK_HTTP_PORT=80
```

- Point DNS at the host
- Terminate TLS with your own load balancer, reverse proxy, or external edge

### Cloudflare Tunnel

**Recommended public path** for this release.

```env
INGRESS_MODE=cloudflare
PUBLIC_URL_SCHEME=https
TRAEFIK_BIND_ADDRESS=127.0.0.1
TRAEFIK_HTTP_PORT=38080
CLOUDFLARE_HOSTNAME_MODE=wildcard
CLOUDFLARE_TUNNEL_ID=<tunnel-id>
CLOUDFLARE_TUNNEL_CREDENTIALS_FILE=/srv/rundiffusion-agents/data/cloudflared/tunnel.json
```

1. Create the named tunnel in Cloudflare.
2. Download the tunnel credentials JSON to the host path named by `CLOUDFLARE_TUNNEL_CREDENTIALS_FILE`.
3. Render the config:

   ```bash
   ./scripts/render-cloudflared-config.sh
   ```

4. Create the wildcard DNS route:

   ```bash
   cloudflared tunnel route dns <tunnel-name> '*.example.com'
   ```

5. Start `cloudflared`:

   ```bash
   cloudflared --config /srv/rundiffusion-agents/data/cloudflared/config.yml tunnel run
   ```

6. After manual validation, manage that command under your preferred Linux service manager.

> **Linux note:** This repo ships a macOS launchd helper for Cloudflare Tunnel but does **not** ship a Linux systemd helper in this release. Manage `cloudflared` with systemd, supervisord, or your preferred process manager.

---

## Create the First Tenant

```bash
./scripts/create-tenant.sh tenant-a "Tenant A"
```

Edit `${TENANT_ENV_ROOT}/tenant-a.env` and set:

- `TENANT_HOSTNAME`
- `OPENCLAW_GATEWAY_TOKEN`
- `TERMINAL_BASIC_AUTH_USERNAME` / `TERMINAL_BASIC_AUTH_PASSWORD`
- `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` — must match the exact browser origin (see [Auth Expectations](./configuration.md#openclaw-origin--auth-expectations))

---

## Deploy

```bash
./scripts/deploy.sh
```

Or for one tenant only:

```bash
./scripts/deploy.sh --tenant tenant-a
```

---

## Verify

```bash
./scripts/status.sh
./scripts/smoke-test.sh --all
```

Check that:

- Traefik is healthy
- Each tenant is `running/healthy`
- The hostname resolves as expected
- `/dashboard` loads
- `/openclaw` has the exact origin allowlisted
