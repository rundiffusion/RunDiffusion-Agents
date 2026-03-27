# Troubleshooting

## Docker Desktop Is Not Running

Symptom:

- `./scripts/deploy.sh` exits with `Docker Desktop is not running`
- `docker info` fails

Action:

1. Start Docker Desktop.
2. Wait until `docker info` succeeds.
3. Retry the deploy.

## Tenant Fails Health Checks

Symptom:

- `wait_for_tenant_healthy` fails
- `./scripts/deploy.sh --tenant <slug>` exits before smoke test passes

Action:

1. Run the audit script for the tenant.
2. Check `./scripts/status.sh`.
3. Inspect recent container logs.
4. Check the tenant env file for malformed secrets or missing required values.

## Tenant Fails Smoke Test

Symptom:

- `/healthz` or `/dashboard-api/config` does not respond through Traefik

Action:

1. Confirm tenant hostname and `TERMINAL_BASIC_AUTH_*` values.
2. Confirm Traefik is healthy.
3. Confirm the tenant is enabled in the local `deploy/tenants/tenants.yml`.
4. Confirm the tenant env file still exists at the path referenced by the registry.

## Container Starts But Routes Return 502

Symptom:

- `docker ps` shows the tenant container running
- `/healthz` succeeds when curled from inside the container
- Traefik returns `502 Bad Gateway` for the tenant hostname

Action:

1. Confirm the tenant container is on the correct Traefik Docker network (`TRAEFIK_NETWORK`).
2. Confirm the dynamic Traefik config references the correct container name and internal port.
3. Confirm Traefik can resolve the container — `docker network inspect <TRAEFIK_NETWORK>` should list it.
4. Re-render the Traefik dynamic config and redeploy the tenant.

## OpenClaw Shows `origin not allowed`

Symptom: `/openclaw` loads an `origin not allowed` message in the browser.

Action: Fix `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` to match the exact browser origin (including port) and redeploy. See [OpenClaw Origin & Auth Expectations](../../../docs/configuration.md#openclaw-origin--auth-expectations) for the full rules.

## OpenClaw Requires Device Identity On HTTP

Symptom: `/openclaw` shows `control ui requires device identity`.

Action: Move the browser origin to HTTPS or localhost. See [OpenClaw Origin & Auth Expectations](../../../docs/configuration.md#openclaw-origin--auth-expectations) for the full rules.

## Shared Ingress Failure

Symptom:

- `./scripts/status.sh` shows Traefik unhealthy
- all tenants fail at once

Action:

1. Inspect shared Traefik config changes first.
2. Re-render generated configs.
3. Use `./scripts/deploy.sh --shared-only` if only shared ingress changed.
4. Roll back shared infrastructure if needed:

```bash
./scripts/rollback.sh --shared
```

## Build Failure

Symptom:

- `docker buildx build` fails before containers restart

Action:

1. Surface the exact failing build step and stderr.
2. Identify whether the failure is in:
   - gateway Dockerfile
   - npm install or dashboard build
   - package install
   - copied runtime scripts
3. Patch the tracked file causing the failure.
4. Re-run the tenant deploy.

Do not summarize build failures as "pod build failed" without the specific step.
