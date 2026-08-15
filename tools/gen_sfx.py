#!/usr/bin/env python3
"""절차적 효과음 합성 — 대역·길이를 수치로 통제해야 하는 소리를 직접 만든다.

AI 생성음은 질감이 좋지만 "이 소리는 저역이 몇 %여야 한다" 같은 요구를 맞추기 어렵다.
반복 재생되는 짧은 타격음·전기음은 대역 구성이 곧 정체성이라(살점이냐 나무냐, 전기냐
전자음이냐) 합성으로 만드는 편이 확실하다.

  zombie_hit  좀비 피격 — 기존 음은 중심 124Hz 에 800Hz 이상이 0% 라 살점이 아니라
              나무를 치는 소리였다(툭툭거림). 젖은 타격(중역 노이즈)과 짧은 몸통 울림으로
              다시 만들고 길이도 0.43s → 0.18s 로 줄인다(초당 최대 18회 재생되는 소리).
  tesla_arc   테슬라 방전 — 총성(shoot)·전자음(laser)을 돌려쓰고 있었다. 불규칙한 스파크
              게이트로 파직거림을 만들고 코일 험을 깔아 '전기가 옮겨붙는' 소리로 만든다.

사용: python3 tools/gen_sfx.py [이름 ...]   (인자 없으면 전체)
"""
import os
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_arrow_rain import svf_bandpass   # noqa: E402  (시간 가변 밴드패스 재사용)

try:
    import imageio_ffmpeg
    FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
except ImportError:
    FFMPEG = "ffmpeg"

SR = 48000
TARGET_RMS_DB = -16.0    # 사운드셋 공통 라우드니스 기준
PEAK_CAP_DB = -1.5
SEED = 11

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "audio"


def one_pole_lp(x: np.ndarray, fc: float) -> np.ndarray:
    a = float(np.exp(-2.0 * np.pi * fc / SR))
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1.0 - a) * x[i] + a * acc
        y[i] = acc
    return y


def synth_zombie_hit(rng: np.random.Generator) -> np.ndarray:
    """좀비 피격 — 젖은 타격.

    구성: 짧은 어택 클릭 + 중역 '철퍽'(700~3500Hz 노이즈) + 아래로 훑는 스퀄치 +
    낮은 몸통 울림 + 옅은 고역 비산. 기존 음은 저역 순음뿐이라 나무를 치는 소리였다 —
    살점의 정체성은 중역 노이즈에 있으므로 그쪽에 무게를 준다.
    """
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)

    click = rng.standard_normal(n) * np.exp(-t / 0.0025)          # 맞는 순간의 날카로움
    out += one_pole_lp(click, 5000.0) * 1.6

    slap = svf_bandpass(rng.standard_normal(n), np.full(n, 1600.0), q=0.8)
    out += slap * np.exp(-t / 0.030) * 0.95                         # 젖은 철퍽(중역)

    # 스퀄치 — 공명 중심이 2600→700Hz 로 훑어 내리며 '찌걱'하는 질감을 만든다.
    sweep = 2600.0 * (700.0 / 2600.0) ** (t / t[-1])
    out += svf_bandpass(rng.standard_normal(n), sweep, q=3.0) * np.exp(-t / 0.055) * 0.75

    # 살점의 몸통 — 200~800Hz. 이 대역이 비면 저역 쿵과 중역 철퍽만 남아 속이 빈 소리가 된다.
    out += svf_bandpass(rng.standard_normal(n), np.full(n, 430.0), q=1.4) * np.exp(-t / 0.045) * 2.4

    for freq, decay, gain in ((125.0, 0.050, 0.80), (245.0, 0.034, 0.85), (430.0, 0.020, 0.55)):
        out += gain * np.sin(2 * np.pi * freq * t) * np.exp(-t / decay)   # 몸통이 흔들리는 둔중함

    spray = rng.standard_normal(n) - one_pole_lp(rng.standard_normal(n), 3500.0)
    out += spray * np.exp(-t / 0.012) * 0.30                       # 옅은 비산

    out[-int(0.02 * SR):] *= np.linspace(1.0, 0.0, int(0.02 * SR))
    return out


