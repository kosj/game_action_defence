#!/usr/bin/env python3
"""화살 1발 사운드(WAV)를 수십 발로 겹쳐 '화살비' 사운드를 합성한다.

AI 사운드 생성기가 화살비를 자꾸 화살 한 발로만 뽑아줄 때의 플랜 B:
잘 뽑힌 화살 1발(슉-턱, 0.3~0.6초)을 입력으로 넣으면, 무작위 시차·피치·볼륨·
팬으로 N발을 겹쳐 지정 길이의 폭우 텍스처를 만든다. 초반은 성기게, 중반은
빽빽하게, 끝은 잦아들게 밀도 곡선을 준다(궁극기 지속 3초 + 테일 구조).

사용:  python3 tools/make_arrow_rain.py one_arrow.wav out_rain.wav [발수=42] [길이초=4.0]
이후:  ffmpeg -i out_rain.wav -af loudnorm=I=-14:TP=-1 -c:a libvorbis -q:a 6 \
           assets/audio/sfx_ult_arrow.ogg
"""
import random
import struct
import sys
import wave


def read_wav_mono(path: str) -> tuple[list[float], int]:
    with wave.open(path, "rb") as w:
        ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    if sw != 2:
        sys.exit(f"16-bit PCM WAV만 지원합니다 (입력: {sw * 8}-bit)")
    samples = struct.unpack(f"<{n * ch}h", raw)
    mono = [sum(samples[i : i + ch]) / ch / 32768.0 for i in range(0, len(samples), ch)]
    return mono, sr


def resample(src: list[float], ratio: float) -> list[float]:
    """선형 보간 리샘플 — ratio>1 이면 높은 피치(짧아짐)."""
    out_len = max(1, int(len(src) / ratio))
    out = []
    for i in range(out_len):
        pos = i * ratio
        j = int(pos)
        frac = pos - j
        a = src[j]
        b = src[j + 1] if j + 1 < len(src) else a
        out.append(a + (b - a) * frac)
    return out


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    src_path, out_path = sys.argv[1], sys.argv[2]
    count = int(sys.argv[3]) if len(sys.argv) > 3 else 42
    length_s = float(sys.argv[4]) if len(sys.argv) > 4 else 4.0

    src, sr = read_wav_mono(src_path)
    total = int(length_s * sr)
    left = [0.0] * total
    right = [0.0] * total

    random.seed(7)  # 결과 재현 가능
    for k in range(count):
        # 밀도 곡선: 앞 15%는 도입(성김), 15~75%는 절정, 이후는 감쇠 구간에 배치.
        u = random.random()
        if u < 0.15:
            t = random.uniform(0.0, 0.12)
        elif u < 0.85:
            t = random.uniform(0.10, 0.72)
        else:
            t = random.uniform(0.70, 0.92)
        start = int(t * total)
        arrow = resample(src, random.uniform(0.85, 1.25))  # 피치 ±수% 변주
        gain = random.uniform(0.35, 0.8)
        pan = random.uniform(-0.8, 0.8)  # 좌우로 흩뿌려 폭우의 폭을 만든다
        gl, gr = gain * (1.0 - pan) * 0.5 + gain * 0.5, gain * (1.0 + pan) * 0.5 + gain * 0.5
        for i, s in enumerate(arrow):
            p = start + i
            if p >= total:
                break
            left[p] += s * gl * 0.5
            right[p] += s * gr * 0.5

    # 소프트 클립 + 마지막 0.3초 페이드아웃.
    fade = int(0.3 * sr)
    frames = bytearray()
    for i in range(total):
        f = min(1.0, (total - i) / fade)
        for v in (left[i] * f, right[i] * f):
            v = max(-1.0, min(1.0, v))
            frames += struct.pack("<h", int(v * 32767))

    with wave.open(out_path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(bytes(frames))
    print(f"{out_path}: 화살 {count}발, {length_s:.1f}초, {sr}Hz 스테레오")


if __name__ == "__main__":
    main()
