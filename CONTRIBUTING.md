# Contributing to cloudron-librecrawl-app

Thanks for your interest in contributing!

## Quick Start

1. Fork the repository
2. Create a safe linked worktree for your change: `git worktree add ../cloudron-librecrawl-app-feature-your-feature -b feature/your-feature main`
3. Create or find the GitHub issue for your change before coding
4. Make your changes
5. Commit with conventional commits: `git commit -m "feat: add new feature"`
6. Push and open a PR with the issue reference in the PR body

<!-- aidevops:issue-first-pr:start -->
<!-- aidevops:issue-first-pr:scope=external -->
## Issue-first pull requests

If you are not a repository owner, member, or collaborator, create or find a GitHub issue before opening a pull request. Maintainers monitor issues more frequently than unsolicited pull requests.

Include `Closes #NNN`, `Fixes #NNN`, `Resolves #NNN`, `For #NNN`, or `Ref #NNN` in the PR body. External human-authored PRs without an issue reference are blocked. Bot PRs and trusted maintainer task workflows are exempt.
<!-- aidevops:issue-first-pr:end -->

## Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only
- `refactor:` - Code change that neither fixes a bug nor adds a feature
- `chore:` - Maintenance tasks

## Package verification

```bash
cloudron-package-helper.sh validate
cloudron-package-helper.sh check-compatibility
bash test/package-test.sh
shellcheck start.sh bin/librecrawl-user bin/librecrawl-retention scripts/*.sh test/*.sh
docker build --platform linux/amd64 -t librecrawl-cloudron:dev .
bash test/upgrade-test.sh
```

`test/upgrade-test.sh` starts the previous catalog image on a disposable
volume, adds an account, settings and two saved crawls, then starts a build of
this checkout on the same volume. It fails unless the signing key, an existing
session cookie, the settings and the row count of each table survive, and the
saved crawls still list, read back and load. Two checks are conditional: the
pre-upgrade snapshot `users.db.bak-<previous commit>` is checked only when the
upstream pin changes (`start.sh` writes none otherwise), and crawl comparison is
skipped when the new image returns 404 for it. The output names each skipped
check. Run it whenever the upstream pin or `start.sh` changes; `--from` and
`--to` take other image references.

Use a disposable Docker volume mounted at `/app/data`, `--read-only`, and tmpfs
at `/tmp` and `/run`. Verify `/login`, admin and service-account login, blocked
registration/guest/anonymous access, a small API crawl and CSV export, sessions
after restart, and retention of completed crawls including child rows. Do not
target production data for destructive verification. Record evidence in the PR.

Pin upstream by full commit and final Cloudron base by digest. Changes to
upstream behavior belong upstream, not in package source patches. Do not commit
secrets or hand-write `CloudronVersions.json`; only the publication workflow
generates that file using the pinned Cloudron CLI. Follow [publishing](docs/PUBLISHING.md)
for release authority and live qualification.
