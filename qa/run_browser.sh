#!/usr/bin/env bash
set -euo pipefail

mkdir -p build/qa/web-root/app
rm -rf build/qa/web-root/app/*
cp -a build/web/. build/qa/web-root/app/

cat > build/qa/web-server.py <<'PY'
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import os

root = Path("build/qa/web-root").resolve()

class Handler(SimpleHTTPRequestHandler):
    def translate_path(self, path):
        clean = path.split("?", 1)[0].split("#", 1)[0]
        if clean == "/":
            clean = "/app/"
        elif not clean.startswith("/app/"):
            clean = "/app/" + clean.lstrip("/")
        return str(root / clean.lstrip("/"))

    def log_message(self, fmt, *args):
        print(fmt % args)

os.chdir(root)
ThreadingHTTPServer(("127.0.0.1", 4173), Handler).serve_forever()
PY

python3 build/qa/web-server.py >build/qa/web-server.log 2>&1 &
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
npx playwright install --with-deps chromium
npm test
