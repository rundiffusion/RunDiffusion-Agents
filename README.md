<p align="center">
  <img src="services/rundiffusion-agents/dashboard/public/rundiffusion-agents-logo.png" alt="RunDiffusion Agents — open-source multi-agent orchestration platform" width="150">
</p>

<h1 align="center">RunDiffusion Agents</h1>

<p align="center">
  <strong>Open-Source Multi-Agent Orchestration Platform</strong>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue.svg" alt="License: Apache-2.0"></a>
  <a href="https://www.docker.com/"><img src="https://img.shields.io/badge/docker-ready-2496ED?logo=docker&logoColor=white" alt="Docker Ready"></a>
  <a href="https://discord.com/invite/wH6dTyBpCf"><img src="https://img.shields.io/badge/Discord-35k%2B_members-5865F2?logo=discord&logoColor=white" alt="Discord"></a>
  <img src="https://img.shields.io/badge/status-production-brightgreen" alt="Production Status">
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL2-lightgrey" alt="Platform: macOS | Linux | WSL2">
</p>

<p align="center">
  <em>One YAML control plane to deploy, govern, and scale your AI agent fleet.</em><br>
  Running in production at RunDiffusion since February 2026.
</p>

<p align="center">
  <a href="#-why-this-exists">Why This Exists</a> &nbsp;&middot;&nbsp;
  <a href="#-the-yaml-control-plane">Control Plane</a> &nbsp;&middot;&nbsp;
  <a href="#-quick-start">Quick Start</a> &nbsp;&middot;&nbsp;
  <a href="#-architecture">Architecture</a> &nbsp;&middot;&nbsp;
  <a href="#-how-we-use-it-at-rundiffusion">Use Cases</a> &nbsp;&middot;&nbsp;
  <a href="#-showcase">Showcase</a> &nbsp;&middot;&nbsp;
  <a href="#-documentation">Docs</a> &nbsp;&middot;&nbsp;
  <a href="https://www.rundiffusion.com/contact-sales?utm_source=github&utm_medium=readme&utm_campaign=run-diffusion-agents&utm_content=header-contact" target="_blank" rel="noopener noreferrer">Contact</a>
</p>

---

<div align="center">
<table>
<tr>
<td align="center" width="50%">

**Multi-agent orchestration**<br>
<sub>Run OpenClaw, Codex, Claude, Gemini & Hermes side-by-side. With a Filebrowser and full Terminal</sub>

</td>
<td align="center" width="50%">

**YAML control plane**<br>
<sub>Govern versions, models, secrets & routes from one file</sub>

</td>
</tr>
<tr>
<td align="center">

**Per-tenant isolation**<br>
<sub>Docker containers with Traefik routing per agent operator</sub>

</td>
<td align="center">

**Agent-managed operations**<br>
<sub>Agents create, repair, upgrade & audit other agents</sub>

</td>
</tr>
<tr>
<td align="center">

**Self-hosted & cost-aware**<br>
<sub>Bare metal, LAN, cloud, or Cloudflare Tunnel — you own it</sub>

</td>
<td align="center">

**Production-tested**<br>
<sub>Runs our entire agent fleet on a single $600 Mac Mini M4</sub>

</td>
</tr>
</table>
</div>

---

## 🔥 Why This Exists

Every team is experimenting with AI agents. Very few can actually **operationalize** them. The gap between "we have a chatbot" and "we have a governed agent fleet driving real output" is enormous — and that gap is where your competitors are moving right now.

Without a control plane, you get tool sprawl, leaked secrets, shadow AI, and agents that nobody owns. With one, you get centralized governance, controlled rollout, and **10x more output without the chaos**.

> **Your competitors are standing up governed AI infrastructure today.** Yes, it's bleeding-edge. But the teams that operationalize AI agents first will compound that advantage every single week. The cost of waiting is falling behind.

This repo is proof that RunDiffusion knows how to deploy governed AI infrastructure in the real world. It is the **exact system** running in production across our organization — not a demo, not a reference architecture, not a blog post. Real agents, real governance, real output.

**Spin it up. Get a win. Then scale it to your team.**

---

## 🎛️ The YAML Control Plane

Every tenant in your fleet is governed by a single YAML file. Pin versions, enforce model policy, rotate secrets, and toggle routes — all without touching individual containers or hand-editing env files.

