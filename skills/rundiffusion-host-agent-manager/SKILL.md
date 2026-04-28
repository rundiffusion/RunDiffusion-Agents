---
name: rundiffusion-host-agent-manager
description: Manage the RunDiffusion Agents multi-tenant host deployment in this repo. Use when creating a new tenant, updating tenant metadata, tenant env files, or host-side control-plane overrides, validating root `.env` against `.env.example`, deriving the effective Docker deploy context for a tenant, deploying or rolling back a tenant, or diagnosing unhealthy Docker, Traefik, cloudflared, or tenant routes on a shared host.
---

# Openclaw Host Agent Manager

## Overview

Use this skill as the source of truth for the **multi-tenant host stack** in this repo. Treat a
user-facing "agent" as a tenant deployment backed by one `openclaw-gateway` container, a tenant
env file, registry entry, release history, and shared host ingress.

This skill owns:

- local multi tenant
- remote multi tenant
- LAN/private-network tenants
- direct public host or VM deployments
- Cloudflare Tunnel deployments

Do not use this skill for the standalone single-tenant package under
`services/rundiffusion-agents`. For local single-tenant or remote single-tenant installs, use
`$rundiffusion-standalone-agent-manager`.

## Inspect First, Ask Second

Before mutating anything, inspect this repo in the following order:

1. current working directory
2. root `.env.example`
3. `services/rundiffusion-agents/.env.example`
4. root `.env`, if present
5. `services/rundiffusion-agents/.env`, if present
6. `TENANT_CONTROL_PLANE_CONFIG_PATH`, if present in root `.env`
7. the host-only control-plane YAML at that path, if it exists
8. tenant registry presence
9. `INGRESS_MODE`
10. Cloudflare tunnel vars
11. hostname and allowed-origin values
12. whether the user is operating from repo root or `services/rundiffusion-agents`

Infer these before asking the user anything:

- standalone vs multi-tenant
- local vs remote intent
- Cloudflare vs direct DNS/HTTPS
- which env example applies
- which package and command path apply

Ask the user only if the environment is still ambiguous after inspection, such as:

- a fresh checkout with no env files and no clear target
- conflicting standalone and multi-tenant state
- remote intent is clear but Cloudflare vs direct DNS/HTTPS is not

If inspection shows the request is really standalone single-tenant, say so plainly and switch to
`$rundiffusion-standalone-agent-manager` instead of guessing.

## Core Rule

Read the root env contract before mutating anything:

- Read [`../../.env.example`](../../.env.example) to learn which shared host variables exist and which ones are expected.
- Read [`../../.env`](../../.env) to get the actual live values for this host when the file exists.
- Read [`../../deploy/tenants/templates/tenant.env.example`](../../deploy/tenants/templates/tenant.env.example) or the real tenant env file for tenant-specific variables.
- Do not invent new env keys when an existing script already derives them.

Use [`scripts/validate_root_env.py`](./scripts/validate_root_env.py) first when the root env may be incomplete or drifted.
Use [`scripts/validate_skill.py`](./scripts/validate_skill.py) to validate this skill on hosts where the system `quick_validate.py` cannot run because `PyYAML` is missing.

## Environment Model

This deployment has three host-side config layers:

| Layer | Source | Owns |
| --- | --- | --- |
| **Root `.env`** | `.env.example` | Shared host settings: `DATA_ROOT`, `TENANT_ENV_ROOT`, `TRAEFIK_*`, `IMAGE_REPOSITORY`, release behavior |
| **Control-plane YAML** (optional) | Host-only file outside git | Tenant-scoped managed overrides: `openclawVersion`, provider keys, startup model state, route flags |
| **Tenant env file** | `${TENANT_ENV_ROOT}/<slug>.env` | Tenant-specific auth, enable flags, provider credentials: `OPENCLAW_GATEWAY_TOKEN`, `TERMINAL_BASIC_AUTH_*`, `GEMINI_API_KEY`, `PI_*` keys |

Important:

- **Root vars are not copied into tenant env files.**
- `TENANT_CONTROL_PLANE_CONFIG_PATH` points to the optional host-only YAML. Default: `${TENANT_ENV_ROOT}/control-plane.yml`.
- **When the control-plane YAML exists and contains a tenant entry, it is authoritative** for the deploy-time managed fields handled by `scripts/sync_tenant_control_plane.py`.
- `deploy/tenants/tenants.yml` is created automatically from `deploy/tenants/tenants.example.yml` when missing.
- **`./scripts/create-tenant.sh` creates both the registry entry and the tenant env file** at `${TENANT_ENV_ROOT}/<slug>.env`.
- Root vars are exported by `scripts/lib/common.sh` and used to derive compose inputs like `TENANT_ENV_FILE`, `TENANT_DATA_ROOT`, `TENANT_HOSTNAME`, `TRAEFIK_NETWORK`, and `OPENCLAW_IMAGE`.
- `./scripts/deploy.sh` now also derives `TENANT_MANAGED_ENV_FILE` and runs deploy-time sync from the host control-plane YAML before starting the tenant.
- The tenant container itself receives both the tenant env file and the managed env overlay through `deploy/tenant-stack.compose.yml`.

See [`../../docs/configuration.md`](../../docs/configuration.md) for the full control-plane field list, precedence, and ownership rules.

Shared ingress behavior:

- `./scripts/deploy.sh --tenant <slug>` re-renders the watched Traefik dynamic config and should not recreate Traefik when shared static ingress settings are unchanged.
- Shared static ingress changes still recreate Traefik. Treat changes to the resolved shared compose config or `deploy/traefik/traefik.yml` as restart-triggering.
- The first deploy after introducing this restart-detection logic may still recreate Traefik once to seed the shared compose snapshot used for future comparisons.

