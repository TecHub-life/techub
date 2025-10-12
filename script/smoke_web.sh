#!/usr/bin/env bash
set -euo pipefail

# Minimal end-to-end smoke to run INSIDE the web container.
# - Verifies Rails health endpoint
# - Seeds a dummy Profile (offline, no GitHub calls)
# - Captures an OG screenshot via Puppeteer/Chromium

APP_HOST=${APP_HOST:-http://localhost:3000}
SMOKE_LOGIN=${SMOKE_LOGIN:-smoketest}
OUT_PATH=${OUT_PATH:-/rails/tmp/smoke-og.png}
TIMEOUT=${TIMEOUT:-60}

log() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

log "Waiting for web to be ready at ${APP_HOST}/up ..."
deadline=$(( $(date +%s) + TIMEOUT ))
until curl -fsS "${APP_HOST}/up" >/dev/null 2>&1; do
  if [ $(date +%s) -ge $deadline ]; then
    fail "Timed out waiting for ${APP_HOST}/up"
  fi
  sleep 1
done
log "Healthcheck OK"

log "Seeding dummy profile '${SMOKE_LOGIN}' (offline) ..."
ruby -e "require './config/environment'; login = ENV.fetch('SMOKE_LOGIN', 'smoketest').downcase; p = Profile.find_by(login: login); unless p; p = Profile.create!(github_id: 999_001, login: login, name: 'Smoke Test', followers: 0); begin; ProfileCard.create!(profile: p, attack: 70, defense: 60, speed: 80); rescue StandardError; end; end; puts 'Seed profile: ' + p.login + ' (id=' + p.id.to_s + ')'"
log "Seed OK"

URL="${APP_HOST}/cards/${SMOKE_LOGIN}/og"
log "Capturing screenshot: ${URL} -> ${OUT_PATH} ..."
node script/screenshot.js --url "${URL}" --out "${OUT_PATH}" --width 1200 --height 630 --wait 300 || fail "screenshot command failed"

if [ ! -s "${OUT_PATH}" ]; then
  fail "Screenshot missing or empty: ${OUT_PATH}"
fi
log "Screenshot OK: ${OUT_PATH}"

echo
echo "Smoke test: PASS"
echo "  Health:      ${APP_HOST}/up"
echo "  Profile:     ${SMOKE_LOGIN}"
echo "  Screenshot:  ${OUT_PATH}"

