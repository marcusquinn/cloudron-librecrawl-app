# cloudron-librecrawl-app

<!-- AI-CONTEXT-START -->

## Quick Reference

- **Validate**: `cloudron-package-helper.sh validate`
- **Build**: `cloudron-package-helper.sh build`
- **Test install**: `cloudron-package-helper.sh install librecrawl-test`
- **Release checks**: `cloudron-package-helper.sh check-compatibility` and
  `cloudron-package-helper.sh preflight-release vX.Y.Z`

## Project Overview

Cloudron app package for [LibreCrawl](https://github.com/PhialsBasement/LibreCrawl)
(MIT), a self-hosted website crawler for SEO audits. It gives hosted
WordPress sites running SEO Pro Stats a crawler server they can reach: each
site signs in with a LibreCrawl account, crawls itself on a schedule and
imports the result.

## Architecture

Mirror the structure of `marcusquinn/cloudron-netbird-app`: `Dockerfile` pinned to
the Cloudron base image, `start.sh`, `CloudronManifest.json`, `docs/` for
operator guides, and the Cloudron release and catalog-publish workflows.
Upstream has no tags: pin LibreCrawl by commit. Signed-in use only:
registration, guest sign-in, local mode and skip-auth stay off. All state in
`/app/data`; old crawls are removed by a scheduled retention task. Design and
decisions: `todo/tasks/t4-brief.md`.

## Conventions

- Commits: [Conventional Commits](https://www.conventionalcommits.org/)
- Branches: `feature/`, `bugfix/`, `hotfix/`, `refactor/`, `chore/`
- Documentation: human/operator guides in `docs/`, AI-only context in `.agents/`;
  retain conventional root entrypoints and respect existing repository conventions.

## Key Files

| File | Purpose |
|------|---------|
| `.agents/AGENTS.md` | Project-specific agent instructions |
| `docs/` | Human/operator guides, linked from root entrypoints |
| `TODO.md` | Task tracking |
| `CHANGELOG.md` | Version history |

<!-- AI-CONTEXT-END -->

## Search targets

Search keywords, AI-answer questions and search entities live in `context/keywords.md` and `context/keywords/` (standard: `~/.aidevops/agents/seo/keywords-standard.md`). Read them, or run `aidevops keywords brief`, before naming, copy, metadata, schema, media, social or PR work. If the files are missing in a clone, run `aidevops keywords sync`.
