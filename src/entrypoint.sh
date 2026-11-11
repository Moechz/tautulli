#!/bin/sh
# ===========================================================================
# Tautulli for TOS 7 - first-run wrapper
#
# Tautulli 2.19 generates a random admin password on a fresh install and only
# prints it in /config/logs/tautulli.log, which is not reachable from the TOS
# App Center. This wrapper seeds a known initial admin account (admin /
# tautulli) into /config/config.ini before the upstream s6 init starts, so the
# login page is usable on first visit. The user is expected to change the
# password immediately; on later starts the existing config is left untouched.
#
# The upstream /init is still executed as PID 1, so the image's own s6
# supervision, migrations and health behaviour are unchanged.
# ===========================================================================
set -u

CONF=/config/config.ini
export HOME=/config
export PATH=/lsiopy/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

mkdir -p /config

if [ ! -f "$CONF" ]; then
  echo "tautulli: first start - seeding the initial admin account (admin / tautulli)"
  umask 077
  cat > "$CONF" <<'CFG'
[General]
http_username = admin
http_password = PBKDF2$sha256$600000$jpggqbUVkm9ELAqHiKqN1Q==$S3fhd0YyqjqTIqV2OerSSmryromxooL+
http_hash_password = 1
http_hashed_password = 1
CFG
  chmod 600 "$CONF"
  umask 022
fi

exec /init
