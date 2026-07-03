# lcars-ask Output Formatting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the run-on, ragged answer render in `bin/lcars10k_ask.py` with a streaming word-wrapper (comfortable measure, hanging indent, LCARS bullet restyle) plus a light `--append-system-prompt` nudge.

**Architecture:** A new pure-logic `AnswerFormatter` class buffers streamed deltas and returns colored, word-wrapped text safe to emit now (whitespace-terminated words only; trailing partial word held). `run_tty` owns one instance so live streaming is preserved. A `build_claude_cmd` helper adds the system-prompt nudge. The non-TTY `render_plain` path is untouched.

**Tech Stack:** Python 3 stdlib only (`re`, `shutil`, `unittest`). No new deps.

---

## File Structure

- `bin/lcars10k_ask.py` — add module constant `ASK_SYSTEM_PROMPT`, class `AnswerFormatter`, helper `build_claude_cmd`; rewire `run_tty` and `main`. `render_plain`, `iter_events`, palette helpers unchanged.
- `bin/test_ask_parser.py` — add `AnswerFormatterTests` and `BuildCmdTests`. Existing test classes unchanged.

Reference: read `docs/superpowers/specs/2026-07-03-lcars-ask-formatting-design.md` before starting.

---

## Task 1: AnswerFormatter (streaming word-wrapper)

**Files:**
- Modify: `bin/lcars10k_ask.py` (add constant + class near the render helpers, after `RESET`/`fg`/`bg`, before `render_header`)
- Test: `bin/test_ask_parser.py` (new `AnswerFormatterTests` class + an ANSI-stripping helper)

- [ ] **Step 1: Write the failing tests**

Add near the top of `bin/test_ask_parser.py`, after the existing imports:

```python
import re as _re

_ANSI = _re.compile(r"\033\[[0-9;?]*[A-Za-z]")


def _strip(s):
    """Remove ANSI escape sequences so visible width can be measured."""
    return _ANSI.sub("", s)


def _render(text, cols=40, chunks=None):
    """Run text through AnswerFormatter; return the full emitted string.

    chunks: optional list of delta strings; when None, feed text whole.
    """
    fmt = engine.AnswerFormatter(engine.load_palette(env={}), cols=cols)
    out = []
    for part in (chunks if chunks is not None else [text]):
        out.append(fmt.feed(part))
    out.append(fmt.flush())
    return "".join(out)
```

Then add this test class at the end of the file, before the `__main__` guard:

```python
class AnswerFormatterTests(unittest.TestCase):
    def _lines(self, rendered):
        # Visible (ANSI-stripped) lines; drop a single trailing empty split.
        return _strip(rendered).split("\n")

    def test_long_paragraph_wraps_within_measure(self):
        text = ("word " * 60).strip()  # 60 short words, one paragraph
        rendered = _render(text, cols=40)
        lines = self._lines(rendered)
        self.assertTrue(len(lines) > 1, "expected multiple wrapped rows")
        for ln in lines:
            self.assertLessEqual(len(ln), 40, f"line too wide: {ln!r}")

    def test_body_lines_are_indented(self):
        text = ("word " * 60).strip()
        for ln in self._lines(_render(text, cols=40)):
            if ln.strip():
                self.assertTrue(ln.startswith("  "), f"not indented: {ln!r}")

    def test_streaming_matches_whole(self):
        # Same text fed in awkward chunks renders identically to one shot.
        text = "The quick brown fox jumps over the lazy dog again and again."
        whole = _render(text, cols=30)
        chunky = _render(text, cols=30,
                         chunks=["The qui", "ck bro", "wn fox jum", "ps over the",
                                 " lazy dog aga", "in and again."])
        self.assertEqual(_strip(whole), _strip(chunky))

    def test_blank_line_between_paragraphs(self):
        rendered = _render("First para here.\n\nSecond para here.", cols=40)
        lines = self._lines(rendered)
        self.assertIn("", [ln.strip() for ln in lines],
                      "expected a blank line between paragraphs")
        # Exactly one blank line even with 3 newlines.
        r3 = self._lines(_render("A.\n\n\n\nB.", cols=40))
        blanks = sum(1 for ln in r3 if ln.strip() == "")
        self.assertEqual(blanks, 1)

    def test_leading_newlines_dropped(self):
        lines = self._lines(_render("\n\nHello.", cols=40))
        self.assertNotEqual(lines[0].strip(), "",
                            "first line should not be blank")

    def test_bullet_marker_and_alignment(self):
        text = "- " + ("bulletword " * 12).strip()
        rendered = _render(text, cols=30)
        lines = self._lines(rendered)
        self.assertIn("◈", lines[0], "expected ◈ bullet on first row")
        # Continuation rows align under the text (indent deeper than 2 spaces).
        cont = [ln for ln in lines[1:] if ln.strip()]
        self.assertTrue(cont, "expected wrapped continuation rows")
        for ln in cont:
            self.assertTrue(ln.startswith("    "),
                            f"continuation not aligned under text: {ln!r}")
            self.assertNotIn("◈", ln, "marker must not repeat on wrap")

    def test_bullet_marker_is_colored(self):
        # The raw (un-stripped) output must contain an SGR color before ◈.
        raw = _render("- item text here", cols=40)
        self.assertRegex(raw, r"\033\[38;2;[0-9;]+m◈")

    def test_overlong_word_not_split(self):
        word = "x" * 60
        rendered = _render("tiny " + word + " end", cols=20)
        self.assertIn(word, _strip(rendered), "long word must stay intact")

    def test_no_ansi_in_plain_words(self):
        # Ordinary answer text carries no color codes (only bullets do).
        raw = _render("just some plain words", cols=40)
        self.assertEqual(raw.count("\033"), 0)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 bin/test_ask_parser.py 2>&1 | tail -20`
