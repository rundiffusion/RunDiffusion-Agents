# Deployment Matrix

RunDiffusion Agents supports four deployment scenarios across two package families. Use this page to find the right package, skill, and command path for your environment.

> **Fastest starting point:** Not sure which to pick? Start with **local single-tenant** — it is the fastest path to a working agent. You can upgrade to multi-tenant later without losing data.

---

## Package Families

| Package | Path | Use When |
| --- | --- | --- |
| **Single-tenant** | `services/rundiffusion-agents/` | One agent on localhost or one remote host. No Traefik. |
| **Multi-tenant** | Repo root host stack | Shared-host architecture with Traefik routing, per-tenant isolation. |

---

## Single-Tenant Scenarios

| | Local | Remote |
| --- | --- | --- |
| **Env template** | `services/rundiffusion-agents/.env.example` | `services/rundiffusion-agents/.env.example` |
| **Skill** | [`$rundiffusion-standalone-agent-manager`](../skills/rundiffusion-standalone-agent-manager/SKILL.md) | [`$rundiffusion-standalone-agent-manager`](../skills/rundiffusion-standalone-agent-manager/SKILL.md) |
| **Browser origin** | `localhost` — clean native `/openclaw` path | HTTPS or Cloudflare Tunnel for native `/openclaw` |

**First commands:**

```bash
cd services/rundiffusion-agents
cp .env.example .env
docker compose up -d --build
```

---

## Multi-Tenant Scenarios

| | Local / LAN | Remote |
| --- | --- | --- |
| **Env template** | `.env.example` + generated tenant env | `.env.example` + generated tenant env |
| **Skill** | [`$rundiffusion-host-agent-manager`](../skills/rundiffusion-host-agent-manager/SKILL.md) | [`$rundiffusion-host-agent-manager`](../skills/rundiffusion-host-agent-manager/SKILL.md) |
| **Browser origin** | Hostnames route tenants; HTTP is fine for sibling tools but not vanilla native `/openclaw` | Cloudflare Tunnel or your own DNS + HTTPS |

**First commands:**

```bash
cp .env.example .env
./scripts/create-tenant.sh tenant-a "Tenant A"
./scripts/deploy.sh
```

---

## Skill Routing

The bundled skills inspect the repo and env state before asking questions. When the wrong skill is invoked, it says so plainly and routes to the correct package.

**Expected inference:**

- Standalone vs multi-tenant
- Local vs remote intent
- Cloudflare vs direct DNS/HTTPS
- Which env example and command path apply

**Ask the user only when ambiguity remains,** such as:

- A fresh checkout with no env files and no clear target
- Conflicting standalone and multi-tenant state
- Remote intent is obvious but Cloudflare vs direct DNS/HTTPS is unclear

<details>
<summary><strong>Inspection order (agent detail)</strong></summary>

1. Current working directory
2. Root `.env.example`
3. Standalone `services/rundiffusion-agents/.env.example`
4. Root `.env`, if present
5. Standalone `services/rundiffusion-agents/.env`, if present
6. Tenant registry presence
7. `INGRESS_MODE`
8. Cloudflare tunnel vars
9. Hostname and allowed-origin values
10. Whether the user is operating from repo root or `services/rundiffusion-agents`

</details>

---

## Next Docs

- [Standalone Host Quickstart](./standalone-host-quickstart.md) — single-tenant from zero to running
- [Multi-Tenant Host Deployment](../deploy/README.md) — shared host stack with Traefik & ingress modes
- [Configuration & Governance](./configuration.md) — all config layers, precedence, and auth expectations
