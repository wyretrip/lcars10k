# lib/lcars-ask.zsh — `lcars`: ask Claude with an animated LCARS readout.
#
# `lcars <words…>` forwards the whole line to `claude -p` and renders a compact
# LCARS readout (bin/lcars10k_ask.py) while the answer streams in.

# Export the live LCARS palette so the Python engine renders in-theme.
# No-op when the palette array isn't loaded (the engine has built-in fallbacks).
_lcars_ask_export_palette() {
    (( ${+LCARS_COLORS} )) || return 0
    export LCARS_C_PUMPKIN="${LCARS_COLORS[pumpkin]}"
    export LCARS_C_PEACH="${LCARS_COLORS[peach]}"
    export LCARS_C_LILAC="${LCARS_COLORS[lilac]}"
    export LCARS_C_SKY="${LCARS_COLORS[sky]}"
    export LCARS_C_ALERT="${LCARS_COLORS[alert]}"
    export LCARS_C_CREAM="${LCARS_COLORS[cream]}"
}

# Indirection point so tests can stub the engine invocation.
_lcars_ask_run() {
    python3 "${_LCARS_ROOT:-$HOME/.lcars10k}/bin/lcars10k_ask.py" "$1"
}

lcars() {
    if (( $# == 0 )); then
        print -P -u2 "%F{208}▌ LCARS 10K ▐%f usage: lcars <prompt…>"
        return 2
    fi
    local prompt="$*"
    _lcars_ask_export_palette
    _lcars_ask_run "$prompt"
}
