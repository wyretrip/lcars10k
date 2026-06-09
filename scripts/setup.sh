#!/usr/bin/env bash
# scripts/setup.sh — one-shot lcars10k installer.
#
# Wires every piece of lcars10k into place so a fresh shell shows the
# full LCARS prompt with no further configuration:
#
#   Step 1  — source line in ~/.zshrc
#   Step 2  — ~/.lcars10krc from the bundled template (with LCARS_HOME
#             auto-pointed at this repo's location)
#   Step 3  — ~/.p10k.zsh symlinked to lcars10k's config (your wizard
#             config is backed up to ~/.p10k.zsh.pre-lcars10k)
#   Step 4  — fonts (MesloLGS NF + Antonio) installed to ~/Library/Fonts
#   Step 5  — TNG sound samples fetched into sounds/ (off by default;
#             enable with LCARS_SOUNDS=1 in ~/.lcars10krc)
#   Step 6  — terminal profile / font config for iTerm2, Terminal.app,
#             Ghostty, or fallback instructions for others
#
# Idempotent. Safe to rerun any time. macOS only (v1 scope).
#
# Usage:
#   ./scripts/setup.sh [--help] [--dry-run] [--force]
#                      [--skip-fonts] [--skip-sounds] [--skip-terminal]

set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LCARS_HOME="$( cd -- "$SCRIPT_DIR/.." &> /dev/null && pwd )"

# ------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------
ZSHRC="$HOME/.zshrc"
SOURCE_LINE="source $LCARS_HOME/lcars10k.zsh-theme"
LCARSRC="$HOME/.lcars10krc"
LCARSRC_TEMPLATE="$LCARS_HOME/config/lcars10krc.template"
P10KRC="$HOME/.p10k.zsh"
P10K_BACKUP="$HOME/.p10k.zsh.pre-lcars10k"
P10K_SRC="$LCARS_HOME/config/p10k.zsh"
FONT_PS_NAME="MesloLGSNF-Regular"
FONT_DISPLAY_NAME="MesloLGS NF"
FONT_SIZE=13

# Truecolor escape — iTerm2/Ghostty/modern Terminal.app support this.
# 8-bit and basic terminals get bold-only formatting instead.
_pumpkin=$'\033[38;2;245;184;110m'   # amber  #F5B86E
_peach=$'\033[38;2;216;196;222m'     # lavender #D8C4DE
_sky=$'\033[38;2;162;168;240m'       # periwinkle #A2A8F0
_lilac=$'\033[38;2;124;116;162m'     # plum  #7C74A2
_rose=$'\033[38;2;134;102;122m'      # rose #86667A
_alert=$'\033[38;2;204;102;102m'     # bright red — visible alert (not coffee)
_dim=$'\033[2m'
_bold=$'\033[1m'
_reset=$'\033[0m'

# ------------------------------------------------------------------------
# Args
# ------------------------------------------------------------------------
DRY_RUN=0
FORCE=0
SKIP_FONTS=0
SKIP_SOUNDS=0
SKIP_TERMINAL=0

