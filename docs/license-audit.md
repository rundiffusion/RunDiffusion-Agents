# License Audit

Engineering-facing license inventory for the current repo state as of 2026-04-28. This is not legal advice.

> **Recommendation:** License the repository under Apache-2.0, ship a root `NOTICE` file stating third-party components keep their own licenses, and treat Claude Code as the main release risk — this repo can orchestrate it, but this repo's license does not make Claude Code open source or grant Anthropic usage rights.

---

## Scope

This audit was based on:

- Dashboard lockfile: [`services/rundiffusion-agents/dashboard/package-lock.json`](../services/rundiffusion-agents/dashboard/package-lock.json)
- Dashboard manifest: [`services/rundiffusion-agents/dashboard/package.json`](../services/rundiffusion-agents/dashboard/package.json)
- Standalone container build: [`services/rundiffusion-agents/Dockerfile`](../services/rundiffusion-agents/Dockerfile)
- Multi-tenant host stack: [`compose.prod.yml`](../compose.prod.yml)
- A live local gateway container sampled on 2026-04-28

Covers direct repo dependencies and major bundled/orchestrated components. Does not enumerate every Debian `apt` package, Python transitive dependency from Hermes, or upstream OpenClaw dependency. Those remain a second-pass item for container-distribution-grade SBOMs.

---

## High-Level Result

The repo is in a workable place for open-sourcing under Apache-2.0:

1. First-party code is RunDiffusion's own
2. Direct dependency surface is mostly permissive
3. `@anthropic-ai/claude-code` is not open-source software
4. The primary gateway runtimes are pinned by explicit versions, refs, or image digests
5. Hermes and OpenClaw pull transitive dependencies outside this repo's lockfiles
6. The dashboard tree includes `CC-BY-4.0` (attribution) and `MPL-2.0` (weak-copyleft) — documented but do not force copyleft

## Repo License Choice

Apache-2.0 is the best fit because it:

- Is compatible with the current direct dependency mix
- Includes an explicit patent grant
- Works well with a root `NOTICE` file
- Makes it easy to say "our code is Apache-2.0, but third-party tools keep their own licenses"

---

## Dashboard NPM Audit

189 resolved packages in the dashboard lockfile.

| License | Count | Notes |
| --- | ---: | --- |
| MIT | 163 | Most of the tree |
| MPL-2.0 | 12 | `lightningcss` toolchain packages |
| ISC | 7 | Includes `lucide-react` and small utilities |
| Apache-2.0 | 4 | Includes `typescript` and `class-variance-authority` |
| BSD-3-Clause | 1 | `source-map-js` |
| CC-BY-4.0 | 1 | `caniuse-lite` |
| 0BSD | 1 | `tslib` |

<details>
<summary><strong>Direct dashboard dependencies</strong></summary>

| Package | Version | License |
| --- | --- | --- |
| `@radix-ui/react-dialog` | `1.1.15` | MIT |
| `class-variance-authority` | `0.7.1` | Apache-2.0 |
| `clsx` | `2.1.1` | MIT |
| `lucide-react` | `0.577.0` | ISC |
| `react` | `19.2.4` | MIT |
| `react-dom` | `19.2.4` | MIT |
| `tailwind-merge` | `3.5.0` | MIT |
| `@tailwindcss/vite` | `4.2.1` | MIT |
| `@types/node` | `25.5.0` | MIT |
| `@types/react` | `19.2.14` | MIT |
| `@types/react-dom` | `19.2.3` | MIT |
| `@vitejs/plugin-react` | `5.2.0` | MIT |
| `tailwindcss` | `4.2.1` | MIT |
| `typescript` | `5.9.3` | Apache-2.0 |
| `vite` | `7.3.1` | MIT |

</details>

**Notable non-MIT items:**

- **`caniuse-lite` (CC-BY-4.0):** Attribution-focused data license. Keep a third-party notice; do not imply it becomes Apache-2.0.
- **`lightningcss` (MPL-2.0):** File-level copyleft. Using as an unmodified build dependency does not require relicensing. Modified `lightningcss` files would carry MPL obligations.

---

## Major Bundled or Orchestrated Components

| Component | License | Version Evidence | Notes |
| --- | --- | --- | --- |
| OpenClaw | MIT | Dockerfile pins `OPENCLAW_VERSION` | Core bundled app |
| Hermes Agent | MIT | Dockerfile pins `HERMES_REF=v2026.4.23` | Delegated-task agent |
| OpenAI Codex CLI | Apache-2.0 | `@openai/codex@0.125.0` | OSS, but OpenAI service terms apply |
| Google Gemini CLI | Apache-2.0 | `@google/gemini-cli@0.39.1` | OSS, but Google service terms apply |
| Pi Coding Agent | MIT | `@mariozechner/pi-coding-agent@0.70.5` | OSS, but selected provider service terms apply |
| Claude Code | **Anthropic commercial** | `@anthropic-ai/claude-code@2.1.119` | **Not open source** |
| FileBrowser Quantum | Apache-2.0 | `stable-slim@sha256:8e6f7d32...` | Bundled binary |
| ttyd | MIT | Dockerfile pins `TTYD_VERSION=1.7.7` | Terminal web bridge |
| Tailscale | BSD-3-Clause | Debian stable package | Bundled in image |
| Homebrew/brew | BSD-2-Clause | `HOMEBREW_INSTALL_REF=d683ebc...`, `HOMEBREW_BREW_REF=5.1.8` | Developer tooling layer |
| Traefik | MIT | `traefik:v3.4@sha256:06ddf61e...` | Multi-tenant ingress |
| cloudflared | Apache-2.0 | Host-managed, optional | Not bundled in standalone image |

---

## Risk Areas & Mitigations

### 1. Claude Code Is Not Open Source

> **Watch out:** A person seeing a `/claude` route in an Apache-2.0 repository could incorrectly assume the tool itself is Apache-2.0. It is not.

The repo addresses this with a root `NOTICE` file, but the product story should stay consistent everywhere Claude Code is mentioned.

**Mitigation:** The NOTICE file and this audit document explicitly state that Claude Code is not open source. The `/claude` route documentation should maintain this distinction.

### 2. Runtime Pin Drift

The gateway image pins the primary runtimes with explicit npm versions, git refs, release versions, and image digests.

Your next public build should not change those primary runtime versions unless the pins are bumped intentionally.

**Mitigation:** Bump the pins as part of the release routine and update this document. Consider adding a CI check that flags accidental `@latest`, `HEAD`, or moving image aliases in production build paths.

### 3. Image-Level Dependency Drift

OpenClaw Control UI build (`npm install`) and Hermes install (`pip install`) pull transitive dependencies not locked in this repo.

**Mitigation:** A container-distribution-grade SBOM is a second-pass item. For now, re-audit at each release per the [release checklist](./release-checklist.md).

---

## Upstream Source Pointers

- [openclaw/openclaw](https://github.com/openclaw/openclaw)
- [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
- [openai/codex](https://github.com/openai/codex/releases)
- [google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli)
- [anthropics/claude-code](https://github.com/anthropics/claude-code)
- [gtsteffaniak/filebrowser](https://github.com/gtsteffaniak/filebrowser)
- [traefik/traefik](https://github.com/traefik/traefik)
- [cloudflare/cloudflared](https://github.com/cloudflare/cloudflared)
- [tailscale/tailscale](https://github.com/tailscale/tailscale)
- [tsl0922/ttyd](https://github.com/tsl0922/ttyd)
- [Homebrew/brew](https://github.com/Homebrew/brew)
