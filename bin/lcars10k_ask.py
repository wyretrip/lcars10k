#!/usr/bin/env python3
"""lcars10k `lcars` engine — runs `claude -p` and renders an LCARS readout.

Pure stdlib. Invoked by lib/lcars-ask.zsh as:
    python3 bin/lcars10k_ask.py "<prompt>"
"""
import json
import os
import shutil
import signal
import subprocess
import sys
import threading
import time

# Fallback palette mirrors lib/lcars-palette.zsh. Live values arrive via the
# LCARS_C_* env vars exported by lib/lcars-ask.zsh and win over these.
_DEFAULT_PALETTE = {
    "pumpkin": "#F5B86E",
    "peach":   "#D8C4DE",
    "lilac":   "#7C74A2",
    "sky":     "#A2A8F0",
    "alert":   "#60463E",
    "cream":   "#FFE6D5",
}

RESET = "\033[0m"


def hex_to_rgb(hexstr):
    h = hexstr.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def fg(hexstr):
    r, g, b = hex_to_rgb(hexstr)
    return f"\033[38;2;{r};{g};{b}m"


def bg(hexstr):
    r, g, b = hex_to_rgb(hexstr)
    return f"\033[48;2;{r};{g};{b}m"


def load_palette(env=None):
    env = os.environ if env is None else env
    return {
        name: env.get(f"LCARS_C_{name.upper()}", default)
        for name, default in _DEFAULT_PALETTE.items()
    }
