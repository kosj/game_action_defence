#!/usr/bin/env python3
"""BGM 을 '이음매 없는 루프 구간'으로 줄인다.

왜
--
웹 pck 는 전량 받아야 첫 프레임이 뜬다. BGM 3곡이 8.3MB 로 pck 의 약 70% 였고, 비트레이트는
이미 96kb/s 모노까지 짜여 있어 남은 수단은 길이뿐이었다(3:08 / 5:48 / 3:11).

어떻게
------
1. 프레임별 스펙트럼 특징의 자기상관으로 곡의 **반복 주기 P** 를 찾고, 루프 길이는 P 의
   정수배 중 목표 구간(기본 55~95초)에 드는 것만 후보로 쓴다 — 마디가 맞아야 되돌아갈 때
   음악적으로 튀지 않는다.
2. 파형은 정확히 안 맞으므로 **크로스페이드**로 마감한다. 구간 [S,E) 를 뽑고 앞머리 xf 초를
   "원곡의 E 이후 소리 → S 이후 소리" 로 섞으면, 끝(E-1)에서 처음으로 돌아갈 때 파형이
   끊기지 않는다.
3. 후보 선택은 **검증에 쓰는 값을 그대로 최적화한다.** 세 가지를 본다.
     · 클릭 — 되돌아가는 지점의 파형 단차 / 구간 RMS
     · 튐   — 전환 구간의 스펙트럼 변화량이 **이 루프 구간 자체**의 변화량 분포에서 몇 % 지점인가
     · 음량 — 조용한 대목만 잘라내면 그 곡만 작게 들린다. 대부분은 게인으로 맞출 수 있으므로
              (원곡 피크를 넘지 않는 선까지) 게인 후에도 남는 차이만 감점한다.

여기까지 오는 데 같은 실수를 세 번 했다. **선택 기준과 검증 기준이 다르면 "점수는 좋은데
들으면 튀는" 지점을 고른다.** 기준 분포도 마찬가지다 — 원곡 전체가 아니라 루프 구간이
기준이어야 한다. 플레이어가 반복해서 듣는 것이 그 구간이고 귀는 그 변화 폭에 적응한다.

크로스페이드는 파형을 바꾸므로 재인코딩이 필요하다(스트림 복사로는 못 한다). 원본이 이미
96kb/s 손실 압축이라 2세대 손실이 생기지만, 실측상 멜 거리 0.7dB 수준으로 작다(같은 코덱을
다시 쓰면 탠덤 손실이 작다 — Ogg Vorbis 로 바꾸면 오히려 2.0dB 로 나빠졌다).

    python3 tools/make_bgm_loop.py assets/audio/bgm_title.mp3          # 미리보기(분석만)
    python3 tools/make_bgm_loop.py --write assets/audio/bgm_*.mp3      # 실제 교체
"""
from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys

try:
    import numpy as np
    import imageio_ffmpeg
except ImportError:
    print("필요: pip install numpy imageio-ffmpeg", file=sys.stderr)
    raise

FF = imageio_ffmpeg.get_ffmpeg_exe()
SR = 44100
A_SR = 22050        # 후보 추리기용 샘플레이트(속도)
HOP = 512           # 특징 프레임 간격
FPS = A_SR / HOP
XFADE = 0.75        # 루프 이음매 크로스페이드(초)
BITRATE = "96k"
## 세 곡 공통 목표 라우드니스(RMS, dBFS)와 피크 상한.
## 원본은 곡마다 -14.2 / -11.2 / -10.4 dBFS 로 **3.8dB 어긋나 있었다** — 테마가 바뀌면
## BGM 음량이 눈에 띄게 달라졌다는 뜻이다. 어차피 자르면서 다시 인코딩하므로 이참에
## 공통 기준으로 맞춘다. 원본 음량을 그대로 보존하면 그 불일치까지 보존된다.
TARGET_RMS_DB = -12.0
PEAK_CEIL = 0.99
_W = int(0.5 * SR)  # 전환을 재는 창(0.5초)


# ── 입출력 ────────────────────────────────────────────────────────────────────

