# tests/test_redalert.zsh — fail-streak counter and on/off semantics.

source "${0:A:h}/lib.zsh"

# Stub the p10k reload to avoid touching the real prompt during tests.
p10k() { return 0; }

source "${0:A:h}/../lib/lcars-palette.zsh"
source "${0:A:h}/../lib/lcars-redalert.zsh"

LCARS_REDALERT_AUTO=1
_LCARS_FAIL_STREAK=0
_LCARS_REDALERT_ACTIVE=0

# 2 failures — no auto-engage yet
_lcars_redalert_track 1
_lcars_redalert_track 1
lcars_assert_eq "2" "$_LCARS_FAIL_STREAK" "fail streak counts to 2"
lcars_assert_eq "0" "$_LCARS_REDALERT_ACTIVE" "red alert not engaged at 2 failures"

# 3rd failure — auto-engage
_lcars_redalert_track 1
lcars_assert_eq "3" "$_LCARS_FAIL_STREAK" "fail streak reaches 3"
lcars_assert_eq "1" "$_LCARS_REDALERT_ACTIVE" "red alert auto-engages at 3 failures"

# Success — counter resets and red alert disengages (unless pinned)
_lcars_redalert_track 0
lcars_assert_eq "0" "$_LCARS_FAIL_STREAK" "fail streak resets on success"
lcars_assert_eq "0" "$_LCARS_REDALERT_ACTIVE" "red alert auto-disengages on success"

# Manual on stays on regardless of subsequent successes
lcars-redalert on
lcars_assert_eq "1" "$_LCARS_REDALERT_ACTIVE" "manual lcars-redalert on engages"

_lcars_redalert_track 0
lcars_assert_eq "1" "$_LCARS_REDALERT_ACTIVE" "success does not clear manual red alert"

lcars-redalert off
lcars_assert_eq "0" "$_LCARS_REDALERT_ACTIVE" "manual lcars-redalert off disengages"
