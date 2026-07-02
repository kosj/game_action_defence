#!/usr/bin/env python3
"""DeadLine BGM generator — seamless loops, 22050 Hz mono 16-bit WAV.

- bgm_title.wav: dark ambient (A minor). Drones with integer-cycle LFOs +
  sparse bell melody; one-shots render wrap-around so the loop is seamless.
- bgm_game.wav: tense action loop (D minor, 126 BPM, 8 bars).
  Four-on-floor kick, snare 2&4, 8th hats, driving bass, quiet 16th arp.
"""
import math, wave, struct, random

SR = 22050
random.seed(42)

def semitone(base, st):
    return base * (2 ** (st / 12.0))

def render_wav(path, buf, peak=0.72):
    # soft clip + normalize
    m = max(1e-9, max(abs(x) for x in buf))
    out = []
    for x in buf:
        v = math.tanh((x / m) * 1.35) * peak
        out.append(int(max(-1.0, min(1.0, v)) * 32767))
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(struct.pack("<%dh" % len(out), *out))
    print(f"{path}: {len(out)/SR:.2f}s, {len(out)*2/1024:.0f} KB")

def add_wrap(buf, start_s, samples):
    """Add a one-shot at start_s, wrapping past the loop end back to the start."""
    n = len(buf)
    s0 = int(start_s * SR)
    for i, v in enumerate(samples):
        buf[(s0 + i) % n] += v

# ───────────────────────── title: dark ambient ─────────────────────────
def gen_title():
    T = 24.0
    N = int(T * SR)
    buf = [0.0] * N

    # integer-cycle LFOs keep drones phase-continuous across the loop point
    def lfo(t, cycles, lo, hi, phase=0.0):
        return lo + (hi - lo) * 0.5 * (1 + math.sin(2 * math.pi * (cycles * t / T + phase)))

    def snap(f):
        # 루프 길이 T 에 정수 사이클이 되도록 주파수를 미세 스냅 — 심에서 위상 클릭 방지
        return round(f * T) / T

    fA1, fA2, fE2, fShim = snap(55.0), snap(110.0), snap(82.41), snap(220.7)
    for i in range(N):
        t = i / SR
        v = 0.0
        v += 0.30 * lfo(t, 2, 0.55, 1.0) * math.sin(2 * math.pi * fA1 * t)          # A1 drone
        v += 0.20 * lfo(t, 3, 0.5, 1.0, 0.25) * math.sin(2 * math.pi * fA2 * t)     # A2
        v += 0.11 * lfo(t, 2, 0.4, 1.0, 0.5) * math.sin(2 * math.pi * fE2 * t)      # E2 (5th)
        # detuned shimmer an octave up — slow beat frequency adds unease
        v += 0.05 * lfo(t, 4, 0.3, 1.0, 0.1) * math.sin(2 * math.pi * fShim * t)
        buf[i] += v

    # wind: one-pole lowpassed noise. 필터에 상태가 있어 그대로는 심에서 값이 점프하므로,
    # N+K 샘플을 만들고 초과분(K)을 머리에 크로스페이드로 접어 넣어 원형 연속으로 만든다.
    # (드론은 스냅된 정수 사이클이라 그 자체로 연속, 벨은 add_wrap 이 랩 처리 — 바람만 문제였다)
    K = int(0.05 * SR)
    wind = []
    lp = 0.0
    for i in range(N + K):
        lp += 0.02 * (random.uniform(-1, 1) - lp)
        wind.append(lp)
    for j in range(K):
        w = j / K
        wind[j] = wind[j] * w + wind[N + j] * (1.0 - w)
    for i in range(N):
        t = i / SR
        buf[i] += wind[i] * 0.35 * lfo(t, 5, 0.3, 1.0, 0.7)

    # sparse bell melody (Am pentatonic-ish), wrap-around so tails cross the seam
    def bell(freq, dur=3.0, amp=0.20):
        n = int(dur * SR)
        s = []
        for i in range(n):
            t = i / SR
            env = math.exp(-t * 1.9)
            a = math.sin(2 * math.pi * freq * t) * env
            a += 0.35 * math.sin(2 * math.pi * freq * 2.76 * t) * math.exp(-t * 4.5)
            a += 0.12 * math.sin(2 * math.pi * freq * 4.07 * t) * math.exp(-t * 7.0)
            atk = min(1.0, t / 0.012)
            s.append(a * amp * atk)
        return s

    melody = [
        (0.5, 220.00), (3.5, 261.63), (6.5, 329.63), (9.5, 293.66),
        (12.5, 261.63), (15.5, 246.94), (18.5, 196.00), (21.5, 220.00),
    ]
    for start, f in melody:
        add_wrap(buf, start, bell(f))
    # 낮은 응답구(콜&리스폰스) — 멜로디 사이 빈 공간을 저음 벨이 받친다
    for start, f in [(2.0, 110.0), (11.0, 130.81), (20.0, 110.0)]:
        add_wrap(buf, start, bell(f, 4.0, 0.10))

    render_wav("assets/audio/bgm_title.wav", buf, peak=0.62)

