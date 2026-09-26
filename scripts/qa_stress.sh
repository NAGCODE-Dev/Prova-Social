#!/bin/sh
# Manual, bounded repetitions. Requires the same isolated build as qa-full.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"
# Baseline first. A failed baseline stops stress rather than misclassifying it.
(cd qa/browser && npm test -- --project=mobile --grep '^smoke|^P0 privado')
for qa_repeat in 1 2 3; do
  echo "Dart stress repetition $qa_repeat/3"
  flutter test test/attempt_draft_store_test.dart test/attempt_repository_test.dart test/attempt_torture_test.dart --reporter expanded
done
cd qa/browser
# Separate outputs prevent repeat runs from replacing baseline artifacts.
QA_STRESS=1 npm test -- --project=mobile --grep '^torture (reload B|rapid|close page)' --repeat-each=3