def decode(path: str, sr: int) -> np.ndarray:
    out = subprocess.run([FF, "-v", "error", "-i", path, "-f", "f32le",
                          "-ac", "1", "-ar", str(sr), "-"], capture_output=True).stdout
    return np.frombuffer(out, dtype=np.float32).astype(np.float64)


def encode(pcm: np.ndarray, path: str) -> None:
    p = subprocess.run([FF, "-v", "error", "-y", "-f", "f32le", "-ac", "1",
                        "-ar", str(SR), "-i", "-", "-c:a", "libmp3lame",
                        "-b:a", BITRATE, "-ac", "1", path],
                       input=pcm.astype(np.float32).tobytes(), capture_output=True)
    if p.returncode != 0:
        raise SystemExit(p.stderr.decode()[-2000:])


# ── 지각 축(멜) ───────────────────────────────────────────────────────────────

def _mel(x: np.ndarray, n: int = 2048, bands: int = 40) -> np.ndarray:
    """로그 대역 에너지(dB). 파형 SNR 은 손실 코덱 평가에 부적절해 지각에 가까운 축을 쓴다."""
    fr = 1 + (len(x) - n) // HOP
    if fr <= 0:
        return np.zeros((1, bands))
    w = np.hanning(n)
    idx = np.arange(n)[None, :] + HOP * np.arange(fr)[:, None]
    S = np.abs(np.fft.rfft(x[idx] * w, axis=1))
    e = np.unique(np.geomspace(2, S.shape[1] - 1, bands + 1).astype(int))
    return 20 * np.log10(np.stack([S[:, a:b].mean(1) for a, b in zip(e[:-1], e[1:])], 1) + 1e-6)


def _mel_dist(a: np.ndarray, b: np.ndarray) -> float:
    A, B = _mel(a), _mel(b)
    m = min(len(A), len(B))
    return float(np.abs(A[:m] - B[:m]).mean()) if m else 1e9


# ── 루프 만들기 ───────────────────────────────────────────────────────────────

