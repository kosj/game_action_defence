#!/usr/bin/env python3
"""AI 생성 사운드(mp4/wav/mp3)를 게임용 OGG 효과음으로 변환한다.

생성기 출력은 그대로 쓸 수 없다 — 앞에 무음이 붙고, 목표보다 길고, 꼬리가 늘어지고,
파일마다 음량이 제각각이다. 이 스크립트가 전 과정을 한 번에 처리한다:

  1. 48kHz 모노로 디코드(기존 에셋 규격과 동일)
  2. PLAN 의 구간만 잘라냄 — 생성기가 한 파일에 여러 테이크를 넣거나 꼬리를 길게 뽑은 경우
  3. 선행 무음 제거(-50dBFS 기준, 5ms 프리롤만 남김) — 어택이 0초에 시작해야 화면 연출과 붙는다
  4. 끝단 페이드아웃 — 뚝 끊기는 소리 방지
  5. RMS -16dBFS 로 통일 + 피크 -1.5dBFS 캡(궁극기 3종과 동일 기준)
  6. OGG Vorbis q6 인코딩 후 assets/audio/ 에 배치

음량 밸런스는 여기서 잡지 않는다 — 전부 같은 라우드니스로 맞추고, 사운드별 세기는
SoundManager._VOLUMES 에서 조정한다(파일마다 제각각이면 믹스 관리가 불가능해진다).

사용: python3 tools/import_sfx.py [사운드이름 ...]   (인자 없으면 PLAN 전체)
"""
import os
import subprocess
import sys
from pathlib import Path

import numpy as np

try:
    import imageio_ffmpeg
    FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
except ImportError:
    FFMPEG = "ffmpeg"   # 시스템 ffmpeg 이 있으면 그대로 사용

SR = 48000
TARGET_RMS_DB = -16.0    # 궁극기 3종과 동일 — 사운드셋 전체 통일 기준
PEAK_CAP_DB = -1.5       # 인코딩 오버슈트 여유
SILENCE_DB = -50.0       # 이 이하는 무음으로 보고 앞부분을 잘라낸다
PREROLL = 0.005          # 어택 직전에 남기는 여유(초)

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "audio"

# 사운드별 처리 계획. cut=(시작초, 끝초) — None 이면 전체. fade=끝단 페이드아웃(초).
# 구간 값은 각 소스의 에너지 포락선을 분석해 정한 것이다(주석은 그 근거).
PLAN = {
    # 소스에 휘두르기 4번이 들어있다(0.09/1.37/2.72/4.60s) — 가장 강한 첫 번째만 사용.
    "swing":        {"src": "7eb5bfaf-bat_whoosh.mp4",       "cut": (0.085, 0.44), "fade": 0.03},
    # 0.5s 이후는 늘어지는 잔향 — 프롬프트의 dry/tight 의도대로 잘라낸다.
    "spit":         {"src": "08119b58-acid_spit.mp4",        "cut": (0.0, 0.55),  "fade": 0.08},
    # 1.0~2.2s 가 정점, 이후 완만한 감쇠 — 감쇠 구간에서 페이드해 자연스럽게 마무리.
    "revive":       {"src": "6eef21e5-heroic_chime.mp4",     "cut": (0.0, 2.45),  "fade": 0.30},
    "wave_clear":   {"src": "dfe8faad-achievement_tone.mp4", "cut": (0.0, 1.60),  "fade": 0.25},
    "evolve":       {"src": "7adc5116-weapon_fanfare.mp4",   "cut": (0.0, 3.00),  "fade": 0.40},
    "bomber_blast": {"src": "a5229eba-zombie_explosion.mp4", "cut": (0.0, 1.15),  "fade": 0.12},
    # 삐 소리 3개가 1.41초에 퍼져 있어 게임의 퓨즈 창(0.55초)을 넘긴다 — 아래에서 재조립.
    "bomber_fuse":  {"src": "4a3dd5cd-beep_warning.mp4",     "cut": None, "fade": 0.02,
                     "rebuild": "fuse"},
}

# 원본 위치 — 환경변수로 덮어쓸 수 있다: SFX_SRC_DIR=~/downloads python3 tools/import_sfx.py
UPLOADS = Path(os.environ.get("SFX_SRC_DIR", "/root/.claude/uploads"))


def find_src(name: str) -> Path:
    """원본 파일 찾기 — 지정 폴더 바로 아래에 없으면 하위 폴더까지 뒤진다
    (업로드는 세션별 하위 폴더에 떨어지므로 경로를 매번 바꾸지 않아도 되게)."""
    direct = UPLOADS / name
    if direct.exists():
        return direct
    for p in UPLOADS.rglob(name):
        return p
    sys.exit(f"원본을 찾을 수 없다: {name} (SFX_SRC_DIR={UPLOADS})")