def synth_tesla_arc(rng: np.random.Generator) -> np.ndarray:
    """테슬라 방전 — 전기가 옮겨붙는 소리.

    핵심은 '스파크 게이트' — 노이즈를 불규칙하게 켰다 껐다 해서 파직거림을 만든다.
    일정하게 흐르는 노이즈는 바람 소리로 들리고, 순음은 전자음으로 들린다. 전기의 정체성은
    불규칙한 단속(斷續)에 있다. 여기에 코일 험(저역 톱니)을 깔아 장비의 무게를 준다.
    """
    n = int(0.36 * SR)
    t = np.arange(n) / SR
    env = np.exp(-t / 0.14)

    # 스파크 게이트: 짧은 구간마다 무작위로 세기가 바뀌고 종종 완전히 끊긴다.
    step = int(0.0016 * SR)
    blocks = n // step + 1
    lv = rng.random(blocks) ** 2.2                    # 대부분 약하고 가끔 크게 튄다
    lv[rng.random(blocks) < 0.30] = 0.0               # 30% 는 완전 단절 — 파직파직
    gate = np.repeat(lv, step)[:n]
    gate = one_pole_lp(gate, 900.0)                   # 각진 경계를 눌러 딸깍임 방지

    # 방전은 3~5kHz 가 중심이다. 광대역 노이즈를 그대로 두면 8kHz 이상이 40% 를 넘어
    # 전기가 아니라 '치익' 하는 바람 소리로 들린다 — 밴드패스로 모으고 로우패스로 덮는다.
    spark = svf_bandpass(rng.standard_normal(n), np.full(n, 2800.0), q=1.0)
    arc = one_pole_lp(spark, 6500.0) * gate * env * 4.2

    # 코일 험 — 방전 자체보다 낮게 깔려 '장비가 돌아간다'는 인상을 준다.
    hum = np.zeros(n)
    for k, g in ((1, 0.5), (2, 0.28), (3, 0.16), (5, 0.08)):
        hum += g * np.sin(2 * np.pi * 92.0 * k * t + rng.uniform(0, 2 * np.pi))
    arc += hum * env * 0.40 * (0.6 + 0.4 * gate)

    zap = rng.standard_normal(n) * np.exp(-t / 0.004)   # 첫 방전의 탁 튀는 어택
    arc += one_pole_lp(svf_bandpass(zap, np.full(n, 2400.0), q=1.0), 7000.0) * 3.0

    arc[-int(0.04 * SR):] *= np.linspace(1.0, 0.0, int(0.04 * SR))
    return arc


