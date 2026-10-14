# LibreCrawl on Cloudron

## Install and first sign-in

Requires Cloudron 9.1.0 or newer. Use the locally built image while qualifying
the package; use the immutable published image/catalog only after publication.
See [PUBLISHING.md](PUBLISHING.md). Cloudron handles public HTTPS; the app
serves HTTP on port 5000 internally. There is no Cloudron SSO or proxy-auth wall.

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
`POST /api/crawls/<id>/load`, and
`GET /api/export_stream?type=urls&format=csv`. Save `maxUrls: 50` for a first
smoke crawl. Clients retain the login cookie; finished crawls are persistent.
Restarting the app stops in-memory work; load persisted results afterwards.

## Memory and JavaScript

Default memory is 2 GiB and JavaScript rendering is off. Only Chromium is
installed. When enabling JavaScript in settings, select Chromium, start with
one concurrent browser page, and raise the Cloudron memory limit to at least
4 GiB for larger sites. Actual needs depend on page size and concurrency.
Unexpected restarts, incomplete crawls or Chromium crashes can indicate OOM;
check Cloudron app logs and resource usage before increasing concurrency.

## Retention

Edit `/app/data/env` in the operator terminal, then restart the app:

```bash
CRAWL_RETENTION_DAYS=90
CRAWL_VACUUM=false
```

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