```yaml
tenants:
  dholbrook-marketing-agent: # This becomes the agent URL prefix
    openclawVersion: 2026.3.24 # Pin the exact OpenClaw version per tenant

    secrets: # Inject API keys from the host — not baked into images
      GEMINI_API_KEY: ""
      GEMINI_CLI_API_KEY: ""
      HERMES_OPENAI_API_KEY: ""
      CODEX_OPENAI_API_KEY: ""
      CLAUDE_ANTHROPIC_API_KEY: ""
      OPENROUTER_API_KEY: ""

    models:
      allowed: # Allowlist which models this tenant can use
        - openai/gpt-5.4
      primary: openai/gpt-5.4 # Set the default model
      fallbacks: [] # Optional fallback chain

    agents:
      main:
        model: openai/gpt-5.4 # Bind the operator agent to a specific model

    providers:
      google:
        hydrateAuth: false # Control provider-level auth behavior

    routes:
      gemini:
        enabled: false # Feature-flag any tool on or off per tenant
```

**What you control from one file:**

- **Version pins** — lock each tenant to a specific OpenClaw release, roll forward on your schedule
- **Secret injection** — API keys managed at the host level, never committed to git
- **Model governance** — allowlists, primary model selection, and fallback chains
- **Agent-to-model binding** — decide which model powers each tenant's operator
- **Provider policy** — toggle auth hydration and provider-level behavior
- **Route-level feature flags** — enable or disable Gemini, Claude, Codex, or any route per tenant

This is the difference between "we have AI tools" and "we have AI governance." One file. Full fleet control.

See the [Configuration Guide](docs/configuration.md) for the complete override surface across all four config layers.

---

## ⚡ Quick Start

### The Fastest Way: Let an Agent Do It

<p align="center">
  <img src="images/Agent_Install.png" alt="Agent-assisted install for RunDiffusion multi-agent platform" width="800">
</p>

Point an agent at this repo, have it install the matching skill, and it handles the entire deployment — configuration, secrets, tenant creation, and verification — then hands you back the URLs and credentials.

**Step 1.** Tell your agent which setup you want:

| I want...                                                               | Have your agent install this skill                                                                |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| **Multiple agents** on a shared host with Traefik routing (recommended) | [`$rundiffusion-host-agent-manager`](skills/rundiffusion-host-agent-manager/SKILL.md)             |
| **One agent** on this machine or one remote host                        | [`$rundiffusion-standalone-agent-manager`](skills/rundiffusion-standalone-agent-manager/SKILL.md) |

**Step 2.** Give your agent a prompt:

```text
Install the skill from /skills/rundiffusion-host-agent-manager, then use it to
create me a RunDiffusion multi-tenant cluster locally with one tenant called
"Chad Smith" using slug "csmith-1234". Configure the first tenant, deploy it,
and return the tenant URLs and credentials.
```

<details>
<summary><strong>More example prompts</strong></summary>

- `Install the skill from /skills/rundiffusion-standalone-agent-manager, then use it to create me a RunDiffusion Agent locally. Use the keys in services/rundiffusion-agents/.env. Name the deployment "My Agent". Return the /openclaw/ URL, the /dashboard/ URL, the operator credentials, and the OpenClaw gateway token.`
- `Install the skill from /skills/rundiffusion-standalone-agent-manager, then use it to create me a RunDiffusion Agent locally. Use the keys in <path-to-env-file>. Name the deployment "My Agent". Keep native OpenClaw auth enabled and return the actual reachable URLs plus the generated credentials.`
- `Install the skill from /skills/rundiffusion-standalone-agent-manager, then use it to create me a remote single-tenant RunDiffusion Agent. Use HTTPS or Cloudflare Tunnel as needed for native /openclaw, tell me which values you can infer from the repo, and tell me exactly what host or DNS inputs you still need from me.`
- `Install the skill from /skills/rundiffusion-host-agent-manager, then use it to create me a RunDiffusion multi-tenant cluster with one tenant called "Chad Smith" using slug "csmith-1234", and help me get Cloudflare Tunnel set up. Use the repo root host stack, configure the tenant, deploy it, and tell me which Cloudflare values or DNS steps still need my input.`

</details>

**Step 3.** Keep using the same agent + skill for updates, redeploys, tenant changes, health checks, and troubleshooting.

