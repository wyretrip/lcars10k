# tests/test_ask.zsh — `lcars` wrapper behavior (no real claude invocation).

source "${0:A:h}/lib.zsh"
source "${0:A:h}/../lib/lcars-ask.zsh"

# Stub the engine call so we can inspect the prompt without spawning python.
typeset -g _LCARS_ASK_CAPTURED=""
_lcars_ask_run() { _LCARS_ASK_CAPTURED="$1"; return 0 }

# 1. All args are joined into a single prompt string.
lcars how do I rebase onto main
lcars_assert_eq "how do I rebase onto main" "$_LCARS_ASK_CAPTURED" \
    "lcars joins all args into one prompt"

# 2. No args → usage line, return code 2.
lcars >/dev/null 2>&1
lcars_assert_eq "2" "$?" "lcars with no args returns 2"

# 3. Palette export copies values out of LCARS_COLORS.
typeset -gA LCARS_COLORS=(
    pumpkin "#F5B86E" peach "#D8C4DE" lilac "#7C74A2"
    sky "#A2A8F0" alert "#60463E" cream "#FFE6D5"
)
unset LCARS_C_PUMPKIN LCARS_C_ALERT
_lcars_ask_export_palette
lcars_assert_eq "#F5B86E" "$LCARS_C_PUMPKIN" \
    "palette export sets LCARS_C_PUMPKIN from LCARS_COLORS"
lcars_assert_eq "#60463E" "$LCARS_C_ALERT" \
    "palette export sets LCARS_C_ALERT from LCARS_COLORS"
