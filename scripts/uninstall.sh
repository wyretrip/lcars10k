#!/usr/bin/env bash
# scripts/uninstall.sh — reverse a lcars10k install.
#
# Removes the wiring that scripts/setup.sh put in place:
#
#   ~/.zshrc            — the lcars10k comment + source line
#   ~/.lcars10krc       — removed
#   ~/.p10k.zsh         — symlink removed (only if it points at our config);
#                         ~/.p10k.zsh.pre-lcars10k restored if present
#   ~/Library/Fonts/    — the four "MesloLGS NF LCARS" files (stock MesloLGS NF
#                         and Antonio are left alone)
#   terminal config     — iTerm2 dynamic profile deleted; Ghostty block removed;
#                         Terminal.app gets a manual note (no prior value stored)
#
# Repo-local files (sounds/*.wav, *.zwc) are left untouched — they vanish when
# you delete the repo.
#
# Idempotent. Safe to rerun. macOS only (v1 scope).
#
# Usage:
#   ./scripts/uninstall.sh [--help] [--dry-run] [--yes]

set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LCARS_HOME="$( cd -- "$SCRIPT_DIR/.." &> /dev/null && pwd )"

# ------------------------------------------------------------------------
# Constants — must match scripts/setup.sh
# ------------------------------------------------------------------------
ZSHRC="$HOME/.zshrc"
SOURCE_LINE="source $LCARS_HOME/lcars10k.zsh-theme"
ZSHRC_COMMENT="# lcars10k — LCARS-themed Zsh prompt"
LCARSRC="$HOME/.lcars10krc"
P10KRC="$HOME/.p10k.zsh"
P10K_BACKUP="$HOME/.p10k.zsh.pre-lcars10k"
P10K_SRC="$LCARS_HOME/config/p10k.zsh"
FONTS_DST="$HOME/Library/Fonts"
FONT_DISPLAY_NAME="MesloLGS NF LCARS"
LCARS_FONT_FILES=(
    "MesloLGS NF LCARS Regular.ttf"
    "MesloLGS NF LCARS Bold.ttf"
    "MesloLGS NF LCARS Italic.ttf"
    "MesloLGS NF LCARS Bold Italic.ttf"
)
ITERM_PROFILE="$HOME/Library/Application Support/iTerm2/DynamicProfiles/lcars10k.json"
GHOSTTY_CFG="$HOME/.config/ghostty/config"

_pumpkin=$'\033[38;2;245;184;110m'
_sky=$'\033[38;2;162;168;240m'
_alert=$'\033[38;2;204;102;102m'
_dim=$'\033[2m'
_bold=$'\033[1m'
_reset=$'\033[0m'

# ------------------------------------------------------------------------
# Args
# ------------------------------------------------------------------------
DRY_RUN=0
ASSUME_YES=0

usage() {
    cat <<EOF
${_bold}lcars10k uninstall${_reset}

Reverses what scripts/setup.sh installed.

${_bold}USAGE${_reset}
  $0 [options]

${_bold}OPTIONS${_reset}
  --help       Show this message and exit.
  --dry-run    Print what would happen without changing anything.
  --yes        Skip the confirmation prompt.

${_bold}WHAT IT REMOVES${_reset}
  ~/.zshrc                   lcars10k comment + source line
  ~/.lcars10krc              deleted
  ~/.p10k.zsh                symlink removed; .pre-lcars10k backup restored if any
  ~/Library/Fonts/           "MesloLGS NF LCARS" files only (stock Meslo + Antonio kept)
  iTerm2 / Ghostty config    lcars10k profile / config block removed
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --dry-run) DRY_RUN=1 ;;
        --yes|-y)  ASSUME_YES=1 ;;
        *) echo "${_alert}unknown argument:${_reset} $1" >&2; echo "see --help" >&2; exit 2 ;;
    esac
    shift
done

# ------------------------------------------------------------------------
# Output helpers (match setup.sh)
# ------------------------------------------------------------------------
banner() {
    printf '%s\n' "${_pumpkin}┌────────────────────────────────────────────────────────┐${_reset}"
    printf '%s\n' "${_pumpkin}│${_reset}  ${_bold}LCARS10K${_reset} ${_dim}uninstall${_reset}    ${_sky}${LCARS_HOME}${_reset}"
    printf '%s\n' "${_pumpkin}└────────────────────────────────────────────────────────┘${_reset}"
    if (( DRY_RUN )); then
        printf '%s\n' "${_alert}DRY-RUN${_reset} ${_dim}— no files will be changed${_reset}"
    fi
    echo
}

step() { printf '%s\n' "${_bold}${_sky}▶ ${1}${_reset} ${_bold}${2}${_reset}"; }
ok()   { printf '  %s✓%s %s\n' "$_sky"   "$_reset" "$*"; }
note() { printf '  %s•%s %s\n' "$_dim"   "$_reset" "$*"; }
warn() { printf '  %s!%s %s\n' "$_pumpkin" "$_reset" "$*"; }
do_or_dry() {
    if (( DRY_RUN )); then
        printf '  %s[dry]%s %s\n' "$_dim" "$_reset" "$*"
    else
        "$@"
    fi
}

# ------------------------------------------------------------------------
# Preflight + confirmation
# ------------------------------------------------------------------------
preflight() {
    if [[ "$(uname)" != "Darwin" ]]; then
        echo "${_alert}uninstall.sh: macOS only.${_reset}" >&2
        exit 2
    fi
}

