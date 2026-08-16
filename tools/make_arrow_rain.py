#!/usr/bin/env python3
"""화살비(헌터 궁극기) 사운드를 만든다 — 화살 한 발을 수십 발로 겹쳐 폭우를 합성.

AI 생성기는 "화살이 쏟아진다"를 자꾸 단발 사건으로 해석하고, 밀도가 부족하면 결과가
'유리 깨지는 소리'처럼 들린다(성긴 데다 밝은 타격만 남기 때문). 화살 한 발을 재료로
수십 발을 겹치면 밀도·음색을 직접 통제할 수 있다.

두 가지 모드:
  합성(기본)  화살 한 발을 절차적으로 합성해 사용한다. 나무 타격 대역(200~800Hz)이
              지배적이라 '나무 화살이 땅에 꽂히는' 소리로 뽑힌다.
  녹음 사용    잘 뽑힌 화살 1발이 있으면 그것을 재료로 쓴다(--src one_arrow.mp4).
               형식은 아무거나 된다 — 앞 무음 제거와 정규화는 자동으로 한다.

사용:
  python3 tools/make_arrow_rain.py                       # 합성 → assets/audio/sfx_ult_arrow.ogg
  python3 tools/make_arrow_rain.py --src one_arrow.mp4   # 실제 녹음 1발로 합성
  python3 tools/make_arrow_rain.py --count 60 --length 4.0 --out /tmp/rain.ogg
"""
import argparse
import subprocess
import sys
from pathlib import Path

import numpy as np

try:
    import imageio_ffmpeg
    FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
except ImportError:
    FFMPEG = "ffmpeg"

SR = 48000
TARGET_RMS_DB = -16.0    # 다른 효과음과 동일한 라우드니스 기준
PEAK_CAP_DB = -1.5
SEED = 7                 # 결과 재현 가능

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = ROOT / "assets" / "audio" / "sfx_ult_arrow.ogg"


def svf_bandpass(x: np.ndarray, fc: np.ndarray, q: float = 1.2) -> np.ndarray:
    """중심 주파수가 시간에 따라 변하는 상태변수 밴드패스 — 화살이 다가오며 음색이 낮아진다."""
    f = 2.0 * np.sin(np.pi * np.clip(fc, 20.0, SR * 0.45) / SR)
    damp = 1.0 / q
    low = band = 0.0
    out = np.empty_like(x)
    for i in range(len(x)):
        low += f[i] * band
        band += f[i] * (x[i] - low - damp * band)
        out[i] = band
    return out


