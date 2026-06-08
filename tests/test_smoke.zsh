# tests/test_smoke.zsh — proves the harness can pass and fail.

lcars_assert_eq "hello" "hello" "string equality works"
lcars_assert_neq "a" "b" "string inequality works"
lcars_assert_match "*-LCARS-*" "47-LCARS-348" "glob match works"
