#!/usr/bin/env bash
# End-to-end check: every service answers through Nginx and the gateway.
set -euo pipefail

BASE="${BASE:-http://localhost:8080}"
EMAIL="smoke-$RANDOM@example.com"

fail() { echo "FAIL: $1" >&2; exit 1; }

echo "== health =="
curl -fsS "$BASE/healthz" >/dev/null || fail "gateway health"

echo "== register + login =="
curl -fsS -X POST "$BASE/api/v1/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"supersecret\"}" >/dev/null || fail "register"

TOKEN=$(curl -fsS -X POST "$BASE/api/v1/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"supersecret\"}" \
  | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
[ -n "$TOKEN" ] || fail "login returned no token"

curl -fsS "$BASE/api/v1/auth/me" -H "Authorization: Bearer $TOKEN" >/dev/null || fail "me"

echo "== profile =="
curl -fsS -X PUT "$BASE/api/v1/users/profiles/u1" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Smoke Test","currency":"EUR"}' >/dev/null || fail "put profile"
curl -fsS "$BASE/api/v1/users/profiles/u1" >/dev/null || fail "get profile"

echo "== rust services =="
curl -fsS -X POST "$BASE/api/v1/ai/classify" -d 'UBER TRIP 123' >/dev/null || fail "classify"
curl -fsS -X POST "$BASE/api/v1/crypto/digest" -d 'hello' >/dev/null || fail "digest"
curl -fsS "$BASE/api/v1/media/healthz" >/dev/null || fail "media health"

echo "== notifications =="
curl -fsS -X POST "$BASE/api/v1/notifications/send" \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"u1","channel":"push","title":"Hi","body":"There"}' >/dev/null || fail "notify"

echo "all checks passed"