def synth_arrow(rng: np.random.Generator) -> np.ndarray:
    """화살 한 발: 공기를 가르는 휙(하강 스윕) → 땅에 꽂히는 나무 타격(감쇠 공명).

    대역 구성을 의도적으로 나무 쪽에 몰아준다 — 타격의 몸통을 200~800Hz 의 감쇠 정현파로
    만들고, 어택 클릭은 로우패스로 눌러 3kHz 이상이 남지 않게 한다. 고역이 남으면 여러 발이
    겹쳤을 때 '챙그랑'거려 유리처럼 들린다.
    """
    # ── 휙(비행음): 착탄 직전의 짧은 공기 소리.
    #
    # 길면 안 된다. 비행음 0.26초짜리를 70발 겹치면 언제나 4~5개가 동시에 울려 끊기지 않는
    # 노이즈 층이 생기고, 화살비가 아니라 벌떼가 몰려오는 소리가 된다(실제로 그렇게 들렸다).
    # 좁은 밴드패스를 훑어 내리는 건 곤충 날갯소리를 만드는 방식 그 자체이기도 하다.
    # 그래서 0.07초로 줄이고(동시 겹침 1.2개), 필터를 넓혀 '삐-' 가 아니라 '휙' 이 되게 한다.
    # 화살비의 정체성은 비행음이 아니라 땅에 꽂히는 타격에 있다.
    n_w = int(0.07 * SR)
    t = np.arange(n_w) / SR
    sweep = 3200.0 * (1400.0 / 3200.0) ** (t / t[-1])
    whoosh = svf_bandpass(rng.standard_normal(n_w), sweep, q=0.5)
    whoosh *= (t / t[-1]) ** 2.0          # 다가올수록 급격히 커지는 접근 포락선
    whoosh /= max(float(np.abs(whoosh).max()), 1e-9)
    whoosh *= 0.25

    # ── 타격: 클릭 + 나무 공명 + 흙먼지
    #
    # 짧고 건조해야 한다. 공명이 길게 울리면(0.05초만 돼도) 수십 발의 여운이 서로 겹쳐
    # 저역이 끊김 없이 깔리고, 개별 화살이 뭉개져 웅웅거리는 덩어리가 된다. 화살이 나무
    # 기둥이 아니라 흙에 꽂히는 소리라는 점에서도 여운은 짧은 게 맞다 — '통' 이 아니라 '톡'.
    n_i = int(0.10 * SR)
    ti = np.arange(n_i) / SR
    impact = np.zeros(n_i)

    click = rng.standard_normal(n_i) * np.exp(-ti / 0.0018)   # 짧은 어택 클릭
    a = np.exp(-2.0 * np.pi * 3200.0 / SR)                    # 원폴 로우패스 — 유리빛 고역 제거
    for i in range(1, n_i):
        click[i] = (1 - a) * click[i] + a * click[i - 1]
    impact += click * 1.5                                     # 어택이 개별 타격을 또렷하게 만든다

    # 나무의 비조화 공명 3개 — 짧게 끊어 '톡' 하고 죽게 한다.
    for freq, decay, gain in ((205.0, 0.016, 1.0), (415.0, 0.011, 0.5), (760.0, 0.007, 0.22)):
        impact += gain * np.sin(2 * np.pi * freq * ti + rng.uniform(0, 2 * np.pi)) * np.exp(-ti / decay)

    soil = rng.standard_normal(n_i) * np.exp(-ti / 0.018)     # 흙이 튀는 소리
    b = np.exp(-2.0 * np.pi * 900.0 / SR)
    for i in range(1, n_i):
        soil[i] = (1 - b) * soil[i] + b * soil[i - 1]
    impact += soil * 0.55

    arrow = np.concatenate([whoosh, np.zeros(n_i)])
    arrow[n_w:] += impact
    return arrow / max(float(np.abs(arrow).max()), 1e-9)


