#!/usr/bin/env bash
# scripts/install-sounds.sh — download TNG-flavored sound samples for lcars10k.
#
# CBS/Paramount audio is fetched for personal/fan use. The repo itself ships no
# Star Trek audio. If you redistribute lcars10k, do so without populated sounds/.

set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/_lib.sh"
SOUNDS_DIR="$SCRIPT_DIR/../sounds"

# role -> URL. Verified at install-script authoring time (2026-06-08).
# Source: TrekCore audio archive (https://www.trekcore.com/audio/)
# Parallel arrays: LCARS_FILES[i] -> LCARS_URLS[i]
LCARS_FILES=(
    "computer-boot.wav"
    "beep-chirp.wav"
    "error-warble.wav"
    "task-complete.wav"
)
LCARS_URLS=(
    "https://www.trekcore.com/audio/computer/computerbeep_1.mp3"
    "https://www.trekcore.com/audio/computer/computerbeep_12.mp3"
    "https://www.trekcore.com/audio/computer/input_failed_clean.mp3"
    "https://www.trekcore.com/audio/computer/computerbeep_6.mp3"
)

# Target RMS loudness (dBFS) every sample is matched to, so no single event
# (startup, error) drowns out the frequent success chirp. Peak normalisation
# alone doesn't do this: dense/sustained samples sit far louder in RMS than
# short transients at the same peak. ~-15 dB matches the quietest TNG clips
# (beep-chirp, task-complete) and leaves comfortable headroom below 0 dBFS.
TARGET_RMS_DB=-15.35

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

mkdir -p "$SOUNDS_DIR"

echo "Downloading TNG sound samples into $SOUNDS_DIR"
echo "(audio is CBS/Paramount IP, fetched for personal use)"
echo

for i in "${!LCARS_FILES[@]}"; do
    filename="${LCARS_FILES[$i]}"
    url="${LCARS_URLS[$i]}"
    target="$SOUNDS_DIR/$filename"

    if [[ -f "$target" && $FORCE -eq 0 ]]; then
        echo "  skip: $filename (exists; pass --force to redownload)"
        continue
    fi

    echo "  fetch: $filename"
    # download to tmp, convert MP3->WAV if sox is installed
    tmp="$(mktemp -t lcars-sound).$i"
    if ! curl -sLfo "$tmp" "$url"; then
        echo "    ERROR: failed to fetch $url" >&2
        rm -f "$tmp"
        continue
    fi
    if command -v sox >/dev/null 2>&1; then
        # TrekCore URLs serve MP3 regardless of target extension. Tell sox
        # explicitly with -t mp3 so it doesn't try to detect from $tmp's
        # extension-less name. Output is real PCM WAV, peak-capped at -1 dB.
        sox -t mp3 "$tmp" -r 44100 -c 2 "$target" norm -1
        # Match perceived loudness across all samples: measure this file's RMS
        # and shift it onto TARGET_RMS_DB. Dense clips get attenuated; sharp,
        # transient clips (whose RMS sits far below their peak) need gaining up,
        # which would push peaks past 0 dBFS — so use sox's limiter (gain -l) to
        # tame those peaks instead of hard-clipping. On the attenuated files the
        # limiter is a no-op.
        rms="$(sox "$target" -n stats 2>&1 | awk '/^RMS lev dB/ {print $4; exit}')"
        if [[ -n "$rms" ]]; then
            delta="$(awk -v t="$TARGET_RMS_DB" -v r="$rms" 'BEGIN { printf "%.2f", t - r }')"
            sox "$target" "$tmp.norm.wav" gain -l "$delta"
            mv "$tmp.norm.wav" "$target"
        fi
    else
        # No sox — the file stays MP3 (just renamed to .wav). macOS afplay and
        # the Linux ffplay/mpv/play backends handle MP3 transparently; paplay/
        # aplay do not, so install sox for a real PCM WAV + loudness match.
        mv "$tmp" "$target"
        echo "    note: sox not installed; sound is raw MP3 and unnormalised."
        echo "          $(lcars_sox_hint) && rerun with --force to fix."
    fi
    rm -f "$tmp"
done

echo
echo "Done. Set LCARS_SOUNDS=1 in ~/.lcars10krc to enable playback."
