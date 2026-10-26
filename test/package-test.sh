#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
jq -e '.manifestVersion == 2 and .version == "0.1.0" and .upstreamVersion == "05a1372" and .httpPort == 5000 and .healthCheckPath == "/login" and .minBoxVersion == "9.1.0" and .memoryLimit == 2147483648 and .addons.localstorage == {} and .addons.scheduler.retention.schedule == "0 3 * * *" and .addons.scheduler.retention.command == "/app/code/bin/librecrawl-retention" and (.addons | has("proxyAuth") | not) and (.addons | has("proxyauth") | not)' CloudronManifest.json >/dev/null
grep -Eq '^ARG LIBRECRAWL_COMMIT=[0-9a-f]{40}$' Dockerfile
grep -Fq 'cloudron/base:6.0.1@sha256:7b1e729960c3ca312d26e886917ba89483241bba0219ff292858e10d9d5768ee' Dockerfile
grep -Fq 'playwright install --with-deps chromium' Dockerfile
grep -Fq 'ln -s /app/data /app/code/data' Dockerfile
grep -Fq 'python main.py --disable-register --disable-guest' start.sh
if grep -Eq -- '--local|--dangerously-skip-auth|--demo' start.sh; then
    printf 'Unsafe startup argument found\n' >&2
    exit 1
fi
grep -Fq 'LOCAL_MODE DANGEROUSLY_SKIP_AUTH DEMO_MODE' start.sh
grep -Fq 'PRAGMA foreign_keys=ON' bin/librecrawl-retention
grep -Fq 'cleanup_old_crawls(days)' bin/librecrawl-retention
# Publication opt-in, catalog dry-run and release creation live in the pinned
# reusable workflow; the caller must bind its helper policy to that same SHA.
workflow=.github/workflows/cloudron-catalog-publish.yml
publisher_ref="$(sed -nE 's|^    uses: marcusquinn/aidevops/\.github/workflows/cloudron-catalog-publish-reusable\.yml@([0-9a-f]{40})$|\1|p' "$workflow")"
test -n "$publisher_ref"
grep -Fxq "      aidevops_ref: $publisher_ref" "$workflow"
for file in CHANGELOG DESCRIPTION.md POSTINSTALL.md logo.png media/hero.png docs/README.md docs/PACKAGING-NOTES.md docs/PUBLISHING.md DESIGN.md; do
    test -s "$file"
done
# Store metadata comes from these files; listing images must be public HTTPS URLs.
jq -e '.description == "file://DESCRIPTION.md" and .postInstallMessage == "file://POSTINSTALL.md" and (.mediaLinks | length > 0 and all(startswith("https://")))' CloudronManifest.json >/dev/null
# Only the authorized CLI publication writes the catalog; never hand-edit it.
if [[ -f CloudronVersions.json ]]; then
    jq -e '.versions | type == "object"' CloudronVersions.json >/dev/null
fi
# Keep the package-specific checks wired into the reusable preflight.
grep -Fxq '        bash test/package-test.sh' "$workflow"
grep -Fxq '        shellcheck start.sh bin/librecrawl-user bin/librecrawl-retention scripts/*.sh test/*.sh' "$workflow"
for script in start.sh bin/librecrawl-user bin/librecrawl-retention bin/librecrawl-config scripts/publish-cloudron-catalog.sh scripts/create-github-release.sh; do
    bash -n "$script"
done
printf 'Package static checks passed\n'
