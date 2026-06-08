# lib/lcars-sounds.zsh — LCARS sound effects on shell startup, command exit, and
# long-command completion. macOS-only (afplay backend). Off by default.

# Internal: play a sound file if sounds are enabled.
_lcars_play() {
    local file="$1"
    [[ -z "$file" ]] && return 0
    [[ "${LCARS_SOUNDS:-0}" != "1" ]] && return 0
    [[ ! -r "$file" ]] && return 0
    afplay "$file"
}

# Internal: handle the precmd dispatch. Pure function for testability.
# Args: $1 = last exit code, $2 = last command duration (seconds, integer)
_lcars_handle_precmd() {
    local code=$1 duration=$2
    [[ "${LCARS_SOUNDS:-0}" != "1" ]] && return 0
    if (( duration >= ${LCARS_LONGCMD_THRESHOLD:-5} )); then
        _lcars_play "$LCARS_SOUND_LONGCMD"
    elif (( code == 0 )); then
        _lcars_play "$LCARS_SOUND_SUCCESS"
    else
        _lcars_play "$LCARS_SOUND_FAILURE"
    fi
}

# Internal: precmd entry point. Reads p10k's recorded state.
_lcars_sounds_precmd() {
    local code=${_p9k_last_exit_status:-$?}
    local duration=${P9K_COMMAND_DURATION_SECONDS:-0}
    # Round duration to integer
    duration=${duration%.*}
    duration=${duration:-0}
    _lcars_handle_precmd "$code" "$duration"
}

# Wire precmd hook (idempotent — add-zsh-hook dedupes)
autoload -Uz add-zsh-hook
add-zsh-hook precmd _lcars_sounds_precmd

# Startup chime fires once when this file is sourced.
_lcars_play "${LCARS_SOUND_STARTUP:-}"