usage() {
    cat <<EOF
${_bold}lcars10k setup${_reset}

Wires lcars10k into your shell so a fresh terminal shows the LCARS prompt.

${_bold}USAGE${_reset}
  $0 [options]

${_bold}OPTIONS${_reset}
  --help             Show this message and exit.
  --dry-run          Print what would happen without changing anything.
  --force            Overwrite existing files instead of preserving them
                     (useful for re-running after edits).
  --skip-fonts       Don't run install-fonts.sh.
  --skip-sounds      Don't run install-sounds.sh.
  --skip-terminal    Don't write a terminal profile.

${_bold}WHAT IT TOUCHES${_reset}
  ~/.zshrc                       source line appended
  ~/.lcars10krc                  written from template (LCARS_HOME patched)
  ~/.p10k.zsh                    symlink to config/p10k.zsh (backup preserved)
  ~/Library/Fonts/               MesloLGS NF + Antonio copied in
  ./sounds/*.wav                 TNG audio fetched (~200KB total)
  iTerm2/Terminal/Ghostty conf   LCARS profile or font setting written
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --dry-run) DRY_RUN=1 ;;
        --force) FORCE=1 ;;
        --skip-fonts) SKIP_FONTS=1 ;;
        --skip-sounds) SKIP_SOUNDS=1 ;;
        --skip-terminal) SKIP_TERMINAL=1 ;;
        *) echo "${_alert}unknown argument:${_reset} $1" >&2; echo "see --help" >&2; exit 2 ;;
    esac
    shift
done

# ------------------------------------------------------------------------
# Output helpers
# ------------------------------------------------------------------------
banner() {
    printf '%s\n' "${_pumpkin}┌────────────────────────────────────────────────────────┐${_reset}"
    printf '%s\n' "${_pumpkin}│${_reset}  ${_bold}LCARS10K${_reset} ${_dim}setup${_reset}    ${_sky}${LCARS_HOME}${_reset}"
    printf '%s\n' "${_pumpkin}└────────────────────────────────────────────────────────┘${_reset}"
    if (( DRY_RUN )); then
        printf '%s\n' "${_alert}DRY-RUN${_reset} ${_dim}— no files will be changed${_reset}"
    fi
    echo
}

step() {  # step "1/6" "Title here"
    printf '%s\n' "${_bold}${_sky}▶ ${1}${_reset} ${_bold}${2}${_reset}"
}

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
# Preflight
# ------------------------------------------------------------------------
preflight() {
    if [[ "$(uname)" != "Darwin" ]]; then
        echo "${_alert}setup.sh: macOS only.${_reset} Linux/WSL is a v2 roadmap item." >&2
        exit 2
    fi
    if [[ ! -f "$P10K_SRC" ]]; then
        echo "${_alert}config/p10k.zsh missing at $P10K_SRC${_reset}" >&2
        echo "repo incomplete or wrong location" >&2
        exit 2
    fi
    if [[ ! -f "$LCARSRC_TEMPLATE" ]]; then
        echo "${_alert}config template missing at $LCARSRC_TEMPLATE${_reset}" >&2
        exit 2
    fi
    if ! command -v zsh >/dev/null 2>&1; then
        echo "${_alert}zsh not found in PATH${_reset}" >&2
        exit 2
    fi
}

# ------------------------------------------------------------------------
# Step 1: zshrc source line
# ------------------------------------------------------------------------
step_zshrc() {
    step "1/6" "Wire ~/.zshrc"
    if [[ ! -e "$ZSHRC" ]]; then
        do_or_dry touch "$ZSHRC"
    fi
    if grep -Fq "$SOURCE_LINE" "$ZSHRC" 2>/dev/null; then
        ok "already sources lcars10k"
    else
        do_or_dry bash -c "{
            echo ''
            echo '# lcars10k — LCARS-themed Zsh prompt'
            echo '$SOURCE_LINE'
        } >> '$ZSHRC'"
        ok "appended source line"
    fi
}

# ------------------------------------------------------------------------
# Step 2: ~/.lcars10krc
# ------------------------------------------------------------------------
step_rc() {
    step "2/6" "Configure ~/.lcars10krc"
    if [[ -f "$LCARSRC" && $FORCE -eq 0 ]]; then
        ok "exists (use --force to overwrite)"
        return
    fi
    do_or_dry cp "$LCARSRC_TEMPLATE" "$LCARSRC"
    # Patch LCARS_HOME to point at this repo
    if (( DRY_RUN == 0 )); then
        sed -i.bak "s|^export LCARS_HOME=.*|export LCARS_HOME=\"$LCARS_HOME\"|" "$LCARSRC"
        rm -f "$LCARSRC.bak"
    fi
    ok "wrote ~/.lcars10krc (LCARS_HOME → ${_sky}$LCARS_HOME${_reset})"
    note "edit it to enable sounds (LCARS_SOUNDS=1) or tune thresholds"
}

# ------------------------------------------------------------------------
# Step 3: ~/.p10k.zsh
# ------------------------------------------------------------------------
step_p10k() {
    step "3/6" "Install lcars10k p10k config as ~/.p10k.zsh"
    if [[ -L "$P10KRC" && "$(readlink "$P10KRC")" == "$P10K_SRC" ]]; then
        ok "already symlinked to config/p10k.zsh"
        return
    fi
    if [[ -e "$P10KRC" ]]; then
        if [[ -e "$P10K_BACKUP" ]]; then
            do_or_dry rm -f "$P10KRC"
            note "removed existing ~/.p10k.zsh (backup at ~/.p10k.zsh.pre-lcars10k preserved)"
        else
            do_or_dry mv "$P10KRC" "$P10K_BACKUP"
            ok "backed up your existing ~/.p10k.zsh → ~/.p10k.zsh.pre-lcars10k"
        fi
    fi
    do_or_dry ln -s "$P10K_SRC" "$P10KRC"
    ok "symlinked ~/.p10k.zsh → ${_sky}$P10K_SRC${_reset}"
}

# ------------------------------------------------------------------------
# Step 4: Fonts
# ------------------------------------------------------------------------
step_fonts() {
    step "4/6" "Fonts"
    if (( SKIP_FONTS )); then
        note "skipped (--skip-fonts)"
        return
    fi
    local installer="$LCARS_HOME/scripts/install-fonts.sh"
    if [[ ! -x "$installer" ]]; then
        warn "install-fonts.sh not executable; skipping"
        return
    fi
    if [[ -f "$HOME/Library/Fonts/MesloLGS NF Regular.ttf" && $FORCE -eq 0 ]]; then
        ok "MesloLGS NF already in ~/Library/Fonts (use --force to reinstall)"
        return
    fi
    if (( DRY_RUN )); then
        note "would run: $installer"
        return
    fi
    "$installer" 2>&1 | sed 's/^/    /'
    ok "fonts installed"
    note "set your terminal font to ${_sky}MesloLGS NF${_reset} (handled in Step 6 for supported terminals)"
}

# ------------------------------------------------------------------------
# Step 5: Sounds
# ------------------------------------------------------------------------
step_sounds() {
    step "5/6" "Sounds (TNG audio samples)"
    if (( SKIP_SOUNDS )); then
        note "skipped (--skip-sounds)"
        return
    fi
    local installer="$LCARS_HOME/scripts/install-sounds.sh"
    if [[ ! -x "$installer" ]]; then
        warn "install-sounds.sh not executable; skipping"
        return
    fi
    if ! command -v sox >/dev/null 2>&1; then
        warn "sox not installed — sounds will be raw MP3 (still playable, but not normalised)"
        note "to normalise: ${_sky}brew install sox${_reset} then rerun this setup with --force"
    fi
    local have_sounds=0
    if compgen -G "$LCARS_HOME/sounds/*.wav" > /dev/null; then
        have_sounds=1
    fi
    if (( have_sounds == 1 && FORCE == 0 )); then
        ok "sound samples already present in sounds/ (use --force to redownload)"
        note "sounds are ${_bold}off${_reset} by default; enable with LCARS_SOUNDS=1 in ~/.lcars10krc"
        return
    fi
    if (( DRY_RUN )); then
        note "would run: $installer$( (( FORCE )) && echo ' --force' )"
        return
    fi
    if (( FORCE )); then
        "$installer" --force 2>&1 | sed 's/^/    /'
    else
        "$installer" 2>&1 | sed 's/^/    /'
    fi
    ok "sounds installed"
    note "sounds are ${_bold}off${_reset} by default; enable with LCARS_SOUNDS=1 in ~/.lcars10krc"
}

# ------------------------------------------------------------------------
# Step 6: Terminal profile / font
# ------------------------------------------------------------------------
step_terminal() {
    step "6/6" "Terminal profile / font"
    if (( SKIP_TERMINAL )); then
        note "skipped (--skip-terminal)"
        return
    fi
    case "${TERM_PROGRAM:-unknown}" in
        iTerm.app)        configure_iterm2 ;;
        Apple_Terminal)   configure_terminalapp ;;
        ghostty)          configure_ghostty ;;
        WarpTerminal)     note "Warp font has to be set in the GUI:" ;
                          note "  Warp → Settings → Appearance → Text → Font: ${_sky}$FONT_DISPLAY_NAME${_reset}" ;;
        vscode)           note "VS Code integrated terminal — set in Settings:" ;
                          note "  cmd-, then search 'terminal.integrated.fontFamily'" ;
                          note "  Set to: ${_sky}$FONT_DISPLAY_NAME${_reset}" ;;
        *)                warn "unrecognised \$TERM_PROGRAM (${TERM_PROGRAM:-unset})" ;
                          note "set your terminal font manually to: ${_sky}$FONT_DISPLAY_NAME${_reset} size ~$FONT_SIZE" ;;
    esac
}

configure_iterm2() {
    local profiles_dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
    local profile_file="$profiles_dir/lcars10k.json"
    if (( DRY_RUN == 0 )); then
        mkdir -p "$profiles_dir"
        cat > "$profile_file" <<JSON
{
  "Profiles": [
    {
      "Name": "LCARS",
      "Guid": "lcars10k-dynamic-profile",
      "Dynamic Profile Parent Name": "Default",
      "Normal Font": "$FONT_PS_NAME $FONT_SIZE",
      "Non Ascii Font": "$FONT_PS_NAME $FONT_SIZE",
      "Use Non-ASCII Font": true,
      "Background Color":        {"Red Component": 0,    "Green Component": 0,    "Blue Component": 0},
      "Foreground Color":        {"Red Component": 1.0,  "Green Component": 0.9,  "Blue Component": 0.83},
      "Ansi 1 Color":            {"Red Component": 0.8,  "Green Component": 0.4,  "Blue Component": 0.4},
      "Ansi 3 Color":            {"Red Component": 0.96, "Green Component": 0.72, "Blue Component": 0.43},
      "Ansi 4 Color":            {"Red Component": 0.64, "Green Component": 0.66, "Blue Component": 0.94},
      "Ansi 5 Color":            {"Red Component": 0.49, "Green Component": 0.45, "Blue Component": 0.64},
      "Ansi 6 Color":            {"Red Component": 0.85, "Green Component": 0.77, "Blue Component": 0.87},
      "Ansi 7 Color":            {"Red Component": 1.0,  "Green Component": 0.9,  "Blue Component": 0.83}
    }
  ]
}
JSON
    fi
    ok "wrote iTerm2 dynamic profile: ${_sky}$profile_file${_reset}"
    note "iTerm2 → Settings → Profiles → ${_bold}LCARS${_reset} → Other Actions → Set as Default"
    note "or cmd-i in any tab and pick ${_bold}LCARS${_reset}"
}

configure_terminalapp() {
    if (( DRY_RUN )); then
        note "would osascript Terminal.app font to $FONT_DISPLAY_NAME $FONT_SIZE"
        return
    fi
    if osascript >/dev/null 2>&1 <<APPLESCRIPT
tell application "Terminal"
    set font name of settings set "Basic" to "$FONT_DISPLAY_NAME"
    set font size of settings set "Basic" to $FONT_SIZE
end tell
APPLESCRIPT
    then
        ok "set Terminal.app 'Basic' font → ${_sky}$FONT_DISPLAY_NAME $FONT_SIZE${_reset}"
        note "open a new Terminal window to see it"
    else
        warn "AppleScript font-set failed; set manually:"
        note "  Terminal → Settings → Profiles → Basic → Font: ${_sky}$FONT_DISPLAY_NAME${_reset}"
    fi
}

configure_ghostty() {
    local ghostty_cfg="$HOME/.config/ghostty/config"
    if (( DRY_RUN == 0 )); then
        mkdir -p "$(dirname "$ghostty_cfg")"
        touch "$ghostty_cfg"
    fi
    if grep -Fq "font-family = $FONT_DISPLAY_NAME" "$ghostty_cfg" 2>/dev/null; then
        ok "Ghostty config already has font-family = $FONT_DISPLAY_NAME"
        return
    fi
    if (( DRY_RUN == 0 )); then
        {
            echo ""
            echo "# lcars10k"
            echo "font-family = $FONT_DISPLAY_NAME"
            echo "font-size = $FONT_SIZE"
        } >> "$ghostty_cfg"
    fi
    ok "appended font config to ${_sky}$ghostty_cfg${_reset}"
    note "restart Ghostty (or cmd-shift-comma → Reload Configuration) to apply"
}

# ------------------------------------------------------------------------
# Closing summary
# ------------------------------------------------------------------------
show_summary() {
    echo
    printf '%s\n' "${_pumpkin}┌────────────────────────────────────────────────────────┐${_reset}"
    printf '%s\n' "${_pumpkin}│${_reset}  ${_bold}SETUP COMPLETE${_reset}"
    printf '%s\n' "${_pumpkin}└────────────────────────────────────────────────────────┘${_reset}"
    cat <<EOF

Open a new ${_bold}iTerm2${_reset} tab on the ${_bold}LCARS${_reset} profile, or run ${_sky}exec zsh${_reset}.

${_bold}Session commands${_reset}
  ${_sky}lcars-loud${_reset}              enable sound effects for this session
  ${_sky}lcars-quiet${_reset}             silence sound effects for this session
  ${_sky}lcars-redalert on${_reset}       force red-alert palette
  ${_sky}lcars-redalert off${_reset}      stand down
  ${_sky}lcars-redalert auto${_reset}     toggle auto-engage on 3 consecutive fails

${_bold}Persistent config${_reset} (edit ~/.lcars10krc)
  LCARS_SOUNDS=1           enable sounds every session
  LCARS_LONGCMD_THRESHOLD  seconds before the long-cmd beep fires (default 5)
  LCARS_REDALERT_AUTO      0 to disable auto-engage entirely
  LCARS_NUMERIC_IDS        0 to hide the LCARS / dirid pills

${_dim}Rollback:${_reset} delete ~/.p10k.zsh symlink and move ~/.p10k.zsh.pre-lcars10k
back into place. Remove the source line from ~/.zshrc.
EOF
}

# ------------------------------------------------------------------------
# Run
# ------------------------------------------------------------------------
banner
preflight
step_zshrc
step_rc
step_p10k
step_fonts
step_sounds
step_terminal
show_summary
