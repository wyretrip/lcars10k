# tests/test_quiet.zsh — lcars-quiet / lcars-loud toggle behavior.

source "${0:A:h}/lib.zsh"
source "${0:A:h}/../lib/lcars-quiet.zsh"

LCARS_SOUNDS=1
lcars-quiet
lcars_assert_eq "0" "$LCARS_SOUNDS" "lcars-quiet sets LCARS_SOUNDS=0"

lcars-loud
lcars_assert_eq "1" "$LCARS_SOUNDS" "lcars-loud sets LCARS_SOUNDS=1"

LCARS_SOUNDS=0
lcars-loud
lcars_assert_eq "1" "$LCARS_SOUNDS" "lcars-loud works from already-quiet state"
