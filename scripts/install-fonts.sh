#!/usr/bin/env bash
# scripts/install-fonts.sh — copy bundled LCARS fonts into the user font dir.
#   macOS:  ~/Library/Fonts
#   Linux:  ~/.local/share/fonts  (fontconfig cache refreshed afterwards)

set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/_lib.sh"
FONTS_SRC="$SCRIPT_DIR/../fonts"
FONTS_DST="$(lcars_fonts_dir)"

if [[ "$LCARS_OS" == "unknown" ]]; then
    echo "install-fonts.sh: unrecognized OS ($(uname -s)). Install fonts from $FONTS_SRC manually." >&2
    exit 2
fi

mkdir -p "$FONTS_DST"

shopt -s nullglob
copied=0
for ttf in "$FONTS_SRC"/*/*.ttf "$FONTS_SRC"/*/*.otf; do
    name="$(basename "$ttf")"
    cp -f "$ttf" "$FONTS_DST/$name"
    echo "  installed: $name"
    copied=$((copied + 1))
done

if (( copied == 0 )); then
    echo "install-fonts.sh: no font files found in $FONTS_SRC" >&2
    exit 1
fi

lcars_refresh_font_cache

echo
echo "Installed $copied font(s) into $FONTS_DST."
echo "Next: set your terminal font to 'MesloLGS NF LCARS' and restart the shell."
