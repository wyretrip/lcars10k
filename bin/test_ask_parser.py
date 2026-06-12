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


if __name__ == "__main__":
    unittest.main()
