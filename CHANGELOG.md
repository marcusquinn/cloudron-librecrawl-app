# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
