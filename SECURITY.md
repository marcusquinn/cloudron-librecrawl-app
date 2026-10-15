# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability, please report it privately.

**Email:** 6428977+marcusquinn@users.noreply.github.com

Please do not open public issues for security vulnerabilities.

## Supported versions

Package 0.1.x pins LibreCrawl to commit `05a1372`. This is a new package;
production qualification on Cloudron is tracked separately from local testing.
Upstream dependencies are not a guarantee of vulnerability-free operation.

## Trust boundary

LibreCrawl fetches arbitrary URLs and does **not** block private addresses.
Signed-in users can reach other apps, internal services and the Docker network.
Registration, guest sign-in, local mode, skip-auth and demo mode are disabled.
Do not expose accounts to untrusted people or sites. Cloudron TLS secures
browser/API transport; it does not isolate outbound crawler traffic.

First-run credentials, session signing key, database and configuration live in
`/app/data`, are included in backups, and must be protected as secrets. Read
the initial administrator password privately, then reset it. Password resets
and tier changes do not revoke already-issued upstream session cookies: existing
clients must sign out and sign in again. To revoke all sessions, stop the app,
remove `/app/data/.secret_key` and restart; all clients must authenticate again.

The operator-owned `/app/data/env` is sourced as shell configuration, including
by startup as root. Never let API users edit it. Retention is destructive by
design; keep backups and use 0-day retention only on disposable test data.

See [packaging limitations and follow-ups](docs/PACKAGING-NOTES.md).