Both skills **inspect first, ask second** — they check the working directory and repo state, infer your intent when possible, and only ask clarifying questions when the state is ambiguous.

---

<details>
<summary><h3>Manual Setup</h3></summary>

#### Prerequisites

**Single-tenant** only requires **Docker** with Compose support.

**Multi-tenant** also requires: `bash`, `curl`, `jq`, `yq`, `openssl`, and optionally `python3`.

We highly recommend getting a **Gemini API key** (or using a Codex account) to give your agents some "gas" to get moving immediately.

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

1. Install Docker Desktop on Windows.
2. Enable WSL2 integration for your Linux distro in Docker Desktop.
3. Inside the WSL distro, install the Linux prerequisites above for your distro.

</details>

---

#### Multi-Tenant (Recommended)

Use this when you want the full shared-host architecture — Traefik ingress, per-tenant isolation, and the ability to scale to many agents.

1. **Configure the Environment**

   ```bash
   cp .env.example .env
   ```

   _Edit the root `.env` file with your host paths, ingress mode, and shared settings._

2. **Create the local tenant registry**

   ```bash
   cp deploy/tenants/tenants.example.yml deploy/tenants/tenants.yml
   ```

   _If you skip this, the deploy scripts create `deploy/tenants/tenants.yml` automatically from the example._

3. **Create your first tenant**

   ```bash
   ./scripts/create-tenant.sh tenant-a "Tenant A"
   ```

   _This generates the tenant env file for you at `${TENANT_ENV_ROOT}/tenant-a.env`. Start from that generated file rather than inventing a new contract._

4. **Edit the tenant env file outside git**
   Set the tenant hostname, auth, and provider keys. Keep
   `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` equal to the exact browser origin. For vanilla native
   `/openclaw`, that browser origin should be **HTTPS** unless you are on `localhost`.

5. **Deploy the host stack**

   ```bash
   ./scripts/deploy.sh
   ```

   _This brings up shared ingress and deploys all enabled tenants._

6. **Verify health**
   ```bash
   ./scripts/status.sh
   ./scripts/smoke-test.sh --all
   ```

<details>
<summary><strong>Multi-Tenant LAN & Remote Notes</strong></summary>

- `INGRESS_MODE=local` is for local multi-tenant and LAN/private-network installs.
- `INGRESS_MODE=direct` is for remote multi-tenant hosts where you already have DNS and HTTPS handled outside the repo.
- `INGRESS_MODE=cloudflare` is for remote multi-tenant hosts published through Cloudflare Tunnel.
- On plain HTTP LAN hostnames, `/dashboard`, `/terminal`, `/filebrowser`, `/hermes`, `/codex`, `/claude`, and `/gemini` work cleanly, but vanilla native `/openclaw` still needs HTTPS or localhost.

TLS automation for private-hostname LAN installs is still outside the scope of this release.

</details>

---

#### Single-Tenant

Use `services/rundiffusion-agents` when you want one agent package without Traefik.

1. **Open the standalone package**

   ```bash
   cd services/rundiffusion-agents
   ```

2. **Copy the standalone env template**

   ```bash
   cp .env.example .env
   ```

3. **Edit the standalone env**
   Set at least:
   - `OPENCLAW_ACCESS_MODE=native`
   - `OPENCLAW_GATEWAY_TOKEN=<long-random-secret>`
   - `TERMINAL_BASIC_AUTH_USERNAME=<username>`
   - `TERMINAL_BASIC_AUTH_PASSWORD=<strong-password>`
   - `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=http://127.0.0.1:8080,http://localhost:8080` for localhost
   - `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=https://agent.example.com` for a remote HTTPS hostname

4. **Start the package**

   ```bash
   docker compose up -d --build
   ```

5. **Open the service**
   - Dashboard: `http://127.0.0.1:8080/dashboard` for localhost
   - OpenClaw: `http://127.0.0.1:8080/openclaw` for localhost

For remote single-tenant installs, see [docs/standalone-host-quickstart.md](docs/standalone-host-quickstart.md) for the full localhost, remote DNS, and remote Cloudflare flows.

</details>

---

## 🚀 How We Use It at RunDiffusion

This is running in production. Here is what it does for us:

