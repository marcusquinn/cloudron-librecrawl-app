# LibreCrawl on Cloudron

## Install and first sign-in

Requires Cloudron 9.1.0 or newer. Add the version catalog
`https://raw.githubusercontent.com/marcusquinn/cloudron-librecrawl-app/main/CloudronVersions.json`
under **Community apps** in the dashboard, or run
`cloudron install --location <subdomain> --versions-url <catalog URL>`. New
versions then appear as updates in the dashboard. To qualify an unpublished
change, install from a checkout instead (see [PUBLISHING.md](PUBLISHING.md)).
Cloudron handles public HTTPS; the app serves HTTP on port 5000 internally.
There is no Cloudron SSO or proxy-auth wall.

Read the initial password privately in the app terminal:

```bash
cat /app/data/admin-password
```

Or run `cloudron exec --app <app-domain> -- cat /app/data/admin-password`.
Sign in as `admin` at the app URL. Reset the password in the app terminal with
`librecrawl-user reset-password admin` (hidden terminal prompt). Once reset,
remove the now-stale `/app/data/admin-password` in the terminal. Startup will
not overwrite an existing admin account or recreate that password file.

## Service accounts for WordPress / SEO Pro Stats

Only create accounts for trusted sites and people: any signed-in account can
crawl private/internal addresses and other apps. Use a separate account per site.
An `admin` tier gives the plugin unrestricted settings/crawls; it is not
Cloudron platform administration.

A copy of a connected site (a clone or a staging copy) keeps the source site's
crawler connection. Disconnect it on the copy (Settings → Connections →
Crawler), then connect the copy with its own account.

In the app terminal:

```bash
librecrawl-user add site-crawler crawler@example.org --tier admin
librecrawl-user list
librecrawl-user tier site-crawler admin
librecrawl-user reset-password site-crawler
```

Passwords are prompted without echo on a terminal or read as one line from
stdin (8–72 UTF-8 bytes); never pass passwords as command-line arguments.
Remote stdin administration requires `cloudron exec` forwarding stdin; the app
terminal is the simplest supported route. Newly added accounts are verified.
Existing usernames/emails are refused, not silently replaced. Tier changes and
password resets require clients to sign out/in to refresh their session tier.

Configure the plugin with the app's HTTPS URL and this username/password.
The API contract is `POST /api/login`, `POST /api/save_settings`,
`POST /api/start_crawl`, `GET /api/crawl_status`, `GET /api/crawls/list`,
`POST /api/crawls/<id>/load`, `POST /api/crawls/<id>/resume`, and
`GET /api/export_stream?type=urls&format=csv` (or `type=links`). Save
`maxUrls: 50` for a first smoke crawl. Clients retain the login cookie;
finished crawls are persistent. A restart or update saves a running crawl as
`paused`: resume it from the same account instead of waiting for completion.

At the pinned upstream commit, clients should allow for this:

- `crawlDelay` only throttles JavaScript crawls; `concurrency` is the real
  limit on HTML crawls, plus up to five HEAD checks at a time.
- JavaScript crawls send `jsUserAgent`, not `userAgent`; set both.
- `maxUrls` counts fetched pages, but exports also have rows for HEAD-checked
  images and external links (19,781 rows for 5,000 pages in qualification).
- A 5,000-page site's links export is about 50 MB and takes over 20 seconds to
  generate; give export requests a minute or more.

## Memory and JavaScript

Default memory is 2 GiB and JavaScript rendering is off. Only Chromium is
installed. Measured in qualification: a 5,000-page HTML crawl peaked at
1.16 GiB including load and export, and each signed-in session keeps its crawl
in memory until it has been idle for an hour, so crawls from several sites in
the same hour add up. JavaScript added 0.6 GiB with one browser page and
0.9 GiB with three (the default) on a small site.

2 GiB holds one large HTML crawl at a time. Raise the Cloudron memory limit to
4 GiB if several sites with thousands of pages may crawl in the same hour, or
before using JavaScript on anything but small sites. When enabling JavaScript,
select Chromium and start with one concurrent browser page
(`jsMaxConcurrentPages: 1`). Unexpected restarts, incomplete crawls or Chromium
crashes can indicate OOM; check Cloudron app logs and resource usage before
increasing concurrency.

## Retention

Edit `/app/data/env` in the operator terminal. The retention task rereads and
validates the file at every run, so retention changes need no app restart
(a restart would pause running crawls):

```bash
CRAWL_RETENTION_DAYS=90
CRAWL_VACUUM=false
```

Configuration is literal `KEY=value` data, not shell code: do not quote values
or use shell expansion. Blank lines and lines starting with `#` are ignored;
unknown keys are rejected. The only accepted keys are `CRAWL_RETENTION_DAYS`,
`CRAWL_VACUUM`, `LOCAL_MODE`, `DANGEROUSLY_SKIP_AUTH` and `DEMO_MODE`.

The scheduler runs at 03:00 daily (Cloudron scheduler time). Upstream's rule
uses the crawl's **start time**, not completion time, and only deletes
`completed`, `failed`, or `stopped` crawls. Running and paused crawls are kept.
Days must be an integer from 0 to 36500. Zero deletes all eligible past crawls;
it is intended only for disposable qualification data.

Run `librecrawl-retention` manually in the app terminal to execute the same task.
Cascades delete pages, links, issues and queue rows in the same transaction.
Vacuum is opt-in: it blocks writers and needs free disk roughly equal to the
database size. Without vacuum SQLite reuses freed pages rather than shrinking
the file. Retention is not a fixed disk quota; monitor growing/paused crawls.
A crawl paused by a restart and never resumed is kept indefinitely. For sizing,
the 5,000-page qualification crawl added about 130 MB to `users.db`; weekly
crawls kept for 90 days mean about 13 stored crawls per site.

## Backup, upgrades and recovery

Cloudron backs up all of `/app/data`, including `users.db`, configuration,
signing key and account bootstrap material. Test restore to a disposable app
before depending on it. A preserved signing key keeps cookies valid after
restart/restore; client sessions still have upstream expiration limits.

Before a changed upstream commit initializes/migrates the database, startup
creates a consistent SQLite online snapshot named `users.db.bak-<old commit>`
and retains the newest two snapshots. These are not a substitute for Cloudron
backups. If an update fails, restore a compatible image and Cloudron backup;
do not overwrite a live database file or its WAL files manually.

Never enable `LOCAL_MODE`, `DANGEROUSLY_SKIP_AUTH` or `DEMO_MODE`. Startup
fails closed for any value other than empty, false, 0 or no. Registration and
guest flags are forced off regardless of operator settings.
