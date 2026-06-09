#!/usr/bin/env fontforge
# scripts/patch-font.py — copy Trekbats glyphs into MesloLGS NF at PUA codepoints.
#
# Produces a "MesloLGS NF LCARS" TTF that contains everything the original
# MesloLGS NF has, PLUS the 55 Trekbats glyphs mapped at U+E100..U+E136.
# Install the output into ~/Library/Fonts (or run install-fonts.sh after
# copying it under fonts/MesloLGS-NF-LCARS/), set your terminal font to
# "MesloLGS NF LCARS", and reference the codepoints from prompt segments.
#
# PUA mapping (chosen because U+E1xx is fully unused by MesloLGS NF, so we
# can't collide with any Nerd Font / Powerline glyph):
#
#     U+E100..U+E119  ←  Trekbats 'A'..'Z'    (26 glyphs)
#     U+E11A..U+E133  ←  Trekbats 'a'..'z'    (26 glyphs)
#     U+E134..U+E136  ←  Trekbats '[' '\' ']' ( 3 glyphs)
#
# Usage (must be run by fontforge's Python, not regular python3):
#
#     fontforge -script scripts/patch-font.py [--all-weights]
#
# Without --all-weights only Regular is patched. With --all-weights all four
# weights (Regular, Bold, Italic, Bold Italic) get the same Trekbats glyphs.

from __future__ import annotations

import os
import sys

import fontforge
import psMat


REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MESLO_DIR = os.path.join(REPO_ROOT, "lcars10k", "fonts", "MesloLGS-NF")
TREKBATS_TTF = os.path.join(REPO_ROOT, "trekbats-font", "TrekbatsRegular-XEWg.ttf")
OUT_DIR = os.path.join(REPO_ROOT, "lcars10k", "fonts", "MesloLGS-NF-LCARS")

NEW_FAMILY = "MesloLGS NF LCARS"
PUA_BASE = 0xE100


def build_codepoint_map() -> dict[int, int]:
    """Source codepoint (Trekbats) -> destination codepoint (in patched Meslo)."""
    mapping: dict[int, int] = {}
    dest = PUA_BASE
    for src in list(range(0x41, 0x5B)) + list(range(0x61, 0x7B)) + [0x5B, 0x5C, 0x5D]:
        mapping[src] = dest
        dest += 1
    return mapping


