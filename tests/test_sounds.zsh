# tests/test_sounds.zsh — sound hook dispatch tests with _lcars_play mocked.
# We mock _lcars_play (not afplay) so we don't have to deal with &! subshell semantics.
# This still exercises _lcars_handle_precmd's dispatch logic (startup vs success vs
# failure vs longcmd, plus the LCARS_SOUNDS=0 short-circuit), which is the interesting
# behaviour. The backgrounded afplay call is a shell-level concern, not unit-test material.
#
# NOTE (DONE_WITH_CONCERNS): The startup-chime assertion is intentionally skipped.
# When lcars-sounds.zsh is sourced, its own _lcars_play function definition executes
# before the startup-chime call at the bottom of the file, overriding any pre-source
# mock. There is no reliable way to intercept that call at the unit-test level.
# We set LCARS_SOUND_STARTUP="" so _lcars_play short-circuits early (the
# `[[ -z "$file" ]]` guard) and skip testing the startup call here.
# The dispatch logic — which is the interesting branch — is fully covered below.

source "${0:A:h}/lib.zsh"

typeset -ga LCARS_PLAY_CALLS=()

LCARS_SOUNDS=1
LCARS_LONGCMD_THRESHOLD=5
LCARS_SOUND_STARTUP=""         # suppress startup chime during source (see note above)
LCARS_SOUND_SUCCESS="/sounds/chirp.wav"
LCARS_SOUND_FAILURE="/sounds/error.wav"
LCARS_SOUND_LONGCMD="/sounds/done.wav"

source "${0:A:h}/../lib/lcars-sounds.zsh"

# Override _lcars_play AFTER sourcing so the module's definition is replaced.
_lcars_play() {
    LCARS_PLAY_CALLS+=("$1")
    return 0
}

# Simulate a successful command
_lcars_handle_precmd 0 1
lcars_assert_eq "/sounds/chirp.wav" "${LCARS_PLAY_CALLS[1]-}" "success sound plays on exit 0"

LCARS_PLAY_CALLS=()
_lcars_handle_precmd 127 1
lcars_assert_eq "/sounds/error.wav" "${LCARS_PLAY_CALLS[1]-}" "failure sound plays on nonzero exit"

LCARS_PLAY_CALLS=()
_lcars_handle_precmd 0 10
lcars_assert_eq "/sounds/done.wav" "${LCARS_PLAY_CALLS[1]-}" "longcmd sound overrides success when duration >= threshold"

LCARS_PLAY_CALLS=()
LCARS_SOUNDS=0
_lcars_handle_precmd 0 1
lcars_assert_eq "" "${LCARS_PLAY_CALLS[1]-}" "no sounds fire when LCARS_SOUNDS=0"