- **Content Creation:** Our content team has their agents hooked up to our blogging platform. A vast majority of our articles on [RunDiffusion Image](https://www.rundiffusion.com/image?utm_source=github&utm_medium=readme&utm_campaign=run-diffusion-agents&utm_content=use-cases-image) and [RunDiffusion Video](https://www.rundiffusion.com/video?utm_source=github&utm_medium=readme&utm_campaign=run-diffusion-agents&utm_content=use-cases-video) are produced agentically. This includes dynamic image generation and intelligent cross-site linking. **Switching to our agent farm has saved our content team over 8 hours of work per week**, allowing them to focus on strategy rather than formatting.

- **Development & Code Review:** Our devs use the agents to check code at night. The agents scan commits, run static analysis, flag potential bugs, and even draft pull requests by the time the team wakes up. It's like having an indefatigable senior engineer reviewing your work 24/7.

- **Sales & Marketing:** Our teams use agents to help draft highly-contextualized replies to prospects. We _never_ send automated responses to clients — the human touch is crucial — but we use agents to draft the perfect reply, ensuring everyone gets answered promptly and accurately.

- **Automated QA:** Our QA team uses agents hooked into Playwright to autonomously write and execute tests across our platforms. The agents interact with the DOM, test user flows, and report back on breaking changes before they hit production.

- **Project Management:** We have our agents hooked into Monday.com to monitor the health of tasks and keep projects moving seamlessly. One agent's specific job is to scan the board for any tasks that have been stale for 3 days and gently ping the assignees for updates, completely eliminating the need for manual "just checking in" messages.

- **Design Review:** We imported the rules of _Refactoring UI_ into an agent's context to have it automatically check design decisions and mockups submitted by the team. It acts as an automated design linter, ensuring our UI consistency stays top-notch.

> **Hardware:** All of this runs on a single 2024 Mac Mini M4 with 16 GB of RAM — about 6 to 8 agents comfortably.

---

## 🏗️ Architecture

A **strong operator agent** sits above the deployment and manages the rest of the fleet. This is what makes RunDiffusion Agents an **agent orchestration platform**, not just another AI tool.

```
┌─────────────────────────────────────────────────────┐
│                  Operator Agent                     │
│          (GPT-5.4 / Claude Opus / Gemini)           │
└──────────────────────┬──────────────────────────────┘
                       │  reads / writes
                       ▼
         ┌───────────────────────────────┐
         │    control-plane.yml          │
         │  versions · models · secrets  │
         │  routes · agents · policy     │
         └──────────────┬────────────────┘
                        │  applied at deploy
                        ▼
              ┌───────────────────┐
              │     Traefik       │
              │   (edge router)   │
              └───┬───┬───┬───┬───┘
                  │   │   │   │
         ┌────┐ ┌────┐ ┌────┐ ┌────┐
         │ T1 │ │ T2 │ │ T3 │ │ T4 │   ← isolated Docker containers
         └────┘ └────┘ └────┘ └────┘
          each: OpenClaw · Codex · Claude · Gemini · Hermes
                Terminal · FileBrowser · Dashboard
```

**At a glance:**

- **Traefik** routes traffic to the right tenant and tool at the edge
- Each tenant runs in its own **isolated Docker container**
- A host-side **control-plane YAML** centrally manages version pins, route flags, model policy, and secrets
- **Provisioning scripts** handle create, deploy, update, rollback, backup, restore, smoke tests, and health checks
- **Cloudflare Tunnel** support for secure remote access without exposing the host
- **Cloudflare Access** can be added for additional authentication and gateway security
- Each agent gets its own **stateful workspace** — dashboard, terminal, and file browser in one place

See the [deployment matrix](docs/deployment-matrix.md) for all four deployment shapes and the [configuration guide](docs/configuration.md) for the control-plane override surface.

### Agent-Managed Operations

Instead of manually editing containers and env files, point a capable agent at this repo and give it high-level tasks:

**Create a new agent:**

```text
> Create me a new agent for David Smith.

Done. I created tenant "dsmith-7821", generated the env file, provisioned data
directories, and assigned the default OpenClaw version. Here are the URLs,
operator credentials, and gateway token. Want me to deploy and run smoke tests?
```

**Upgrade the whole cluster:**

```text
> Update all agents to the latest OpenClaw and run the tests.

Done. Updated the host default version, redeployed each tenant in order, and ran
smoke tests after each rollout. All tenants are aligned. Full report attached.
```

<details>
<summary><strong>More agent operation examples</strong></summary>

**Copy skills between agents:**

```text
> Copy the skills from Dave's Marketing agent to Tyler's Marketing agent.

Done. Synced the missing marketing skills from Dave's agent into Tyler's,
preserved Tyler's local customizations, and verified file paths. Tyler now has
the same baseline skill pack as Dave.
```

**Audit secrets across the fleet:**

```text
> Check all deployments for secrets and tell me what should move to the control plane.

Done. Scanned all tenant env files and host config. Grouped findings into:
shared secrets that belong in the control plane, tenant-specific credentials,
duplicated values, and keys that should be rotated before centralization.
Ready to generate a migration plan when you are.
```

</details>

### Recommended Operator Models

| Model                        | Best For                                                     | Notes                              |
| ---------------------------- | ------------------------------------------------------------ | ---------------------------------- |
| **OpenAI GPT-5.4**           | Top-end agentic operations, coding, long-running infra tasks | Highest capability vs cost         |
| **Claude Opus 4.6**          | Most capable Claude-class operator                           | Strong reasoning                   |
| **Claude Sonnet 4.5**        | Fast, highly capable day-to-day operations                   | Best speed/capability ratio        |
| **Gemini 3 Flash** (preview) | Budget-conscious operations                                  | Our pick for capability per dollar |

---

## 📸 Showcase

Each tool runs on its own dedicated route — pop any app out of the dashboard for a full-screen experience.

### OpenClaw, Codex, Claude & Gemini

Run your favorite models side-by-side in fully featured, stateful environments.

<p align="center">
  <img src="images/OpenClaw.png" alt="OpenClaw — AI agent orchestration interface" width="400">&nbsp;&nbsp;
  <img src="images/Codex.png" alt="Codex — OpenAI agent terminal" width="400">
</p>
<p align="center">
  <img src="images/Claude.png" alt="Claude Code — Anthropic agent terminal" width="400">&nbsp;&nbsp;
  <img src="images/Gemini.png" alt="Gemini CLI — Google agent terminal" width="400">
</p>

<details>
<summary><strong>Hermes — Delegated Tasks</strong></summary>

Delegate complex, asynchronous tasks to sub-agents and let Hermes manage the execution.

<p align="center">
  <img src="images/Hermes.png" alt="Hermes — delegated task execution for multi-agent platform" width="800">
</p>

</details>

<details>
<summary><strong>Integrated Terminal</strong></summary>

Separate, fully integrated terminal sessions for each application with multiple modes for scrolling, copying, and pasting.

<p align="center">
  <img src="images/Terminal.png" alt="Integrated terminal for self-hosted AI agents" width="800">
  <img src="images/Help_Files.png" alt="Terminal help modal" width="800">
</p>

</details>

<details>
<summary><strong>Quantum Filebrowser</strong></summary>

A secure file browser for managing documents and adding secrets securely.
_(User write permissions are **OFF by default** for security. Turn them on in settings to upload.)_

<p align="center">
  <img src="images/Filebrowser.png" alt="Filebrowser — secure file management for agent fleet" width="800">
</p>

</details>

<details>
<summary><strong>Utilities & Dashboard</strong></summary>

Your entire agent farm is secured by Basic Auth, with robust device pairing for OpenClaw. The utilities section features custom scripts like `approve-device` and gateway recovery helpers to keep your farm healthy.

<p align="center">
  <img src="images/Utilities.png" alt="Utilities panel — agent fleet management dashboard" width="800">
</p>

</details>

---

## 💡 Good to Know

- **Terminal Quirks:** The integrated terminal has multiple modes for scrolling, copying, and pasting. Read the help modal inside the terminal for full details.
- **Filebrowser Permissions:** User write permissions are **OFF by default** for security. You must manually turn them on in the Filebrowser settings to upload documents or edit files.
- **Hardware:** For an optimal experience balancing performance and cost, a **Mac Mini M4 (16 GB RAM)** runs about **6 to 8 agents comfortably**.

---

## 📚 Documentation

| Guide                                                            | Description                                            |
| ---------------------------------------------------------------- | ------------------------------------------------------ |
| [Deployment Matrix](docs/deployment-matrix.md)                   | Choose the right deployment shape for your environment |
| [Standalone Host Quickstart](docs/standalone-host-quickstart.md) | Single-tenant from zero to running                     |
| [Multi-Tenant Deployment](deploy/README.md)                      | Shared host stack with Traefik & ingress modes         |
| [Linux Host Quickstart](docs/linux-cloud-host-quickstart.md)     | Cloud VM and Linux server deployment                   |
| [Configuration Guide](docs/configuration.md)                     | All four config layers and precedence rules            |
| [Tenant Operations Runbook](docs/tenant-operations.md)           | Day-to-day operational tasks                           |
| [Operator Runbook](docs/openclaw-gateway-operator-runbook.md)    | OpenClaw gateway operator responsibilities             |
| [Release Checklist](docs/release-checklist.md)                   | Release process and verification                       |

---

## 🤝 Trust & Community

RunDiffusion has been in business since 2022. Our team of DevOps engineers brings over 30 combined years of experience in software systems architecture. This codebase is free from malicious code, malware, or any devious intent — you are welcome to audit every line.

<p>
  <a href="https://discord.com/invite/wH6dTyBpCf">
    <img src="images/discord-logo.svg" alt="Discord" width="36" valign="middle">
  </a>
  <strong><a href="https://discord.com/invite/wH6dTyBpCf">Join our Discord with 35k+ members.</a></strong>
  Come build with us, get help, and talk with like-minded AI enthusiasts.
</p>

**Find us:**&nbsp;&nbsp;
[LinkedIn](https://www.linkedin.com/company/rundiffusion) &nbsp;&middot;&nbsp;
[X](https://x.com/RunDiffusion) &nbsp;&middot;&nbsp;
[GitHub](https://github.com/rundiffusion) &nbsp;&middot;&nbsp;
[Discord](https://discord.com/invite/wH6dTyBpCf) &nbsp;&middot;&nbsp;
[rundiffusion.com](https://www.rundiffusion.com?utm_source=github&utm_medium=readme&utm_campaign=run-diffusion-agents&utm_content=trust-homepage)

> **Designate an Agent-Wise Internal Champion.** To succeed, your team needs someone to run and maintain the farm — checking agent health daily, monitoring secrets inside containers, reviewing errors and usage, and managing the entire deployment using the bundled [multi-tenant host manager skill](skills/rundiffusion-host-agent-manager/SKILL.md) or [standalone manager skill](skills/rundiffusion-standalone-agent-manager/SKILL.md).

> **Use At Your Own Risk.** This is bleeding-edge software. You are responsible for security, secrets, data protection, access control, compliance, third-party API usage, costs, and any impact in your environment. See [DISCLAIMER.md](DISCLAIMER.md).

---

## License

RunDiffusion Agents is licensed under Apache-2.0. See [LICENSE](LICENSE),
[NOTICE](NOTICE), [TRADEMARKS.md](TRADEMARKS.md), [DISCLAIMER.md](DISCLAIMER.md),
and the engineering inventory in [docs/license-audit.md](docs/license-audit.md).

This repository can bundle or launch third-party tools such as
OpenClaw, Codex, Claude Code, Gemini CLI, Hermes, Traefik, and FileBrowser. The
Apache-2.0 license applies to RunDiffusion's code in this repo only. It does not
relicense those third-party tools or grant rights to the separate APIs and hosted
services they may use.

---

<p align="center">
  <img src="services/rundiffusion-agents/dashboard/public/rundiffusion-agents-logo.png" alt="RunDiffusion Agents" width="24" valign="middle">
  <strong>RunDiffusion Agents</strong> — Open-Source Multi-Agent Orchestration Platform
</p>

<p align="center">
  If you are a team or enterprise and want help deploying governed AI agents at scale,
  <a href="https://www.rundiffusion.com/contact-sales?utm_source=github&utm_medium=readme&utm_campaign=run-diffusion-agents&utm_content=footer-contact">contact us</a>.
</p>

<p align="center">
  <sub>RunDiffusion Agents is an open-source agent platform for multi-agent orchestration, AI agent orchestration, self-hosted AI agents, agentic AI, and agent fleet management — a complete agent orchestration platform and multi-agent platform for teams and enterprises.</sub>
</p>
