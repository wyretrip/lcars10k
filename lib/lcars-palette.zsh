# lib/lcars-palette.zsh — LCARS Okuda canonical palette.
# Sourced by lcars10k.zsh-theme after p10k init but before user .lcars10krc.

# Color names → hex (24-bit, truecolor terminals required).
typeset -gA LCARS_COLORS=(
    pumpkin "#FF9966"   # primary / context segment
    peach   "#FFCC99"   # secondary / dir
    tan     "#FFCC66"   # tertiary / time
    lilac   "#CC99CC"   # alt / git
    sky     "#99CCFF"   # info / duration
    alert   "#CC6666"   # red-alert mode
    black   "#000000"   # text on light segment
)

_lcars_apply_palette() {
    # Left prompt segments
    POWERLEVEL9K_OS_ICON_BACKGROUND="$LCARS_COLORS[pumpkin]"
    POWERLEVEL9K_OS_ICON_FOREGROUND="$LCARS_COLORS[black]"

    POWERLEVEL9K_CONTEXT_BACKGROUND="$LCARS_COLORS[pumpkin]"
    POWERLEVEL9K_CONTEXT_FOREGROUND="$LCARS_COLORS[black]"
    POWERLEVEL9K_CONTEXT_DEFAULT_BACKGROUND="$LCARS_COLORS[pumpkin]"
    POWERLEVEL9K_CONTEXT_DEFAULT_FOREGROUND="$LCARS_COLORS[black]"

    POWERLEVEL9K_DIR_BACKGROUND="$LCARS_COLORS[peach]"
    POWERLEVEL9K_DIR_FOREGROUND="$LCARS_COLORS[black]"

    POWERLEVEL9K_VCS_CLEAN_BACKGROUND="$LCARS_COLORS[lilac]"
    POWERLEVEL9K_VCS_CLEAN_FOREGROUND="$LCARS_COLORS[black]"
    POWERLEVEL9K_VCS_MODIFIED_BACKGROUND="$LCARS_COLORS[lilac]"
    POWERLEVEL9K_VCS_MODIFIED_FOREGROUND="$LCARS_COLORS[black]"
    POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND="$LCARS_COLORS[lilac]"
    POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND="$LCARS_COLORS[black]"

    # Right prompt segments (we define these in lcars-segments.zsh)
    POWERLEVEL9K_LCARS_DATE_BACKGROUND="$LCARS_COLORS[tan]"
    POWERLEVEL9K_LCARS_DATE_FOREGROUND="$LCARS_COLORS[black]"
    POWERLEVEL9K_LCARS_ERR_BACKGROUND="$LCARS_COLORS[alert]"
    POWERLEVEL9K_LCARS_ERR_FOREGROUND="$LCARS_COLORS[black]"
    POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND="$LCARS_COLORS[sky]"
    POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND="$LCARS_COLORS[black]"

    # Okuda IDs (set in lcars-segments.zsh)
    POWERLEVEL9K_LCARS_HOSTID_BACKGROUND="$LCARS_COLORS[pumpkin]"
    POWERLEVEL9K_LCARS_HOSTID_FOREGROUND="$LCARS_COLORS[black]"
    POWERLEVEL9K_LCARS_DIRID_BACKGROUND="$LCARS_COLORS[peach]"
    POWERLEVEL9K_LCARS_DIRID_FOREGROUND="$LCARS_COLORS[black]"
}

_lcars_apply_redalert_palette() {
    # Override every segment's background with alert red for "Red Alert" mode.
    local seg
    for seg in OS_ICON CONTEXT CONTEXT_DEFAULT DIR \
               VCS_CLEAN VCS_MODIFIED VCS_UNTRACKED \
               LCARS_DATE LCARS_ERR LCARS_HOSTID LCARS_DIRID \
               COMMAND_EXECUTION_TIME; do
        eval "POWERLEVEL9K_${seg}_BACKGROUND=\"$LCARS_COLORS[alert]\""
        eval "POWERLEVEL9K_${seg}_FOREGROUND=\"$LCARS_COLORS[black]\""
    done
}

_lcars_apply_palette
