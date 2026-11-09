#!/usr/bin/env bash
# Local upgrade check. Runs the previous published package image on a fresh
# /app/data volume, seeds an account, settings and two saved crawls, then starts
# the candidate image on the same volume and checks that the data, the signing
# key and existing sessions survive. Requires Docker, curl, jq and openssl.
# Images are linux/amd64, as on Cloudron; other hosts use emulation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM=linux/amd64
CANDIDATE_TAG=librecrawl-upgrade-test:candidate
RUN_ID="librecrawl-upgrade-$$"
VOLUME="${RUN_ID}-data"
USERNAME=upgrade-check
EMAIL=upgrade-check@example.invalid
FROM_IMAGE=""
TO_IMAGE=""
READY_TIMEOUT=300
REQUIRE_COMPARE=false
CONTAINER=""
CONTAINERS=""
WORK_DIR=""
BASE_URL=""
API_STATUS=""
API_BODY=""
PASSWORD=""

usage() {
    cat <<'EOF'
Usage: test/upgrade-test.sh [--from IMAGE] [--to IMAGE] [--timeout SECONDS]
                            [--require-compare]

  --from IMAGE   Image to upgrade from. Default: the newest CloudronVersions.json
                 entry older than CloudronManifest.json's version.
  --to IMAGE     Image to upgrade to. Default: a linux/amd64 build of this
                 checkout, tagged librecrawl-upgrade-test:candidate.
  --timeout N    Seconds to wait for each container to answer GET /login
                 (default 300; emulated hosts are slow).
  --require-compare
                 Fail if the upgraded image has no crawl comparison endpoint
                 (HTTP 404). Without it, that check is skipped with a note.
                 Use it for release checks; packages from 0.1.8 have it.
EOF
    return 0
}

log() {
    local message="$1"
    printf '%s\n' "$message"
    return 0
}

fail() {
    local message="$1"
    printf 'Upgrade check failed: %s\n' "$message" >&2
    if [[ -n "$CONTAINER" ]]; then
        printf -- '--- last log lines of %s ---\n' "$CONTAINER" >&2
        docker logs --tail 40 "$CONTAINER" >&2 2>&1 || true
    fi
    # exit is the terminal path; an explicit return here would be unreachable.
    exit 1
}

