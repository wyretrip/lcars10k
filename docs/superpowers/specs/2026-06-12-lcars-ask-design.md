# LCARS-10K `lcars` — Ask Claude readout

**Date:** 2026-06-12
**Status:** Approved (design)
**Lives in:** the `lcars10k` suite at `~/.lcars10k/`

## Summary

Add a `lcars` shell command to the lcars10k suite. Running `lcars <words…>`
forwards the rest of the line to `claude -p` (print/headless mode) and renders
a compact, animated LCARS readout in the terminal while Claude's answer streams
in live beneath it. The readout reuses the suite's existing color palette so it
looks native to lcars10k.

## Goals

- One-shot, ergonomic: `lcars how do I rebase onto main` just works — no quoting
  required, the whole line becomes the prompt.
- A "the ship's computer is answering you" effect: an animated, in-flow LCARS
  header with the answer streaming below it.
- Visual consistency with lcars10k: same palette, same red-alert convention.
- Robust in scripts/pipes: degrade to clean plain text when not on a TTY.

## Non-goals

- No multi-turn / conversation continuity (each call is a fresh one-shot).
- No audio in this version (a hook is left for the existing `LCARS_SOUND_*`
  files if desired later).
- No model selection flags; use whatever `claude` is configured to default to.
- No full-screen TUI takeover; the readout stays in the normal scroll flow.

## User experience

```
$ lcars summarize the difference between rebase and merge
▌ LCARS 10K ▐███▐ WORKING ▐ ●●●●○○○○ ▐ 2.4s ──────────────────────
  Rebase rewrites your branch's commits on top of the target…
  (answer streams in here, word-wrapped to terminal width)
▌ LCARS 10K ▐███▐ COMPLETE ▐ 3.1s ▐ $0.004 ───────────────────────
```

- The header line animates in place (sweeping bars, blinking block, progress
  dots, elapsed-time counter, cycling status text).
- The answer text streams token-by-token below the header and scrolls normally.
- On completion the header repaints to `COMPLETE` and a thin footer shows
  elapsed time and reported cost.
- `lcars` with no arguments prints a short LCARS-styled usage line and exits 2.

## Architecture

A thin zsh function joins the line and calls a Python engine. Python owns all
rendering and process management.

```
args → zsh `lcars` fn (join + palette env) → python engine
        → spawn `claude -p … --output-format stream-json --include-partial-messages --verbose`
        → read stdout lines → parse JSON
             ├─ animator thread: repaint compact LCARS header in place
             └─ main thread: print text_delta tokens live; detect result/error
        → footer (elapsed, cost) | ALERT header on error
```

### Component 1 — `lib/lcars-ask.zsh`

Defines the top-level `lcars` shell function. Loaded by `lcars10k.zsh-theme`
alongside the other `lib/*.zsh` modules (so no `.zshrc` change is needed — the
theme is already sourced from `~/.zshrc`).

Responsibilities:

- Join all positional args into a single prompt string (`"$*"`). With zero
  args, print the usage line to stderr and `return 2`.
- Read the live palette from the `${LCARS_COLORS[...]}` associative array
  (already global because `lib/lcars-palette.zsh` is sourced by the theme) and
  export each as an env var the engine reads: `LCARS_C_PUMPKIN`,
  `LCARS_C_PEACH`, `LCARS_C_LILAC`, `LCARS_C_SKY`, `LCARS_C_ALERT`,
  `LCARS_C_CREAM`. If `LCARS_COLORS` is unset (suite not loaded), skip — the
  engine has built-in fallbacks.
- Invoke the engine: `python3 "${_LCARS_ROOT:-$HOME/.lcars10k}/bin/lcars10k-ask.py" "$prompt"`
  and propagate its exit code.

### Component 2 — `bin/lcars10k-ask.py`

The engine. New `bin/` directory in the repo. Pure stdlib Python 3 (ships with
macOS); no third-party deps.

- **Palette resolution:** read `LCARS_C_*` env vars; fall back to the current
  hard-coded hex values (see Palette section). Convert each hex to a 24-bit
  ANSI SGR sequence (`\033[38;2;R;G;Bm` for fg, `48;2;` for bg).
- **TTY check:** if `sys.stdout.isatty()` is false, run in plain mode — no
  threads, no ANSI, no header; just stream `text_delta` text to stdout and exit
  with the subprocess's status. This keeps `lcars … | grep`, `> file`, and
  `$(lcars …)` clean.
- **Spawn:** `subprocess.Popen(["claude", "-p", prompt, "--output-format",
  "stream-json", "--include-partial-messages", "--verbose"], stdout=PIPE,
  stderr=PIPE, text=True)`. If `claude` is not found (`FileNotFoundError`),
  paint the ALERT header with a clear message and exit non-zero.
- **Animator thread (TTY mode):** a daemon thread repaints a single header line
  in place using `\r` + clear-to-end-of-line, at a fixed cadence (~10 fps). It
  reads shared state (current status label, start time) under a lock. Status
  labels cycle/advance: `ACCESSING CORE` → `WORKING` → `RECEIVING` (set by the
  main thread when the first text delta arrives) → `COMPLETE`/`ALERT` (final).
  The header includes animated bars, a blinking block, progress dots, and an
  elapsed-seconds counter.
