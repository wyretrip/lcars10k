# lib/lcars-segments.zsh — custom LCARS-flavored prompt segments.
# p10k calls prompt_<name> to render the <name> segment.

# _lcars_md5_hex <input>
# Portable MD5 hex digest. macOS ships `md5` (digest on stdout); most Linux
# distros ship `md5sum` (digest is the first field). Fall back to `cksum` so
# the IDs still render on minimal systems that have neither.
_lcars_md5_hex() {
    local input="$1"
    if (( $+commands[md5sum] )); then
        printf '%s' "$input" | md5sum | cut -d' ' -f1
    elif (( $+commands[md5] )); then
        printf '%s' "$input" | md5
    else
        # cksum is POSIX; emit its checksum as hex so downstream digit-mapping works.
        printf '%x' "$(printf '%s' "$input" | cksum | cut -d' ' -f1)"
    fi
}

# _lcars_hash_to_digits <input> <length>
# Deterministic numeric ID derived from input. Output is exactly <length> digits.
_lcars_hash_to_digits() {
    local input="$1" length="$2"
    # md5 -> hex -> keep only digits -> pad with the hex chars converted to mod-10
    local hex
    hex=$(_lcars_md5_hex "$input")
    # Build a long digit-only string: digits from hex first, then map a-f → 0-5
    local digits=""
    local i ch
    for (( i = 1; i <= ${#hex}; i++ )); do
        ch="${hex[i]}"
        case "$ch" in
            [0-9]) digits+="$ch" ;;
            [a-f]) digits+=$(( 16#$ch % 10 )) ;;
        esac
    done
    # Take the first <length> chars; md5 hex is 32 chars so this is always long enough.
    print -r -- "${digits:0:$length}"
}

# Helper format: "XX-XXX-XX" style chunks for visual Okuda flavor.
_lcars_format_okuda_id() {
    local digits="$1"
    case ${#digits} in
        4) print -r -- "${digits:0:2}-${digits:2:2}" ;;
        6) print -r -- "${digits:0:2}-${digits:2:3}-${digits:5:1}" ;;
        *) print -r -- "$digits" ;;
    esac
}

prompt_lcars_hostid() {
    p10k segment -t $' LCARS'
}

prompt_lcars_dirid() {
    local id
    id=$(_lcars_hash_to_digits "${PWD}" 4)
    p10k segment -t "$(_lcars_format_okuda_id "$id")"
}

prompt_lcars_date() {
    p10k segment -t "$(date '+%Y-%m-%d %H:%M:%S')"
}

prompt_lcars_err() {
    # Set by p10k before the right-prompt is rendered.
    local code=${_p9k_last_exit_status:-0}
    if (( code == 0 )); then
        P9K_CONTENT=""
        return
    fi
    P9K_CONTENT="ERR $(printf '%02d' "$code")"
}
