# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.8] - 2026-11-09

### Changed

- Update the pinned LibreCrawl revision from `b5b288f` to `f25bee6` (issue #47).
  This adds end-of-crawl analysis (indexability, inlinks, outlinks and Link
  Score), a sitemap audit, and comparison of two saved crawls with CSV export.
  The crawl database adds an `analysis` column on first start; existing crawls
  stay readable. No new dependencies.

## [0.1.7] - 2026-11-07

### Changed

- Update the pinned LibreCrawl revision from `38e3bb4` to `b5b288f` (issue #41).
  Upstream fixes accounts stuck unverified without email, loads `.env` before
  the email settings, and adds `manage.py`. No new dependencies; accounts stay
  managed with `librecrawl-user`.

## [0.1.6] - 2026-11-05

### Changed

- Update the pinned LibreCrawl revision from `8f4d31d` to `38e3bb4` (issue #39).
  This adds n-gram analysis with filters and export, table column visibility
  and sorting, and per-user table column preferences. No new dependencies.

## [0.1.5] - 2026-11-04

### Changed

- Update the pinned LibreCrawl revision from `5ae2792` to `8f4d31d` (issue #33).
  This adds configurable CSS/XPath extraction and a list mode for checking an
  explicit set of URLs without spidering beyond it.

### Fixed

- Reuse each host's robots.txt result during a crawl and surface the reason a
  crawl failed to start.

## [0.1.4] - 2026-11-02

### Changed

- Update the pinned LibreCrawl revision from `05a1372` to `5ae2792` (issue #30).
  Cloudron base 6.0.1, the Cloudron 10 minimum and signed-in-only settings are unchanged.

### Fixed

- Include upstream's crawl-delay fix for crawls with JavaScript rendering disabled.
- Include upstream's row-wise save/load handling for large crawl files and
  incremental link bookkeeping to avoid quadratic work on large sites.

## [0.1.3] - 2026-11-02

### Changed

- Set `packagerUrl` to this repository so the Community Apps Package link opens it.
  ca.cloudron.io builds the Package link (and the "By" link) from `packagerUrl`
  and ignores `packageUrl`, so the 0.1.2 change had no visible effect
  (marcusquinn/aidevops#36428). `packageUrl` and `minBoxVersion` 10.0.0 are unchanged.
- No change to the app; LibreCrawl stays at commit 05a1372.

## [0.1.2] - 2026-11-01

### Changed

- Set `packageUrl` so the Community Apps Package button opens this repository;
  `packagerUrl` still links the maintainer (issue #24).
- Require Cloudron 10.0.0 (`minBoxVersion`). Cloudron 9 rejects `packageUrl`
  anywhere in `CloudronVersions.json`, so 9.x servers can no longer read this
  catalog. LibreCrawl stays at commit `05a1372`; no app change.

## [0.1.1] - 2026-10-27

### Changed

- Use the pinned aidevops reusable catalog publisher, preserving package checks,
  the image repository and Cloudron CLI pin while adding PR image builds and
  guarded publication retries when main advances with documentation changes.

### Fixed

- Pin the package to Cloudron base 6.0.1, including the patched CA bundle
  and shared MIME data, and align the package static check with its digest.
- The catalog workflow creates each version's GitHub release itself, after
  verifying the tag, image and catalog provenance. The version tag sits on a
  `[skip ci]` commit, which tag-push workflows ignore; later runs on main
  repair a missing release.

## [0.1.0] - 2026-10-16

### Added

- Cloudron 9.1+ package for LibreCrawl pinned to commit `05a1372`.
- Trusted-account-only access, first administrator provisioning and user CLI.
- Persistent session signing, SQLite state and pre-upgrade snapshots.
- Daily configurable retention with cascading child deletion and opt-in vacuum.
- Chromium-only rendering, publishing workflows and operator documentation.
- LibreCrawl runs under tini, so the Chromium helper processes each JavaScript
  crawl leaves behind are reaped instead of accumulating as zombies.
- Live Cloudron qualification notes: memory sizing, restart and resume,
  scheduled retention, and upstream crawl behaviour that clients must allow for.
- App store description, post-install guide, documentation and licence links,
  and five listing screenshots.
