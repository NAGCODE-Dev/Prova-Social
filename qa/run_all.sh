#!/usr/bin/env bash
set -uo pipefail

mkdir -p build/qa
failed=0

stage() {
  name="$1"
  shift

  echo
  echo "========================================"
  echo " QA: $name"
  echo "========================================"

  "$@" 2>&1 | tee "build/qa/${name}.log"
  code=${PIPESTATUS[0]}

  if [ "$code" -ne 0 ]; then
    echo "FAIL: $name ($code)"
    failed=1
  else
    echo "PASS: $name"
  fi
}

stage static bash qa/run_static.sh
stage flutter-tests bash qa/run_tests.sh
stage p0 bash qa/run_p0.sh
stage web-build bash qa/run_web.sh
stage browser bash qa/run_browser.sh

echo
if [ "$failed" -eq 0 ]; then
  echo "QA FULL: PASS"
else
  echo "QA FULL: FAIL"
fi

exit "$failed"