Expected: FAIL — `AttributeError: module 'lcars10k_ask' has no attribute 'AnswerFormatter'`

- [ ] **Step 3: Implement AnswerFormatter**

In `bin/lcars10k_ask.py`, add after the `RESET = "\033[0m"` / `fg` / `bg` helpers and before `def iter_events` (import `re` at the top with the other stdlib imports):

```python
import re  # add to the existing import block at the top of the file
```

```python
ASK_SYSTEM_PROMPT = (
    "Answer concisely for a terminal readout. Prefer short paragraphs. "
    "Use simple \"- \" bullet lists for enumerations. Avoid markdown tables, "
    "headers, and code fences unless explicitly asked. Do not add preamble or "
    "sign-off."
)

_WS_RUN = re.compile(r"[ \t]+")
_WORD_RUN = re.compile(r"[^\s]+")


class AnswerFormatter:
    """Streaming word-wrapper for the TTY answer path.

    feed(delta) takes a raw text chunk and returns colored, wrapped text that is
    safe to emit now. Only whitespace-terminated words are emitted; a trailing
    partial word is held so it is never torn across a wrap. flush() returns the
    remainder at end of stream. Never writes to stdout itself, so it is unit
    testable. Emitted lines carry their own indent; visible width (excluding the
    ANSI-colored bullet marker) never exceeds the measure.
    """

    BULLET = "◈"  # ◈

    def __init__(self, palette, cols=None):
        if cols is None:
            cols = shutil.get_terminal_size((80, 24)).columns
        self.width = max(20, min(cols - 4, 80))
        self.palette = palette
        self._buf = ""
        self._col = 0             # visible cols used on the current row
        self._indent_cont = "  "  # continuation indent for the current line
        self._line_started = False
        self._sep = False         # a space separator is pending before next word
        self._skip_next_sep = False  # swallow the space after a bullet marker
        self._lead_spaces = 0     # leading spaces seen at the current line start
        self._pending_nl = 0      # consecutive unresolved newlines

    # -- public API ------------------------------------------------------
    def feed(self, text):
        self._buf += text
        return self._drain(final=False)

    def flush(self):
        return self._drain(final=True)

    # -- internals -------------------------------------------------------
    def _take_token(self, final):
        b = self._buf
        if not b:
            return None
        if b[0] == "\n":
            self._buf = b[1:]
            return ("nl", "\n")
        if b[0] in " \t":
            m = _WS_RUN.match(b)
            if m.end() == len(b) and not final:
                return None  # spaces may still be growing
            self._buf = b[m.end():]
            return ("sp", b[:m.end()])
        m = _WORD_RUN.match(b)
        if m.end() == len(b) and not final:
            return None  # word may still be growing
        self._buf = b[m.end():]
        return ("word", b[:m.end()])

    def _drain(self, final):
        out = []
        while True:
            tok = self._take_token(final)
            if tok is None:
                break
            kind, text = tok
            if kind == "nl":
                self._pending_nl += 1
                continue
            if self._pending_nl:
                self._resolve_newlines(out)
                self._pending_nl = 0
            if kind == "sp":
                if not self._line_started:
                    self._lead_spaces += len(text)
                elif self._skip_next_sep:
                    self._skip_next_sep = False
                else:
                    self._sep = True
                continue
            # kind == "word"
            if not self._line_started:
                self._start_line(out, text)
            else:
                self._place_word(out, text)
        return "".join(out)

    def _resolve_newlines(self, out):
        if self._line_started:
            out.append("\n")
            if self._pending_nl >= 2:
                out.append("\n")  # collapse any run of blanks to one
            self._col = 0
            self._sep = False
            self._skip_next_sep = False
            self._line_started = False
            self._lead_spaces = 0
        # newlines before any content produce no leading blank line

    def _start_line(self, out, word):
        base = "  " + "  " * (self._lead_spaces // 2)
        self._lead_spaces = 0
        if word in ("-", "*"):
            marker = fg(self.palette["pumpkin"]) + self.BULLET + RESET
            out.append(base + marker + " ")
            self._col = len(base) + 2  # visible width of "◈ "
            self._indent_cont = base + "  "  # align continuation under text
            self._skip_next_sep = True
        else:
            out.append(base + word)
            self._col = len(base) + len(word)
            self._indent_cont = base
        self._line_started = True

    def _place_word(self, out, word):
        self._skip_next_sep = False
        wlen = len(word)
        sep = 1 if self._sep else 0
        if self._col + sep + wlen > self.width:
            out.append("\n" + self._indent_cont)
            self._col = len(self._indent_cont) + wlen
            out.append(word)
        else:
            if sep:
                out.append(" ")
                self._col += 1
            out.append(word)
            self._col += wlen
        self._sep = False
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 bin/test_ask_parser.py 2>&1 | tail -8`
Expected: PASS — all tests OK (13 existing + 9 new = 22).