# ───────────────────────── game: action loop ─────────────────────────
def gen_game():
    BPM = 126.0
    beat = 60.0 / BPM
    eighth = beat / 2
    sixteenth = beat / 4
    bars = 8
    T = bars * 4 * beat
    N = int(round(T * SR))
    buf = [0.0] * N

    D2, Bb1, F2, C2 = 73.42, 58.27, 87.31, 65.41
    chords = [D2, D2, Bb1, Bb1, F2, F2, C2, C2]           # 2 bars each: i–VI–III–VII
    minor = [True, True, False, False, False, False, False, False]

    def kick(amp=1.0):
        n = int(0.14 * SR)
        s = []
        ph = 0.0
        for i in range(n):
            t = i / SR
            f = 45 + 115 * math.exp(-t * 34)               # pitch sweep 160->45
            ph += 2 * math.pi * f / SR
            s.append(amp * math.sin(ph) * math.exp(-t * 22))
        return s

    def snare(amp=0.5):
        n = int(0.11 * SR)
        s = []
        for i in range(n):
            t = i / SR
            v = random.uniform(-1, 1) * math.exp(-t * 38)
            v += 0.5 * math.sin(2 * math.pi * 190 * t) * math.exp(-t * 55)
            s.append(amp * v)
        return s

    def hat(amp=0.18):
        n = int(0.03 * SR)
        prev = 0.0
        s = []
        for i in range(n):
            t = i / SR
            x = random.uniform(-1, 1)
            v = x - prev                                    # crude highpass
            prev = x
            s.append(amp * v * math.exp(-t * 90))
        return s

    def bass_note(freq, dur, amp=0.55):
        n = int(dur * SR)
        s = []
        for i in range(n):
            t = i / SR
            env = math.exp(-t * 6.5) * min(1.0, t / 0.004)
            v = 0.0
            for h in range(1, 6):                           # saw-ish, gentle lowpass
                v += math.sin(2 * math.pi * freq * h * t) / (h ** 1.3)
            s.append(amp * v * env)
        return s

    def arp_note(freq, dur, amp=0.15):
        n = int(dur * SR)
        s = []
        for i in range(n):
            t = i / SR
            env = math.exp(-t * 14) * min(1.0, t / 0.003)
            v = math.sin(2 * math.pi * freq * t) + 0.4 * math.sin(2 * math.pi * freq * 2 * t)
            s.append(amp * v * env)
        return s

    total_beats = bars * 4
    for b in range(total_beats):
        t0 = b * beat
        add_wrap(buf, t0, kick(0.95))                       # four-on-floor
        if b % 4 in (1, 3):
            add_wrap(buf, t0, snare(0.5))
    for e in range(bars * 8):                               # hats on 8ths, offbeat accent
        add_wrap(buf, e * eighth, hat(0.24 if e % 2 == 1 else 0.13))

    # bass: driving 8ths, per-bar pattern in semitones from chord root
    pattern = [0, 0, 12, 0, 0, 12, 7, 10]
    for bar in range(bars):
        root = chords[bar]
        for e in range(8):
            st = pattern[e]
            add_wrap(buf, bar * 4 * beat + e * eighth, bass_note(semitone(root, st), eighth * 0.92))

    # arp: quiet 16ths two octaves up, chord tones up-down
    for bar in range(bars):
        root4 = chords[bar] * 4
        third = 3 if minor[bar] else 4
        tones = [0, third, 7, 12, 7, third]
        for x in range(16):
            f = semitone(root4, tones[x % len(tones)])
            add_wrap(buf, bar * 4 * beat + x * sixteenth, arp_note(f, sixteenth * 0.85))

    render_wav("assets/audio/bgm_game.wav", buf, peak=0.70)

gen_title()
gen_game()
