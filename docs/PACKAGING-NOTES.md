# Packaging decisions and upstream limitations

## Pinned runtime

LibreCrawl MIT source: `05a1372de8334ca18dec0bc1f7470c62901a9418`.
On 2026-10-14, `gh api repos/PhialsBasement/LibreCrawl/commits/main --jq .sha`
returned that same full commit; there were no newer commits to assess.
Waitress binds `0.0.0.0:5000` with eight threads. `/login` is the unauthenticated
health path. No upstream source is patched. `/app/code/data` is a build-time
symlink to `/app/data`; the working directory stays `/app/code`.

The pinned Python tree's write-path audit found SQLite writes in `main.py`,
`src/auth_db.py` and `src/crawl_db.py`, all pointing to `data/users.db`.
Settings are in SQLite; exports are in-memory streams. Bytecode writes are
disabled. Browser downloads are build-time `/app/code/ms-playwright`; HOME is
`/app/data`, browser temporary files use `/tmp`, and `/run` is ephemeral.
The image removes any upstream `.env` and installs only Playwright Chromium.
Requirements with unpinned versions remain upstream-managed; inspect the
installed versions and re-qualify every image build, even at the same commit.
The local image verification installed Python 3.14.4, Flask 2.3.3,
Waitress 3.0.2, Playwright 1.64.0, bcrypt 4.1.2 and requests 2.31.0.

## Retention defect and package adapter

Upstream `crawl_db.get_db()` never sets `PRAGMA foreign_keys=ON`, despite all
four crawl child tables declaring `ON DELETE CASCADE`. Deleting a crawl through
that connection leaves orphan pages, links, issues and queued URLs.

The standalone retention command replaces `get_db` **only in its own process**
with a connection adapter that enables foreign keys, then calls upstream
`cleanup_old_crawls(days)` unchanged. Cascade and parent deletion are in the
same transaction. It refuses invalid days/vacuum values and reports failure if
eligible rows exist but upstream returns zero. Regular upstream UI/API deletion
still has the orphan-row defect: the package deliberately does not patch it or
delete unrelated orphan rows. Follow-up: propose enabling foreign keys on every
upstream connection and test both scheduled cleanup and interactive deletion.

Cleanup uses `started_at`, with statuses completed/failed/stopped. The task does
not remove paused/running crawls or authentication/settings history. Retention
bounds finished-result history, not total disk usage. Vacuum is explicitly opt-in.

## Sessions and idle crawlers

The package generates a signing key once, atomically stores it with mode 0600,
and reuses it. Upstream keeps crawler instances in memory per session. Its
cleanup thread runs every five minutes and drops instances idle for one hour,
stopping even a running crawl if the client stops accessing it. Persisted crawls
remain in SQLite, so weekly/monthly clients must
use the saved crawl list/load endpoints rather than assume a live instance.
Restarts stop live in-memory crawls; upstream crash-recovery state may be loaded.
Tier and password changes do not invalidate already-issued cookies.

## Network security follow-up

Upstream has no private-address/SSRF filter. Registration and guest access are
disabled and unsafe modes fail startup, but any trusted account can reach
internal services. Follow-up (not implemented here): propose an upstream
"block private addresses" setting that covers DNS rebinding, redirects, IPv6,
browser subresources and proxies; alternatively qualify a package-level egress
policy. Until then access is only for fully trusted accounts. Cloudron ingress
TLS/proxy configuration does not fix outbound reachability.

## Qualification boundary

Local Docker evidence belongs in the implementation PR. Live Cloudron install,
upgrade, backup/restore and plugin connection are operator qualification in t5.
The implementation runner is arm64; Cloudron's pinned base is amd64. The
read-only web/API/account/restart/retention checks passed under emulation.
A supplementary Chromium render attempt failed with QEMU signal 5 and an
unusable GPU process. Chromium installation is verified, but actual JS rendering
must be qualified on native amd64 in t5; no upstream launch flags were patched
to disguise this runner limitation.
Publication is disabled until the operator enables it explicitly; this task
does not publish or change other repositories. See [PUBLISHING.md](PUBLISHING.md).
