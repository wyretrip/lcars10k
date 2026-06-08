# tests/lib.zsh — tiny Zsh assertion helpers. No external dependencies.

# Counters are global and survive re-sourcing — test files that source lib.zsh
# (e.g. for assertion helpers) should not reset the running tally.
typeset -gi LCARS_TESTS_PASSED=${LCARS_TESTS_PASSED:-0}
typeset -gi LCARS_TESTS_FAILED=${LCARS_TESTS_FAILED:-0}

lcars_assert_eq() {
    local expected="$1" actual="$2" msg="${3:-}"
    if [[ "$expected" == "$actual" ]]; then
        LCARS_TESTS_PASSED+=1
        print -P "  %F{green}✔%f $msg"
    else
        LCARS_TESTS_FAILED+=1
        print -P "  %F{red}✘%f $msg"
        print -P "      %F{yellow}expected:%f $expected"
        print -P "      %F{yellow}actual:%f   $actual"
    fi
}

lcars_assert_neq() {
    local a="$1" b="$2" msg="${3:-}"
    if [[ "$a" != "$b" ]]; then
        LCARS_TESTS_PASSED+=1
        print -P "  %F{green}✔%f $msg"
    else
        LCARS_TESTS_FAILED+=1
        print -P "  %F{red}✘%f $msg ($a == $b but expected ≠)"
    fi
}

lcars_assert_match() {
    local pattern="$1" value="$2" msg="${3:-}"
    if [[ "$value" == ${~pattern} ]]; then
        LCARS_TESTS_PASSED+=1
        print -P "  %F{green}✔%f $msg"
    else
        LCARS_TESTS_FAILED+=1
        print -P "  %F{red}✘%f $msg"
        print -P "      %F{yellow}pattern:%f $pattern"
        print -P "      %F{yellow}value:%f   $value"
    fi
}

lcars_test_summary() {
    local total=$(( LCARS_TESTS_PASSED + LCARS_TESTS_FAILED ))
    print
    print -P "%F{cyan}Tests: $total · passed: $LCARS_TESTS_PASSED · failed: $LCARS_TESTS_FAILED%f"
    return $LCARS_TESTS_FAILED
}
