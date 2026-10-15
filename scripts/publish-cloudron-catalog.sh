#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

main() {
    local catalog="${1:-CloudronVersions.json}"
    local image="${2:-}"
    local version="${3:-}"
    [[ "$catalog" == CloudronVersions.json ]] || return 1
    [[ "$image" =~ ^ghcr\.io/marcusquinn/cloudron-librecrawl-app@sha256:[0-9a-f]{64}$ ]] || return 1
    [[ "$version" == "$(jq -r .version CloudronManifest.json)" ]] || return 1
    # Only the CLI creates the catalog, including the first empty catalog.
    if [[ ! -f "$catalog" ]]; then
        cloudron versions init || return 1
    fi
    if jq -e --arg version "$version" '.versions[$version] != null' "$catalog" >/dev/null; then
        printf 'Refusing to overwrite version %s\n' "$version" >&2
        return 1
    fi
    cloudron versions add --state testing --image "$image" || return 1
    jq -e --arg version "$version" --arg image "$image" \
        '.versions[$version].manifest.version == $version and .versions[$version].manifest.dockerImage == $image and .versions[$version].publishState == "testing"' "$catalog" >/dev/null || return 1
    cloudron versions update --version="$version" --state=published --image "$image" || return 1
    jq -e --arg version "$version" --arg image "$image" \
        '.versions[$version].manifest.dockerImage == $image and .versions[$version].publishState == "published"' "$catalog" >/dev/null || return 1
    cloudron versions verify || return 1
    return 0
}

main "$@"
