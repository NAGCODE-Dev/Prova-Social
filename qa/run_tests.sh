#!/usr/bin/env bash
set -uo pipefail

mkdir -p build/qa
failed=0

echo "===== Flutter tests ====="
if [[ -n "${FLUTTER_TEST_FILE:-}" ]]; then
  test_args=(--reporter expanded --concurrency=1 --timeout=90s)
  if [[ -n "${FLUTTER_TEST_NAME:-}" ]]; then
    test_args+=(--plain-name "$FLUTTER_TEST_NAME")
  fi
  flutter test "${test_args[@]}" "$FLUTTER_TEST_FILE" 2>&1 \
    | tee build/qa/flutter-tests.log || failed=1
else
  flutter test --reporter expanded --concurrency=1 --timeout=90s 2>&1 \
    | tee build/qa/flutter-tests.log || failed=1
fi

exit "$failed"