- [ ] **Step 5: Commit**

```bash
git add bin/lcars10k_ask.py bin/test_ask_parser.py
git commit -m "feat(ask): streaming word-wrapper with LCARS bullet restyle

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: System-prompt nudge via build_claude_cmd

**Files:**
- Modify: `bin/lcars10k_ask.py` (add `build_claude_cmd`, use it in `main`)
- Test: `bin/test_ask_parser.py` (new `BuildCmdTests`)

- [ ] **Step 1: Write the failing test**

Add before the `__main__` guard in `bin/test_ask_parser.py`:

```python
class BuildCmdTests(unittest.TestCase):
    def test_includes_stream_json_and_prompt(self):
        cmd = engine.build_claude_cmd("why is the sky blue")
        self.assertEqual(cmd[:3], ["claude", "-p", "why is the sky blue"])
        self.assertIn("--output-format", cmd)
        self.assertIn("stream-json", cmd)

    def test_appends_system_prompt_nudge(self):
        cmd = engine.build_claude_cmd("hi")
        self.assertIn("--append-system-prompt", cmd)
        idx = cmd.index("--append-system-prompt")
        self.assertEqual(cmd[idx + 1], engine.ASK_SYSTEM_PROMPT)
        self.assertIn("bullet", engine.ASK_SYSTEM_PROMPT.lower())
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 bin/test_ask_parser.py 2>&1 | tail -12`
Expected: FAIL — `AttributeError: module 'lcars10k_ask' has no attribute 'build_claude_cmd'`

- [ ] **Step 3: Implement build_claude_cmd and use it in main**

In `bin/lcars10k_ask.py`, add this function just above `def main(argv):`:

```python
def build_claude_cmd(prompt):
    """Argv for the `claude -p` streaming run, incl. the LCARS format nudge."""
    return [
        "claude", "-p", prompt,
        "--output-format", "stream-json",
        "--include-partial-messages", "--verbose",
        "--append-system-prompt", ASK_SYSTEM_PROMPT,
    ]
```

Then in `main`, replace the existing `cmd = [...]` assignment:

```python
    cmd = ["claude", "-p", prompt, "--output-format", "stream-json",
           "--include-partial-messages", "--verbose"]
