# tests/test_palette.zsh — floating-pill color maps + Red Alert recolor.
#
# Pills are transparent segments whose color is read at render time from the
# _LCARS_PILL_BG / _LCARS_PILL_FG maps. The palette functions are the single
# lever Red Alert pulls, so verify they populate/flip the maps correctly.

source "${0:A:h}/lib.zsh"
source "${0:A:h}/../lib/lcars-palette.zsh"   # defines LCARS_COLORS + the two apply fns

# The maps normally live in config/p10k.zsh; declare them here for the test.
typeset -gA _LCARS_PILL_BG _LCARS_PILL_FG

# --- normal palette ---
_lcars_apply_palette
lcars_assert_eq "$LCARS_COLORS[sky]"     "$_LCARS_PILL_BG[hostid]"  "hostid bg = sky (normal)"
lcars_assert_eq "$LCARS_COLORS[black]"   "$_LCARS_PILL_FG[hostid]"  "hostid fg = black (normal)"
lcars_assert_eq "$LCARS_COLORS[rose]"    "$_LCARS_PILL_BG[dir]"     "dir bg = rose (normal)"
lcars_assert_eq "$LCARS_COLORS[alert]"   "$_LCARS_PILL_BG[err]"     "err bg = alert (normal)"
lcars_assert_eq "$LCARS_COLORS[cream]"   "$_LCARS_PILL_FG[err]"     "err fg = cream (normal)"

# --- red alert: every mapped pill goes coffee + cream ---
_lcars_apply_redalert_palette
local k
for k in hostid dirid date err context dir cmdtime vcs; do
    lcars_assert_eq "$LCARS_COLORS[alert]" "$_LCARS_PILL_BG[$k]" "$k bg = coffee (red alert)"
    lcars_assert_eq "$LCARS_COLORS[cream]" "$_LCARS_PILL_FG[$k]" "$k fg = cream (red alert)"
done

# --- disengage restores the normal palette ---
_lcars_apply_palette
lcars_assert_eq "$LCARS_COLORS[sky]"  "$_LCARS_PILL_BG[hostid]" "hostid bg back to sky after disengage"
lcars_assert_neq "$LCARS_COLORS[alert]" "$_LCARS_PILL_BG[dir]"  "dir no longer coffee after disengage"

lcars_test_summary
