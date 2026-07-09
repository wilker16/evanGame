#!/usr/bin/env python3
"""Generate retro sound effects for the game as 16-bit mono WAVs.

Usage: python3 tools/make_sfx.py   (writes audio/*.wav)
No external assets needed - everything is synthesized.
"""
import math
import random
import struct
import wave

RATE = 22050
ROOT = __file__.rsplit("/tools/", 1)[0]
random.seed(7)


def save(name, samples):
    path = f"{ROOT}/audio/{name}.wav"
    peak = max(1e-9, max(abs(s) for s in samples))
    norm = 0.85 / peak if peak > 0.85 else 1.0
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1, min(1, s * norm)) * 32767)) for s in samples))
    print(f"{name}.wav  {len(samples)/RATE:.2f}s")


def env(i, n, attack=0.01, decay=None):
    t = i / n
    a = min(1.0, (i / RATE) / attack) if attack > 0 else 1.0
    d = (1 - t) ** (decay if decay is not None else 2)
    return a * d


def noise():
    return random.uniform(-1, 1)


def punch():
    n = int(0.16 * RATE)
    out, lp = [], 0.0
    for i in range(n):
        t = i / RATE
        lp += 0.25 * (noise() - lp)  # muffled thud noise
        thump = math.sin(2 * math.pi * (90 - 200 * t) * t)
        out.append((lp * 0.8 + thump * 0.9) * env(i, n, 0.002, 3))
    return out


def crumble():
    n = int(0.5 * RATE)
    out, lp = [], 0.0
    for i in range(n):
        t = i / RATE
        rumble = math.sin(2 * math.pi * 55 * t + 3 * math.sin(2 * math.pi * 7 * t))
        lp += 0.4 * (noise() - lp)
        crackle = noise() if random.random() < 0.4 else 0.0
        out.append((lp * 0.7 + crackle * 0.35 + rumble * 0.4) * env(i, n, 0.005, 2))
    return out


def boom():
    n = int(0.9 * RATE)
    out, lp = [], 0.0
    for i in range(n):
        t = i / RATE
        f = 70 * math.exp(-2.5 * t) + 32
        lp += 0.12 * (noise() - lp)
        out.append((math.sin(2 * math.pi * f * t) * 1.0 + lp * 0.5) * env(i, n, 0.004, 2.5))
    return out


def pew():
    n = int(0.18 * RATE)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / n
        f = 950 - 650 * t
        ph += f / RATE
        sq = 1.0 if (ph % 1.0) < 0.5 else -1.0
        out.append(sq * 0.5 * env(i, n, 0.004, 1.5))
    return out


def hurt():
    n = int(0.28 * RATE)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / n
        f = 420 - 260 * t
        ph += f / RATE
        saw = 2 * (ph % 1.0) - 1
        out.append(saw * 0.6 * env(i, n, 0.003, 1.8))
    return out


def roar():
    n = int(0.7 * RATE)
    out, lp = [], 0.0
    ph = 0.0
    for i in range(n):
        t = i / RATE
        f = 95 + 25 * math.sin(2 * math.pi * 9 * t)
        ph += f / RATE
        saw = 2 * (ph % 1.0) - 1
        lp += 0.3 * (noise() - lp)
        a = min(1.0, t / 0.08) * (1 - (i / n)) ** 1.2
        out.append((saw * 0.8 + lp * 0.5) * a)
    return out


def fanfare():
    notes = [262, 330, 392, 523, 392, 523, 659, 784]
    dur = [0.12, 0.12, 0.12, 0.2, 0.12, 0.12, 0.15, 0.5]
    out = []
    for f, d in zip(notes, dur):
        n = int(d * RATE)
        for i in range(n):
            t = i / RATE
            ph = f * t
            sq = 0.6 if (ph % 1.0) < 0.5 else -0.6
            sq += 0.25 * math.sin(2 * math.pi * f * 2 * t)
            out.append(sq * env(i, n, 0.005, 1.2))
    return out


def dizzy():
    n = int(0.7 * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        f = 600 * math.exp(-1.8 * t) + 120 + 60 * math.sin(2 * math.pi * 11 * t)
        out.append(math.sin(2 * math.pi * f * t) * 0.5 * env(i, n, 0.005, 1.2))
    return out


def jump():
    n = int(0.16 * RATE)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / n
        f = 220 + 480 * t
        ph += f / RATE
        out.append(math.sin(2 * math.pi * ph) * 0.45 * env(i, n, 0.004, 1.2))
    return out


if __name__ == "__main__":
    save("punch", punch())
    save("crumble", crumble())
    save("boom", boom())
    save("pew", pew())
    save("hurt", hurt())
    save("roar", roar())
    save("fanfare", fanfare())
    save("dizzy", dizzy())
    save("jump", jump())
