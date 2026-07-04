#!/usr/bin/env bash
# scripts/_lib.sh — shared cross-platform helpers for the lcars10k scripts.
#
# Sourced by setup.sh / install-fonts.sh / uninstall.sh. Keeps OS-specific
# knowledge (font directories, cache refresh, package hints) in one place so
# the individual scripts stay readable.
#
# Not meant to be run directly.

# LCARS_OS — normalized platform name: "macos", "linux", or "unknown".
case "$(uname -s)" in
    Darwin) LCARS_OS="macos" ;;
    Linux)  LCARS_OS="linux" ;;
    *)      LCARS_OS="unknown" ;;
esac

# lcars_fonts_dir — per-user font install directory for the current OS.
#   macOS:  ~/Library/Fonts
#   Linux:  $XDG_DATA_HOME/fonts (default ~/.local/share/fonts)
lcars_fonts_dir() {
    case "$LCARS_OS" in
        macos) printf '%s\n' "$HOME/Library/Fonts" ;;
        linux) printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/fonts" ;;
        *)     printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/fonts" ;;
    esac
}

# lcars_refresh_font_cache — make newly-copied fonts visible to apps.
# macOS registers fonts automatically; Linux needs fontconfig's fc-cache.
lcars_refresh_font_cache() {
    if [[ "$LCARS_OS" == "linux" ]] && command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$(lcars_fonts_dir)" >/dev/null 2>&1 || true
    fi
}

# lcars_sox_hint — OS-appropriate one-liner for installing sox.
lcars_sox_hint() {
    case "$LCARS_OS" in
        macos) printf '%s\n' "brew install sox" ;;
        linux)
            if   command -v apt-get >/dev/null 2>&1; then printf '%s\n' "sudo apt install sox"
            elif command -v dnf     >/dev/null 2>&1; then printf '%s\n' "sudo dnf install sox"
            elif command -v pacman  >/dev/null 2>&1; then printf '%s\n' "sudo pacman -S sox"
            elif command -v zypper  >/dev/null 2>&1; then printf '%s\n' "sudo zypper install sox"
            else printf '%s\n' "install 'sox' with your package manager"
            fi ;;
        *) printf '%s\n' "install 'sox' with your package manager" ;;
    esac
}
