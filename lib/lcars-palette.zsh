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

_lcars_apply_palette() {
    POWERLEVEL9K_LCARS_HOSTID_BACKGROUND="$LCARS_COLORS[sky]"
    POWERLEVEL9K_LCARS_HOSTID_FOREGROUND="$LCARS_COLORS[black]"
    POWERLEVEL9K_LCARS_DIRID_BACKGROUND="$LCARS_COLORS[peach]"
    POWERLEVEL9K_LCARS_DIRID_FOREGROUND="$LCARS_COLORS[black]"
    POWERLEVEL9K_CONTEXT_DEFAULT_BACKGROUND="$LCARS_COLORS[lilac]"
    POWERLEVEL9K_CONTEXT_DEFAULT_FOREGROUND="$LCARS_COLORS[black]"
    POWERLEVEL9K_DIR_BACKGROUND="$LCARS_COLORS[rose]"
    POWERLEVEL9K_DIR_FOREGROUND="$LCARS_COLORS[black]"
    POWERLEVEL9K_VCS_CLEAN_BACKGROUND="$LCARS_COLORS[lilac]"
    POWERLEVEL9K_VCS_CLEAN_FOREGROUND="$LCARS_COLORS[black]"
    POWERLEVEL9K_VCS_MODIFIED_BACKGROUND="$LCARS_COLORS[tan]"
    POWERLEVEL9K_VCS_MODIFIED_FOREGROUND="$LCARS_COLORS[black]"
    POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND="$LCARS_COLORS[lilac]"
    POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND="$LCARS_COLORS[black]"
    POWERLEVEL9K_LCARS_DATE_BACKGROUND="$LCARS_COLORS[pumpkin]"
    POWERLEVEL9K_LCARS_DATE_FOREGROUND="$LCARS_COLORS[black]"
    POWERLEVEL9K_LCARS_ERR_BACKGROUND="$LCARS_COLORS[alert]"
    POWERLEVEL9K_LCARS_ERR_FOREGROUND="$LCARS_COLORS[cream]"
    POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND="$LCARS_COLORS[sky]"
    POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND="$LCARS_COLORS[black]"
}

_lcars_apply_redalert_palette() {
    # Every segment's background goes coffee for "Red Alert" mode. Coffee is
    # dark so foreground switches to cream for legibility.
    local seg
    for seg in LCARS_HOSTID LCARS_DIRID CONTEXT_DEFAULT CONTEXT_SUDO \
               DIR VCS_CLEAN VCS_MODIFIED VCS_UNTRACKED \
               LCARS_DATE LCARS_ERR COMMAND_EXECUTION_TIME; do
        eval "POWERLEVEL9K_${seg}_BACKGROUND=\"$LCARS_COLORS[alert]\""
        eval "POWERLEVEL9K_${seg}_FOREGROUND=\"$LCARS_COLORS[cream]\""
    done
}
