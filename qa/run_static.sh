#!/usr/bin/env bash
set -uo pipefail

mkdir -p build/qa
failed=0

run() {
  echo
  echo "===== $1 ====="
  shift
  "$@" || failed=1
}

run "Flutter version" flutter --version
run "Dart version" dart --version
run "Dart format" dart format --output=none --set-exit-if-changed lib test tool
run "Flutter analyze" flutter analyze

exit "$failed"
