#!/usr/bin/env python3
"""절차적 효과음 합성 — 대역·길이를 수치로 통제해야 하는 소리를 직접 만든다.

두 종류의 작업을 한다 — 순수 합성(전기음처럼 물리 대상이 없는 소리)과, 생성음을 재료로
쓰는 가공(자르기·겹치기·배음 생성). 대역·길이를 수치로 맞춰야 할 때 쓴다.

교훈 하나: 실물 타격음(살점·흙)은 순수 합성으로 만들지 않는 게 낫다. 노이즈와 감쇠
정현파로는 대역 수치는 맞출 수 있어도 "무엇을 때린 소리인가"가 만들어지지 않는다.

  zombie_hit  좀비 피격 — 생성 소스의 두 테이크(둔중한 몸통 + 젖은 파열)를 겹쳐 만든다.
              한때 순수 합성으로 만들었으나 대역 수치는 맞아도 타격으로 들리지 않았다.
  ult_quake   베테랑 궁극기 — 원본이 저역 덩어리라 폰 스피커로 안 들렸다. 배음을 생성해
              들리는 대역을 만들고 암석 파열을 얹는다.
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
    """좀비 피격 — 생성음의 젖은 질감에 '때리는 순간'을 만들어 붙인다.

    소스를 그대로 쓸 수 없었던 이유: 포락선이 150ms 에 걸쳐 -53dB 에서 -4dB 로 서서히
    부풀어 오른다. 타격이 아니라 질척한 텍스처만 뽑힌 것이다. 그대로 자르면 파고율
    10.2dB, 피크 도달 86ms 로 뭉툭했다(게임의 좀비 사망음은 피크 도달 1ms).

    없는 어택은 잘라내서 만들 수 없으므로 이렇게 나눈다.
      · 몸통 = 소스에서 **가장 시끄러운 구간부터** 쓴다. 느린 빌드업은 버린다.
        살점의 젖은 질감은 실제 생성음에서만 나오므로 이 부분이 정체성이다.
      · 어택 = 짧은 광대역 버스트로 만들어 앞에 붙인다.

    앞서 절차적 합성이 실패했던 것과는 다른 일이다. 그때는 소리의 **정체성**(무엇을 때렸나)을
    합성으로 만들려다 악기음이 됐다. 여기서 합성이 맡는 건 '탁' 하는 가장자리뿐이고,
    정체성은 실제 녹음이 그대로 쥐고 있다.
    """
    src_dir = Path(os.environ.get("SFX_SRC_DIR", "/root/.claude/uploads"))
    found = next(iter(src_dir.rglob("24eaf120-zombie_hit.mp4")), None)
    if found is None:
        sys.exit("좀비 피격 원본(24eaf120-zombie_hit.mp4)을 찾을 수 없다")
    src = decode(found)

    def loud_part(t0: float, t1: float) -> np.ndarray:
        """구간에서 가장 시끄러운 지점의 20ms 앞부터 잘라 정규화한다."""
        seg = src[int(t0 * SR):int(t1 * SR)]
        b = SR // 500
        e = np.array([np.sqrt(np.mean(seg[i:i + b] ** 2)) for i in range(0, len(seg) - b, b)])
        seg = seg[max(0, (int(np.argmax(e)) - 10) * b):]
        return seg / max(float(np.abs(seg).max()), 1e-9)

    wet = loud_part(0.07, 0.65)      # 둔중한 몸통(200Hz 이하가 두껍다)
    gore = loud_part(1.75, 2.29)     # 젖은 파열(3~8kHz 가 두껍다)

    n = int(0.20 * SR)
    out = np.zeros(n)
    # 세기 비율은 대역 목표(저역 44 / 몸통 21 / 중역 17 / 고역 13%)에 맞춰 훑어 정했다.
    for layer, gain in ((wet, 0.6), (gore, 1.0)):
        m = min(n, len(layer))
        out[:m] += layer[:m] * gain

    # 살점의 몸통(200~800Hz)을 채운다. 소스에는 이 대역이 비어 있는데(테이크별 2.7% / 9.2%)
    # 그대로 두면 저역 쿵과 고역 파열만 남아 속이 빈 소리가 된다. 없는 대역을 노이즈로
    # 채우면 이물감이 생기므로, 소스의 저역에서 배음을 만들어 쓴다 — 원음에서 나온
    # 성분이라 같은 타격의 일부로 붙는다(지진 궁극기에 쓴 것과 같은 방법).
    body = band_filter(out, 40.0, 200.0)
    body /= max(float(np.abs(body).max()), 1e-9)
    out += band_filter(np.tanh(body * 6.0), 200.0, 800.0) * 2.0

    # 어택 — 맞는 순간의 '탁'. 6kHz 로우패스로 눌러 유리처럼 밝아지지 않게 한다.
    ta = np.arange(n) / SR
    out += one_pole_lp(rng.standard_normal(n) * np.exp(-ta / 0.0016), 6000.0) * 5.0

    out[-int(0.05 * SR):] *= np.linspace(1.0, 0.0, int(0.05 * SR))
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


# 이 셋은 대응 원본(업로드)이 없어 **커밋된 에셋 자체가 재료**다. 그런데 결과를 같은
# 경로에 덮어쓰므로, 그냥 읽으면 두 번째 실행이 이미 가공된 것을 다시 가공한다(배음 위에
# 배음). 그래서 가공 전 상태가 담긴 커밋에서 읽는다 — 몇 번을 돌려도 같은 결과가 나온다.
PRISTINE_REV = "8b473ee6b019320c7e816177e352045195ff1e4c"


def decode_pristine(rel: str) -> np.ndarray:
    """가공 전 에셋을 커밋에서 꺼내 디코드한다."""
    blob = subprocess.run(["git", "-C", str(ROOT), "show", f"{PRISTINE_REV}:{rel}"],
                          capture_output=True, check=True).stdout
    out = subprocess.run([FFMPEG, "-v", "error", "-i", "-", "-f", "f32le", "-ac", "1",
                          "-ar", str(SR), "-"], input=blob, capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype=np.float32).astype(np.float64)


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



def _quiet_norm(x: np.ndarray) -> np.ndarray:
    """RMS 를 기준에 맞추되 피크가 캡을 넘으면 **RMS 를 포기하고** 피크에 맞춘다.

    공용 normalize() 는 tanh 로 피크를 눌러 RMS 를 채우는데, 총성처럼 파고율이 20dB 넘는
    소리에 그걸 걸면 포화가 곧 왜곡으로 들린다. 여기서는 기준 미달을 감수하고, 모자란
    만큼은 SoundManager 볼륨에서 채운다(SOUND_GUIDE §8).
    """
    rms = float(np.sqrt(np.mean(x ** 2)))
    if rms <= 0:
        return x
    x = x * (10.0 ** (TARGET_RMS_DB / 20.0) / rms)
    peak = float(np.abs(x).max())
    cap = 10.0 ** (PEAK_CAP_DB / 20.0)
    return x * (cap / peak) if peak > cap else x


def _exciter(x: np.ndarray, drive: float, gain: float) -> np.ndarray:
    """저역에서 배음을 만들어 들리는 대역(150~900Hz)에 넣는다 — SOUND_GUIDE §2.

    저역을 키우는 것과는 다르다. 폰 스피커는 200Hz 이하를 못 내므로, 그 대역을 아무리
    올려도 안 들린다. 배음은 원음에서 파생돼 이질감 없이 같은 소리로 붙는다.
    """
    low = band_filter(x, 25.0, 220.0)
    low /= max(float(np.abs(low).max()), 1e-9)
    return band_filter(np.tanh(low * drive), 150.0, 900.0) * gain


def synth_shoot(_rng: np.random.Generator) -> np.ndarray:
    """기본 총 발사음 — 폰에서 들리게 만든다.

    게임에서 가장 자주 나는 소리인데 폰 체감이 -37dB 로 세트 중 가장 작았다(중앙값 -26.5).
    에너지의 85.7% 가 200Hz 이하라 기기가 그 대역을 못 낸다. 저역 무게를 조금만 덜고
    (0.85) 배음을 얹어, 권총다운 저역 펀치는 남기면서 들리게 한다.
    """
    src = decode_pristine("assets/audio/sfx_shoot.ogg")
    return _quiet_norm(src * 0.85 + _exciter(src, 6.0, 0.5))


def synth_boom(_rng: np.random.Generator) -> np.ndarray:
    """범용 폭발음 — 16개 호출부가 공유한다.

    에너지의 99.8% 가 200Hz 이하로, §2 에서 '소리가 안 난다'고 판정했던 지진 궁극기
    (99.4%)보다 심했다. 보스 페이즈 전환은 피치 0.55 로 재생해 완전히 폰 대역 밖이다.
    저역 비중을 72% 로 남겨 '쿵' 은 지키고 배음으로 들리게 한다.
    """
    src = decode_pristine("assets/audio/sfx_boom.wav")
    return _quiet_norm(src * 0.8 + _exciter(src, 6.0, 0.7))


def synth_ui_click(_rng: np.random.Generator) -> np.ndarray:
    """버튼 탭음 — '탭' 이 아니라 스웰이었다.

    피크가 107ms 뒤에 와서(§11 기준 0~5ms) 누른 순간과 소리가 어긋났고, 8kHz 이상이
    41% 라 들릴 때는 쨍했다. 진짜 트랜지언트 앞에서 잘라 0.09초로 줄이고, 3kHz 위를
    10dB 깎는다(§5 처방).
    """
    src = decode_pristine("assets/audio/sfx_ui_click.ogg")
    step = SR // 1000
    e = np.array([np.sqrt(np.mean(src[i:i + step] ** 2)) for i in range(0, len(src) - step, step)])
    x = src[max(0, int(np.argmax(e)) - 4) * step:][:int(0.09 * SR)].copy()
    tail = int(0.02 * SR)
    x[-tail:] *= np.linspace(1.0, 0.0, tail)
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    ramp = np.clip((f - 3000.0) / (3000.0 * 1.5), 0.0, 1.0)
    return _quiet_norm(np.fft.irfft(np.fft.rfft(x) * 10.0 ** (-10.0 * ramp / 20.0), n))


# 출력 포맷 — 기존 파일의 컨테이너·샘플레이트를 그대로 지킨다.
# 규격은 48kHz OGG 지만, 이 셋은 내용이 전부 저역이라 상향 리샘플이 용량만 늘린다.
# boom 은 heap_hunt.gd 가 WAV 대조군(_SOUND_WAV)으로 쓰고 있어 컨테이너를 바꾸면 안 된다.
SELF_NORMALIZED = {"shoot", "boom", "ui_click"}

FORMATS = {
    "shoot": ("sfx_shoot.ogg", 44100),
    "boom": ("sfx_boom.wav", 22050),
    "ui_click": ("sfx_ui_click.ogg", 44100),
}

GENERATORS = {
    "zombie_hit": synth_zombie_hit,
    "shoot": synth_shoot,
    "boom": synth_boom,
    "ui_click": synth_ui_click,
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


def encode(x: np.ndarray, path: Path, out_sr: int = SR) -> None:
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    codec = ["-c:a", "pcm_s16le"] if path.suffix == ".wav" else ["-c:a", "libvorbis", "-q:a", "6"]
    subprocess.run(
        [FFMPEG, "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
         "-ar", str(out_sr), "-ac", "1", *codec, str(path)],
        input=pcm, check=True)


def main() -> None:
    names = sys.argv[1:] or list(GENERATORS)
    rng = np.random.default_rng(SEED)
    for name in names:
        gen = GENERATORS.get(name)
        if gen is None:
            sys.exit(f"알 수 없는 사운드: {name} (가능: {', '.join(GENERATORS)})")
        # 파고율이 높은 소리는 생성기가 _quiet_norm 으로 스스로 맞춘다 — 여기서 공용
        # normalize 를 한 번 더 걸면 tanh 포화가 들어가 그 의도가 무효가 된다.
        x = gen(rng) if name in SELF_NORMALIZED else normalize(gen(rng))
        fname, out_sr = FORMATS.get(name, (f"sfx_{name}.ogg", SR))
        out = OUT_DIR / fname
        encode(x, out, out_sr)
        rms = 20 * np.log10(float(np.sqrt(np.mean(x ** 2))))
        peak = 20 * np.log10(float(np.abs(x).max()))
        print(f"{out.name:22s} {len(x)/SR:5.3f}s  RMS={rms:6.1f}dB  peak={peak:5.1f}dB")


if __name__ == "__main__":
    main()
