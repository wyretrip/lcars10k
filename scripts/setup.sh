#!/usr/bin/env bash
# scripts/setup.sh — one-shot lcars10k setup.
#
# Idempotent. Safe to run multiple times. Does five things:
#   1. Appends the theme-source line to ~/.zshrc (only if not already there)
#   2. Copies the config template to ~/.lcars10krc (only if it doesn't exist)
#   3. Detects $TERM_PROGRAM and configures the terminal font where possible
#      - iTerm2: writes a dynamic profile that auto-installs on next launch
#      - Apple Terminal: sets the Basic profile font via AppleScript
#      - Ghostty: appends font-family to ~/.config/ghostty/config
#      - Others: prints clear manual instructions
#   4. Reminds you to install fonts/sounds if scripts haven't been run yet
#   5. Prints what to do next
#
# macOS only (matches lcars10k v1 scope).

set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LCARS_HOME="$( cd -- "$SCRIPT_DIR/.." &> /dev/null && pwd )"

if [[ "$(uname)" != "Darwin" ]]; then
    echo "setup.sh: macOS only. (Linux/WSL support is a v2 roadmap item.)" >&2
    exit 2
fi

echo "lcars10k setup"
echo "  repo: $LCARS_HOME"
echo

# -------------------------------------------------------------
# 1. Append source line to ~/.zshrc (idempotent)
# -------------------------------------------------------------
ZSHRC="$HOME/.zshrc"
SOURCE_LINE="source $LCARS_HOME/lcars10k.zsh-theme"

touch "$ZSHRC"
if grep -Fq "$SOURCE_LINE" "$ZSHRC"; then
    echo "✓ ~/.zshrc already sources lcars10k"
else
    {
        echo ""
        echo "# lcars10k — LCARS-themed Zsh prompt"
        echo "$SOURCE_LINE"
    } >> "$ZSHRC"
    echo "✓ appended lcars10k source line to ~/.zshrc"
fi

# -------------------------------------------------------------
# 2. Set up ~/.lcars10krc (only if missing)
# -------------------------------------------------------------
LCARSRC="$HOME/.lcars10krc"
TEMPLATE="$LCARS_HOME/config/lcars10krc.template"

if [[ -f "$LCARSRC" ]]; then
    echo "✓ ~/.lcars10krc already exists (leaving it alone)"
elif [[ -f "$TEMPLATE" ]]; then
    cp "$TEMPLATE" "$LCARSRC"
    # Patch LCARS_HOME in the rc to point at the actual repo location
    sed -i.bak "s|^export LCARS_HOME=.*|export LCARS_HOME=\"$LCARS_HOME\"|" "$LCARSRC"
    rm -f "$LCARSRC.bak"
    echo "✓ wrote ~/.lcars10krc (pointing LCARS_HOME at $LCARS_HOME)"
else
    echo "⚠ no config template at $TEMPLATE — skipped ~/.lcars10krc"
fi

# -------------------------------------------------------------
# 2b. Install our LCARS-tuned ~/.p10k.zsh (back up the existing one).
#     lcars10k owns the prompt; the wizard-generated config doesn't compose
#     cleanly with LCARS styling. Old config preserved for rollback.
# -------------------------------------------------------------
P10KRC="$HOME/.p10k.zsh"
P10K_BACKUP="$HOME/.p10k.zsh.pre-lcars10k"
P10K_SRC="$LCARS_HOME/config/p10k.zsh"

if [[ ! -f "$P10K_SRC" ]]; then
    echo "⚠ $P10K_SRC missing — repo incomplete?"
elif [[ -L "$P10KRC" && "$(readlink "$P10KRC")" == "$P10K_SRC" ]]; then
    echo "✓ ~/.p10k.zsh already symlinked to lcars10k config"
else
    if [[ -e "$P10KRC" && ! -e "$P10K_BACKUP" ]]; then
        mv "$P10KRC" "$P10K_BACKUP"
        echo "✓ backed up existing ~/.p10k.zsh → ~/.p10k.zsh.pre-lcars10k"
    elif [[ -e "$P10KRC" ]]; then
        # backup already exists; just remove the current file
        rm -f "$P10KRC"
        echo "✓ removed existing ~/.p10k.zsh (backup at ~/.p10k.zsh.pre-lcars10k already exists)"
    fi
    ln -s "$P10K_SRC" "$P10KRC"
    echo "✓ symlinked ~/.p10k.zsh → $P10K_SRC"
fi

# -------------------------------------------------------------
# 3. Terminal-specific font configuration
# -------------------------------------------------------------
FONT_PS_NAME="MesloLGSNF-Regular"   # PostScript name for iTerm2
FONT_DISPLAY_NAME="MesloLGS NF"     # Display name for Terminal.app / Ghostty
FONT_SIZE=13

