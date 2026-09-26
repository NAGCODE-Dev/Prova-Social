#!/usr/bin/env bash
set -euo pipefail

mkdir -p build/qa

python3 -m http.server 4173 \
  --directory build/web \
  >build/qa/web-server.log 2>&1 &

SERVER_PID=$!

cleanup() {
  kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:4173/app/ >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS http://127.0.0.1:4173/app/ >/dev/null

cd qa/browser
npm ci
npx playwright install chromium
npm test
