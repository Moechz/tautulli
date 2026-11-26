#!/bin/sh
# ===========================================================================
# Tautulli for TOS 7 - first-start preparation
#
# This wrapper adds no software and ships no credential. It only prepares the
# data directory before the upstream s6 init (PID 1) starts:
#
#   1) On the very first start it generates a RANDOM admin password with the
#      PBKDF2 parameters Tautulli itself uses (sha256, 600000 rounds, 16-byte
#      salt, 24-byte key) and writes
#        - only the hash into /config/config.ini (the file Tautulli reads),
#        - the plaintext into /config/initial-password.txt (mode 600), which
#          the owner can open from the app data folder in the TOS file manager.
#      Nothing secret is printed to the container log, and the package itself
#      contains no account (review item S6: credentials are generated at
#      install time instead of being baked in).
#   2) It keeps the data directory private (review item S11): umask 077,
#      /config mode 700, 600 for the files that hold credentials or history.
#   3) As soon as the user has set a different password, the plaintext file no
#      longer matches the stored hash and is deleted on the next start.
#
# The upstream /init is still executed as PID 1, so the image's own s6
# supervision, migrations and health behaviour are unchanged.
# ===========================================================================
set -u

CONF=/config/config.ini
PWFILE=/config/initial-password.txt
export HOME=/config
export PATH=/lsiopy/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

umask 077
mkdir -p /config /config/logs /config/cache /config/backups
chmod 700 /config /config/logs /config/cache /config/backups 2>/dev/null || true

# The s6 service manager starts the app with its own umask, so the SQLite file
# would be created 644. Create it here with the right mode first - SQLite opens
# an existing (empty) file and keeps the permissions.
if [ ! -e /config/tautulli.db ]; then
  : > /config/tautulli.db
fi
chmod 600 /config/tautulli.db 2>/dev/null || true

if ! ( : > /config/.write-test ) 2>/dev/null; then
  echo "tautulli: WARNING - /config is not writable by uid $(id -u)" >&2
  echo "tautulli: WARNING - the app data folder must be owned by 1000:1000" >&2
else
  rm -f /config/.write-test
fi

PY=""
for cand in /lsiopy/bin/python3 python3 python; do
  if command -v "$cand" >/dev/null 2>&1; then PY="$cand"; break; fi
done

if [ -z "$PY" ]; then
  echo "tautulli: WARNING - no python3 found, leaving credential setup to upstream" >&2
else
  "$PY" - <<'PYEOF'
import base64
import hashlib
import os
import secrets

CONF = '/config/config.ini'
PW_FILE = '/config/initial-password.txt'
COST = 600000
KEY_LEN = 24
USERNAME = 'tautulli'


def make_hash(password):
    salt = base64.b64encode(os.urandom(16)).decode()
    key = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'),
                              salt.encode('utf-8'), COST, KEY_LEN)
    return 'PBKDF2$sha256$%d$%s$%s' % (COST, salt, base64.b64encode(key).decode())


def check_hash(password, stored):
    try:
        algorithm, hash_function, cost, salt, digest = stored.split('$')
        if algorithm != 'PBKDF2':
            return False
        raw = base64.b64decode(digest.encode())
        calc = hashlib.pbkdf2_hmac(hash_function, password.encode('utf-8'),
                                   salt.encode('utf-8'), int(cost), len(raw))
        return base64.b64encode(calc).decode() == digest
    except Exception:
        return False


def chmod(path, mode):
    try:
        os.chmod(path, mode)
    except OSError:
        pass


def read_plain_password():
    try:
        with open(PW_FILE, encoding='utf-8') as fh:
            for line in fh:
                key, _, value = line.partition(':')
                if key.strip() == 'password':
                    return value.strip()
    except OSError:
        pass
    return ''


def read_stored_hash():
    try:
        with open(CONF, encoding='utf-8') as fh:
            for line in fh:
                if line.strip().startswith('http_password'):
                    return line.split('=', 1)[1].strip()
    except OSError:
        pass
    return ''


def write_first_run():
    password = secrets.token_urlsafe(12)
    # All four sections exist in every Tautulli config since 2015. Writing them
    # (three empty) keeps the file complete so Tautulli does not treat it as a
    # truncated file and copy it aside as "damaged" on the first start.
    with open(CONF, 'w', encoding='utf-8') as fh:
        fh.write('[General]\n')
        fh.write('http_username = %s\n' % USERNAME)
        fh.write('http_password = %s\n' % make_hash(password))
        fh.write('http_hash_password = 1\n')
        fh.write('http_hashed_password = 1\n')
        fh.write('\n[Advanced]\n\n[PMS]\n\n[Monitoring]\n')
    chmod(CONF, 0o600)
    with open(PW_FILE, 'w', encoding='utf-8') as fh:
        fh.write('Tautulli initial admin password\n')
        fh.write('%s: %s\n' % ('username', USERNAME))
        fh.write('%s: %s\n' % ('password', password))
        fh.write('\nChange it after the first login:\n')
        fh.write('Settings > Web Interface > Authentication.\n')
        fh.write('Then delete this file - it is removed automatically on the\n')
        fh.write('next start once the password no longer matches config.ini.\n')
    chmod(PW_FILE, 0o600)
    print('tautulli: first start - generated a random admin password '
          '(config/initial-password.txt, mode 600)')


def main():
    if not os.path.exists(CONF):
        write_first_run()
    elif os.path.exists(PW_FILE):
        plain = read_plain_password()
        stored = read_stored_hash()
        if plain and stored and not check_hash(plain, stored):
            os.remove(PW_FILE)
            print('tautulli: password changed - removed the initial password file')
    for path in (CONF, PW_FILE, '/config/tautulli.db', '/config/tautulli.db-wal',
                 '/config/tautulli.db-shm'):
        if os.path.exists(path):
            chmod(path, 0o600)
    for path in ('/config', '/config/logs', '/config/cache', '/config/backups'):
        if os.path.isdir(path):
            chmod(path, 0o700)


main()
PYEOF
fi

exec /init