def decode(path: Path) -> np.ndarray:
    """48kHz 모노 float32 로 디코드."""
    out = subprocess.run(
        [FFMPEG, "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
        capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype=np.float32).astype(np.float64)


def db(x: float) -> float:
    return 20.0 * np.log10(max(x, 1e-12))


def trim_head(x: np.ndarray) -> np.ndarray:
    """선행 무음 제거 — 어택이 0초에서 시작해야 화면 셰이크·버스트와 동기화된다."""
    loud = np.where(np.abs(x) > 10.0 ** (SILENCE_DB / 20.0))[0]
    if len(loud) == 0:
        return x
    return x[max(0, loud[0] - int(PREROLL * SR)):]


def high_shelf(x: np.ndarray, fc: float, db: float) -> np.ndarray:
    """fc 위쪽을 db 만큼 완만히 깎는다(FFT 셸프).

    생성기가 뽑아준 유리·금속 소리는 5kHz 이상에 에너지가 몰려 귀에 쨍하게 박히는 경우가
    많다. 귀는 2~5kHz 에 가장 예민해서, 같은 음량이라도 이 대역이 두꺼우면 금세 피로해진다.
    fc~fc*2.5 구간에서 서서히 기울여 자르므로 음색이 갑자기 먹먹해지지 않는다.
    """
    N = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(N, 1.0 / SR)
    ramp = np.clip((f - fc) / (fc * 1.5), 0.0, 1.0)   # fc 에서 0, fc*2.5 이상에서 1
    return np.fft.irfft(X * 10.0 ** (db * ramp / 20.0), N)


def fade_out(x: np.ndarray, seconds: float) -> np.ndarray:
    n = min(len(x), int(seconds * SR))
    if n > 0:
        x = x.copy()
        x[-n:] *= np.linspace(1.0, 0.0, n)
    return x


def normalize(x: np.ndarray) -> np.ndarray:
    """RMS 를 기준값에 맞추고, 피크가 캡을 넘으면 그만큼 다시 낮춘다."""
    rms = float(np.sqrt(np.mean(x ** 2)))
    if rms <= 0.0:
        return x
    x = x * (10.0 ** (TARGET_RMS_DB / 20.0) / rms)
    peak = float(np.abs(x).max())
    cap = 10.0 ** (PEAK_CAP_DB / 20.0)
    if peak > cap:
        x = x * (cap / peak)
    return x


def _resample(x: np.ndarray, ratio: float) -> np.ndarray:
    """선형 보간 리샘플 — ratio>1 이면 높은 음(짧아짐)."""
    n = max(1, int(len(x) / ratio))
    return np.interp(np.arange(n) * ratio, np.arange(len(x)), x)


def rebuild_fuse(x: np.ndarray) -> np.ndarray:
    """자폭 점화 경고음 재조립.

    소스는 삐 소리 3개가 0.06/0.55/1.12초에 떨어져 있어 총 1.41초 — 그런데 게임의 점화~폭발
    간격은 0.55초라 뒤 두 개는 폭발 뒤에 울린다. 각 삐를 뽑아 0.15초 간격으로 촘촘히 붙이고,
    음량·음높이를 단계적으로 올려 '터지기 직전'의 조급함을 만든다(프롬프트의 rising ticks 의도).
    """
    spans = [(0.055, 0.185), (0.545, 0.675), (1.115, 1.245)]   # 각 삐의 앞부분 0.13초
    gains = [0.72, 0.86, 1.0]
    pitches = [1.0, 1.06, 1.12]
    step = int(0.15 * SR)
    beeps = []
    for (s, e), g, p in zip(spans, gains, pitches):
        b = x[int(s * SR):int(e * SR)]
        peak = float(np.abs(b).max())
        if peak > 0:
            b = b / peak
        b = _resample(b, p)
        n = min(len(b), int(0.02 * SR))
        b[-n:] *= np.linspace(1.0, 0.0, n)   # 삐마다 끝을 짧게 닫아 딸깍임 방지
        beeps.append(b * g)
    total = step * (len(beeps) - 1) + len(beeps[-1])
    out = np.zeros(total)
    for i, b in enumerate(beeps):
        out[i * step:i * step + len(b)] += b
    return out


def encode(x: np.ndarray, path: Path) -> None:
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    subprocess.run(
        [FFMPEG, "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
         "-c:a", "libvorbis", "-q:a", "6", str(path)],
        input=pcm, check=True)


def main() -> None:
    names = sys.argv[1:] or list(PLAN)
    for name in names:
        spec = PLAN.get(name)
        if spec is None:
            sys.exit(f"알 수 없는 사운드: {name}")
        x = decode(find_src(spec["src"]))
        if spec.get("rebuild") == "fuse":
            x = rebuild_fuse(x)
        else:
            if spec["cut"]:
                s, e = spec["cut"]
                x = x[int(s * SR):int(e * SR)]
            x = trim_head(x)
        if spec.get("shelf"):
            x = high_shelf(x, *spec["shelf"])
        x = fade_out(x, spec["fade"])
        x = normalize(x)
        out = OUT_DIR / f"sfx_{name}.ogg"
        encode(x, out)
        print(f"{out.name:24s} {len(x)/SR:5.2f}s  RMS={db(float(np.sqrt(np.mean(x**2)))):6.1f}dB  "
              f"peak={db(float(np.abs(x).max())):5.1f}dB")


if __name__ == "__main__":
    main()
