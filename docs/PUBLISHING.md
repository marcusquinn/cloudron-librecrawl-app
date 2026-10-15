# Publish and qualify the Cloudron package

## Release authority

PRs run static package checks and linked-issue validation only. Merging code is
not publication authorization. The catalog workflow also validates main but
does not publish until the operator sets repository variable
`CLOUDRON_PUBLICATION_ENABLED=true`. Enabling this variable is standing
authorization for that workflow's main-branch image/catalog publication.
Leave it unset during implementation and local qualification.

Before enabling it, configure the repository secret `CLOUDRON_RELEASE_PAT` with
the narrowly scoped permission required to push the generated catalog and tag
to this repository under its protection policy. Never add the secret to Git or
paste it into an issue. GHCR image pushes use the workflow's `GITHUB_TOKEN`.

## Pipeline

1. Update manifest version, upstream commit pin and both changelogs in a PR.
2. Complete local verification and review, then merge to main.
3. Once explicitly enabled, the catalog workflow builds the verified source
   as `linux/amd64`, pushes `ghcr.io/marcusquinn/cloudron-librecrawl-app`, and
   attests the immutable image digest with GitHub keyless provenance.
4. Make the GHCR package publicly readable after its first push. Anonymous
   digest inspection must succeed before catalog publication; if first-push
   visibility is private, set visibility and rerun the failed workflow.
5. Pinned Cloudron CLI 8.2.6 (registry integrity checked) creates
   `CloudronVersions.json` with `cloudron versions init`, adds a testing entry,
   changes it to published, and verifies it. Do not hand-write the catalog.
6. The workflow attests/verifies the catalog, commits only the generated file,
   and atomically pushes main plus the version tag. Concurrent main changes
   cause push rejection rather than an overwrite; rerun from the new main.
7. The unchanged aidevops tag caller creates the GitHub release. Existing
   catalog versions are never overwritten; use revoke/new version for rollback.

If generation/attestation/push fails, no catalog is published by that failed
step. A pushed GHCR image without a catalog is a recoverable intermediate state,
not an installable release. Re-run from the same trusted main after resolving the
external failure. Already-generated versions are skipped; release callers can
be rerun if a tagged release failed. Never force-push publication history.

Verify image provenance with `gh attestation verify oci://<immutable-image> --repo
marcusquinn/cloudron-librecrawl-app`. Verify the downloaded generated catalog
with `gh attestation verify CloudronVersions.json --repo
marcusquinn/cloudron-librecrawl-app`; require this repository's catalog workflow
and main source ref as in CI. The workflow uses digest-pinned image references.

## Operator hand-off (t5)

- Configure `CLOUDRON_RELEASE_PAT`, publication opt-in, and public GHCR visibility.
- Install at **librecrawl-test**, never a production target for qualification.
  For an unpublished package, run `cloudron install --location librecrawl-test`
  from a checkout: Cloudron builds the image on the server, so no registry is
  needed. `cloudron update --app librecrawl-test` rebuilds after changes.
- Confirm TLS, health, first sign-in, trusted service-account creation and the
  plugin login/crawl/list/load/CSV path. Test Chromium separately with adequate RAM.
- Restart and confirm the same cookie and saved crawl work; confirm registration,
  guest and unsafe modes stay disabled.
- Upgrade from a qualified earlier image; confirm settings/users/crawls and the
  signing key persist and the pre-upgrade SQLite snapshot exists.
- Back up, restore to a disposable app, and re-check users, settings, sessions,
  saved crawls and exports. Exercise retention with child rows on disposable data.
- Record real Cloudron version and image digest, then submit the package to
  Community Apps using its generated version catalog and artwork. Results of
  the local-build qualification are in [PACKAGING-NOTES.md](PACKAGING-NOTES.md).