def decode(path: Path) -> np.ndarray:
    out = subprocess.run(
        [FFMPEG, "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
        capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype=np.float32).astype(np.float64)


def band_filter(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    """FFT 대역 통과 — 경계를 부드럽게 기울여 링잉을 줄인다."""
    N = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(N, 1.0 / SR)
    g = np.clip((f - lo) / max(lo, 1.0), 0.0, 1.0) * np.clip((hi * 2.0 - f) / hi, 0.0, 1.0)
    return np.fft.irfft(X * g, N)


def synth_ult_quake(rng: np.random.Generator) -> np.ndarray:
    """베테랑 궁극기(지진) — 원본 저역에 '들리는' 성분을 얹는다.

    원본은 에너지의 99.4% 가 200Hz 이하라 폰 스피커로는 거의 재생되지 않는다. 실제로
    체감 음량이 다른 궁극기보다 17~20dB 낮아 "소리가 안 난다"는 말이 나왔다. 저역을
    키우는 건 답이 아니다 — 작은 스피커는 그 대역 자체를 못 낸다.

    두 가지를 더한다.
      1. 배음 생성(익사이터) — 저역을 비선형에 통과시켜 2·3배음을 만들고 150~900Hz 로
         걸러 섞는다. 귀는 배음만 듣고도 원래의 낮은 음을 인지하므로(결여 기본음),
         작은 스피커에서도 '우르릉'이 살아난다. 원음에서 파생된 배음이라 이질감이 없다.
      2. 암석 파열 — 화면에는 방사형 균열 8줄과 연쇄 충격 링이 그려지고 0.3초마다 피해
         틱이 돈다. 그 리듬에 맞춰 갈라지는 파열음을 얹어 눈에 보이는 것을 귀로도 들려준다.
    """
    src_dir = Path(os.environ.get("SFX_SRC_DIR", "/root/.claude/uploads"))
    found = next(iter(src_dir.rglob("970f68f7-quake_slam.mp4")), None)
    base = decode(found) if found else decode(OUT_DIR / "sfx_ult_quake.ogg")

    n = min(len(base), int(4.5 * SR))    # 궁극기 지속 3.0초 + 감쇠 테일
    base = base[:n]
    t = np.arange(n) / SR
    # 저역은 대부분의 기기가 재생하지 못한다 — 원본 그대로 두면 RMS 예산만 먹고
    # 정작 들리는 대역이 조용해진다. 무게감이 남을 만큼만 남기고 낮춘다.
    out = base * 0.42

    # 1) 배음 생성 — 저역만 뽑아 포화시킨 뒤 중역만 걸러 섞는다.
    low = band_filter(base, 25.0, 220.0)
    low /= max(float(np.abs(low).max()), 1e-9)
    out += band_filter(np.tanh(low * 7.0), 150.0, 900.0) * 1.45

    # 2) 암석 파열 — 발동 순간 큰 것 하나, 이후 피해 틱(0.3초) 리듬으로 이어진다.
    ct = 0.01
    while ct < 3.1:
        big = ct < 0.05
        m = int(ct * SR)
        ln = min(int(0.30 * SR), n - m)
        if ln <= 0:
            break
        tc = np.arange(ln) / SR
        crack = rng.standard_normal(ln) * np.exp(-tc / 0.0022)              # 갈라지는 순간
        crack += band_filter(rng.standard_normal(ln), 300.0, 1800.0) * np.exp(-tc / 0.055)
        crack += band_filter(rng.standard_normal(ln), 120.0, 500.0) * np.exp(-tc / 0.13) * 0.8
        crack = band_filter(crack, 150.0, 3000.0)                            # 유리처럼 밝아지지 않게
        peak = float(np.abs(crack).max())
        if peak > 0:
            crack /= peak
        fade = 1.0 - ct / 3.4      # 뒤로 갈수록 잦아든다
        out[m:m + ln] += crack * (1.6 if big else rng.uniform(0.5, 0.95)) * fade
        ct += rng.uniform(0.24, 0.40)

    out[-int(0.35 * SR):] *= np.linspace(1.0, 0.0, int(0.35 * SR))
    return out


GENERATORS = {
    "zombie_hit": synth_zombie_hit,
    "tesla_arc": synth_tesla_arc,
    "ult_quake": synth_ult_quake,
}


def normalize(x: np.ndarray) -> np.ndarray:
    cap = 10.0 ** (PEAK_CAP_DB / 20.0)
    target = 10.0 ** (TARGET_RMS_DB / 20.0)
    for _ in range(6):
        rms = float(np.sqrt(np.mean(x ** 2)))
        if rms <= 0:
            return x
        x = x * (target / rms)
        if float(np.abs(x).max()) > cap:
            x = cap * np.tanh(x / cap)     # 순간 피크만 완만히 눌러 기준 RMS 를 채운다
        if abs(20 * np.log10(float(np.sqrt(np.mean(x ** 2))) / target)) < 0.1:
            break
    return x


def encode(x: np.ndarray, path: Path) -> None:
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    subprocess.run(
        [FFMPEG, "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
         "-c:a", "libvorbis", "-q:a", "6", str(path)],
        input=pcm, check=True)


def main() -> None:
    names = sys.argv[1:] or list(GENERATORS)
    rng = np.random.default_rng(SEED)
    for name in names:
        gen = GENERATORS.get(name)
        if gen is None:
            sys.exit(f"알 수 없는 사운드: {name} (가능: {', '.join(GENERATORS)})")
        x = normalize(gen(rng))
        out = OUT_DIR / f"sfx_{name}.ogg"
        encode(x, out)
        rms = 20 * np.log10(float(np.sqrt(np.mean(x ** 2))))
        peak = 20 * np.log10(float(np.abs(x).max()))
        print(f"{out.name:22s} {len(x)/SR:5.3f}s  RMS={rms:6.1f}dB  peak={peak:5.1f}dB")


if __name__ == "__main__":
    main()
