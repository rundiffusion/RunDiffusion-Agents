# Workflows

This reference is for the multi-tenant host stack only.
**If inspection shows the request is really a single-tenant deployment under
`services/rundiffusion-agents`, stop and use `$rundiffusion-standalone-agent-manager` instead.**

## Create Tenant

1. Validate `.env.example` against `.env`.
2. Choose a lowercase hyphenated slug.
3. Run:

```bash
./scripts/create-tenant.sh <slug> "<Display Name>" [hostname]
```

4. Edit the generated tenant env file and fill tenant-specific secrets.
   Confirm `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` matches the exact browser origin, including the
   Traefik port when it is not `80` or `443`.
   For vanilla native auth, the browser origin should be HTTPS or localhost.
   Plain HTTP LAN hostnames are not a supported native `/openclaw` path.
5. Deploy:

```bash
./scripts/deploy.sh --tenant <slug>
```

6. Verify:

```bash
./scripts/smoke-test.sh --tenant <slug>
./scripts/status.sh
```

## Update Tenant

Registry-only updates:

```bash
./scripts/update-tenant.sh <slug> --display-name "Updated Name"
./scripts/update-tenant.sh <slug> --hostname <hostname>
./scripts/update-tenant.sh <slug> --enable
./scripts/update-tenant.sh <slug> --disable
```

Config or secret updates:

1. Edit `${TENANT_ENV_ROOT}/<slug>.env`
   If `/openclaw` shows `origin not allowed`, update `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` to the
   exact public origin you open in the browser, including the port when present.
   If `/openclaw` says it requires device identity, move the browser origin to HTTPS or localhost.
   **If the requested deployment is really localhost-only Docker, stop and switch to
   `$rundiffusion-standalone-agent-manager`.**
2. Redeploy:

```bash
./scripts/deploy.sh --tenant <slug>
```

3. Re-run smoke test.

## Shared Changes

Use a shared deploy when changing:

- Traefik config
- Cloudflare config rendering
- shared compose
- shared root env values
- gateway image contents used by every tenant

Commands:

```bash
./scripts/deploy.sh
./scripts/deploy.sh --shared-only
```

## Inspect Effective Tenant Context

Use:

```bash
python3 skills/rundiffusion-host-agent-manager/scripts/tenant_runtime_context.py <slug>
```

Use this before debugging when you need to confirm:

- hostname
- env file path
- data root
- compose project name
- current release
- current image
- resource limits

## Health Check Loop

For one tenant:

```bash
bash skills/rundiffusion-host-agent-manager/scripts/agent_health_audit.sh <slug>
```

This should be your default post-change verification step when something feels off.
