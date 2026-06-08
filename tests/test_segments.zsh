# tests/test_segments.zsh — pure-function tests for LCARS custom segments.

source "${0:A:h}/lib.zsh"
source "${0:A:h}/../lib/lcars-segments.zsh"

# --- hash-to-digits ---
result1="$(_lcars_hash_to_digits 'lcarstui' 4)"
lcars_assert_match '[0-9][0-9][0-9][0-9]' "$result1" "_lcars_hash_to_digits returns 4 digits"

result2="$(_lcars_hash_to_digits 'lcarstui' 4)"
lcars_assert_eq "$result1" "$result2" "_lcars_hash_to_digits is deterministic"

result3="$(_lcars_hash_to_digits 'different-input' 4)"
lcars_assert_neq "$result1" "$result3" "_lcars_hash_to_digits differs for different inputs"

result6="$(_lcars_hash_to_digits 'lcarstui' 6)"
lcars_assert_match '[0-9][0-9][0-9][0-9][0-9][0-9]' "$result6" "_lcars_hash_to_digits respects length"

# --- prompt_lcars_err ---
P9K_CONTENT=""
_p9k_last_exit_status=0
prompt_lcars_err
lcars_assert_eq "" "$P9K_CONTENT" "lcars_err empty when exit status is 0"

P9K_CONTENT=""
_p9k_last_exit_status=127
prompt_lcars_err
lcars_assert_eq "ERR 127" "$P9K_CONTENT" "lcars_err shows ERR + code when nonzero"

P9K_CONTENT=""
_p9k_last_exit_status=1
prompt_lcars_err
lcars_assert_eq "ERR 01" "$P9K_CONTENT" "lcars_err zero-pads single-digit codes"
