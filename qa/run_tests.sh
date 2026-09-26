#!/usr/bin/env bash
set -uo pipefail

mkdir -p build/qa
failed=0

echo "===== Flutter tests ====="
flutter test --reporter expanded 2>&1 | tee build/qa/flutter-tests.log || failed=1

exit "$failed"
