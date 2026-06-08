#!/usr/bin/env zsh
# tests/run-tests.zsh — discovers and runs every tests/test_*.zsh file.

set -u
SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR/.." || exit 2

source "tests/lib.zsh"

for test_file in tests/test_*.zsh; do
    print -P "%F{cyan}» $test_file%f"
    source "$test_file"
done

lcars_test_summary
exit $?
