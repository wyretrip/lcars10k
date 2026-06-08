#!/usr/bin/env bash
# scripts/install-fonts.sh — copy bundled LCARS fonts into ~/Library/Fonts.
# macOS only (other platforms have different font dirs).

set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
FONTS_SRC="$SCRIPT_DIR/../fonts"
FONTS_DST="$HOME/Library/Fonts"

if [[ "$(uname)" != "Darwin" ]]; then
    echo "install-fonts.sh: macOS only. Other platforms must install fonts manually." >&2
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

echo
echo "Installed $copied font(s)."
echo "Next: set your terminal font to 'MesloLGS NF' and restart the shell."
