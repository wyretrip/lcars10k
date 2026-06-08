# lib/lcars-redalert.zsh — palette swap + auto-engage on consecutive failures.

typeset -gi _LCARS_FAIL_STREAK=0
typeset -gi _LCARS_REDALERT_ACTIVE=0
typeset -gi _LCARS_REDALERT_PINNED=0   # 1 when user manually engaged

_lcars_redalert_engage() {
    _LCARS_REDALERT_ACTIVE=1
    _lcars_apply_redalert_palette
    p10k reload 2>/dev/null
}

_lcars_redalert_disengage() {
    _LCARS_REDALERT_ACTIVE=0
    _lcars_apply_palette
    p10k reload 2>/dev/null
}

# _lcars_redalert_track <last_exit_code>
# Called from precmd. Increments/resets the failure streak and toggles auto-engage.
_lcars_redalert_track() {
    local code=$1
    if (( code == 0 )); then
        _LCARS_FAIL_STREAK=0
        if (( _LCARS_REDALERT_ACTIVE == 1 && _LCARS_REDALERT_PINNED == 0 )); then
            _lcars_redalert_disengage
        fi
    else
        _LCARS_FAIL_STREAK+=1
        if (( _LCARS_FAIL_STREAK >= 3 && ${LCARS_REDALERT_AUTO:-1} == 1 && _LCARS_REDALERT_ACTIVE == 0 )); then
            _lcars_redalert_engage
        fi
    fi
}

_lcars_redalert_precmd() {
    local code=${_p9k_last_exit_status:-$?}
    _lcars_redalert_track "$code"
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _lcars_redalert_precmd

# Public function: lcars-redalert on|off|auto
lcars-redalert() {
    case "${1:-}" in
        on)
            _LCARS_REDALERT_PINNED=1
            _lcars_redalert_engage
            print -P "%F{red}🚨 RED ALERT%f engaged."
            ;;
        off)
            _LCARS_REDALERT_PINNED=0
            _lcars_redalert_disengage
            print -P "%F{green}Stand down.%f Red alert disengaged."
            ;;
        auto)
            if (( ${LCARS_REDALERT_AUTO:-1} == 1 )); then
                LCARS_REDALERT_AUTO=0
                print -P "Auto red alert: %F{yellow}off%f"
            else
                LCARS_REDALERT_AUTO=1
                print -P "Auto red alert: %F{green}on%f"
            fi
            ;;
        *)
            print -u2 "usage: lcars-redalert on|off|auto"
            return 2
            ;;
    esac
}
