#!/usr/bin/env python3
"""Unit tests for the lcars10k ask engine (pure logic only)."""
import io
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lcars10k_ask as engine


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


if __name__ == "__main__":
    unittest.main()
