# t5: Qualify the LibreCrawl package on Cloudron, connect SEO Pro Stats sites, submit to Community Apps

## Origin

- **Created:** 2026-10-14
- **Created by:** ai-interactive (Marcus Quinn session)
- **Blocked by:** t4 (package implementation PR merged)
- **Conversation context:** Operator half of the LibreCrawl package lifecycle. These steps need the maintainer's GitHub secret, Cloudron server, WordPress sites and Cloudron Community Apps account, so they are not worker-dispatchable.

## What

The package from t4 is published, qualified on a live Cloudron, used by at least one SEO Pro Stats site through its crawler connection, and listed in Cloudron Community Apps.

## Why

The package exists so hosted WordPress sites can crawl themselves on a schedule (wpallstars/seoprostats#337). Only a live install with real sites proves the API path, memory sizing and retention under real crawls.

## How (operator checklist)

1. Create a fine-grained PAT limited to this repository with only `Contents: Read and write`; save it as the repository secret `CLOUDRON_RELEASE_PAT` (`docs/PUBLISHING.md` → Release credential).
2. Merge the t4 PR (or re-run `cloudron-catalog-publish.yml` on `main`); confirm the image, `CloudronVersions.json`, tag `v<VERSION>` and GitHub release.
3. Install: `cloudron install --versions-url <PUBLIC_VERSIONS_URL> --location librecrawl-test`.
4. Qualify: health green; read the admin password with `cloudron exec`, sign in, change it; `/register` and guest sign-in refused; create a service account with `librecrawl-user add` (tier `admin`); crawl a 5,000-page site with JS off and one small site with JS on, watching memory (`cloudron logs`, Cloudron graphs) and record whether 2 GiB is enough; restart mid-crawl and confirm the crawl resumes or is listed; update to the next catalog version when available; backup and restore keep users and crawls; set `CRAWL_RETENTION_DAYS=1` briefly and confirm the scheduler run deletes an old crawl.
5. Once wpallstars/seoprostats#337 is released: on one SEO Pro Stats site set Settings → Connections → Crawler to this server with the service account; Test connection, Crawl now, and confirm the import appears in Search → Audit → Site crawl. Then roll out to the other sites, each with its own account (or one shared account; record the choice and why).
6. Sign in at Cloudron Community Apps, add the versions URL, verify icon, hero, description, changelog and install URL.
7. In local `~/.config/aidevops/repos.json`, set `cloudron_package.monitor_upstream` and `monitor_compatibility` to `true` for this repository.
8. Record evidence (commands; screenshots at most 1568px) in this issue, without passwords or cookies. Record the memory and crawl-size findings in `docs/PACKAGING-NOTES.md` (and adjust the default `memoryLimit` through a normal PR if 2 GiB proved too small).

### Files Scope

- `docs/PACKAGING-NOTES.md`
- `CloudronManifest.json`
- `TODO.md`

## Acceptance Criteria

- [ ] `CloudronVersions.json` on `main` lists the published version with an immutable image digest.
- [ ] Live install passes the qualification list above, with evidence in the issue, including the memory finding.
- [ ] At least one SEO Pro Stats site imports a scheduled crawl from this server.
- [ ] The app appears in Cloudron Community Apps with correct metadata.
- [ ] No secret values appear in the repository, issue or logs.

## Dependencies

- **Blocked by:** t4
- **External:** GitHub PAT, Cloudron admin access, a released SEO Pro Stats with the crawler connection (wpallstars/seoprostats#337) for step 5, Cloudron Community Apps account.
