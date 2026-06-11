# lib/lcars-palette.zsh — runtime palette swap helpers for Red Alert mode.
#
# Static palette configuration now lives in config/p10k.zsh (symlinked as
# ~/.p10k.zsh by scripts/setup.sh). This file only defines the two functions
# the red-alert module calls to swap between normal and alert palettes at
# runtime. They MUST stay in sync with the colors in config/p10k.zsh.

typeset -gA LCARS_COLORS=(
    pumpkin "#F5B86E"   # amber
    peach   "#D8C4DE"   # lavender
    tan     "#A07A6E"   # terracotta
    lilac   "#7C74A2"   # plum
    sky     "#A2A8F0"   # periwinkle
    alert   "#60463E"   # coffee (dark — use cream fg)
    rose    "#86667A"   # held in reserve
    black   "#000000"
    cream   "#FFE6D5"   # fg for dark (coffee) segments
)

# Pills are now floating: every segment background is TRANSPARENT and each
# pill's color is drawn inside its CONTENT_EXPANSION, which reads the per-pill
# color from the _LCARS_PILL_BG / _LCARS_PILL_FG maps (defined in
# config/p10k.zsh). So the palette swap is just reassigning those maps — never
# the POWERLEVEL9K_*_BACKGROUND vars (setting those would re-paint a solid
# rectangle behind the pill and destroy the float). `vcs` is absent from the
# map on purpose: its color is state-dependent and computed in
# _lcars_vcs_format, which honors _LCARS_REDALERT_ACTIVE directly.
#
# Keep these values in sync with the initial _LCARS_PILL_* in config/p10k.zsh.

_lcars_apply_palette() {
    _LCARS_PILL_BG=(
        hostid  "$LCARS_COLORS[sky]"     dirid   "$LCARS_COLORS[peach]"
        date    "$LCARS_COLORS[pumpkin]" err     "$LCARS_COLORS[alert]"
        context "$LCARS_COLORS[lilac]"   dir     "$LCARS_COLORS[rose]"
        cmdtime "$LCARS_COLORS[sky]"     vcs     "$LCARS_COLORS[lilac]"
    )
    _LCARS_PILL_FG=(
        hostid  "$LCARS_COLORS[black]"   dirid   "$LCARS_COLORS[black]"
        date    "$LCARS_COLORS[black]"   err     "$LCARS_COLORS[cream]"
        context "$LCARS_COLORS[black]"   dir     "$LCARS_COLORS[black]"
        cmdtime "$LCARS_COLORS[black]"   vcs     "$LCARS_COLORS[black]"
    )
}

_lcars_apply_redalert_palette() {
    # Every pill goes coffee with cream text. (vcs follows via
    # _LCARS_REDALERT_ACTIVE inside _lcars_vcs_format.)
    local k
    for k in hostid dirid date err context dir cmdtime vcs; do
        _LCARS_PILL_BG[$k]="$LCARS_COLORS[alert]"
        _LCARS_PILL_FG[$k]="$LCARS_COLORS[cream]"
    done
}
