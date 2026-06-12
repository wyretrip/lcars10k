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


def _rule(plain_prefix):
    cols = shutil.get_terminal_size((80, 24)).columns
    return "─" * max(0, cols - len(plain_prefix) - 1)


def render_header(palette, status, elapsed, frame):
    """One-line animated LCARS header (no trailing newline)."""
    block = "███" if frame % 2 == 0 else "▓▓▓"
    n = 8
    pos = frame % n
    dots = "".join("●" if i <= pos else "○" for i in range(n))
    plain = f"▌ LCARS 10K ▐{block}▐ {status:<13} {dots} {elapsed:4.1f}s "
    p, l, s = fg(palette["pumpkin"]), fg(palette["lilac"]), fg(palette["sky"])
    return (f"{p}▌ LCARS 10K ▐{block}▐{RESET} {l}{status:<13}{RESET} "
            f"{s}{dots}{RESET} {p}{elapsed:4.1f}s {_rule(plain)}{RESET}")


def render_footer(palette, is_error, elapsed, cost):
    """Final status line."""
    cost_s = f"${cost:.4f}" if isinstance(cost, (int, float)) else "—"
    if is_error:
        status = "⚠ ALERT"
        label = f"{bg(palette['alert'])}{fg(palette['cream'])} {status} {RESET}"
    else:
        status = "COMPLETE"
        label = f"{fg(palette['pumpkin'])}▐ {status} ▐{RESET}"
    plain = f"▌ LCARS 10K ▐███▐ {status} ▐ {elapsed:.1f}s ▐ {cost_s} "
    p = fg(palette["pumpkin"])
    return (f"{p}▌ LCARS 10K ▐███▐{RESET} {label} "
            f"{p}{elapsed:.1f}s ▐ {cost_s} {_rule(plain)}{RESET}")


class Animator(threading.Thread):
    """Repaints the header line in place until stopped (waiting phase only)."""
    def __init__(self, palette, start_time, status="ACCESSING CORE"):
        super().__init__(daemon=True)
        self.palette = palette
        self.start_time = start_time
        self.status = status
        self._stop = threading.Event()
        self._frame = 0

    def run(self):
        while not self._stop.is_set():
            elapsed = time.time() - self.start_time
            sys.stdout.write(
                "\r\033[K" + render_header(self.palette, self.status,
                                           elapsed, self._frame))
            sys.stdout.flush()
            self._frame += 1
            self._stop.wait(0.1)

    def stop(self):
        self._stop.set()


def run_tty(proc, palette):
    """Animate while waiting, then freeze header and stream the answer."""
    start = time.time()
    sys.stdout.write("\033[?25l")  # hide cursor
    sys.stdout.flush()
    anim = Animator(palette, start)
    anim.start()
    is_error = False
    cost = None
    streaming = False
    try:
        for kind, payload in iter_events(proc.stdout):
            if kind == "delta":
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
            elif kind == "done":
                is_error = payload["is_error"]
                cost = payload["cost"]
    finally:
        if anim.is_alive():
            anim.stop()
            anim.join()
        sys.stdout.write("\n" if streaming else "\r\033[K")
        elapsed = time.time() - start
        sys.stdout.write(render_footer(palette, is_error, elapsed, cost) + "\n")
        sys.stdout.write("\033[?25h")  # restore cursor
        sys.stdout.flush()
    return 1 if is_error else 0


def main(argv):
    if len(argv) < 2 or not argv[1].strip():
        sys.stderr.write("usage: lcars <prompt…>\n")
        return 2
    prompt = argv[1]
    palette = load_palette()
    cmd = ["claude", "-p", prompt, "--output-format", "stream-json",
           "--include-partial-messages", "--verbose"]
    try:
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, bufsize=1)
    except FileNotFoundError:
        if sys.stdout.isatty():
            sys.stdout.write(render_footer(palette, True, 0.0, None) + "\n")
        sys.stderr.write("lcars: `claude` not found on PATH\n")
        return 127

    # Audio hook: a future version could afplay $LCARS_SOUND_* here / on done.

    def _on_sigint(_signum, _frame):
        proc.terminate()
    signal.signal(signal.SIGINT, _on_sigint)

    if sys.stdout.isatty():
        rc = run_tty(proc, palette)
    else:
        rc = render_plain(iter_events(proc.stdout), sys.stdout)
    proc.wait()
    if rc == 0 and proc.returncode:
        # Surface a subprocess failure that produced no result event.
        err = (proc.stderr.read() or "").strip()
        if err:
            sys.stderr.write(err + "\n")
        rc = proc.returncode
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