def load_mono(path: Path) -> np.ndarray:
    """어떤 형식이든(mp4/wav/mp3/ogg) 48kHz 모노로 읽는다 — 생성기 출력은 보통 mp4 다.

    앞의 무음을 잘라내고 진폭을 정규화해서 돌려준다. 재료 한 발의 시작이 늦으면 겹칠 때
    타이밍이 전부 밀린다.
    """
    if not path.exists():
        sys.exit(f"원본을 찾을 수 없다: {path}")
    out = subprocess.run(
        [FFMPEG, "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
        capture_output=True, check=True).stdout
    x = np.frombuffer(out, dtype=np.float32).astype(np.float64)
    loud = np.where(np.abs(x) > 10.0 ** (-50.0 / 20.0))[0]
    if len(loud):
        x = x[max(0, loud[0] - int(0.003 * SR)):]
    return x / max(float(np.abs(x).max()), 1e-9)


def resample(x: np.ndarray, ratio: float) -> np.ndarray:
    """선형 보간 리샘플 — ratio>1 이면 높은 음(짧아짐)."""
    n = max(1, int(len(x) / ratio))
    return np.interp(np.arange(n) * ratio, np.arange(len(x)), x)


def layer(arrow_of, count: int, length_s: float, rng: np.random.Generator) -> np.ndarray:
    """화살들을 무작위 시차·피치·좌우 위치로 겹쳐 폭우를 만든다.

    arrow_of(rng) 는 화살 한 발을 돌려주는 함수 — 합성 모드에서는 발마다 미세하게 다른
    화살이 나와 '같은 소리의 반복'으로 들리지 않는다.
    밀도 곡선: 앞 12% 도입(성김) → 중반 절정(빽빽) → 뒤 감쇠(잦아듦).
    """
    total = int(length_s * SR)
    out = np.zeros((2, total))
    intro = max(3, count // 12)
    body = count - intro
    for k in range(count):
        a = resample(arrow_of(rng), rng.uniform(0.85, 1.28))
        if k < intro:
            # 도입부 화살은 발동 시점에 이미 낙하 중 — 시작을 음수로 둬 비행음이 잘리고
            # 타격이 0초 부근에 꽂힌다. 궁극기 발동의 화면 셰이크·버스트와 소리가 붙는다.
            start = int(rng.uniform(-0.85, 0.02) * len(a))
        else:
            # 층화 배치 — 구간을 발수만큼 나눠 한 칸에 하나씩 놓고 칸 안에서만 흔든다.
            # 순수 무작위로 뿌리면 뭉치고 비는 구간이 생겨 '쉼 없이 쏟아진다'가 깨진다.
            slot = k - intro
            span = 0.94 / body
            start = int((slot * span + rng.uniform(0.0, span * 0.95)) * total)
        # 세기 편차를 넓게 — 가까운 화살과 먼 화살이 섞여야 개별 타격이 도드라진다.
        gain = rng.uniform(0.16, 1.0) ** 1.4
        pan = rng.uniform(-0.85, 0.85)          # 좌우로 흩뿌려 폭우의 폭을 만든다
        head = max(0, -start)                   # 음수 시작이면 앞부분(비행음)을 잘라낸다
        start = max(0, start)
        seg = a[head:]
        n = min(len(seg), total - start)
        if n <= 0:
            continue
        out[0, start:start + n] += seg[:n] * gain * (1.0 - pan * 0.5)
        out[1, start:start + n] += seg[:n] * gain * (1.0 + pan * 0.5)
    return out


def normalize(x: np.ndarray) -> np.ndarray:
    """RMS 를 기준에 맞추되, 겹침이 우연히 몰린 소수의 피크는 소프트 클립으로 깎는다.

    화살 수십 발이 겹치는 소리는 파고율(피크/RMS)이 높아, 피크만 보고 눌러 맞추면 전체가
    3~4dB 조용해진다. tanh 니(knee)로 상위 피크만 완만히 눌러 기준 RMS 를 채운다 —
    노이즈성 밀집 텍스처라 이 정도 포화는 들리지 않고, 하드 클리핑과 달리 각지지 않는다.
    """
    cap = 10.0 ** (PEAK_CAP_DB / 20.0)
    target = 10.0 ** (TARGET_RMS_DB / 20.0)
    for _ in range(6):   # 클립이 RMS 를 다시 낮추므로 몇 번 되풀이해 수렴시킨다
        rms = float(np.sqrt(np.mean(x ** 2)))
        if rms <= 0:
            return x
        x = x * (target / rms)
        if float(np.abs(x).max()) > cap:
            x = cap * np.tanh(x / cap)
        if abs(20 * np.log10(float(np.sqrt(np.mean(x ** 2))) / target)) < 0.1:
            break
    return x


def encode(x: np.ndarray, path: Path) -> None:
    """(2, N) 스테레오를 인터리브해 OGG Vorbis 로 인코딩."""
    pcm = (np.clip(x.T.reshape(-1), -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    subprocess.run(
        [FFMPEG, "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "2", "-i", "-",
         "-c:a", "libvorbis", "-q:a", "6", str(path)],
        input=pcm, check=True)


def main() -> None:
    ap = argparse.ArgumentParser(description="화살비 사운드 합성")
    ap.add_argument("--src", type=Path, help="화살 1발 오디오(mp4/wav/mp3 — 없으면 절차적 합성)")
    # 70 발은 너무 촘촘해 타격의 여운이 서로 메워지면서 벌떼처럼 웅웅거렸다. 44~70 을
    # 비교해 48 발로 낮췄다 — 타격 12회/초로 여전히 빽빽하면서, 피크-바닥이 29.9dB 로
    # 개별 화살이 또렷하다(파리떼 17.0dB, 유리 깨짐 29.3dB 와 비교한 값).
    ap.add_argument("--count", type=int, default=48, help="화살 발수")
    ap.add_argument("--length", type=float, default=4.0, help="전체 길이(초)")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = ap.parse_args()

    rng = np.random.default_rng(SEED)
    if args.src:
        sample = load_mono(args.src)
        arrow_of = lambda _r: sample
        mode = f"녹음({args.src.name})"
    else:
        arrow_of = synth_arrow
        mode = "절차적 합성"

    x = layer(arrow_of, args.count, args.length, rng)
    fade = int(0.30 * SR)
    x[:, -fade:] *= np.linspace(1.0, 0.0, fade)
    x = normalize(x)
    encode(x, args.out)
    rms = 20 * np.log10(float(np.sqrt(np.mean(x ** 2))))
    print(f"{args.out.name}: {mode}, 화살 {args.count}발, {args.length:.1f}초, "
          f"스테레오 RMS={rms:.1f}dB")


if __name__ == "__main__":
    main()