case "${TERM_PROGRAM:-unknown}" in
    iTerm.app)
        # iTerm2 dynamic profile — dropped into the magic directory.
        # iTerm2 picks this up at next launch (or live if it's already watching).
        PROFILES_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
        mkdir -p "$PROFILES_DIR"
        cat > "$PROFILES_DIR/lcars10k.json" <<EOF
{
  "Profiles": [
    {
      "Name": "LCARS",
      "Guid": "lcars10k-dynamic-profile",
      "Dynamic Profile Parent Name": "Default",
      "Normal Font": "$FONT_PS_NAME $FONT_SIZE",
      "Non Ascii Font": "$FONT_PS_NAME $FONT_SIZE",
      "Use Non-ASCII Font": true,
      "Background Color": {"Red Component": 0, "Green Component": 0, "Blue Component": 0},
      "Foreground Color": {"Red Component": 1, "Green Component": 0.8, "Blue Component": 0.6}
    }
  ]
}
EOF
        echo "✓ wrote iTerm2 dynamic profile: $PROFILES_DIR/lcars10k.json"
        echo "  → Open iTerm2 Settings → Profiles → LCARS → 'Other Actions...' → 'Set as Default'"
        echo "  → Or cmd-i in a new tab to switch to it for this session"
        ;;

    Apple_Terminal)
        # Terminal.app — AppleScript sets the font on the active default profile
        if osascript >/dev/null 2>&1 <<EOF
tell application "Terminal"
    set font name of settings set "Basic" to "$FONT_DISPLAY_NAME"
    set font size of settings set "Basic" to $FONT_SIZE
end tell
EOF
        then
            echo "✓ set Terminal.app 'Basic' profile font to $FONT_DISPLAY_NAME $FONT_SIZE"
            echo "  → Open a new Terminal window to see it"
        else
            echo "⚠ AppleScript font-set failed for Terminal.app — set it manually:"
            echo "  Terminal → Settings → Profiles → Basic → Font: $FONT_DISPLAY_NAME"
        fi
        ;;

    ghostty)
        GHOSTTY_CONFIG="$HOME/.config/ghostty/config"
        mkdir -p "$(dirname "$GHOSTTY_CONFIG")"
        touch "$GHOSTTY_CONFIG"
        if grep -Fq "font-family = $FONT_DISPLAY_NAME" "$GHOSTTY_CONFIG"; then
            echo "✓ Ghostty config already has font-family = $FONT_DISPLAY_NAME"
        else
            {
                echo ""
                echo "# lcars10k"
                echo "font-family = $FONT_DISPLAY_NAME"
                echo "font-size = $FONT_SIZE"
            } >> "$GHOSTTY_CONFIG"
            echo "✓ appended font config to $GHOSTTY_CONFIG"
            echo "  → Restart Ghostty (or cmd-shift-comma → Reload Configuration) to apply"
        fi
        ;;

    WarpTerminal)
        echo "⚠ Warp detected — font has to be set in the GUI:"
        echo "  Warp → Settings → Appearance → Text → Font: $FONT_DISPLAY_NAME"
        ;;

    vscode)
        echo "⚠ VS Code integrated terminal — set in Settings:"
        echo "  Cmd-, then search 'terminal.integrated.fontFamily'"
        echo "  Set to: $FONT_DISPLAY_NAME"
        ;;

    *)
        echo "⚠ Unknown TERM_PROGRAM ($TERM_PROGRAM) — set the font manually:"
        echo "  Set your terminal's font to: $FONT_DISPLAY_NAME (size ~$FONT_SIZE)"
        ;;
esac

# -------------------------------------------------------------
# 4. Remind about font/sound installers
# -------------------------------------------------------------
echo

if [[ ! -f "$HOME/Library/Fonts/MesloLGS NF Regular.ttf" ]]; then
    echo "ℹ  MesloLGS NF not yet installed in ~/Library/Fonts"
    echo "   Run: $LCARS_HOME/scripts/install-fonts.sh"
else
    echo "✓ MesloLGS NF is installed in ~/Library/Fonts"
fi

# A populated sounds/ dir means install-sounds.sh has run
if compgen -G "$LCARS_HOME/sounds/*.wav" > /dev/null; then
    echo "✓ TNG sound samples are present in $LCARS_HOME/sounds/"
else
    echo "ℹ  No TNG sounds downloaded yet (optional)"
    echo "   Run: $LCARS_HOME/scripts/install-sounds.sh"
fi

# -------------------------------------------------------------
# 5. Closing instructions
# -------------------------------------------------------------
cat <<EOF

────────────────────────────────────────────────────────────
Done. To see lcars10k in action, open a new terminal window.

Useful commands once the prompt is live:
  lcars-quiet              # silence sounds for this session
  lcars-loud               # re-enable sounds
  lcars-redalert on|off    # manual Red Alert palette
  lcars-redalert auto      # toggle auto-engage on 3 fails

Edit ~/.lcars10krc to change defaults (sound on/off, thresholds).
────────────────────────────────────────────────────────────
EOF