- **Main thread parse loop:** iterate stdout lines, `json.loads` each. Handle:
  - `type=="system" && subtype=="init"` → capture `model` (shown in footer).
  - `type=="stream_event" && event.type=="content_block_delta" &&
    event.delta.type=="text_delta"` → on first one, flip status to
    `RECEIVING` and move the cursor below the header; append/print
    `event.delta.text` with word-wrapping to terminal width.
  - `type=="result"` → stop animator; if `is_error` truthy, ALERT; else
    `COMPLETE`. Capture `duration_ms` and `total_cost_usd` for the footer.
  - Everything else (hook events, `rate_limit_event`, `assistant`/`message_*`
    wrappers, malformed/non-JSON lines) → ignored.
- **Footer:** thin LCARS rule with `COMPLETE`, elapsed time (s), and cost
  (`$total_cost_usd`, formatted). ALERT footer on error.
- **Signals:** install a SIGINT handler that terminates the subprocess, joins
  the animator, restores the cursor (`\033[?25h`) and resets SGR (`\033[0m`),
  then exits.
- **Cleanup:** a `finally` always restores cursor + SGR even on unexpected
  errors, so the terminal is never left in a broken state.
- **Audio hook:** a clearly-commented no-op point where a future version could
  `afplay` the existing `LCARS_SOUND_*` files on completion/error. Not wired in
  this version.

### Component 3 — `lib/lcars-cli.zsh` (minor edit)

Add one line to the `lcars10k` help text documenting the new top-level `lcars`
command, for discoverability. The command itself is the standalone `lcars`
function (not a `lcars10k` subcommand), matching the user's request for a
`lcars` alias. No behavior change to the dispatcher.

## Palette

Sourced from `lib/lcars-palette.zsh`, rendered as 24-bit truecolor ANSI. The
engine uses these as fallback defaults; live shell values (via `LCARS_C_*`)
override them.

| Role                 | Name      | Hex       |
|----------------------|-----------|-----------|
| Header bars / status | `pumpkin` | `#F5B86E` |
| Accent               | `peach`   | `#D8C4DE` |
| Label text           | `lilac`   | `#7C74A2` |
| Progress dots        | `sky`     | `#A2A8F0` |
| Error bg             | `alert`   | `#60463E` |
| Error fg             | `cream`   | `#FFE6D5` |

Error/ALERT state uses `alert` background + `cream` foreground, matching the
convention in `lib/lcars-redalert.zsh` (coffee, not generic red).

## `claude -p` stream contract

Verified against `claude` v2.1.173 with `--output-format stream-json
--include-partial-messages --verbose`. Relevant line types:

- `{"type":"system","subtype":"init","model":"…", …}` — once, near the start.
- `{"type":"stream_event","event":{"type":"content_block_delta",
   "delta":{"type":"text_delta","text":"…"}}}` — the live answer tokens.
- `{"type":"result","subtype":"success"|…,"is_error":false,"result":"…",
   "duration_ms":N,"total_cost_usd":N, …}` — final summary.

All other line types are noise and ignored: `hook_started`/`hook_response`/
`hook_progress`/`status` system events (which can be large), `rate_limit_event`,
`assistant`, and `message_start`/`message_delta`/`message_stop`/
`content_block_start`/`content_block_stop` wrappers.

## Error handling

- `claude` not on PATH → ALERT header + message, exit non-zero.
- Subprocess exits non-zero / `result.is_error` true → ALERT header; print any
  captured stderr / error text below; propagate the exit code.
- Malformed or non-JSON stdout lines → skipped, do not crash the parser.
- SIGINT (Ctrl-C) → kill subprocess, restore terminal, exit.
- Any unexpected exception → `finally` restores cursor + SGR.

## Testing

- **`tests/test_ask.zsh`** (zsh, matches existing `tests/` pattern, registered
  in `tests/run-tests.zsh` like the others):
  - arg-joining produces the expected single prompt string;
  - no-args prints usage and returns 2;
  - palette env vars are exported from `LCARS_COLORS` before the engine call.
  These test the wrapper without invoking the real `claude` (the engine call is
  stubbed / `claude` shadowed).
- **`bin/test_ask_parser.py`** (Python `unittest`) over a captured fixture of
  the real stream (text deltas + result + representative noise lines):
  - assembled answer text equals the concatenated `text_delta`s;
  - noise lines (hooks, rate-limit, message wrappers, a malformed line) are
    ignored and do not crash;
  - final state is `COMPLETE` for `is_error:false` and `ALERT` for an error
    result;
  - footer extracts `duration_ms` and `total_cost_usd` correctly.
  A `Makefile` target / `run-tests.zsh` hook runs the Python tests too.
- The animator (timing/threads/ANSI) and the full live path are verified by
  running `lcars` for real in a terminal.

## Git

Commit only the new and changed files into the `~/.lcars10k` repo:
`lib/lcars-ask.zsh`, `bin/lcars10k-ask.py`, `bin/test_ask_parser.py`,
`tests/test_ask.zsh`, the `lib/lcars-cli.zsh` help edit, the `run-tests.zsh`
registration, and this spec. Leave any pre-existing uncommitted change in the
repo untouched.
