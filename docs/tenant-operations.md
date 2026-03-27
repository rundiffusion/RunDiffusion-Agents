# Tenant Operations

Day-to-day operational runbook for the multi-tenant host stack.

For LAN expectations and HTTP/HTTPS rules on private networks, see [LAN Expectations](../deploy/README.md#lan-expectations). For browser origin and auth requirements, see [OpenClaw Origin & Auth Expectations](./configuration.md#openclaw-origin--auth-expectations).

---

## Create a Tenant

1. Confirm `.env` is present and matches `.env.example`

2. Create the tenant:

   ```bash
   ./scripts/create-tenant.sh tenant-a "Tenant A" tenant-a.example.com
   ```

3. Edit the generated tenant env file under `TENANT_ENV_ROOT`. Confirm `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` matches the exact browser origin. See [auth expectations](./configuration.md#openclaw-origin--auth-expectations) for the full rules.

4. Deploy the tenant:

   ```bash
   ./scripts/deploy.sh --tenant tenant-a
   ```

5. Verify:

   ```bash
   ./scripts/status.sh
   ./scripts/smoke-test.sh --tenant tenant-a
   ```

---

## Update a Tenant

**Registry metadata:**

```bash
./scripts/update-tenant.sh tenant-a --display-name "Tenant A Updated"
./scripts/update-tenant.sh tenant-a --hostname tenant-a.example.com
./scripts/update-tenant.sh tenant-a --disable
./scripts/update-tenant.sh tenant-a --enable
```

**Tenant secrets or provider keys:**

1. Edit `${TENANT_ENV_ROOT}/tenant-a.env`
2. Redeploy:

   ```bash
   ./scripts/deploy.sh --tenant tenant-a
   ```

> **If auth breaks:** If `/openclaw` shows `origin not allowed` or a device-identity error after an update, check the [auth expectations](./configuration.md#openclaw-origin--auth-expectations) for fixes.

---

## Control-Plane Operations

Use the [host control-plane YAML](./configuration.md#layer-2-host-control-plane-overrides) to manage fleet-wide overrides without hand-editing individual tenant env files.

**When to use the control-plane YAML vs the tenant env file:**

| Change | Use |
| --- | --- |
| Pin a tenant to a specific OpenClaw version | Control-plane YAML |
| Inject or rotate managed API keys | Control-plane YAML |
| Set model allowlists, primary model, fallbacks | Control-plane YAML |
| Change agent-to-model binding | Control-plane YAML |
| Toggle route feature flags (Gemini, etc.) | Control-plane YAML |
| Change tenant hostname or allowed origins | Tenant env file |
| Change gateway token or Basic Auth credentials | Tenant env file |
| Enable/disable Tailscale | Tenant env file |

**Workflow:**

1. Edit the control-plane YAML at `${TENANT_CONTROL_PLANE_CONFIG_PATH}`
2. Redeploy the affected tenant(s):

   ```bash
   ./scripts/deploy.sh --tenant tenant-a
   ```

The sync script applies managed fields at deploy time. See [Configuration & Governance](./configuration.md) for the full field list and precedence rules.

---

## Upgrade All Tenants

To upgrade all tenants to a new OpenClaw version:

```bash
# Update the host default
# Edit .env → OPENCLAW_VERSION=<new-version>

# Redeploy all enabled tenants
./scripts/deploy.sh

# Verify
./scripts/status.sh
./scripts/smoke-test.sh --all
```

To upgrade a single tenant via the control-plane:

1. Set `openclawVersion` for that tenant in the control-plane YAML
2. Redeploy: `./scripts/deploy.sh --tenant <slug>`

---

## Deploy, Roll Back, Stop, Delete

```bash
# Deploy all enabled tenants
./scripts/deploy.sh

# Deploy shared ingress only
./scripts/deploy.sh --shared-only

# Roll back a tenant
./scripts/rollback.sh --tenant tenant-a

# Stop a tenant
./scripts/stop-tenant.sh tenant-a

# Delete a tenant (keep data)
./scripts/delete-tenant.sh tenant-a

# Delete a tenant and purge data
./scripts/delete-tenant.sh tenant-a --purge
```

---

## Health Checks

```bash
# List tenants
./scripts/list-tenants.sh

# Shared status
./scripts/status.sh

# Smoke test one tenant
./scripts/smoke-test.sh --tenant tenant-a

# Smoke test all enabled tenants
./scripts/smoke-test.sh --all
```

---

## Safety Rules

> **Safety rails:** These rules protect your deployment from common operational mistakes.

- Keep root `.env` and tenant env files outside public version control
- Keep tenant runtime data outside the repo checkout
- Re-render shared ingress by running the normal deploy scripts after tenant add/delete/hostname changes
- Use `TENANT_CONTAINER_SECURITY_PROFILE=tool-userns` before escalating to `privileged`
- Treat Cloudflare tunnel IDs, credentials files, API keys, and tenant auth tokens as secrets
