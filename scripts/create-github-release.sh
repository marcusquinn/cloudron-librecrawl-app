#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Create the GitHub release for a published catalog version, or repair a
# missing one. The catalog workflow tags its own [skip ci] commit, so tag-push
# workflows never run for it. Every check reads the version tag, not the
# working tree. Requires GH_TOKEN with contents: write and attestations: read.
set -euo pipefail

readonly SIGNER_WORKFLOW=".github/workflows/cloudron-catalog-publish.yml"
WORKDIR=""

cleanup() {
    if [[ -n "$WORKDIR" ]]; then
        rm -rf "$WORKDIR"
    fi
    return 0
}

fail() {
    local message="$1"
    printf '%s\n' "$message" >&2
    return 1
}

release_notes() {
    local tag="$1"
    local version="$2"
    local upstream
    upstream="$(git show "${tag}:CloudronManifest.json" | jq -r .upstreamVersion)" || return 1
    printf 'Cloudron package %s for LibreCrawl commit %s.\n\n' "$version" "$upstream"
    git show "${tag}:CHANGELOG" |
        awk -v heading="[${version}]" '$0 == heading { found = 1; next } found && /^\[/ { exit } found' || return 1
    return 0
}

main() {
    local version="${1:-}"
    local repo="${GITHUB_REPOSITORY:-marcusquinn/cloudron-librecrawl-app}"
    local tag="v${version}"
    local catalog image notes
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Usage: ${0##*/} <x.y.z>" || return 1
    # The catalog workflow pushes main and the tag atomically.
    git rev-parse -q --verify "refs/tags/${tag}^{commit}" >/dev/null || fail "Tag ${tag} not found" || return 1
    git merge-base --is-ancestor "$tag" origin/main || fail "Tag ${tag} is not on main" || return 1
    WORKDIR="$(mktemp -d)"
    trap cleanup EXIT
    catalog="${WORKDIR}/CloudronVersions.json"
    git show "${tag}:CloudronVersions.json" >"$catalog" || return 1
    image="$(jq -r --arg version "$version" '.versions[$version] | select(.publishState == "published") | .manifest.dockerImage' "$catalog")"
    [[ "$image" =~ ^ghcr\.io/marcusquinn/cloudron-librecrawl-app@sha256:[0-9a-f]{64}$ ]] ||
        fail "Tag ${tag} has no published digest-pinned catalog entry for ${version}" || return 1
    # Cloudron servers pull anonymously; the CI job has no registry login.
    docker buildx imagetools inspect "$image" >/dev/null || fail "Image ${image} is not pullable" || return 1
    gh attestation verify "$catalog" --repo "$repo" --signer-workflow "${repo}/${SIGNER_WORKFLOW}" \
        --source-ref refs/heads/main >/dev/null || fail "Catalog at ${tag} lacks main-branch provenance" || return 1
    if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
        printf 'GitHub release %s already exists\n' "$tag"
        return 0
    fi
    notes="${WORKDIR}/notes.md"
    release_notes "$tag" "$version" >"$notes" || return 1
    gh release create "$tag" --repo "$repo" --verify-tag --title "$tag" --notes-file "$notes" || return 1
    return 0
}

main "$@"
