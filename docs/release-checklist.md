# Release Checklist

Performed by the release engineer before exporting to the public OSS repository. This project uses date-based versioning (e.g., `2026.4.15`).

---

## Safety

> **Leak prevention:** These items prevent accidental credential or state leaks in the public release.

- [ ] No real `.env` files are present in the export
- [ ] No real tenant env files are present in the export
- [ ] No runtime state directories are present in the export
- [ ] `deploy/tenants/tenants.example.yml` is `tenants: []`
- [ ] `deploy/tenants/tenants.yml` is not included in the export

## Content Review

- [ ] Release-facing brand is `RunDiffusion Agents`
- [ ] Repo/export name is `rundiffusion-agents`
- [ ] `LICENSE`, `NOTICE`, `DISCLAIMER.md`, and `docs/license-audit.md` are present and current
- [ ] Docs use placeholder domains (`example.com`)
- [ ] Docs use placeholder usernames and host paths
- [ ] No real tenant names, slugs, or org-specific repo names remain
- [ ] No org-specific optional private registry service remains in the export
- [ ] Proprietary or separately licensed integrations described accurately (especially Claude Code and Pi provider/API terms)
- [ ] Release-facing disclaimer matches current risk posture
- [ ] Main README and quickstarts visibly warn that operators use the software at their own risk
- [ ] Gateway runtime pins reviewed and intentionally bumped where needed

## Verification

- [ ] `node --test deploy/test/*.test.js` passes in the source repo
- [ ] `node --test test/*.test.js` passes in `services/rundiffusion-agents`
- [ ] `npm run build` succeeds in `services/rundiffusion-agents/dashboard`
- [ ] Release hygiene test passes

## Export

- [ ] Run `./scripts/export-oss-release.sh <destination>`
- [ ] Inspect the exported tree before pushing
- [ ] Initialize the destination as a brand-new repo before publishing
- [ ] `scripts/export-oss-release.sh` is the source of truth for the OSS release filter

## Rollback

If a release is published with leaked secrets or broken state:

- [ ] Immediately revoke all exposed credentials
- [ ] Force-push a corrected release to the public repository
- [ ] Notify affected parties if credentials were exposed
