# lcars-ask output formatting — design

**Date:** 2026-07-03
**Branch:** `feature/lcars-ask-formatting` (off `feature/lcars-ask`)
**Status:** Approved (design), pending spec review

## Problem

`lcars <prompt>` streams `claude -p`'s answer through `bin/lcars10k_ask.py`. The
TTY render path currently prints the answer with a single transform
(`lcars10k_ask.py` `run_tty`):

```python
sys.stdout.write(payload.replace("\n", "\n  "))
```

This indents each *existing* newline by two spaces and does nothing else. Two
consequences:

1. Claude's `-p` mode usually replies as one long paragraph with no internal
   newlines, so the whole answer is a single run-on block.
2. Because there is no reflow, the terminal soft-wraps that block at full width,
   and the wrapped continuation lines start at column 0 — the two-space indent
   only applies at real newlines. The result is ragged and hard to read.

Goal: make the answer read as a clean, LCARS-flavored readout — comfortable line
length, real breaks between ideas — without discarding streaming.

## Approach

Two complementary levers, per the "Both" decision:

- **Local reformat (backbone).** An incremental, streaming word-wrapper replaces
  the single `write` in `run_tty`. Deterministic; never alters Claude's words;
  works even if Claude ignores instructions.
- **Steer Claude (flavor).** A light `--append-system-prompt` nudge toward brevity
  and simple bullet lists. Shapes form, never forces structure onto answers that
  don't want it.

The local reformat is the real fix; the nudge is a cooperative enhancement.

## Component 1 — streaming word-wrapper

New pure-logic unit in `bin/lcars10k_ask.py`, unit-testable in isolation
(mirrors how `iter_events` / `render_plain` are tested today).

**Shape:** a small stateful class, e.g. `AnswerFormatter`, constructed with the
palette and the target width. It exposes:

- `feed(text) -> str` — accept a delta chunk, return the ANSI-colored, wrapped
  text that is now safe to emit (only complete words within the width budget).
- `flush() -> str` — emit any buffered trailing partial word at end of stream.

`run_tty` owns an instance and writes whatever `feed`/`flush` return, so the live
`RECEIVING` animation and streaming feel are preserved. The formatter never
calls `sys.stdout` itself — it returns strings — which keeps it testable.

**Wrapping rules:**

- **Measure.** Wrap width = `min(terminal_cols - 4, 80)`. On a wide terminal the
  text does not sprawl edge-to-edge; on a narrow one it shrinks. Terminal width
  is read once at construction via `shutil.get_terminal_size`.
- **Indent.** Body lines use a 2-space left indent (matches today's look). Wrapped
  continuation lines keep the same 2-space indent (hanging), so no continuation
  line ever starts at column 0.
- **Word boundaries.** Break only at whitespace. A word longer than the measure
  (rare — a URL) is emitted whole rather than hard-split mid-token.
- **Line breaks.** Every `\n` from Claude is a hard line break (the next line
  re-wraps from its own indent). A run of 2+ newlines collapses to exactly one
  blank line — a breath between ideas — so Claude's paragraph gaps are preserved
  without stacking multiple blanks. Leading newlines before any text are dropped
  (no blank line above the first answer line). This is simpler and more robust
  than reflowing single `\n`, and matches real `claude -p` output (one long line
  per paragraph, `\n\n` between blocks, `\n` between list items) — a rule that
  also keeps `\n`-before-`- item` a clean bullet break rather than a reflow.

**Bullet restyle (the visible LCARS flourish):**

- A line whose first non-space characters are `- ` or `* ` is a bullet. Its marker
  renders as `◈ ` in an LCARS accent color from the live palette (pumpkin, with
  the marker distinct from the body text). Body text wraps with continuation lines
  aligned under the text (indent = body indent + 2 for the `◈ `), not under the
  glyph.
- Nested bullets (leading whitespace before `- `) increase the indent one level.
  Keep this simple — one extra indent step per two leading spaces; do not build a
  full markdown list parser.

**Out of scope (YAGNI):** markdown tables, headers (`#`), code fences, inline
emphasis (`**bold**`, `` `code` ``). The system-prompt nudge asks Claude to avoid
these; if one slips through, it is wrapped as ordinary text, not specially
rendered. No syntax highlighting.

## Component 2 — system-prompt nudge

Add to the `claude -p` argv in `main` (`lcars10k_ask.py` ~line 230):

```
--append-system-prompt "<nudge>"
```

Nudge text (single line):

> Answer concisely for a terminal readout. Prefer short paragraphs. Use simple
> "- " bullet lists for enumerations. Avoid markdown tables, headers, and code
> fences unless explicitly asked. Do not add preamble or sign-off.

Kept intentionally light so a one-line factual question still gets a one-line
answer. The nudge is a constant in the engine; no new user config knob in this
iteration.

## Non-TTY path — unchanged

`render_plain` (used when stdout is not a TTY: pipes, redirects, `lcars foo >
file`) continues to stream raw answer text with a single trailing newline. No
wrapping, no color, no bullet restyle — output stays clean and scriptable. The
existing `PlainRenderTests` must keep passing unmodified.

## Testing

Extend `bin/test_ask_parser.py` (pure-logic, stdlib `unittest`, no live
`claude`):

- **Wrapping:** a long single-paragraph delta wraps at the measure; no line
  (stripped of ANSI) exceeds the width; continuation lines carry the 2-space
  indent.
- **Streaming safety:** feeding the same text split across arbitrary delta
  boundaries produces the same rendered output as feeding it whole (no word
  torn across a flush).
- **Line breaks:** a single `\n` starts a new wrapped line; `\n\n` (or more)
  yields exactly one blank line; leading newlines are dropped.
- **Bullets:** a `- ` line renders the `◈ ` marker and aligns wrapped
  continuation under the body text.
- **Long word:** a token longer than the measure is emitted unbroken.
- **Plain path untouched:** existing `PlainRenderTests` assertions unchanged.

ANSI-aware assertions strip color codes before measuring line length (helper in
the test module), since the visible width is what matters.

`tests/test_ask.zsh` (the zsh-level smoke test that stubs the engine) needs no
change — the engine's external contract is unchanged.

## Files touched

- `bin/lcars10k_ask.py` — add `AnswerFormatter`; wire it into `run_tty`; add
  `--append-system-prompt` to the argv. `render_plain` untouched.
- `bin/test_ask_parser.py` — new formatter tests.
- No changes to `lib/lcars-ask.zsh`, `tests/test_ask.zsh`, or config.

## Risks / notes

- **Terminal resize mid-stream** is not handled (width is captured once). Matches
  the existing header/rule behavior, which also samples width once. Acceptable.
- The `◈` glyph renders in `MesloLGS NF` (and most fonts) as a standard Unicode
  diamond — it is not a Private Use Area glyph, so no font-patch dependency
  (unlike the Trekbats note in the repo's font constraint).
