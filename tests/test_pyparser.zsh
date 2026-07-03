# tests/test_pyparser.zsh — bridge: run the Python engine unit tests and
# assert they pass, so they're covered by `make`/run-tests.zsh too.

source "${0:A:h}/lib.zsh"

if (( ${+commands[python3]} )); then
    local rc
    python3 "${0:A:h}/../bin/test_ask_parser.py" >/dev/null 2>&1
    rc=$?
    lcars_assert_eq "0" "$rc" "python engine unit tests pass"
else
    print -P "  %F{yellow}∼%f python3 not found — skipping engine unit tests"
fi
