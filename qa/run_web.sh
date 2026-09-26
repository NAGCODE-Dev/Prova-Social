#!/usr/bin/env bash
set -euo pipefail

mkdir -p build/qa

flutter build web \
  --release \
  --base-href /app/ \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://example.supabase.co}" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-qa-placeholder}" \
  --dart-define=WEB_AUTH_CALLBACK="${WEB_AUTH_CALLBACK:-http://127.0.0.1:4173/app/}"

test -f build/web/index.html
echo "Flutter Web compilado com sucesso."
