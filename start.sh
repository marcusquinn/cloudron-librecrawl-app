#!/usr/bin/env bash
set -euo pipefail
umask 077
mkdir -p /app/data
cd /app/code

# The app-writable env file contains literal operator configuration, not shell code.
if [[ ! -f /app/data/env ]]; then
    printf '# LibreCrawl operator configuration\nCRAWL_RETENTION_DAYS=90\nCRAWL_VACUUM=false\n' > /app/data/env.tmp
    mv /app/data/env.tmp /app/data/env
fi
# shellcheck disable=SC1091
source /app/code/bin/librecrawl-config
load_librecrawl_config /app/data/env
for flag in LOCAL_MODE DANGEROUSLY_SKIP_AUTH DEMO_MODE; do
    value="${!flag:-false}"
    case "${value,,}" in
        false|0|no|'') ;;
        *) printf 'Refusing unsafe configuration: %s\n' "$flag" >&2; exit 1 ;;
    esac
done
export LOCAL_MODE=false DANGEROUSLY_SKIP_AUTH=false DEMO_MODE=false
export REGISTRATION_DISABLED=true DISABLE_GUEST=true
# Avoid loading any operator-supplied signing key: always use the persisted key.
if [[ ! -f /app/data/.secret_key ]]; then
    openssl rand -hex 32 > /app/data/.secret_key.tmp
    chmod 600 /app/data/.secret_key.tmp
    mv /app/data/.secret_key.tmp /app/data/.secret_key
fi
read -r SECRET_KEY < /app/data/.secret_key
[[ "$SECRET_KEY" =~ ^[0-9a-f]{64}$ ]] || { printf 'Invalid persistent signing key\n' >&2; exit 1; }
export SECRET_KEY
chmod 600 /app/data/.secret_key

/app/code/venv/bin/python - <<'PY'
import os
import pathlib
import secrets
import sqlite3

data = pathlib.Path('/app/data')
revision = pathlib.Path('/app/code/upstream-commit').read_text().strip()
marker = data / '.upstream-commit'
previous = marker.read_text().strip() if marker.exists() else None
database = data / 'users.db'
# SQLite online backup includes WAL contents; do not copy only the main file.
if previous and previous != revision and database.exists():
    if len(previous) != 40 or any(c not in '0123456789abcdef' for c in previous):
        raise RuntimeError('Invalid previous upstream revision')
    snapshot = data / ('users.db.bak-' + previous)
    temporary = snapshot.with_suffix(snapshot.suffix + '.tmp')
    with sqlite3.connect(database) as source, sqlite3.connect(temporary) as target:
        source.backup(target)
    os.replace(temporary, snapshot)
    for old in sorted(data.glob('users.db.bak-*'), key=lambda p: p.stat().st_mtime, reverse=True)[2:]:
        old.unlink()

from src import auth_db
auth_db.init_db()
with auth_db.get_db() as conn:
    admin = conn.execute('SELECT id FROM users WHERE username = ?', ('admin',)).fetchone()
pending = data / '.admin-bootstrap-pending'
if admin is None:
    temporary = data / '.admin-bootstrap-pending.tmp'
    temporary.write_text('admin\n')
    os.replace(temporary, pending)
    password_file = data / 'admin-password'
    # Persist before insertion so a crash can safely retry the same password.
    if not password_file.exists():
        temporary = data / 'admin-password.tmp'
        temporary.write_text(secrets.token_urlsafe(24) + '\n')
        temporary.chmod(0o600)
        os.replace(temporary, password_file)
    ok, message, user_id = auth_db.create_user('admin', 'admin@librecrawl.local', password_file.read_text().strip())
    if not ok or not auth_db.verify_user(user_id)[0] or not auth_db.set_user_tier(user_id, 'admin')[0]:
        raise RuntimeError('First admin initialization failed')
    pending.unlink()
    print('Created admin; retrieve the password from /app/data/admin-password')
elif pending.exists():
    # Complete an interrupted bootstrap without replacing its password.
    if not auth_db.verify_user(admin['id'])[0] or not auth_db.set_user_tier(admin['id'], 'admin')[0]:
        raise RuntimeError('Admin initialization failed')
    pending.unlink()
temporary = data / '.upstream-commit.tmp'
temporary.write_text(revision + '\n')
os.replace(temporary, marker)
PY
chown -R cloudron:cloudron /app/data
# tini as PID 1 reaps the Chromium helpers orphaned by each JavaScript crawl and
# forwards SIGTERM, so upstream's shutdown handler still saves live crawls as paused.
exec /usr/bin/tini -- gosu cloudron:cloudron /app/code/venv/bin/python main.py --disable-register --disable-guest