```

with:

```python
    cmd = build_claude_cmd(prompt)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 bin/test_ask_parser.py 2>&1 | tail -8`
Expected: PASS — all tests OK (now 24).

- [ ] **Step 5: Commit**

```bash
git add bin/lcars10k_ask.py bin/test_ask_parser.py
git commit -m "feat(ask): nudge claude toward concise LCARS-style answers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Wire the formatter into run_tty

**Files:**
- Modify: `bin/lcars10k_ask.py` (`run_tty` only)

No new unit test — `run_tty` drives threads/timers and stdout escape codes, so it is verified by the existing zsh smoke test plus a manual live run. The formatting logic it delegates to is already covered by Task 1.

- [ ] **Step 1: Construct the formatter and stop indenting via the header**

In `run_tty`, just after `streaming = False` (the local init before the `try:`), add:

```python
    formatter = AnswerFormatter(palette)
```

- [ ] **Step 2: Feed deltas through the formatter**

In `run_tty`, replace this block:

```python
            elif kind == "delta":
                if not streaming:
                    anim.stop()
                    anim.join()
                    elapsed = time.time() - start
                    sys.stdout.write(
                        "\r\033[K"
                        + render_header(palette, "RECEIVING", elapsed, 0)
                        + "\n  ")
                    streaming = True
                sys.stdout.write(payload.replace("\n", "\n  "))
                sys.stdout.flush()
```

with:

```python
            elif kind == "delta":
                if not streaming:
                    anim.stop()
                    anim.join()
                    elapsed = time.time() - start
                    sys.stdout.write(
                        "\r\033[K"
                        + render_header(palette, "RECEIVING", elapsed, 0)
                        + "\n")
                    streaming = True
                sys.stdout.write(formatter.feed(payload))
                sys.stdout.flush()
```

(Note: the header now ends with `"\n"` instead of `"\n  "` — the formatter owns the body indent.)

- [ ] **Step 3: Flush the formatter before the footer**

In the `finally` block of `run_tty`, replace:

```python
        sys.stdout.write("\n" if streaming else "\r\033[K")
```

with:

```python
        if streaming:
            sys.stdout.write(formatter.flush() + "\n")
        else:
            sys.stdout.write("\r\033[K")
```

- [ ] **Step 4: Verify existing suites still pass**

Run: `python3 bin/test_ask_parser.py 2>&1 | tail -4`
Expected: PASS — all OK (24).

Run: `tests/run-tests.zsh 2>&1 | tail -6`
Expected: PASS — the zsh suite (incl. `test_ask.zsh`) is green; it stubs the engine so it is unaffected.

- [ ] **Step 5: Manual live verification**

Run (in an interactive terminal where `claude` is on PATH):

```bash
python3 bin/lcars10k_ask.py "In two short paragraphs and a 3-item bullet list, explain what a transporter buffer is."
```

Expected: animated `ACCESSING CORE`/`WORKING` header, then the answer streams **wrapped** at a comfortable width with a 2-space hanging indent, a blank line between paragraphs, and `◈` bullets whose wrapped lines align under the text; a `COMPLETE` footer follows. Confirm no line runs off into a soft-wrapped run-on block.

Also confirm the pipe path is unchanged:

```bash
python3 bin/lcars10k_ask.py "say hello" | cat
```

Expected: plain answer text, one trailing newline, no ANSI/wrapping.

- [ ] **Step 6: Commit**

```bash
git add bin/lcars10k_ask.py
git commit -m "feat(ask): render streamed answers through the LCARS word-wrapper

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review Notes

- **Spec coverage:** Component 1 (wrapper: measure, hanging indent, word boundaries, line breaks, bullet restyle, long-word) → Task 1. Component 2 (system-prompt nudge) → Task 2. run_tty wiring + non-TTY-unchanged verification → Task 3. Testing section → Task 1 & 2 unit tests + Task 3 manual/zsh checks.
- **Non-TTY path:** never touched; `render_plain` and its `PlainRenderTests` remain as-is (asserted green in Task 3 Step 4).
- **Type consistency:** `AnswerFormatter(palette, cols)`, `.feed()/.flush()`, `ASK_SYSTEM_PROMPT`, `build_claude_cmd(prompt)` names are used identically across tasks and tests.
- **Out of scope (unchanged from spec):** markdown tables/headers/code fences/inline emphasis, syntax highlighting, terminal-resize-mid-stream, new user config knobs.
