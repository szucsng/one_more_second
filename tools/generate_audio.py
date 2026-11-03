#!/usr/bin/env python3
"""Procedural audio generator for ONE MORE SECOND.

All audio in the project is synthesized from scratch (no third-party samples),
so it is safe to ship and easy to tweak. Requires Python 3 and ffmpeg (only for
OGG encoding; WAV output needs the standard library alone).

Usage: python3 tools/generate_audio.py
"""

from __future__ import annotations

import math
import random
import struct
import subprocess
import wave
from pathlib import Path

SR = 44100
ROOT = Path(__file__).resolve().parent.parent
SFX_DIR = ROOT / "assets" / "sounds"
MUSIC_DIR = ROOT / "assets" / "music"

TAU = math.pi * 2.0


def clamp(value: float, low: float = -1.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


def env_ad(t: float, duration: float, attack: float = 0.005, release: float = 0.05) -> float:
    if t < 0.0 or t >= duration:
        return 0.0
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, (duration - t) / release) if release > 0 else 1.0
    return a * r


def soft_clip(x: float) -> float:
    return math.tanh(x * 1.4) / math.tanh(1.4)


def write_wav(path: Path, samples: list[float], stereo: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as fh:
        fh.setnchannels(2 if stereo else 1)
        fh.setsampwidth(2)
        fh.setframerate(SR)
        frames = bytearray()
        for value in samples:
            frames += struct.pack("<h", int(clamp(value) * 32767))
        fh.writeframes(bytes(frames))


def make_sfx() -> None:
    SFX_DIR.mkdir(parents=True, exist_ok=True)

    # UI tap: a crisp, friendly confirmation blip.
    n = int(SR * 0.09)
    buf = []
    for i in range(n):
        t = i / SR
        freq = 880 + 440 * (t / 0.09)
        val = math.sin(TAU * freq * t) * env_ad(t, 0.09, 0.002, 0.06)
        val += random.uniform(-0.08, 0.08) * env_ad(t, 0.09, 0.0, 0.01)
        buf.append(val * 0.28)
    write_wav(SFX_DIR / "ui_tap.wav", buf)

    # Lane switch: synthetic whoosh, low and fast.
    n = int(SR * 0.15)
    buf = []
    prev = 0.0
    for i in range(n):
        t = i / SR
        p = t / 0.15
        raw = random.uniform(-1.0, 1.0)
        prev += 0.16 * (raw - prev)
        tone = math.sin(TAU * (240 + 520 * p) * t) * 0.35
        val = (prev * 0.85 + tone) * math.sin(math.pi * p) ** 1.5
        buf.append(val * 0.5)
    write_wav(SFX_DIR / "lane_switch.wav", buf)

    # Score tick: quiet bright ping.
    n = int(SR * 0.075)
    buf = []
    for i in range(n):
        t = i / SR
        val = math.sin(TAU * 1500 * t) * 0.6 + math.sin(TAU * 2250 * t) * 0.25
        buf.append(val * env_ad(t, 0.075, 0.002, 0.06) * 0.22)
    write_wav(SFX_DIR / "score.wav", buf)

    # Game over: falling saw through a soft low-pass filter.
    n = int(SR * 0.75)
    buf = []
    lp = 0.0
    for i in range(n):
        t = i / SR
        p = t / 0.75
        freq = 330 * (1.0 - p) ** 1.6 + 42
        saw = ((t * freq) % 1.0) * 2.0 - 1.0
        lp += 0.055 * (saw - lp)
        sub = math.sin(TAU * (freq * 0.5) * t) * 0.5
        impact = random.uniform(-1.0, 1.0) * math.exp(-t * 40.0) * 0.35
        buf.append((lp * 0.6 + sub * 0.45 + impact) * (1.0 - p) ** 0.7 * 0.55)
    write_wav(SFX_DIR / "game_over.wav", buf)

    # New record: rising four-note arpeggio with shimmer.
    notes = [523.25, 659.25, 783.99, 1046.5]
    total = 0.72
    n = int(SR * total)
    buf = [0.0] * n
    for idx, freq in enumerate(notes):
        start = idx * 0.11
        length = 0.34
        for i in range(int(SR * length)):
            t = i / SR
            tt = start + t
            if tt >= total:
                break
            tone = math.sin(TAU * freq * t) + 0.35 * math.sin(TAU * freq * 2 * t)
            shimmer = math.sin(TAU * freq * 3.01 * t) * 0.12
            buf[int(tt * SR)] += (tone + shimmer) * env_ad(t, length, 0.006, 0.22) * 0.16
    write_wav(SFX_DIR / "new_record.wav", buf)

    # Revive: rising energy sweep.
    n = int(SR * 0.55)
    buf = []
    for i in range(n):
        t = i / SR
        p = t / 0.55
        freq = 160 * (1.0 + p * 6.0)
        val = math.sin(TAU * freq * t) * 0.5 + math.sin(TAU * freq * 1.5 * t) * 0.2
        val *= math.sin(math.pi * min(1.0, p * 1.15)) ** 0.8
        buf.append(val * 0.42)
    write_wav(SFX_DIR / "revive.wav", buf)

    # Pause: soft two-step confirmation.
    n = int(SR * 0.16)
    buf = []
    for i in range(n):
        t = i / SR
        freq = 520 if t < 0.06 else 390
        active = 1.0 if (t < 0.09 or t > 0.105) else 0.0
        val = math.sin(TAU * freq * t) * env_ad(t, 0.16, 0.004, 0.05)
        buf.append(val * 0.2 * active)
    write_wav(SFX_DIR / "pause.wav", buf)

    # Countdown heartbeat for the revive shield / intro (subtle).
    n = int(SR * 0.2)
    buf = []
    for i in range(n):
        t = i / SR
        val = math.sin(TAU * 90 * t) * math.exp(-t * 18.0)
        val += math.sin(TAU * 180 * t) * math.exp(-t * 26.0) * 0.25
        buf.append(val * 0.35)
    write_wav(SFX_DIR / "heartbeat.wav", buf)


def make_music() -> None:
    MUSIC_DIR.mkdir(parents=True, exist_ok=True)
    bpm = 100.0
    beat = 60.0 / bpm
    bars = 8
    total_beats = bars * 4
    n = int(SR * total_beats * beat)
    left = [0.0] * n
    right = [0.0] * n
    rng = random.Random(7)

    def add_note(freq: float, start_beat: float, length_beats: float, gain: float,
                 timbre: str = "sine", pan: float = 0.0) -> None:
        start = int(start_beat * beat * SR)
        length = max(1, int(length_beats * beat * SR))
        attack = 0.012 if timbre in ("pluck", "arp") else 0.18
        release = 0.12 if timbre in ("pluck", "arp") else 0.5
        for i in range(length):
            t = i / SR
            p = t / (length / SR)
            if timbre == "saw":
                base = ((t * freq) % 1.0) * 2.0 - 1.0
                value = base * 0.5 + math.sin(TAU * freq * t) * 0.5
            elif timbre == "pluck":
                value = math.sin(TAU * freq * t) + 0.4 * math.sin(TAU * freq * 2 * t)
                value *= math.exp(-t * 7.0)
            elif timbre == "arp":
                value = math.sin(TAU * freq * t) + 0.25 * math.sin(TAU * freq * 2.01 * t)
                value *= math.exp(-t * 9.0)
            else:
                value = math.sin(TAU * freq * t) + 0.18 * math.sin(TAU * freq * 2 * t)
            a = min(1.0, t / attack) if attack > 0 else 1.0
            r = min(1.0, (1.0 - p) / max(0.001, release / (length / SR))) if release > 0 else 1.0
            value *= a * r
            idx = (start + i) % n
            left[idx] += value * gain * (1.0 - pan)
            right[idx] += value * gain * (1.0 + pan)

    def add_noise(start_beat: float, length_beats: float, gain: float, highpass: bool,
                  pan: float = 0.0) -> None:
        start = int(start_beat * beat * SR)
        length = max(1, int(length_beats * beat * SR))
        prev = 0.0
        data = []
        for i in range(length):
            t = i / SR
            raw = rng.uniform(-1.0, 1.0)
            if highpass:
                hp = raw - prev
                prev = raw
                value = hp
            else:
                prev += 0.2 * (raw - prev)
                value = prev
            data.append(value * math.exp(-t * (38.0 if highpass else 16.0)) * gain)
        for i, v in enumerate(data):
            idx = (start + i) % n
            left[idx] += v * (1.0 - pan)
            right[idx] += v * (1.0 + pan)

    chords = [
        ("Am", [110.00, 130.81, 164.81]),
        ("F", [87.31, 110.00, 130.81]),
        ("C", [130.81, 164.81, 196.00]),
        ("G", [98.00, 123.47, 146.83]),
    ]
    bass_roots = [55.00, 43.65, 65.41, 49.00]

    # Pad layer: warm, wide, side-chained feel through gain envelope.
    for bar in range(bars):
        name, chord = chords[bar % 4]
        for idx, freq in enumerate(chord):
            add_note(freq, bar * 4, 3.9, 0.055, "sine", -0.35 + idx * 0.35)
            add_note(freq * 1.005, bar * 4, 3.9, 0.04, "sine", 0.35 - idx * 0.35)

    # Bass: eighth-note pulse with an octave lift on the last eighth.
    for bar in range(bars):
        root = bass_roots[bar % 4]
        for eighth in range(8):
            freq = root * (2.0 if eighth == 7 else 1.0)
            add_note(freq, bar * 4 + eighth * 0.5, 0.44, 0.16 if eighth % 2 == 0 else 0.1, "pluck")

    # Four-on-the-floor kick and offbeat hats.
    for beat_index in range(total_beats):
        add_noise(beat_index, 0.09, 0.12, highpass=False)
        add_note(52.0, beat_index, 0.16, 0.2, "sine")
        if beat_index % 2 == 1:
            add_noise(beat_index + 0.5, 0.05, 0.055, highpass=True, pan=0.25)

    # Snare/clap on the backbeat.
    for bar in range(bars):
        for beat_offset in (1, 3):
            add_noise(bar * 4 + beat_offset, 0.11, 0.075, highpass=True, pan=-0.15)

    # Arp: sixteenth-note chord tones with a dotted-eighth echo.
    arp_pattern = [0, 2, 1, 2, 0, 2, 1, 2]
    for bar in range(bars):
        _, chord = chords[bar % 4]
        base = chord[0] * 4.0
        for step in range(16):
            if step % 2 == 1 and bar % 2 == 1:
                continue
            freq = base * (1.0 if arp_pattern[step % 8] == 0 else (1.25 if arp_pattern[step % 8] == 1 else 1.5))
            start = bar * 4 + step * 0.25
            add_note(freq, start, 0.22, 0.045, "arp", -0.4 if step % 2 == 0 else 0.4)
            add_note(freq, start + 0.375, 0.22, 0.018, "arp", 0.4 if step % 2 == 0 else -0.4)

    # Sparse lead motif in the second half.
    lead = [
        (16, 0.0, 880.0), (16, 1.5, 659.25), (17, 0.0, 783.99),
        (18, 0.0, 659.25), (18, 1.5, 880.0), (19, 0.0, 987.77),
        (20, 0.0, 783.99), (20, 1.0, 659.25), (21, 0.0, 880.0),
        (22, 0.0, 1046.5), (22, 1.5, 880.0), (23, 0.0, 783.99),
    ]
    for bar, offset, freq in lead:
        add_note(freq, bar * 4 + offset, 1.1, 0.05, "sine", 0.05)
        add_note(freq, bar * 4 + offset + 0.5, 0.7, 0.02, "sine", -0.5)

    peak = max(max(abs(v) for v in left), max(abs(v) for v in right), 1e-9)
    scale = 0.72 / peak
    stereo = []
    for l, r in zip(left, right):
        stereo.append(soft_clip(l * scale) * 0.95)
        stereo.append(soft_clip(r * scale) * 0.95)

    wav_path = MUSIC_DIR / "neon_drive.wav"
    write_wav(wav_path, stereo, stereo=True)
    ogg_path = MUSIC_DIR / "neon_drive.ogg"
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "vorbis", "-strict", "experimental", "-b:a", "144k", str(ogg_path)],
            check=True,
        )
        wav_path.unlink()
        print(f"wrote {ogg_path.relative_to(ROOT)}")
    except (OSError, subprocess.CalledProcessError) as exc:
        print(f"ffmpeg not available ({exc}); kept WAV fallback {wav_path.relative_to(ROOT)}")


if __name__ == "__main__":
    make_sfx()
    make_music()
    print("audio generated")