def build(x: np.ndarray, s: float, ln: float) -> np.ndarray:
    """[S,E) 를 잘라 앞머리를 크로스페이드로 마감한 루프 PCM."""
    S, E = int(s * SR), int((s + ln) * SR)
    xf = min(int(XFADE * SR), (E - S) // 4, len(x) - E)
    seg = x[S:E].copy()
    if xf > 0:
        fade = np.sin(np.linspace(0.0, 1.0, xf) * np.pi / 2) ** 2   # 등출력에 가까운 S커브
        seg[:xf] = x[E:E + xf] * (1.0 - fade) + x[S:S + xf] * fade
    return seg


def normalize(seg: np.ndarray) -> tuple[np.ndarray, float, float]:
    """공통 목표 RMS 로 맞추고, 그때 넘치는 피크만 부드럽게 눌러 담는다.

    단순히 피크로 게인을 제한하면 크레스트가 큰 구간(조용한 본문 + 드문 타격음)에서
    목표 음량에 못 미친다 — 실제로 bgm_game_2 가 그래서 3dB 이상 조용했다. 드문 피크만
    tanh 니(knee)로 눌러 담으면 본문 음량을 목표에 맞출 수 있다. 눌린 비율을 함께 돌려주어
    과한 압축이면 드러나게 한다.
    """
    r = float(np.sqrt((seg ** 2).mean())) + 1e-12
    gain = (10.0 ** (TARGET_RMS_DB / 20.0)) / r
    y = seg * gain
    thr = PEAK_CEIL * 0.75                       # 이 위부터 부드럽게 휘어진다
    over = np.abs(y) > thr
    ratio = float(over.mean())
    if ratio > 0.0:
        head = PEAK_CEIL - thr
        e = np.abs(y[over]) - thr
        y[over] = np.sign(y[over]) * (thr + head * np.tanh(e / head))
    return y, 20.0 * np.log10(gain), ratio * 100.0


def _boundary(x: np.ndarray, S: int, E: int) -> np.ndarray:
    """루프에서 실제로 들리는 경계 — [끝 0.5초] + [크로스페이드된 앞머리]."""
    wev = int(XFADE * SR) + _W
    xf = int(XFADE * SR)
    head = x[S:S + wev].copy()
    if xf > 0 and E + xf <= len(x):
        fade = np.sin(np.linspace(0.0, 1.0, xf) * np.pi / 2) ** 2
        head[:xf] = x[E:E + xf] * (1.0 - fade) + x[S:S + xf] * fade
    return np.concatenate([x[E - _W:E], head])


def _transition(pcm_boundary: np.ndarray) -> float:
    wev = int(XFADE * SR) + _W
    return _mel_dist(pcm_boundary[:_W + wev // 2], pcm_boundary[_W:])


def _natural(M: np.ndarray) -> np.ndarray:
    """이 구간이 원래 갖는 변화량 분포 — 전환 판정의 기준선."""
    lag = _W // HOP
    n = (int(XFADE * SR) + _W) // HOP
    hi = len(M) - lag - n
    if hi <= 1:
        return np.array([1e9])
    return np.array([np.abs(M[a:a + n] - M[a + lag:a + lag + n]).mean()
                     for a in range(0, hi, 4)])


# ── 후보 탐색 ─────────────────────────────────────────────────────────────────

def features(x: np.ndarray) -> np.ndarray:
    """프레임별 로그 대역 에너지(24밴드), 밴드별 표준화. 음색+리듬을 함께 담는다."""
    n = 1024
    frames = 1 + (len(x) - n) // HOP
    w = np.hanning(n)
    idx = np.arange(n)[None, :] + HOP * np.arange(frames)[:, None]
    S = np.abs(np.fft.rfft(x[idx] * w, axis=1))
    e = np.unique(np.geomspace(2, S.shape[1] - 1, 25).astype(int))
    B = np.log1p(np.stack([S[:, a:b].sum(1) for a, b in zip(e[:-1], e[1:])], 1))
    B -= B.mean(0, keepdims=True)
    B /= B.std(0, keepdims=True) + 1e-6
    return B


def find_loop(x_a: np.ndarray, x: np.ndarray, lo_s: float, hi_s: float) -> tuple[float, float, dict]:
    """(시작초, 길이초, 진단)."""
    F = features(x_a)

    # ① 반복 주기 후보
    lags = []
    lo, hi = int(8 * FPS), min(int(100 * FPS), len(F) - int(20 * FPS))
    for lag in range(lo, hi):
        a, b = F[:-lag], F[lag:]
        lags.append((float((a * b).sum() / (len(a) * F.shape[1])), lag))
    lags.sort(reverse=True)

    w = int(1.5 * FPS)
    cands, seen = [], set()
    for _, lag in lags[:40]:
        for mult in range(1, 13):
            L = lag * mult
            if not (lo_s * FPS <= L <= hi_s * FPS):
                continue
            for s in range(0, max(1, len(F) - L - w), int(0.25 * FPS)):
                a, b = F[s:s + w], F[s + L:s + L + w]
                if len(b) < w:
                    continue
                key = (round(s / FPS, 1), round(L / FPS, 1))
                if key in seen:
                    continue
                seen.add(key)
                cands.append((float((a * b).sum() / (w * F.shape[1])), s / FPS, L / FPS))
    if not cands:
        raise SystemExit("루프 구간을 찾지 못했습니다 — --min/--max 를 넓혀 보세요.")
    cands.sort(reverse=True)
    cands = cands[:400]

    # ② 최종 선택 — 검증에 쓰는 값을 그대로 최적화한다
    M_full = _mel(x)
    fr_per_s = SR / HOP
    diff_full = np.abs(np.diff(x))
    best = None
    for seam, s, ln in cands:
        S, E = int(s * SR), int((s + ln) * SR)
        if S < 0 or E + int(XFADE * SR) + _W > len(x):
            continue
        trans = _transition(_boundary(x, S, E))
        nat = _natural(M_full[int(s * fr_per_s):int((s + ln) * fr_per_s)])
        pct = float((nat < trans).mean())

        # 크로스페이드가 앞머리를 x[E] 로 시작시키므로 실제 경계는 x[E-1] -> x[E] 다.
        # (x[S] 와의 단차를 재면 크로스페이드가 이미 없앤 것을 감점하게 된다.)
        click = float((diff_full < abs(float(x[E] - x[E - 1]))).mean())
        # 음량은 뒤에서 공통 목표로 정규화하므로 선택 기준에서 뺀다 — 넣으면 음량 감점이
        # 튐 기준을 눌러 "안 튀는 지점" 을 놓친다(실제로 그랬다).
        score = pct + 0.5 * click
        if best is None or score < best[0]:
            best = (score, s, ln, seam, pct, click)
    if best is None:
        raise SystemExit("루프 구간을 찾지 못했습니다 — --min/--max 를 넓혀 보세요.")
    _, s, ln, seam, pct, click = best
    return s, ln, {"seam": seam, "pct": pct, "click": click}


def main() -> int:
    global XFADE
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+")
    ap.add_argument("--write", action="store_true", help="원본을 교체한다(기본은 분석만)")
    ap.add_argument("--min", type=float, default=55.0, help="최소 루프 길이(초)")
    ap.add_argument("--max", type=float, default=95.0, help="최대 루프 길이(초)")
    ap.add_argument("--xfade", type=float, default=XFADE, help="크로스페이드 길이(초)")
    args = ap.parse_args()
    XFADE = args.xfade

    for f in args.files:
        p = pathlib.Path(f)
        x_a, x = decode(f, A_SR), decode(f, SR)
        s, ln, d = find_loop(x_a, x, args.min, args.max)
        seg, gain_db, limited = normalize(build(x, s, ln))

        before = p.stat().st_size
        tmp = p.with_suffix(".loop.mp3")
        encode(seg, str(tmp))
        after = tmp.stat().st_size
        back = decode(str(tmp), SR)

        # 검증 — 선택과 같은 값으로 다시 잰다(이번엔 실제 인코딩 결과 위에서)
        # 클릭은 절대값이 아니라 **이 음악의 통상 샘플 간 변화**와 견준다. 크로스페이드 덕에
        # 경계는 x[E-1] -> x[E], 즉 원곡이 그냥 이어질 때의 변화다 — 그 분포 안에 들면
        # 클릭이 아니라 그냥 음악이다. (참고: 원본 bgm_game_2 의 경계는 13.8% 로 더 나빴다.)
        step = abs(float(back[-1] - back[0]))
        d = np.abs(np.diff(back))
        step_pct = float((d < step).mean() * 100.0)
        rms = float(np.sqrt((back ** 2).mean()))
        trans = _transition(np.concatenate([back[-_W:], back[:int(XFADE * SR) + _W]]))
        nat = _natural(_mel(back))
        pct = float((nat < trans).mean() * 100.0)
        n = min(len(back), len(seg))
        err = float(np.sqrt(((back[:n] - seg[:n]) ** 2).mean()))
        snr = 20 * np.log10(rms / err) if err > 0 else 99.0
        db = lambda v: 20 * np.log10(np.sqrt((v ** 2).mean()) + 1e-12)

        print(f"{p.name}")
        print(f"   {len(x)/SR:6.1f}s -> {ln:5.1f}s  (시작 {s:.2f}s)")
        print(f"   용량 {before/1024:7.1f}KB -> {after/1024:6.1f}KB "
              f"({(1-after/before)*100:.0f}% 감소)")
        print(f"   클릭: 경계 변화량이 이 곡 통상 변화량의 {step_pct:3.0f}% 지점 "
              f"(RMS 대비 {step/rms*100:.1f}%)")
        print(f"   튐  : 전환 {trans:5.2f}dB — 이 루프 자체 변화량의 {pct:3.0f}% 지점 "
              f"(중앙값 {np.median(nat):.2f}, 최대 {nat.max():.2f})")
        print(f"   음량: {db(x):+.2f} -> {db(back):+.2f}dBFS (목표 {TARGET_RMS_DB:+.1f}, "
              f"게인 {gain_db:+.2f}dB, 리미터가 만진 샘플 {limited:.2f}%)")
        print(f"   크로스페이드 {XFADE}s · 재인코딩 SNR {snr:.1f}dB")

        if args.write:
            tmp.replace(p)
            print(f"   -> {p} 교체")
        else:
            tmp.unlink()
            print("   (미리보기 — 교체하려면 --write)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
