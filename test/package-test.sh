#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
jq -e '.manifestVersion == 2 and .version == "0.1.0" and .upstreamVersion == "05a1372" and .httpPort == 5000 and .healthCheckPath == "/login" and .minBoxVersion == "9.1.0" and .memoryLimit == 2147483648 and .addons.localstorage == {} and .addons.scheduler.retention.schedule == "0 3 * * *" and .addons.scheduler.retention.command == "/app/code/bin/librecrawl-retention" and (.addons | has("proxyAuth") | not) and (.addons | has("proxyauth") | not)' CloudronManifest.json >/dev/null
grep -Eq '^ARG LIBRECRAWL_COMMIT=[0-9a-f]{40}$' Dockerfile
grep -Fq 'cloudron/base:6.0.0@sha256:9bed4c8fa880645f8e669041ee28febe941481d00e9445e3e5a5483cb541d09b' Dockerfile
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
grep -Fq 'CLOUDRON_PUBLICATION_ENABLED' .github/workflows/cloudron-catalog-publish.yml
for file in CHANGELOG logo.png media/hero.png docs/README.md docs/PACKAGING-NOTES.md docs/PUBLISHING.md DESIGN.md; do
    test -s "$file"
done
# Catalog is deliberately absent until the authorized CLI publication runs.
if [[ -f CloudronVersions.json ]]; then
    jq -e '.versions | type == "object"' CloudronVersions.json >/dev/null
fi
bash -n start.sh bin/librecrawl-user bin/librecrawl-retention scripts/publish-cloudron-catalog.sh
printf 'Package static checks passed\n'
