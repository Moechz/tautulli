#!/bin/bash
# ===========================================================================
# Tautulli functional smoke test - core flow, not just "the port answers".
#
# usage:  test/smoke.sh <base-url>
#
#   TAUTULLI_USER            login name (default: the one in initial-password.txt)
#   TAUTULLI_PASSWORD        use this password instead of the auto-discovered one
#   TAUTULLI_PASSWORD_FILE   path of config/initial-password.txt
#   TAUTULLI_DOCKER          docker CLI (default: the TOS DockerEngine path)
#
# What is verified:
#   1. "/" redirects to the login page
#   2. the login page renders with a CSRF token and both form fields
#   3. the first-login credential from config/initial-password.txt is accepted
#      (this is the documented first-run flow; the password is generated at
#      install time and is not shipped in the package)
#   4. the dashboard and the settings page render real HTML
#   5. the JSON API rejects requests that carry no apikey
#   6. a wrong password is rejected (authentication is really enforced)
#
# Exit code: 0 = core flow works, 1 = unusable, 2 = the flow could not be
# verified (e.g. no credential and no docker access). Any non-zero fails the gate.
# ===========================================================================
set -uo pipefail

BASE="${1:-}"
if [ -z "$BASE" ]; then
  echo "usage: $0 <base-url>" >&2
  exit 2
fi
BASE="${BASE%/}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ok()   { echo "  [ OK ] $*"; }
fail() { echo "  [FAIL] $*"; exit 1; }
info() { echo "  [info] $*"; }

http() {  # http <url> <output> <extra curl args...>
  local url="$1" out="$2"; shift 2
  curl -sS -m 15 -o "$out" -w '%{http_code}' "$@" "$url" 2>/dev/null || echo 000
}

# ---------------------------------------------------------------- docker ----
docker_cli() {
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo "docker"; return 0
  fi
  local cli="${TAUTULLI_DOCKER:-/Volume1/@apps/DockerEngine/dockerd/bin/docker}"
  [ -x "$cli" ] || return 1
  if "$cli" info >/dev/null 2>&1; then echo "$cli"; return 0; fi
  if sudo -n "$cli" info >/dev/null 2>&1; then echo "sudo -n $cli"; return 0; fi
  return 1
}
DD="$(docker_cli || true)"

# Find config/initial-password.txt through the container that publishes the
# port we are testing (the same place the user opens in the file manager).
find_password_file() {
  local port="${BASE##*:}"
  port="${port%%/*}"
  [ -n "$DD" ] || return 1
  local line name mounts src
  while IFS= read -r line; do
    name="${line%% *}"
    [ -n "$name" ] || continue
    mounts=$($DD inspect --format '{{range .Mounts}}{{.Source}}{{"\n"}}{{end}}' "$name" 2>/dev/null || true)
    while IFS= read -r src; do
      [ -n "$src" ] || continue
      for cand in "$src/initial-password.txt" "$src/config/initial-password.txt"; do
        if [ -f "$cand" ]; then echo "$cand"; return 0; fi
      done
    done <<< "$mounts"
  done <<< "$($DD ps --format '{{.Names}} {{.Ports}}' 2>/dev/null | grep -F ":$port->" || true)"
  return 1
}

# --------------------------------------------------------------- 1. root ----
code="$(http "$BASE/" "$TMP/root.html")"
case "$code" in
  200|301|302|303) ok "GET / -> HTTP $code" ;;
  *) fail "GET / -> HTTP $code (expected 200/30x)" ;;
esac