def patch_one(meslo_path: str, trekbats_path: str, out_path: str, style_suffix: str) -> None:
    """Patch a single Meslo weight with Trekbats glyphs, save as TTF."""
    src = fontforge.open(trekbats_path)
    dst = fontforge.open(meslo_path)

    # The terminal cell width — every glyph we paste must end up with this
    # advance so the prompt's monospace grid stays intact. We grab it from
    # an existing ASCII glyph in Meslo (the digit "0" is a safe pick).
    cell_advance = dst[ord("0")].width
    src_em = src.em
    dst_em = dst.em

    # Cap-height of the destination font, measured from a flat-topped letter
    # so we don't have to trust os2_capHeight being populated. This is the
    # size every Trekbats emblem will be scaled to so it reads at the same
    # visual scale as the LCARS pill's letters around it.
    cap_height = dst[ord("H")].boundingBox()[3]

    # Trekbats glyphs are designed for the source font's em-square. Scaling
    # by dst_em/src_em moves them into Meslo's em-square at their natural
    # proportions; a per-glyph height-to-cap-height pass then sizes each
    # emblem to match cap-height exactly.
    em_scale = dst_em / src_em

    mapping = build_codepoint_map()
    copied = 0
    for src_cp, dst_cp in mapping.items():
        if src_cp not in src:
            continue
        # Select source glyph, copy to clipboard.
        src.selection.select(("unicode", None), src_cp)
        src.copy()

        # Create the destination slot at the PUA codepoint and paste.
        dst.selection.select(("unicode", None), dst_cp)
        dst.paste()

        glyph = dst[dst_cp]
        glyph.glyphname = "trekbats_u%04X" % dst_cp

        if em_scale != 1.0:
            glyph.transform(psMat.scale(em_scale))

        # Fit each emblem to cap-height while bounding its width to two
        # monospace cells. Square emblems (the Starfleet delta, Federation
        # logo, etc.) hit cap-height exactly and overflow ~0.25 cell either
        # side. Wide side-view ships (Trekbats 'a' is the runabout at 4:1)
        # would balloon past five cells if scaled to cap-height, so the
        # width cap pulls them shorter and they end up <cap-height but
        # bounded at 2 cells wide.
        max_width = 2 * cell_advance
        bbox = glyph.boundingBox()  # (xmin, ymin, xmax, ymax)
        glyph_h = bbox[3] - bbox[1]
        glyph_w = bbox[2] - bbox[0]
        if glyph_h > 0 and glyph_w > 0 and cap_height > 0:
            fit = min(cap_height / glyph_h, max_width / glyph_w)
            glyph.transform(psMat.scale(fit))
            bbox = glyph.boundingBox()

        # Center horizontally in the cell. Square emblems overflow slightly
        # — same convention Nerd Font uses for icons — and the cursor still
        # advances exactly one cell so the monospace grid stays intact.
        glyph_width = bbox[2] - bbox[0]
        x_shift = (cell_advance - glyph_width) / 2 - bbox[0]
        glyph.transform(psMat.translate(x_shift, 0))

        glyph.width = cell_advance
        copied += 1

    # Rename so the patched font doesn't collide with the original in
    # the system font menu. Family + fullname + fontname all updated.
    dst.familyname = NEW_FAMILY
    dst.fullname = f"{NEW_FAMILY} {style_suffix}".strip()
    dst.fontname = dst.fullname.replace(" ", "")

    # The unique font identifier (SFNT name id 3) must also change or
    # macOS will sometimes serve the cached original.
    dst.appendSFNTName("English (US)", "UniqueID", f"{NEW_FAMILY} {style_suffix} v1.0")
    dst.appendSFNTName("English (US)", "Family", NEW_FAMILY)
    dst.appendSFNTName("English (US)", "Fullname", dst.fullname)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    dst.generate(out_path)
    src.close()
    dst.close()

    # macOS (Font Book, terminals) reads nameID 16 ("Preferred Family") in
    # preference to nameID 1 ("Family") when present. The source MesloLGS NF
    # has nameID 16 = "MesloLGS NF" — fontforge's familyname setter doesn't
    # touch it, so the font shows up under the old family name unless we
    # strip these "preferred" / WWS records. Also strip 17/21/22 for the
    # subfamily side, so the new family + new subfamily are matched only by
    # nameIDs 1/2/4/6.
    _strip_preferred_family_records(out_path)
    print(f"  wrote {out_path}  (+{copied} Trekbats glyphs)")


def _strip_preferred_family_records(path: str) -> None:
    """Remove nameID 16/17/21/22 so apps fall back to nameID 1/2."""
    # Lazy import: fontforge's Python doesn't bundle fontTools, but the
    # system python3 we shell out to does.
    import subprocess
    code = (
        "from fontTools.ttLib import TTFont;"
        "import sys;"
        "f = TTFont(sys.argv[1]);"
        "nt = f['name'];"
        "nt.names = [r for r in nt.names if r.nameID not in (16,17,21,22)];"
        "f.save(sys.argv[1]);"
    )
    subprocess.run(["python3", "-c", code, path], check=True)


def main(argv: list[str]) -> int:
    if not os.path.isfile(TREKBATS_TTF):
        sys.stderr.write(f"missing Trekbats font: {TREKBATS_TTF}\n")
        return 2
    if not os.path.isdir(MESLO_DIR):
        sys.stderr.write(f"missing MesloLGS NF dir: {MESLO_DIR}\n")
        return 2

    all_weights = "--all-weights" in argv

    weights: list[tuple[str, str]] = [
        ("MesloLGS NF Regular.ttf", "Regular"),
    ]
    if all_weights:
        weights += [
            ("MesloLGS NF Bold.ttf", "Bold"),
            ("MesloLGS NF Italic.ttf", "Italic"),
            ("MesloLGS NF Bold Italic.ttf", "Bold Italic"),
        ]

    print(f"Patching {len(weights)} weight(s) into {OUT_DIR}")
    for src_name, suffix in weights:
        src = os.path.join(MESLO_DIR, src_name)
        out = os.path.join(OUT_DIR, f"{NEW_FAMILY} {suffix}.ttf")
        print(f"\n→ {src_name}  ({suffix})")
        patch_one(src, TREKBATS_TTF, out, suffix)

    print("\nDone.")
    print(f"Trekbats glyphs live at U+{PUA_BASE:04X}–U+{PUA_BASE + 54:04X}.")
    print("Install with: cp '" + OUT_DIR + "'/*.ttf ~/Library/Fonts/")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
