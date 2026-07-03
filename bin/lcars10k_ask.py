#!/usr/bin/env python3
"""lcars10k `lcars` engine — runs `claude -p` and renders an LCARS readout.

Pure stdlib. Invoked by lib/lcars-ask.zsh as:
    python3 bin/lcars10k_ask.py "<prompt>"
"""
import json
import os
import re
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


def render_footer(palette, is_error, elapsed, model=None):
    """Final status line."""
    model_s = f" ▐ {model}" if model else ""
    if is_error:
        status = "⚠ ALERT"
        label = f"{bg(palette['alert'])}{fg(palette['cream'])} {status} {RESET}"
    else:
        status = "COMPLETE"
        label = f"{fg(palette['pumpkin'])}▐ {status} ▐{RESET}"
    plain = f"▌ LCARS 10K ▐███▐ {status} ▐ {elapsed:.1f}s{model_s} "
    p = fg(palette["pumpkin"])
    return (f"{p}▌ LCARS 10K ▐███▐{RESET} {label} "
            f"{p}{elapsed:.1f}s{model_s} {_rule(plain)}{RESET}")


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
            label = self.status if elapsed < 1.2 else "WORKING"
            sys.stdout.write(
                "\r\033[K" + render_header(self.palette, label,
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
    got_result = False
    model = None
    streaming = False
    try:
        for kind, payload in iter_events(proc.stdout):
            if kind == "model":
                model = payload
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
            elif kind == "done":
                got_result = True
                is_error = payload["is_error"]
    finally:
        if anim.is_alive():
            anim.stop()
            anim.join()
        sys.stdout.write("\n" if streaming else "\r\033[K")
        elapsed = time.time() - start
        # No result event means the run was interrupted (Ctrl-C) or the
        # subprocess died early — never report COMPLETE in that case.
        failed = is_error or not got_result
        sys.stdout.write(render_footer(palette, failed, elapsed, model) + "\n")
        sys.stdout.write("\033[?25h")  # restore cursor
        sys.stdout.flush()
    return 1 if failed else 0


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
            sys.stdout.write(render_footer(palette, True, 0.0) + "\n")
        sys.stderr.write("lcars: `claude` not found on PATH\n")
        return 127

    # Audio hook: a future version could afplay $LCARS_SOUND_* here / on done.

    # Drain stderr on a background thread so a large stderr burst can never
    # deadlock against the stdout pipe we're reading.
    stderr_chunks = []

    def _drain_stderr():
        try:
            for line in proc.stderr:
                stderr_chunks.append(line)
        except (ValueError, OSError):
            pass
    stderr_thread = threading.Thread(target=_drain_stderr, daemon=True)
    stderr_thread.start()

    def _on_sigint(_signum, _frame):
        sys.stdout.write("\033[?25h\033[0m")  # restore cursor + reset colors
        sys.stdout.flush()
        proc.terminate()
    signal.signal(signal.SIGINT, _on_sigint)

    try:
        if sys.stdout.isatty():
            rc = run_tty(proc, palette)
        else:
            rc = render_plain(iter_events(proc.stdout), sys.stdout)
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        stderr_thread.join(timeout=1)
        if rc == 0 and proc.returncode:
            # Surface a subprocess failure that produced no result event.
            err = "".join(stderr_chunks).strip()
            if err:
                sys.stderr.write(err + "\n")
            rc = proc.returncode
        return rc
    finally:
        if sys.stdout.isatty():
            sys.stdout.write("\033[?25h\033[0m")  # ensure cursor + colors restored
            sys.stdout.flush()


if __name__ == "__main__":
    sys.exit(main(sys.argv))
