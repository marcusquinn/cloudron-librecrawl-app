<!-- aidevops:brief-schema=v2 -->

# t4: Package LibreCrawl as a Cloudron app (crawler server for SEO Pro Stats and aidevops)

## Pre-flight (auto-populated by briefing workflow)

- [x] Memory recall: `new cloudron app repo aidevops init worktree repos add` → 0 hits — no relevant lessons
- [x] Discovery pass: new repository; `gh repo list marcusquinn` shows no existing LibreCrawl package; upstream has no Cloudron packaging
- [x] File refs verified: LibreCrawl `main` at `05a1372de8334ca18dec0bc1f7470c62901a9418` (`Dockerfile`, `docker-compose.yml`, `main.py`, `src/auth_db.py`, `src/crawl_db.py`, `src/core/js_renderer.py`, `src/settings_manager.py`); `marcusquinn/cloudron-netbird-app` `Dockerfile`, `CloudronManifest.json`, workflows
- [x] Tier: `tier:standard` — runtime, auth, storage and security decisions are fixed below; the worker composes a known package shape
- [x] Seeded draft PR decision recorded: skipped — no package code yet

## Origin

- **Created:** 2026-10-14
- **Created by:** ai-interactive (Marcus Quinn session)
- **Parent task:** none
- **Blocked by:** none
- **Conversation context:** SEO Pro Stats 1.11.0 imports site crawls (wpallstars/seoprostats#331). Its next step is a crawler connection (wpallstars/seoprostats#337): each WordPress site signs in to a LibreCrawl server the owner runs, crawls itself weekly or monthly, and imports the result. A LibreCrawl on a desktop is not reachable from hosted sites, so the owner wants one on Cloudron, reachable by every site, packaged like the other `cloudron-*-app` repositories.

## What

A complete, publishable Cloudron app package for LibreCrawl (MIT, <https://github.com/PhialsBasement/LibreCrawl>):

- Installs on Cloudron (minBoxVersion 9.1.0, as NetBird) with LibreCrawl's web app and REST API at `https://<app domain>/` behind Cloudron TLS.
- **Signed-in use only**: registration and guest sign-in are off; local mode and skip-auth can never be turned on. The first admin account is created on first start with a random password the operator reads once with `cloudron exec`; a small `librecrawl-user` command adds, verifies, re-tiers and resets users.
- Sessions survive restarts: a `SECRET_KEY` is generated once into `/app/data` (upstream otherwise makes a new one each start, which signs every API client out, breaking the plugin's long crawls).
- All state (`users.db`: users, settings and every crawl) under `/app/data`, surviving restart, update and backup/restore.
- **Bounded storage**: a daily Cloudron `scheduler` task deletes finished crawls older than `CRAWL_RETENTION_DAYS` (default 90, set in `/app/data/env`) with upstream's own `crawl_db.cleanup_old_crawls()` (defined but never called upstream), so the database does not grow forever.
- JavaScript rendering available (Playwright Chromium only, not Firefox and WebKit, to keep the image smaller), off by default in LibreCrawl's settings.
- The same release pipeline as `cloudron-netbird-app`: pull-request validation, GHCR image, `CloudronVersions.json` publication, attestations, tag-triggered release caller.
- Operator docs: install, first sign-in, adding a service account for SEO Pro Stats sites (tier `admin`, as the plugin needs it for crawls without guest limits), memory sizing, retention, the network warning below, backup/restore.

## Why

The plugin connection (wpallstars/seoprostats#337) and the aidevops site crawler both need a LibreCrawl that is always on and reachable from hosted WordPress sites. Cloudron gives TLS, backups, updates and resource limits; a package keeps it maintained like the owner's other self-hosted services. No Cloudron package exists.

## Tier

### Tier checklist (verify before assigning)

- [ ] **Exact execution contract supplied?** No — files are composed from a reference pattern.
- [x] **Targets and reference pattern verified?** Yes.
- [ ] **No semantic or design decision remains?** Minor: health path confirmation, which Playwright deps the Cloudron base lacks.
- [x] **Bounded, reversible, low-consequence impact?** New repository; nothing published without the release secret.
- [x] **No stateful coordination to invent?** One process, SQLite.
- [x] **Focused verification and rollback are explicit?** Yes.
- [x] **No dispatch-path risk override?** Not an aidevops dispatch-path file.

**Selected tier:** `tier:standard`

**Tier rationale:** Auth, storage, process and port decisions are fixed here; the worker follows a verified package shape.

## PR Conventions

Leaf task: the implementation PR uses `Resolves #<this issue>`.

## How (Approach)

### Progressive Context Plan

- **Read first:** `marcusquinn/cloudron-netbird-app` `CloudronManifest.json`, `Dockerfile`, `start.sh`, `docs/PUBLISHING.md`, `.github/workflows/cloudron-catalog-publish.yml`, `scripts/publish-cloudron-catalog.sh`, `test/package-test.sh`.
- **Then:** LibreCrawl at the pinned commit: `Dockerfile`, `docker-compose.yml` (flags and env), `main.py` (startup flags around lines 40–60, `main()` near the end: Waitress on `0.0.0.0:5000`, 8 threads), `src/auth_db.py` (`create_user`, `verify_user`, `set_user_tier`, tiers `guest|user|extra|admin`), `src/crawl_db.py` (`cleanup_old_crawls`, `delete_crawl`), `src/core/js_renderer.py` (Chromium launched with `--no-sandbox --disable-dev-shm-usage`).
- **Load only if:** `~/.aidevops/agents/tools/deployment/cloudron-app-packaging.md` and the Cloudron manifest reference for `scheduler`, `localstorage`, `memoryLimit`, `postInstallMessage`.
- **Stop when:** manifest, Dockerfile, start script, user command and retention task are clear.

### Worker Quick-Start

```bash
# Upstream: PhialsBasement/LibreCrawl, MIT, no tags or releases; pin by commit
gh api repos/PhialsBasement/LibreCrawl/commits/main --jq '.sha'   # newer than 05a1372? read its log before moving the pin
gh repo clone PhialsBasement/LibreCrawl ~/.aidevops/.agent-workspace/tmp/librecrawl-src
gh repo clone marcusquinn/cloudron-netbird-app ~/.aidevops/.agent-workspace/tmp/netbird-ref
cat ~/.aidevops/agents/templates/workflows/cloudron-package-release-caller.yml
```

Key facts (pinned commit):

- Waitress serves on port 5000 (hard-coded in `main()`): manifest `httpPort: 5000`.
- `users.db` path is `<code dir>/data/users.db` (`src/auth_db.py`, `src/crawl_db.py`, `main.py`), and `main.py` runs `os.makedirs("data")` relative to the working directory. Cloudron's `/app/code` is read-only: at build time replace `/app/code/data` with a symlink to `/app/data`, and run from `/app/code`. Grep the pinned tree for any other writes under the code directory (`open(..., 'w')`, `__file__`-relative paths) and redirect each to `/app/data` or `/run`.
- Startup flags: `--disable-register`, `--disable-guest` (or env `REGISTRATION_DISABLED`, `DISABLE_GUEST`); never `--local`, `--demo`, `--dangerously-skip-auth`. `start.sh` must refuse to start if `LOCAL_MODE`, `DANGEROUSLY_SKIP_AUTH` or `DEMO_MODE` is set truthy in `/app/data/env`.
- `SECRET_KEY` env, else ephemeral: generate 32 random bytes into `/app/data/.secret_key` (0600) once, export it each start.
- A new user is unverified until `verify_user()`; tier defaults to non-admin. First start: create user `admin` with a random password written to `/app/data/admin-password` (0600), verify, tier `admin`; never overwrite on later starts.
- Playwright: set `PLAYWRIGHT_BROWSERS_PATH=/app/code/ms-playwright` and run `playwright install --with-deps chromium` at build time (the upstream image installs every browser). JS rendering is off by default; Chromium needs memory.

### Files to Modify

- `NEW: CloudronManifest.json` — id `com.marcusquinn.cloudron.librecrawl`, `httpPort` 5000, addons `localstorage` and `scheduler` (daily retention task), `memoryLimit` 2147483648 (2 GiB; document raising it for JS rendering), `healthCheckPath` `/login` (confirm it answers 200 without a session; else choose another unauthenticated 200 path), `postInstallMessage` with the `cloudron exec` command to read the admin password, metadata and tags as NetBird's, `upstreamVersion` = short commit.
- `NEW: Dockerfile` — `FROM` the digest-pinned Cloudron base used by `cloudron-netbird-app`; fetch LibreCrawl at the pinned commit (`ARG LIBRECRAWL_COMMIT`; clone and `git checkout`, then verify `git rev-parse HEAD` equals it), Python venv in `/app/code/venv` with `requirements.txt`, Chromium only, `/app/code/data` → `/app/data` symlink, `librecrawl-user` and the retention script copied in.
- `NEW: start.sh` — create `/app/data` layout, `env` template on first run, secret and first admin, refuse unsafe flags, `chown -R cloudron:cloudron /app/data`, `exec gosu cloudron:cloudron` the venv's `python main.py --disable-register --disable-guest` from `/app/code`.
- `NEW: bin/librecrawl-user` — `add <username> <email> [--tier admin|extra|user]` (reads the password from stdin, verifies), `tier <username> <tier>`, `reset-password <username>` (stdin), `list`; thin calls to `src/auth_db.py` functions run as `cloudron`.
- `NEW: bin/librecrawl-retention` — sources `/app/data/env`, runs `crawl_db.cleanup_old_crawls(days)` and prints the count; check whether crawl child tables (pages, links, issues) are deleted with the crawl (foreign keys with `ON DELETE CASCADE` *and* `PRAGMA foreign_keys=ON` in the connection, or explicit deletes); if not, delete child rows of removed crawls in the same transaction, and record the finding in `docs/PACKAGING-NOTES.md`. Run `VACUUM` only when `CRAWL_VACUUM=true` (it needs free disk equal to the database size).
- `NEW: CHANGELOG`, `EDIT: CHANGELOG.md` — first entry 0.1.0.
- `NEW: logo.png` (256×256), `NEW: media/hero.png` (1188×396) — upstream artwork only if its licence permits; otherwise original artwork with provenance in `DESIGN.md`.
- `NEW: docs/README.md`, `NEW: docs/PACKAGING-NOTES.md`, `NEW: docs/PUBLISHING.md` (adapt NetBird's: image `ghcr.io/marcusquinn/cloudron-librecrawl-app`, test location `librecrawl-test`).
- `NEW: scripts/publish-cloudron-catalog.sh`, `NEW: .github/workflows/cloudron-catalog-publish.yml` — adapt from NetBird.
- `NEW: .github/workflows/cloudron-package-release.yml` — the aidevops caller template unchanged.
- `NEW: .github/workflows/linked-issue-check.yml`, `NEW: .github/dependabot.yml` — from NetBird.
- `EDIT: SECURITY.md`, `EDIT: CONTRIBUTING.md` (created by `aidevops init`; add the package specifics from NetBird's), `NEW: .dockerignore`, `NEW: .editorconfig` — adapt from NetBird.
- `NEW: test/package-test.sh` — static checks as NetBird's, plus: manifest has no `proxyAuth`, start script contains no `--local`/`--dangerously-skip-auth`, Dockerfile pins `LIBRECRAWL_COMMIT` to 40 hex characters.
- `EDIT: README.md` (keep managed blocks), `EDIT: AGENTS.md` (commands), `EDIT: DESIGN.md`.

### Complete Write Surface

- **Callers/readers:** browsers (LibreCrawl UI); API clients signing in with `POST /api/login` (SEO Pro Stats connection, aidevops `site-crawler-helper.sh`); Cloudron reads the manifest and `CloudronVersions.json`.
- **Writers/mutation paths:** LibreCrawl writes `/app/data/users.db`; `start.sh` writes `/app/data/env`, `.secret_key`, `admin-password`; the scheduler task deletes old crawls; only the catalog workflow writes `CloudronVersions.json` and tags.
- **Existing verification/tests:** none here yet; NetBird's `test/package-test.sh` is the pattern; upstream `tests/` may be run in the image if quick.
- **Schemas/config:** `CloudronManifest.json`, `/app/data/env`.
- **Generated/deployed mirrors:** GHCR image and catalog, never hand-written.
- **Migrations/backfills:** LibreCrawl creates and migrates its tables on start (`init_db`, `init_crawl_tables`); before moving the commit pin, `start.sh` copies `users.db` to `users.db.bak-<old commit>` once (keep the last two).
- **Cleanup/rollback paths:** Cloudron backup/restore of `/app/data`; catalog entries are append-only (revoke + new version).

### Implementation Steps

1. Read the reference and pinned upstream files above; confirm no upstream commit after the pin changes startup, paths or the API used by wpallstars/seoprostats#337 (sign-in, `start_crawl`, `crawl_status`, `crawls/list`, `crawls/<id>/load`, `export_stream`); if one does, pin the newer commit and note it.
2. Write manifest, Dockerfile, `start.sh`, `bin/` scripts.
3. Build and run locally (verification block); sign in with the generated admin; create a service user with `librecrawl-user`; run a small crawl through the API exactly as the plugin will (sign in, `save_settings` with `maxUrls` 50, `start_crawl` of a test site, poll, `crawls/list`, `load`, `export_stream?type=urls&format=csv`); restart the container and confirm the session cookie still works and the crawl is listed.
4. Run the retention script with `CRAWL_RETENTION_DAYS=0` against a finished crawl and confirm it and its child rows are gone.
5. Adapt workflows and publishing; docs, changelogs, artwork; open the PR with the evidence.

### Hazards and Compatibility

- **Network reach (SSRF):** LibreCrawl fetches any URL a signed-in user gives, with no private-address block at the pinned commit. On Cloudron that includes other apps' internal addresses and the host's Docker network. Mitigation in this package: only trusted accounts (registration and guest off), documented in `README.md`, `SECURITY.md` and the post-install message. Do not invent an egress filter in this task; record a follow-up (upstream issue proposing a "block private addresses" setting, or a package-level egress rule) in `docs/PACKAGING-NOTES.md`.
- **Memory:** crawler plus Chromium; a 2 GiB default with JS off. Document symptoms and raising the limit. Upstream `--demo` per-user memory caps are not used.
- **Sessions:** each signed-in session has its own in-memory crawler (`main.py` session instances, cleaned by `cleanup_old_instances()`): note the idle cleanup interval in `docs/PACKAGING-NOTES.md`, since a plugin polling weekly crawls relies on the session and the persisted crawl list.
- **Idempotency:** `start.sh` safe on every restart; secrets and admin only when missing; writes via temp file + `mv`.
- **Partial failure:** a failed first-run step exits non-zero (Cloudron marks the app unhealthy) rather than starting without auth settings.

### Verification Before Dispatch

```bash
cloudron-package-helper.sh validate
cloudron-package-helper.sh check-compatibility
bash test/package-test.sh
shellcheck start.sh bin/librecrawl-user bin/librecrawl-retention scripts/*.sh test/*.sh
docker build -t librecrawl-cloudron:dev .
docker run -d --name lc -p 5000:5000 -v "$PWD/.tmp-data:/app/data" --read-only --tmpfs /tmp --tmpfs /run librecrawl-cloudron:dev
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:5000/login
docker exec lc cat /app/data/admin-password
```

- **Surface mapping:** `validate`/`check-compatibility` prove manifest and base; `package-test.sh` the static invariants; `--read-only` with tmpfs proves no writes outside `/app/data`, `/tmp`, `/run`; the API crawl in step 3 proves the plugin's path; step 4 proves retention.
- **Broad verification trigger:** not required — new standalone repository.

### Recoverability Checkpoint

- [ ] Focused functional verification passes: build, health, admin sign-in, API crawl and export
- [ ] WIP commit created before broad gates: `wip: librecrawl cloudron package runtime`
- [ ] Evidence-triggered broad verification then run: not required — new repository

### Scope Boundaries

**Hard boundaries:** do not hand-write `CloudronVersions.json`; no secrets in the repository; never enable local mode, guest or skip-auth; do not patch LibreCrawl's source beyond path redirection (anything more is an upstream PR, linked from `docs/PACKAGING-NOTES.md`); do not change other repositories.

**AI brief owner:** marcusquinn interactive session (this brief).

**Recovery:** preserve the current PR and use the structured runtime request and Pulse intake in `reference/worker-discipline.md` when local recovery is unsafe.

### Files Scope

- `CloudronManifest.json`
- `Dockerfile`
- `.dockerignore`
- `.editorconfig`
- `start.sh`
- `bin/librecrawl-user`
- `bin/librecrawl-retention`
- `CHANGELOG`
- `CHANGELOG.md`
- `README.md`
- `AGENTS.md`
- `DESIGN.md`
- `SECURITY.md`
- `CONTRIBUTING.md`
- `logo.png`
- `media/hero.png`
- `docs/README.md`
- `docs/PACKAGING-NOTES.md`
- `docs/PUBLISHING.md`
- `scripts/publish-cloudron-catalog.sh`
- `test/package-test.sh`
- `.github/workflows/cloudron-catalog-publish.yml`
- `.github/workflows/cloudron-package-release.yml`
- `.github/workflows/linked-issue-check.yml`
- `.github/dependabot.yml`
- `TODO.md`
- `todo/tasks/t4-brief.md`

## Acceptance Criteria

- [ ] The package builds and serves LibreCrawl with all state in `/app/data`, running with a read-only root filesystem.

  ```yaml
  verify:
    method: bash
    run: "cloudron-package-helper.sh validate && bash test/package-test.sh"
  ```

- [ ] Unsafe modes cannot be enabled and registration and guest are off.

  ```yaml
  verify:
    method: codebase
    pattern: "--local|--dangerously-skip-auth|--demo"
    path: "start.sh"
    expect: absent
  ```

- [ ] No secret or catalog material is hand-committed.

  ```yaml
  verify:
    method: codebase
    pattern: "BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY|SECRET_KEY="
    path: "."
    expect: absent
  ```

- [ ] PR body includes local evidence: health status, admin sign-in, service user created, the API crawl and CSV export (row count), the session still valid after restart, and retention deleting a crawl with its child rows.
- [ ] The pull-request runs of `cloudron-catalog-publish.yml` and `linked-issue-check.yml` pass.
- [ ] `docs/PUBLISHING.md` lists the operator hand-off: `CLOUDRON_RELEASE_PAT` secret, live install at `librecrawl-test`, upgrade/restart/backup-restore checks, Community Apps submission.
- [ ] Changed-file lint is clean (`shellcheck`, markdownlint where configured).

## Context & Decisions

- Mirror `cloudron-netbird-app` structure and publication.
- No Cloudron `proxyAuth`: it would put a Cloudron sign-in in front of the API and block WordPress sites signing in with LibreCrawl accounts. LibreCrawl's own accounts, with registration and guest off, are the gate. Cloudron SSO (`oidc`) would need upstream support; a non-goal for 0.1.0.
- Pin by commit: upstream has no tags or releases.
- Chromium only, to keep the image smaller; Firefox/WebKit rendering is a non-goal.
- Retention in the package because upstream never calls its own cleanup.
- Operator-only steps (secret, live qualification, Community Apps submission) are t5.

## Relevant Files

- `marcusquinn/cloudron-netbird-app:CloudronManifest.json`, `Dockerfile`, `start.sh`, `docs/PUBLISHING.md`, `.github/workflows/cloudron-catalog-publish.yml`, `test/package-test.sh`.
- `marcusquinn/aidevops:.agents/templates/workflows/cloudron-package-release-caller.yml`; `.agents/tools/deployment/cloudron-app-packaging.md`.
- `PhialsBasement/LibreCrawl@05a1372:main.py`, `src/auth_db.py`, `src/crawl_db.py`, `src/core/js_renderer.py`, `docker-compose.yml`.
- `wpallstars/seoprostats#337` — the API calls the plugin makes (the contract this server must serve).

## Dependencies

- **Blocked by:** none
- **Blocks:** t5 (operator qualification); live use by wpallstars/seoprostats#337
- **External:** GHCR uses `GITHUB_TOKEN`; the catalog push needs the operator's `CLOUDRON_RELEASE_PAT`.

## Estimate Breakdown

| Phase | Time | Notes |
|-------|------|-------|
| Research/read | 45m | NetBird reference, LibreCrawl startup, auth and storage |
| Implementation | 4h | manifest, Dockerfile, start script, user and retention commands, workflows, docs, artwork |
| Verification | 1h15m | read-only run, API crawl, restart, retention, CI |
| **Total** | **~6h** | |
