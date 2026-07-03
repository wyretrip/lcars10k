#!/usr/bin/env python3
"""Unit tests for the lcars10k ask engine (pure logic only)."""
import io
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lcars10k_ask as engine

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


class PaletteTests(unittest.TestCase):
    def test_hex_to_rgb(self):
        self.assertEqual(engine.hex_to_rgb("#F5B86E"), (245, 184, 110))
        self.assertEqual(engine.hex_to_rgb("000000"), (0, 0, 0))

    def test_fg_sequence(self):
        self.assertEqual(engine.fg("#000000"), "\033[38;2;0;0;0m")

    def test_load_palette_defaults(self):
        pal = engine.load_palette(env={})
        self.assertEqual(pal["pumpkin"], "#F5B86E")
        self.assertEqual(pal["alert"], "#60463E")

    def test_load_palette_env_override(self):
        pal = engine.load_palette(env={"LCARS_C_PUMPKIN": "#112233"})
        self.assertEqual(pal["pumpkin"], "#112233")
        self.assertEqual(pal["sky"], "#A2A8F0")  # untouched default

    def test_bg_sequence(self):
        self.assertEqual(engine.bg("#000000"), "\033[48;2;0;0;0m")

    def test_load_palette_rejects_malformed(self):
        # A bad LCARS_C_* value must fall back to the built-in default,
        # so fg()/bg() never receive un-parseable input at runtime.
        pal = engine.load_palette(env={"LCARS_C_PUMPKIN": "not-a-color"})
        self.assertEqual(pal["pumpkin"], "#F5B86E")


# A representative slice of a real `claude -p --output-format stream-json
# --include-partial-messages --verbose` run, plus noise that must be ignored.
SUCCESS_STREAM = [
    '{"type":"system","subtype":"hook_started","hook_name":"SessionStart"}',
    '{"type":"system","subtype":"init","model":"claude-opus-4-8","session_id":"x"}',
    '{"type":"stream_event","event":{"type":"message_start","message":{}}}',
    '{"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}}',
    '{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}}',
    '{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" there"}}}',
    'not json at all',
    '',
    '{"type":"rate_limit_event","rate_limit_info":{"status":"allowed"}}',
    '{"type":"stream_event","event":{"type":"content_block_stop","index":0}}',
    '{"type":"result","subtype":"success","is_error":false,"result":"Hello there","duration_ms":2754,"total_cost_usd":0.0745}',
]

ERROR_STREAM = [
    '{"type":"system","subtype":"init","model":"claude-opus-4-8"}',
    '{"type":"result","subtype":"error_during_execution","is_error":true,"duration_ms":120,"total_cost_usd":0.0}',
]


class ParserTests(unittest.TestCase):
    def _events(self, lines):
        return list(engine.iter_events(iter(lines)))

    def test_model_captured(self):
        events = self._events(SUCCESS_STREAM)
        self.assertIn(("model", "claude-opus-4-8"), events)

    def test_text_deltas_only(self):
        deltas = [p for k, p in self._events(SUCCESS_STREAM) if k == "delta"]
        self.assertEqual("".join(deltas), "Hello there")

    def test_noise_ignored(self):
        # message_start/stop, content_block_start/stop, rate_limit, malformed,
        # and blank lines must never surface as events.
        kinds = [k for k, _ in self._events(SUCCESS_STREAM)]
        self.assertEqual(kinds.count("delta"), 2)
        self.assertEqual(kinds.count("model"), 1)
        self.assertEqual(kinds.count("done"), 1)

    def test_done_success(self):
        done = [p for k, p in self._events(SUCCESS_STREAM) if k == "done"][0]
        self.assertFalse(done["is_error"])
        self.assertEqual(done["duration_ms"], 2754)
        self.assertAlmostEqual(done["cost"], 0.0745)

    def test_done_error(self):
        done = [p for k, p in self._events(ERROR_STREAM) if k == "done"][0]
        self.assertTrue(done["is_error"])
        self.assertEqual(done["duration_ms"], 120)
        self.assertEqual(done["cost"], 0.0)


class PlainRenderTests(unittest.TestCase):
    def test_streams_text_and_trailing_newline(self):
        out = io.StringIO()
        code = engine.render_plain(engine.iter_events(iter(SUCCESS_STREAM)), out)
        self.assertEqual(out.getvalue(), "Hello there\n")
        self.assertEqual(code, 0)

    def test_error_result_sets_exit_code(self):
        out = io.StringIO()
        code = engine.render_plain(engine.iter_events(iter(ERROR_STREAM)), out)
        self.assertEqual(code, 1)
        self.assertEqual(out.getvalue(), "\n")  # trailing newline only, no text


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


if __name__ == "__main__":
    unittest.main()
