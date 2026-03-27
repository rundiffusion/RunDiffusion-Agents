---
name: rundiffusion-standalone-agent-manager
description: Manage the standalone RunDiffusion Agents single-tenant deployment in this repo. Use when a user wants local single-tenant or remote single-tenant deployment under `services/rundiffusion-agents`, help with the standalone `.env`, or help starting, stopping, rebuilding, or repairing the standalone package with Docker Compose.
---

# Openclaw Standalone Agent Manager

## Overview

Use this skill for the **single-tenant** `openclaw-gateway` deployment under
`services/rundiffusion-agents/`.

This skill owns:

- local single tenant
- remote single tenant
- direct DNS + HTTPS single-service hosts
- Cloudflare-published single-service hosts

Do not use this skill for the repo-root shared-host stack with Traefik and per-tenant env files.
For local multi-tenant or remote multi-tenant installs, use
`$rundiffusion-host-agent-manager`.

## Inspect First, Ask Second

Before mutating anything, inspect this repo in the following order:

1. current working directory
2. root `.env.example`
3. `services/rundiffusion-agents/.env.example`
4. root `.env`, if present
5. `services/rundiffusion-agents/.env`, if present
6. tenant registry presence
7. `INGRESS_MODE`
8. Cloudflare tunnel vars
9. hostname and allowed-origin values
10. whether the user is operating from repo root or `services/rundiffusion-agents`

Infer these before asking the user anything:

- standalone vs multi-tenant
- local vs remote intent
- Cloudflare vs direct DNS/HTTPS
- which env example applies
- which command path applies

Ask the user only if the environment is still ambiguous after inspection, such as:

- a fresh checkout with no env files and no stated target
- conflicting standalone and multi-tenant state
- remote intent is clear but Cloudflare vs direct DNS/HTTPS is not

If inspection shows the request is really multi-tenant, say so plainly and switch to
`$rundiffusion-host-agent-manager` instead of guessing.

## Core Rule

Read the standalone contract before mutating anything:

- Read [`../../services/rundiffusion-agents/.env.example`](../../services/rundiffusion-agents/.env.example).
- Read [`../../services/rundiffusion-agents/docker-compose.yml`](../../services/rundiffusion-agents/docker-compose.yml).
- Read [`../../services/rundiffusion-agents/.env`](../../services/rundiffusion-agents/.env) if it already exists.
- Prefer explicit loopback origins such as `http://127.0.0.1:8080,http://localhost:8080` for localhost installs.
- Keep native OpenClaw vanilla. Do not recommend insecure-auth or device-auth bypass flags as the normal path.

## Standard Workflow

1. Enter the standalone package:

```bash
cd services/rundiffusion-agents
```

2. Create the env file from the example if it is missing:

```bash
cp .env.example .env
```

3. Set at least:

- `OPENCLAW_ACCESS_MODE=native`
- `OPENCLAW_GATEWAY_TOKEN=<long-random-secret>`
- `TERMINAL_BASIC_AUTH_USERNAME=<username>`
- `TERMINAL_BASIC_AUTH_PASSWORD=<strong-password>`
- `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=<exact browser origin>`

4. Adjust Compose helper vars only when the host-side package shape needs it:

- `STANDALONE_BIND_ADDRESS`
- `STANDALONE_PUBLIC_PORT`
- `STANDALONE_CONTAINER_NAME`
- `STANDALONE_DATA_VOLUME`

5. Start or rebuild the package:

```bash
docker compose up -d --build
```

6. Verify:

```bash
docker compose ps
curl -fsS http://127.0.0.1:${STANDALONE_PUBLIC_PORT:-8080}/healthz
curl -I http://127.0.0.1:${STANDALONE_PUBLIC_PORT:-8080}/openclaw
curl -I -u <username>:<password> http://127.0.0.1:${STANDALONE_PUBLIC_PORT:-8080}/dashboard
```

7. Return the deployed URLs and credentials to the user exactly as configured:

```text
http://127.0.0.1:<port>/openclaw/
http://127.0.0.1:<port>/dashboard/

Operator credentials:
username: <TERMINAL_BASIC_AUTH_USERNAME>
password: <TERMINAL_BASIC_AUTH_PASSWORD>

OpenClaw gateway token: <OPENCLAW_GATEWAY_TOKEN>
```

Use the actual runtime values from `services/rundiffusion-agents/.env`, not placeholders.
If the auth password contains symbols, do not assume it is broken just because a user had trouble entering it.
Only rotate credentials when verification shows a real auth problem or the user asks for a change.
When the bind address, port, hostname, or scheme differs from localhost defaults, return the real reachable URLs instead of hard-coding `127.0.0.1:8080`.

## Operations

Use these as the default day-two commands:

```bash
docker compose logs -f
docker compose down
docker compose up -d --build
```

## Important Guidance

- **`localhost` is the clean native OpenClaw path without HTTPS.**
- **If the browser origin moves to a non-loopback hostname, native `/openclaw` needs HTTPS** or an intentional switch to `trusted-proxy`.
- For remote single-tenant direct installs, DNS and HTTPS are external to this repo.
- For remote single-tenant Cloudflare installs, treat the tunnel as host-managed infrastructure outside this package.
- If the user asks for multiple tenant hostnames, shared ingress, `./scripts/create-tenant.sh`, or repo-root Traefik management, stop and switch to `$rundiffusion-host-agent-manager`.
