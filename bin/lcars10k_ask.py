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


def _valid_hex(value):
    """True if value is a #RRGGBB / RRGGBB hex color string."""
    if not isinstance(value, str):
        return False
    h = value.lstrip("#")
    if len(h) != 6:
        return False
    try:
        int(h, 16)
    except ValueError:
        return False
    return True


def load_palette(env=None):
    env = os.environ if env is None else env
    out = {}
    for name, default in _DEFAULT_PALETTE.items():
        value = env.get(f"LCARS_C_{name.upper()}", default)
        out[name] = value if _valid_hex(value) else default
    return out


def iter_events(lines):
    """Yield semantic events from a claude stream-json line iterator.

    Yields:
      ("model", str)
      ("delta", str)
      ("done", {"is_error": bool, "duration_ms": int|None, "cost": float|None})
    All other line types, malformed JSON, and blank lines are ignored.
    """
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except (ValueError, TypeError):
            continue
        if not isinstance(obj, dict):
            continue
        kind = obj.get("type")
        if kind == "system" and obj.get("subtype") == "init":
            model = obj.get("model")
            if model:
                yield ("model", model)
        elif kind == "stream_event":
            event = obj.get("event") or {}
            if event.get("type") == "content_block_delta":
                delta = event.get("delta") or {}
                if delta.get("type") == "text_delta":
                    text = delta.get("text", "")
                    if text:
                        yield ("delta", text)
        elif kind == "result":
            yield ("done", {
                "is_error": bool(obj.get("is_error")),
                "duration_ms": obj.get("duration_ms"),
                "cost": obj.get("total_cost_usd"),
            })


def render_plain(events, out):
    """Non-TTY path: stream answer text only. Returns exit code (0 ok, 1 err)."""
    is_error = False
    for kind, payload in events:
        if kind == "delta":
            out.write(payload)
            out.flush()
        elif kind == "done":
            is_error = payload["is_error"]
    out.write("\n")
    out.flush()
    return 1 if is_error else 0
