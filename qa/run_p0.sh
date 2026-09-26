#!/usr/bin/env bash
set -uo pipefail

mkdir -p build/qa
failed=0

echo "===== P0 / local database ====="

if [ -f scripts/pglite_test.mjs ]; then
  TMP_QA="$(mktemp -d)"
  trap 'rm -rf "$TMP_QA"' EXIT

  cd "$TMP_QA"
  npm init -y >/dev/null 2>&1
  npm install --no-audit --no-fund @electric-sql/pglite@0.5.8

  cd "$CM_BUILD_DIR"
  NODE_PATH="$TMP_QA/node_modules" node scripts/pglite_test.mjs \
    2>&1 | tee build/qa/pglite.log || failed=1
else
  echo "scripts/pglite_test.mjs não encontrado."
  failed=1
fi

exit "$failed"
