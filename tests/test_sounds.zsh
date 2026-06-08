# tests/test_sounds.zsh — sound hook dispatch tests with afplay mocked.

source "${0:A:h}/lib.zsh"

# Mock afplay before sourcing lcars-sounds.zsh so the module picks up the mock.
typeset -ga LCARS_AFPLAY_CALLS=()
afplay() {
    LCARS_AFPLAY_CALLS+=("$@")
    return 0
}

# Configure paths and enable sounds (real empty tempfiles so _lcars_play's readability check passes)
LCARS_SOUNDS=1
LCARS_LONGCMD_THRESHOLD=5
LCARS_SOUND_STARTUP="$(mktemp -t lcars-boot).wav";   : > "$LCARS_SOUND_STARTUP"
LCARS_SOUND_SUCCESS="$(mktemp -t lcars-chirp).wav";  : > "$LCARS_SOUND_SUCCESS"
LCARS_SOUND_FAILURE="$(mktemp -t lcars-error).wav";  : > "$LCARS_SOUND_FAILURE"
LCARS_SOUND_LONGCMD="$(mktemp -t lcars-done).wav";   : > "$LCARS_SOUND_LONGCMD"

source "${0:A:h}/../lib/lcars-sounds.zsh"

# Startup chime should have been called once when the module was sourced
lcars_assert_match "*lcars-boot*" "${LCARS_AFPLAY_CALLS[1]}" "startup chime plays at module load"

# Reset for next assertions
LCARS_AFPLAY_CALLS=()

# Simulate a successful command
_lcars_handle_precmd 0 1
lcars_assert_match "*lcars-chirp*" "${LCARS_AFPLAY_CALLS[1]}" "success sound plays on exit 0"

LCARS_AFPLAY_CALLS=()
_lcars_handle_precmd 127 1
lcars_assert_match "*lcars-error*" "${LCARS_AFPLAY_CALLS[1]}" "failure sound plays on nonzero exit"

LCARS_AFPLAY_CALLS=()
_lcars_handle_precmd 0 10
lcars_assert_match "*lcars-done*" "${LCARS_AFPLAY_CALLS[1]}" "longcmd sound overrides success when duration >= threshold"

LCARS_AFPLAY_CALLS=()
LCARS_SOUNDS=0
_lcars_handle_precmd 0 1
lcars_assert_eq "" "${LCARS_AFPLAY_CALLS[1]-}" "no sounds fire when LCARS_SOUNDS=0"

# Clean up temp files
rm -f "$LCARS_SOUND_STARTUP" "$LCARS_SOUND_SUCCESS" "$LCARS_SOUND_FAILURE" "$LCARS_SOUND_LONGCMD"