Use [`scripts/tenant_runtime_context.py`](./scripts/tenant_runtime_context.py) to inspect the effective runtime context for one tenant before editing or debugging it.

Read [`references/env-contract.md`](./references/env-contract.md) for the full model.
Read [`../../docs/linux-cloud-host-quickstart.md`](../../docs/linux-cloud-host-quickstart.md) when
the target host is a Linux server, bare VM, or any cloud-hosted Linux machine.

## Create A New Agent

When the user wants a new tenant on the shared host stack, create a new tenant deployment:

1. Validate the root env:

```bash
python3 skills/rundiffusion-host-agent-manager/scripts/validate_root_env.py
```

2. Create the tenant:

```bash
./scripts/create-tenant.sh <slug> "<Display Name>" [hostname]
```

3. Open the generated tenant env file at `${TENANT_ENV_ROOT}/<slug>.env` and fill only tenant-specific values.
   `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` must match the exact browser origin, including the
   Traefik port when it is not `80` or `443`.
   For vanilla native auth, the browser origin should be HTTPS or localhost so device approval can use a secure context.
   Plain HTTP LAN hostnames are not a supported native `/openclaw` path.
   If this host uses a control-plane YAML, put managed overrides there instead of hand-editing the tenant env or container state.
4. Deploy just that tenant:

```bash
./scripts/deploy.sh --tenant <slug>
```

5. Verify health:

```bash
./scripts/smoke-test.sh --tenant <slug>
./scripts/status.sh
```

If deployment fails, run:

```bash
bash skills/rundiffusion-host-agent-manager/scripts/agent_health_audit.sh <slug>
```

Read [`references/workflows.md`](./references/workflows.md) for the detailed flow.

## Validate This Skill

Run:

```bash
python3 skills/rundiffusion-host-agent-manager/scripts/validate_skill.py
```

This validator is self-contained and does not depend on `PyYAML`.

## Update Or Patch An Existing Agent

Use the narrowest change path that fits:

- Registry metadata only:

```bash
./scripts/update-tenant.sh <slug> --display-name "New Name"
./scripts/update-tenant.sh <slug> --hostname <host>
./scripts/update-tenant.sh <slug> --enable
./scripts/update-tenant.sh <slug> --disable
```

- Secrets, startup models, feature flags, or a tenant-specific OpenClaw version:
  If the host control-plane YAML is in use and the tenant has an entry there, update the host-only control-plane YAML first, then redeploy with `./scripts/deploy.sh --tenant <slug>`.
  Otherwise edit the real tenant env file, then redeploy with `./scripts/deploy.sh --tenant <slug>`.
  If `/openclaw` shows `origin not allowed`, fix `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` to the
  exact public browser origin, including the port when present.
  If `/openclaw` says it requires device identity, move the browser origin to HTTPS or localhost for the native flow.
  If the user wants simple single-service Docker instead of the shared host stack, stop and switch
  to `$rundiffusion-standalone-agent-manager`.

  Expect tenant-only deploys to keep shared ingress up unless this host is doing its first deploy after the restart-detection rollout.

- Shared ingress or shared host changes:
  Validate `.env`, update repo config, then run `./scripts/deploy.sh` or `./scripts/deploy.sh --shared-only` if the change is shared-only.

After every mutation, run `./scripts/smoke-test.sh --tenant <slug>` unless the user explicitly says not to.

## Control-Plane Override Workflow

Use the host-only control-plane YAML when the user wants one place to manage a per-tenant OpenClaw version or other deploy-time managed overrides.

1. Inspect root `.env` for `TENANT_CONTROL_PLANE_CONFIG_PATH`.
2. If the file exists, inspect the tenant entry before editing the tenant env file.
3. For managed fields, update the control-plane YAML instead of the tenant env file.
4. Redeploy the tenant with `./scripts/deploy.sh --tenant <slug>`.
5. Verify inside the live container:
   - `/data/.openclaw/openclaw.json`
   - `/data/.openclaw/agents/main/agent/auth-profiles.json`
   - `/data/.codex/config.toml`
   - `env | sort` for the managed key vars

Prefer the control-plane YAML for managed fields because it is authoritative at deploy time. `openclawVersion` stays host-side and affects image selection during deploy; it is not copied into the tenant env file.

## Diagnose Build Or Runtime Failures

When a build, deploy, or smoke test fails:

1. Capture the exact failing command and stderr.
2. Run the health audit script for the tenant if one exists.
3. Surface the concrete failure with file or command references.
4. Patch the repo if the failure is caused by tracked code or config.
5. Roll back only when recovery is slower or riskier than restoring the previous known-good release.

Do not say "the pod failed" without naming:

- whether Docker failed before compose,
- whether compose failed before health,
- whether health failed before smoke test,
- whether ingress failed after the container became healthy.

Use these references when troubleshooting:

- [`references/troubleshooting.md`](./references/troubleshooting.md)
- [`scripts/agent_health_audit.sh`](./scripts/agent_health_audit.sh)

## Rollback

When a tenant is broken after a deploy and a known-good release exists:

```bash
./scripts/rollback.sh --tenant <slug>
./scripts/rollback.sh --tenant <slug> --release <release-id>
```

For shared ingress rollback:

```bash
./scripts/rollback.sh --shared
```

Prefer explaining why rollback is needed before invoking it.