confirm() {
    (( DRY_RUN )) && return 0
    (( ASSUME_YES )) && return 0
    printf '%s' "${_bold}Remove lcars10k wiring from this system?${_reset} [y/N] "
    local reply
    read -r reply
    case "$reply" in
        y|Y|yes|YES) return 0 ;;
        *) echo "aborted."; exit 0 ;;
    esac
}

# Remove specific full lines from a file via a temp copy. Args: file, then
# one or more exact line strings to drop.
_strip_lines() {
    local file="$1"; shift
    [[ -f "$file" ]] || return 0
    local tmp
    tmp="$(mktemp)"
    local keep line drop
    while IFS= read -r line || [[ -n "$line" ]]; do
        keep=1
        for drop in "$@"; do
            [[ "$line" == "$drop" ]] && keep=0 && break
        done
        (( keep )) && printf '%s\n' "$line"
    done < "$file" > "$tmp"
    mv "$tmp" "$file"
}

# ------------------------------------------------------------------------
# Step 1: ~/.zshrc
# ------------------------------------------------------------------------
step_zshrc() {
    step "1/5" "Unwire ~/.zshrc"
    if [[ ! -f "$ZSHRC" ]]; then
        ok "no ~/.zshrc — nothing to do"
        return
    fi
    if ! grep -Fq "$SOURCE_LINE" "$ZSHRC" 2>/dev/null; then
        ok "no lcars10k source line present"
        return
    fi
    do_or_dry _strip_lines "$ZSHRC" "$SOURCE_LINE" "$ZSHRC_COMMENT"
    ok "removed lcars10k source line from ~/.zshrc"
}

# ------------------------------------------------------------------------
# Step 2: ~/.lcars10krc
# ------------------------------------------------------------------------
step_rc() {
    step "2/5" "Remove ~/.lcars10krc"
    if [[ -f "$LCARSRC" ]]; then
        do_or_dry rm -f "$LCARSRC"
        ok "removed ~/.lcars10krc"
    else
        ok "already removed"
    fi
}

# ------------------------------------------------------------------------
# Step 3: ~/.p10k.zsh
# ------------------------------------------------------------------------
step_p10k() {
    step "3/5" "Restore ~/.p10k.zsh"
    if [[ -L "$P10KRC" && "$(readlink "$P10KRC")" == "$P10K_SRC" ]]; then
        do_or_dry rm -f "$P10KRC"
        ok "removed lcars10k ~/.p10k.zsh symlink"
        if [[ -e "$P10K_BACKUP" ]]; then
            do_or_dry mv "$P10K_BACKUP" "$P10KRC"
            ok "restored ~/.p10k.zsh from ~/.p10k.zsh.pre-lcars10k"
        fi
    elif [[ -e "$P10KRC" ]]; then
        warn "~/.p10k.zsh exists but is not our symlink — leaving it untouched"
    else
        ok "no ~/.p10k.zsh — nothing to do"
    fi
}

# ------------------------------------------------------------------------
# Step 4: Fonts (LCARS variant only)
# ------------------------------------------------------------------------
step_fonts() {
    step "4/5" "Remove MesloLGS NF LCARS fonts"
    local removed=0 f
    for f in "${LCARS_FONT_FILES[@]}"; do
        if [[ -f "$FONTS_DST/$f" ]]; then
            do_or_dry rm -f "$FONTS_DST/$f"
            removed=$((removed + 1))
        fi
    done
    if (( removed > 0 )); then
        ok "removed $removed LCARS font file(s)"
    else
        ok "no LCARS fonts present"
    fi
    note "stock ${_sky}MesloLGS NF${_reset} and ${_sky}Antonio${_reset} left in place"
}

# ------------------------------------------------------------------------
# Step 5: Terminal config
# ------------------------------------------------------------------------
step_terminal() {
    step "5/5" "Terminal config"
    # iTerm2 dynamic profile
    if [[ -f "$ITERM_PROFILE" ]]; then
        do_or_dry rm -f "$ITERM_PROFILE"
        ok "removed iTerm2 dynamic profile"
    else
        ok "no iTerm2 lcars10k profile"
    fi
    # Ghostty config block
    if [[ -f "$GHOSTTY_CFG" ]] && grep -Fq "font-family = $FONT_DISPLAY_NAME" "$GHOSTTY_CFG" 2>/dev/null; then
        do_or_dry _strip_lines "$GHOSTTY_CFG" \
            "# lcars10k" \
            "font-family = $FONT_DISPLAY_NAME" \
            "font-size = 13"
        ok "removed lcars10k block from Ghostty config"
    else
        ok "no Ghostty lcars10k block"
    fi
    note "Terminal.app font can't be auto-reverted — set it back manually if needed"
    note "  Terminal → Settings → Profiles → Basic → Font"
}

show_summary() {
    echo
    printf '%s\n' "${_pumpkin}┌────────────────────────────────────────────────────────┐${_reset}"
    printf '%s\n' "${_pumpkin}│${_reset}  ${_bold}UNINSTALL COMPLETE${_reset}"
    printf '%s\n' "${_pumpkin}└────────────────────────────────────────────────────────┘${_reset}"
    cat <<EOF

Open a new terminal (or run ${_sky}exec zsh${_reset}) for the change to take effect.
The lcars10k repo itself is untouched — delete it to finish removing lcars10k.
EOF
}

# ------------------------------------------------------------------------
# Run
# ------------------------------------------------------------------------
banner
preflight
confirm
step_zshrc
step_rc
step_p10k
step_fonts
step_terminal
show_summary
