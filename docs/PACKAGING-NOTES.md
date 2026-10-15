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
Tier and password changes do not invalidate already-issued cookies.

Stopping the container (restart, update) sends SIGTERM: upstream saves each
running crawl as `paused`, and `POST /api/crawls/<id>/resume` from the owning
account continues it. A crash or OOM kill skips that handler; upstream startup
then marks running crawls `failed`, which are also resumable and eligible for
retention. A resumed crawl counts its saved rows, including HEAD-check rows for
images and external links, against `maxUrls`, so it fetches fewer pages than an
uninterrupted crawl.

## Process supervision

`start.sh` execs `tini` as PID 1, which runs upstream through `gosu`. Each
JavaScript crawl orphans two Chromium helper processes; with upstream as PID 1
they stayed defunct until restart (five after three crawls on the live test).
tini reaps them and forwards SIGTERM, so the shutdown handler above still runs.

## Upstream crawl behaviour clients must allow for

- `crawlDelay` only throttles JavaScript crawls: the HTML crawl path never calls
  the rate limiter. On the live test, 15 pages with a 5-second delay finished in
  about a second. `concurrency` plus up to five HEAD-check workers is the only
  limit. Follow-up: propose applying the rate limiter to the HTML path upstream.
- JavaScript crawls send `jsUserAgent` (default `LibreCrawl/1.0 (Web Crawler
  with JavaScript)`), not `userAgent`. A WAF-protected WordPress site answered
  403 to the default and 200 once the client set both.
- `maxUrls` counts fetched pages, but results also get a row for every
  HEAD-checked image and external link: 5,000 pages gave 19,781 URL rows.
- Links exports are slow to generate: inside the container, that crawl's
  397,953-row links CSV (49.5 MB) took 22.8 s, against 0.6 s for the 2.4 MB URL
  CSV. Clients need about a minute of export timeout for sites this size.

## Network security follow-up

Upstream has no private-address/SSRF filter. Registration and guest access are
disabled and unsafe modes fail startup, but any trusted account can reach
internal services. Follow-up (not implemented here): propose an upstream
"block private addresses" setting that covers DNS rebinding, redirects, IPv6,
browser subresources and proxies; alternatively qualify a package-level egress
policy. Until then access is only for fully trusted accounts. Cloudron ingress
TLS/proxy configuration does not fix outbound reachability.

## Live qualification (t5)

On 2026-10-15 a disposable Cloudron 10.0.5 install (x86_64, 8 CPUs, 15 GiB),
built on the server from this repository, passed these checks:

- Health, sign-in and refusals: `/login` 200 and `/` redirects there;
  anonymous API calls get 401; registration and guest sign-in are refused; the
  generated admin password works and can be reset; a `librecrawl-user add`
  service account signs in, and duplicates are refused.
- Client path: login, `save_settings`, `start_crawl`, `crawl_status` polling,
  `crawls/list`, `crawls/<id>/load` and URL/links CSV exports, all 200.
- HTML crawl of 5,000 pages (loopback synthetic WordPress-shaped site, 6,000
  posts plus archives and sitemaps): 19,781 URL rows, 397,953 links and 10,653
  issues in 7 min 43 s; `users.db` grew by about 130 MB.
- JavaScript on native amd64: Chromium rendered a script-built title and
  followed links that exist only after rendering.
- Restart mid-crawl: the crawl was saved as `paused` and the resume endpoint
  completed it. The signing key, users and crawls survived restart, backup and
  restore, and an image update; restore removed an account created after the
  backup.
- Retention through the Cloudron scheduler (temporary two-minute schedule in a
  disposable build): with 90 days nothing was deleted; with
  `CRAWL_RETENTION_DAYS=1` it deleted only a crawl backdated three days, with
  all its child rows and no orphans left.

Memory, measured by the cgroup and `docker stats`: idle 50–80 MiB. The
5,000-page HTML crawl peaked at 1.16 GiB including load and export. The process
held about 1 GiB until the app restarted, because each session keeps its crawl
until upstream drops it after an hour idle; crawls from several sites within
that hour add up. JavaScript added 0.6 GiB with one browser page and 0.9 GiB
with three (the upstream default) on a small real site. The 2 GiB default
holds one large HTML crawl at a time, so it stays; README states when to raise it.

The t4 implementation runner was arm64 under emulation, where Chromium could not
render (QEMU signal 5); native amd64 removed that limitation without any launch
flag changes. Publication stays disabled until the operator enables it
explicitly. See [PUBLISHING.md](PUBLISHING.md).