# ---------------------------------------------------------- 2. login page ---
code="$(http "$BASE/auth/login" "$TMP/login.html" -c "$TMP/jar0")"
[ "$code" = "200" ] || fail "GET /auth/login -> HTTP $code (expected 200)"
grep -q 'name="username"' "$TMP/login.html" || fail "login page has no username field"
grep -q 'name="password"' "$TMP/login.html" || fail "login page has no password field"
TOKEN="$(grep -o 'name="csrf-token" content="[^"]*"' "$TMP/login.html" \
         | sed 's/.*content="//; s/"$//' | head -1)"
[ -n "$TOKEN" ] || fail "login page has no CSRF token"
ok "GET /auth/login -> 200, login form + CSRF token present"

# ------------------------------------------------------- 3. credentials -----
PWFILE="${TAUTULLI_PASSWORD_FILE:-}"
[ -n "$PWFILE" ] || PWFILE="$(find_password_file || true)"
PASSWORD="${TAUTULLI_PASSWORD:-}"
USERNAME="${TAUTULLI_USER:-}"
if [ -z "$PASSWORD" ] && [ -n "${PWFILE:-}" ] && [ -f "$PWFILE" ]; then
  PASSWORD="$(awk -F': ' '/^password:/{print $2; exit}' "$PWFILE" | tr -d '\r')"
  [ -n "$USERNAME" ] || USERNAME="$(awk -F': ' '/^username:/{print $2; exit}' "$PWFILE" | tr -d '\r')"
  info "first-login credential read from $PWFILE"
fi
[ -n "$USERNAME" ] || USERNAME="tautulli"
if [ -z "$PASSWORD" ]; then
  echo "  [FAIL] no first-login password found: pass TAUTULLI_PASSWORD or" >&2
  echo "         TAUTULLI_PASSWORD_FILE, or run where docker can inspect the" >&2
  echo "         container that publishes this port (config/initial-password.txt)" >&2
  echo "         -- the core flow cannot be verified without it." >&2
  exit 2
fi

# --------------------------------------------------------------- 4. login ---
code="$(http "$BASE/auth/login" "$TMP/login1.html" -c "$TMP/jar1")"
TOKEN="$(grep -o 'name="csrf-token" content="[^"]*"' "$TMP/login1.html" \
         | sed 's/.*content="//; s/"$//' | head -1)"
[ -n "$TOKEN" ] || fail "second login page load returned no CSRF token"
code="$(http "$BASE/auth/signin" "$TMP/signin.json" -b "$TMP/jar1" -c "$TMP/jar1" \
        -H "X-CSRF-Token: $TOKEN" -H 'X-Requested-With: XMLHttpRequest' \
        --data-urlencode "username=$USERNAME" \
        --data-urlencode "password=$PASSWORD" \
        --data-urlencode "remember_me=1" --data-urlencode "admin_login=1")"
if [ "$code" != "200" ] || ! grep -q '"status": *"success"' "$TMP/signin.json"; then
  fail "POST /auth/signin with the generated first-login credential -> HTTP $code $(head -c 160 "$TMP/signin.json")"
fi
ok "POST /auth/signin accepted the generated first-login credential"

# ----------------------------------------------------------- 5. dashboard ---
code="$(http "$BASE/home" "$TMP/home.html" -b "$TMP/jar1")"
[ "$code" = "200" ] || fail "GET /home after login -> HTTP $code (expected 200)"
grep -qi '<title>Tautulli' "$TMP/home.html" || fail "/home is not the Tautulli dashboard"
bytes=$(wc -c < "$TMP/home.html")
[ "$bytes" -ge 5000 ] || fail "/home is only $bytes bytes (empty shell / error page)"
grep -q 'name="password"' "$TMP/home.html" && fail "/home still renders the login form"
ok "GET /home -> 200, $bytes bytes of dashboard HTML"

code="$(http "$BASE/settings" "$TMP/settings.html" -b "$TMP/jar1")"
[ "$code" = "200" ] || fail "GET /settings after login -> HTTP $code (expected 200)"
grep -qi 'Settings' "$TMP/settings.html" || fail "/settings does not render the settings page"
ok "GET /settings -> 200, settings page renders"

# ------------------------------------------------------------- 6. API auth --
code="$(http "$BASE/api/v2?cmd=get_server_info" "$TMP/api.json")"
case "$code" in
  401|403) ok "GET /api/v2 without apikey -> HTTP $code (API is authenticated)" ;;
  *) fail "GET /api/v2 without apikey -> HTTP $code (expected 401/403)" ;;
esac

# --------------------------------------------------- 7. wrong password ------
code="$(http "$BASE/auth/login" "$TMP/login2.html" -c "$TMP/jar2")"
TOKEN="$(grep -o 'name="csrf-token" content="[^"]*"' "$TMP/login2.html" \
         | sed 's/.*content="//; s/"$//' | head -1)"
code="$(http "$BASE/auth/signin" "$TMP/bad.json" -b "$TMP/jar2" \
        -H "X-CSRF-Token: $TOKEN" -H 'X-Requested-With: XMLHttpRequest' \
        --data-urlencode "username=$USERNAME" \
        --data-urlencode "password=smoke-test-not-the-password" \
        --data-urlencode "admin_login=1")"
case "$code" in
  401|429) ok "POST /auth/signin with a wrong password -> HTTP $code (rejected)" ;;
  *) fail "POST /auth/signin with a wrong password -> HTTP $code (authentication is not enforced)" ;;
esac

echo "  [ OK ] Tautulli core flow works: login -> dashboard -> settings, API guarded"
exit 0