cleanup() {
    local status=$?
    local name
    for name in $CONTAINERS; do
        docker rm -f "$name" >/dev/null 2>&1 || true
    done
    docker volume rm -f "$VOLUME" >/dev/null 2>&1 || true
    if [[ -n "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
    fi
    return "$status"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        local arg="$1"
        local value="${2:-}"
        case "$arg" in
            --from) [[ $# -ge 2 ]] || fail '--from needs an image'; FROM_IMAGE="$value"; shift 2 ;;
            --to) [[ $# -ge 2 ]] || fail '--to needs an image'; TO_IMAGE="$value"; shift 2 ;;
            --timeout) [[ $# -ge 2 && "$value" =~ ^[1-9][0-9]*$ ]] || fail '--timeout needs a positive integer'; READY_TIMEOUT="$value"; shift 2 ;;
            --require-compare) REQUIRE_COMPARE=true; shift ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; fail "unknown argument: $arg" ;;
        esac
    done
    return 0
}

require_tools() {
    local tool
    for tool in docker curl jq openssl; do
        command -v "$tool" >/dev/null 2>&1 || fail "$tool is required"
    done
    docker info >/dev/null 2>&1 || fail 'the Docker daemon is not reachable'
    return 0
}

# Newest published catalog entry older than the manifest version.
previous_image() {
    local version
    version="$(jq -r '.version' "$ROOT/CloudronManifest.json")" || return 1
    [[ -f "$ROOT/CloudronVersions.json" ]] || return 1
    jq -r --arg current "$version" '
        def v: split(".") | map(tonumber);
        [.versions | to_entries[] | select((.key | v) < ($current | v))]
        | sort_by(.key | v) | last | .value.manifest.dockerImage // empty
    ' "$ROOT/CloudronVersions.json" || return 1
    return 0
}

resolve_images() {
    if [[ -z "$FROM_IMAGE" ]]; then
        FROM_IMAGE="$(previous_image)" || fail 'cannot read CloudronManifest.json or CloudronVersions.json'
        [[ -n "$FROM_IMAGE" ]] || fail 'no earlier catalog version to upgrade from; pass --from'
    fi
    if [[ -z "$TO_IMAGE" ]]; then
        log "Building $CANDIDATE_TAG ($PLATFORM) from $ROOT"
        docker build --platform "$PLATFORM" -t "$CANDIDATE_TAG" "$ROOT" || fail 'candidate image build failed'
        TO_IMAGE="$CANDIDATE_TAG"
    fi
    return 0
}

wait_ready() {
    local deadline=$((SECONDS + READY_TIMEOUT))
    while ((SECONDS < deadline)); do
        if [[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" != true ]]; then
            printf '%s stopped during startup\n' "$CONTAINER" >&2
            return 1
        fi
        if curl -fsS -o /dev/null "$BASE_URL/login" 2>/dev/null; then
            return 0
        fi
        sleep 3
    done
    printf '%s did not answer GET /login within %ss\n' "$CONTAINER" "$READY_TIMEOUT" >&2
    return 1
}

# Mirror Cloudron's runtime: read-only image, writable /app/data, /tmp and /run.
start_container() {
    local image="$1"
    local name="$2"
    local mapping
    CONTAINER="$name"
    CONTAINERS="$CONTAINERS $name"
    log "Starting $name: $image"
    docker run -d --name "$name" --platform "$PLATFORM" --read-only \
        --tmpfs /tmp --tmpfs /run -v "$VOLUME:/app/data" \
        -p 127.0.0.1::5000 "$image" >/dev/null || fail "cannot start $image"
    mapping="$(docker port "$name" 5000/tcp | head -n 1)" || fail "no port mapping for $name"
    BASE_URL="http://127.0.0.1:${mapping##*:}"
    wait_ready || fail "$image did not become ready"
    return 0
}

stop_container() {
    # SIGTERM reaches upstream's shutdown handler through tini, as on Cloudron.
    docker stop -t 30 "$CONTAINER" >/dev/null || fail "cannot stop $CONTAINER"
    docker rm "$CONTAINER" >/dev/null || fail "cannot remove $CONTAINER"
    CONTAINER=""
    return 0
}

app_python() {
    local script="$1"
    shift
    docker exec -i -w /app/code "$CONTAINER" gosu cloudron:cloudron \
        /app/code/venv/bin/python - "$@" <<<"$script" || return 1
    return 0
}

api() {
    local method="$1"
    local path="$2"
    local jar="$3"
    local data="${4:-}"
    local args=(-sS -o "$WORK_DIR/body" -w '%{http_code}' -X "$method" -b "$jar" -c "$jar"
        -H 'Content-Type: application/json')
    if [[ -n "$data" ]]; then
        args+=(--data "$data")
    fi
    API_STATUS="$(curl "${args[@]}" "$BASE_URL$path")" || return 1
    API_BODY="$(cat "$WORK_DIR/body")"
    return 0
}

expect_json() {
    local filter="$1"
    local message="$2"
    if ! jq -e "$filter" >/dev/null 2>&1 <<<"$API_BODY"; then
        fail "expected: $message (HTTP $API_STATUS: ${API_BODY:0:300})"
    fi
    log "ok: $message"
    return 0
}

# Filters see the state JSON from before and after the upgrade as `before` and `after`.
expect_state() {
    local filter="$1"
    local message="$2"
    if ! jq -e "def before: .[0]; def after: .[1]; $filter" >/dev/null <<<"[$BEFORE,$AFTER]"; then
        fail "expected: $message"
    fi
    log "ok: $message"
    return 0
}

login() {
    local jar="$1"
    local body
    body="$(jq -nc --arg u "$USERNAME" --arg p "$PASSWORD" '{username: $u, password: $p}')"
    api POST /api/login "$jar" "$body" || fail 'login request failed'
    expect_json '.success == true' "$USERNAME signs in with its password"
    return 0
}

read -r -d '' SEED_PY <<'PY' || true
import json
import sys
from src import auth_db, crawl_db

username = sys.argv[1]
crawl_db.init_crawl_tables()
with auth_db.get_db() as conn:
    user_id = conn.execute('SELECT id FROM users WHERE username = ?', (username,)).fetchone()['id']
ok, message = auth_db.save_user_settings(user_id, {'maxDepth': 3, 'upgradeCheck': 'kept'})
if not ok:
    sys.exit('save_user_settings failed: ' + message)

base = 'https://upgrade-check.example.invalid/'

def page(path, title):
    return {'url': base + path, 'status_code': 200, 'content_type': 'text/html',
            'is_internal': True, 'depth': 1 if path else 0, 'title': title,
            'meta_description': 'Upgrade check fixture', 'h1': title,
            'word_count': 120, 'linked_from': []}

fixtures = (
    ('previous', [page('', 'Home'), page('about', 'About'), page('old', 'Old page')]),
    ('current', [page('', 'Home'), page('about', 'About us'), page('new', 'New page')]),
)
crawl_ids = []
for label, pages in fixtures:
    crawl_id = crawl_db.create_crawl(user_id, 'upgrade-check', base,
                                     'upgrade-check.example.invalid', {'label': label})
    issues = [{'url': pages[-1]['url'], 'type': 'warning', 'category': 'SEO',
               'issue': 'Upgrade check fixture issue', 'details': label}]
    if not (crawl_id and crawl_db.save_url_batch(crawl_id, pages)
            and crawl_db.save_issues_batch(crawl_id, issues)
            and crawl_db.update_crawl_stats(crawl_id, discovered=len(pages), crawled=len(pages))
            and crawl_db.set_crawl_status(crawl_id, 'completed')):
        sys.exit('seeding crawl ' + label + ' failed')
    crawl_ids.append(crawl_id)
print(json.dumps({'previous': crawl_ids[0], 'current': crawl_ids[1]}))
PY

read -r -d '' STATE_PY <<'PY' || true
import hashlib
import json
import pathlib
import sqlite3
import sys
from src import auth_db

data = pathlib.Path('/app/data')
tables = ('users', 'user_settings', 'crawls', 'crawled_urls', 'crawl_issues', 'crawl_links')
with sqlite3.connect(data / 'users.db') as conn:
    counts = {t: conn.execute('SELECT COUNT(*) FROM ' + t).fetchone()[0] for t in tables}
    user_id = conn.execute('SELECT id FROM users WHERE username = ?', (sys.argv[1],)).fetchone()[0]
snapshots = {}
for path in sorted(data.glob('users.db.bak-*')):
    with sqlite3.connect('file:' + str(path) + '?mode=ro', uri=True) as snap:
        snapshots[path.name] = {
            'integrity': snap.execute('PRAGMA integrity_check').fetchone()[0],
            'users': snap.execute('SELECT COUNT(*) FROM users').fetchone()[0],
        }
marker = data / '.upstream-commit'
print(json.dumps({
    'counts': counts,
    'settings': auth_db.get_user_settings(user_id),
    'key_sha256': hashlib.sha256((data / '.secret_key').read_bytes()).hexdigest(),
    'marker': marker.read_text().strip() if marker.exists() else None,
    'image_commit': pathlib.Path('/app/code/upstream-commit').read_text().strip(),
    'snapshots': snapshots,
}, sort_keys=True))
PY

seed_previous() {
    local jar="$WORK_DIR/session.jar"
    printf '%s\n' "$PASSWORD" | docker exec -i "$CONTAINER" /app/code/bin/librecrawl-user \
        add "$USERNAME" "$EMAIL" --tier user >/dev/null || fail 'librecrawl-user add failed'
    login "$jar"
    CRAWLS="$(app_python "$SEED_PY" "$USERNAME")" || fail 'seeding saved crawls failed'
    CRAWLS="$(tail -n 1 <<<"$CRAWLS")"
    PREVIOUS_ID="$(jq -r '.previous' <<<"$CRAWLS")"
    CURRENT_ID="$(jq -r '.current' <<<"$CRAWLS")"
    api GET /api/crawls/list "$jar" || fail 'crawl list request failed'
    expect_json "[.crawls[].id] | contains([$PREVIOUS_ID, $CURRENT_ID])" 'seeded crawls are listed before the upgrade'
    BEFORE="$(app_python "$STATE_PY" "$USERNAME" | tail -n 1)" || fail 'reading state before the upgrade failed'
    # Keep this session cookie to prove it still works after the upgrade.
    cp "$jar" "$WORK_DIR/previous-session.jar"
    return 0
}

check_files() {
    local previous_marker
    previous_marker="$(jq -r '.marker' <<<"$BEFORE")"
    expect_state 'after.key_sha256 == before.key_sha256' 'session signing key is unchanged'
    expect_state 'after.marker == after.image_commit' '.upstream-commit records the new upstream commit'
    expect_state 'after.counts == before.counts' 'users, settings, crawls, URLs, issues and links are all kept'
    expect_state 'after.settings == before.settings' 'user settings are unchanged'
    if [[ "$previous_marker" == "$(jq -r '.marker' <<<"$AFTER")" ]]; then
        log 'note: upstream pin is unchanged, so no pre-upgrade snapshot is expected'
    else
        expect_state "after.snapshots[\"users.db.bak-$previous_marker\"].integrity == \"ok\" and after.snapshots[\"users.db.bak-$previous_marker\"].users == before.counts.users" \
            "pre-upgrade snapshot users.db.bak-$previous_marker exists and is intact"
    fi
    return 0
}

check_api() {
    local previous_jar="$WORK_DIR/previous-session.jar"
    local jar="$WORK_DIR/new-session.jar"
    api GET /api/user/info "$previous_jar" || fail 'user info request failed'
    expect_json ".success == true and .user.username == \"$USERNAME\"" 'session cookie issued before the upgrade is still accepted'
    login "$jar"
    api GET /api/crawls/list "$jar" || fail 'crawl list request failed'
    expect_json "[.crawls[].id] | contains([$PREVIOUS_ID, $CURRENT_ID])" 'saved crawls are listed after the upgrade'
    api GET "/api/crawls/$PREVIOUS_ID" "$jar" || fail 'crawl request failed'
    expect_json '.success == true and (.urls | length) == 3 and (.issues | length) == 1' 'saved crawl reads back with its URLs and issues'
    api POST "/api/crawls/$CURRENT_ID/load" "$jar" '{}' || fail 'crawl load request failed'
    expect_json '.success == true and .urls_count == 3 and .issues_count == 1' 'saved crawl loads into a session'
    api GET "/api/crawls/compare?previous=$PREVIOUS_ID&current=$CURRENT_ID" "$jar" || fail 'compare request failed'
    if [[ "$API_STATUS" == 404 ]] && ! jq -e . >/dev/null 2>&1 <<<"$API_BODY"; then
        if [[ "$REQUIRE_COMPARE" == true ]]; then
            fail 'expected: crawl comparison endpoint exists (HTTP 404)'
        fi
        log 'note: candidate has no crawl comparison endpoint; skipped'
    else
        expect_json '.success == true and .total_changes > 0' 'crawls saved before the upgrade can be compared'
    fi
    api POST /api/register "$jar" '{"username":"intruder","email":"intruder@example.invalid","password":"not-allowed-1"}' || fail 'register request failed'
    expect_json '.success == false and (.message | test("disabled"; "i"))' 'registration stays disabled'
    api POST /api/guest-login "$WORK_DIR/guest.jar" '{}' || fail 'guest login request failed'
    expect_json '.success == false and (.message | test("disabled"; "i"))' 'guest sign-in stays disabled'
    return 0
}

main() {
    parse_args "$@"
    require_tools
    WORK_DIR="$(mktemp -d)"
    trap cleanup EXIT
    PASSWORD="$(openssl rand -hex 16)"
    resolve_images
    docker volume create "$VOLUME" >/dev/null || fail 'cannot create the data volume'

    start_container "$FROM_IMAGE" "${RUN_ID}-from"
    seed_previous
    stop_container

    start_container "$TO_IMAGE" "${RUN_ID}-to"
    AFTER="$(app_python "$STATE_PY" "$USERNAME" | tail -n 1)" || fail 'reading state after the upgrade failed'
    check_files
    check_api
    log "Upgrade check passed: $FROM_IMAGE -> $TO_IMAGE"
    return 0
}

main "$@"
