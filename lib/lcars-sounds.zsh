# lib/lcars-sounds.zsh — LCARS sound effects on shell startup, command exit, and
# long-command completion. Off by default.
#
# Playback backend is auto-detected: macOS uses `afplay`; Linux falls back
# through the common players (paplay/pw-play for PulseAudio/PipeWire, ffplay,
# mpv, sox's `play`, then aplay for raw ALSA). Set LCARS_SOUND_PLAYER in
# ~/.lcars10krc to force a specific command. If none is found, playback is a
# silent no-op — sounds are opt-in, so a headless box stays quiet.

# Internal: resolve the playback command once and cache it in _LCARS_SOUND_CMD
# (a zsh array: command + fixed flags). Empty array means "no player available".
_lcars_detect_player() {
    (( $+_LCARS_SOUND_CMD )) && return 0
    typeset -ga _LCARS_SOUND_CMD=()
    # Explicit override wins — split on whitespace so flags can be included.
    if [[ -n "${LCARS_SOUND_PLAYER:-}" ]]; then
        _LCARS_SOUND_CMD=(${=LCARS_SOUND_PLAYER})
        return 0
    fi
    if (( $+commands[afplay] )); then      _LCARS_SOUND_CMD=(afplay)
    elif (( $+commands[paplay] )); then    _LCARS_SOUND_CMD=(paplay)
    elif (( $+commands[pw-play] )); then   _LCARS_SOUND_CMD=(pw-play)
    elif (( $+commands[ffplay] )); then    _LCARS_SOUND_CMD=(ffplay -nodisp -autoexit -loglevel quiet)
    elif (( $+commands[mpv] )); then       _LCARS_SOUND_CMD=(mpv --no-video --really-quiet)
    elif (( $+commands[play] )); then      _LCARS_SOUND_CMD=(play -q)
    elif (( $+commands[aplay] )); then     _LCARS_SOUND_CMD=(aplay -q)
    fi
}

# Internal: play a sound file if sounds are enabled and a backend exists.
_lcars_play() {
    local file="$1"
    [[ -z "$file" ]] && return 0
    [[ "${LCARS_SOUNDS:-0}" != "1" ]] && return 0
    [[ ! -r "$file" ]] && return 0
    _lcars_detect_player
    (( ${#_LCARS_SOUND_CMD} )) || return 0
    "${_LCARS_SOUND_CMD[@]}" "$file" &!
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
