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


def _rng_for(name: str) -> "np.random.Generator":
    """사운드 이름마다 독립된 난수열을 준다 — **재현성의 전제다.**

    처음엔 `main()` 에서 `default_rng(SEED)` 하나를 만들어 생성기들이 차례로 썼다.
    그러면 각 생성기가 몇 개를 뽑느냐에 따라 뒤에 오는 생성기의 난수열이 밀린다 —
    즉 결과가 **"무엇을 함께 생성했는가"와 "그 순서"** 에 달라진다.
    `gen_sfx.py tesla_arc` 와 `gen_sfx.py` 가 서로 다른 파일을 내놓았다.

    이름에서 씨앗을 뽑으면 그 의존이 사라진다. 하나만 다시 뽑든 전부 뽑든 결과가 같다.
    (`hash()` 는 실행마다 달라지므로 쓰면 안 된다 — 고정 해시를 직접 계산한다.)
    """
    h = 0
    for ch in name:
        h = (h * 131 + ord(ch)) & 0xFFFFFFFF
    return np.random.default_rng(SEED * 1000003 + h)

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


# ─────────────────────── P2-24: UI 전용 소리 네 개 ───────────────────────
#
# 지금까지 UI 사운드는 `ui_click` 하나였다. 선택 성공은 `gold`(동전)를 피치로 일곱 가지
# 변주했고, **거부는 `player_hurt`(피격음)를 돌려썼다** — 살 돈이 없을 때 맞는 소리가 났다.
#
# UI 음은 전투음과 다른 규칙을 따른다(SOUND_GUIDE §5). 런 하나에서 가장 자주 울리는 축이라
#   · 짧고 건조하게 — 꼬리가 길면 연달아 누를 때 뭉갠다
#   · 2~5kHz 를 피한다 — 귀가 가장 예민해 반복되면 금세 피로하다
#   · 개성을 죽인다 — 인상적인 소리일수록 몇 분 만에 거슬린다
# 그래서 넷 다 0.10~0.16초, 중심을 600~1400Hz 에 두고 3kHz 위를 깎는다.
#
# 넷은 **한 가족**이어야 한다. 같은 음색에서 방향만 다르게 한다:
#   ui_open   올라감  — 무언가 열렸다
#   ui_close  내려감  — 닫혔다 (열기보다 짧고 조용하게: 닫기는 결과가 아니라 정리다)
#   ui_select 두 번 올라감 — 정했다
#   ui_deny   낮게 떨림 — 안 된다 (음정이 아니라 거친 맥놀이로, 다른 셋과 확실히 갈린다)
#
# 순수 합성으로 만드는 이유: 이 소리들에는 물리적 대상이 없다(SOUND_GUIDE §9 의 경계선 —
# 기계·전기·추상은 합성이 통하고, 생물의 목소리는 안 된다).


def _ui_env(n: int, attack: float = 0.004, release: float = 0.6) -> np.ndarray:
    """UI 음 공통 포락선 — 온셋 0ms(§7), 짧은 어택 뒤 지수 감쇠."""
    t = np.arange(n) / SR
    a = int(attack * SR)
    env = np.exp(-t / (release * t[-1] if t[-1] > 0 else 1.0))
    if a > 0:
        env[:a] *= np.linspace(0.0, 1.0, a)
    return env


def _ui_shelf(x: np.ndarray, hz: float = 3000.0, db: float = -12.0) -> np.ndarray:
    """3kHz 위를 깎는다 — 반복 재생되는 소리에서 찌르는 성분만 덜어내는 처방(§5)."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    ramp = np.clip((f - hz) / (hz * 1.5), 0.0, 1.0)
    return np.fft.irfft(np.fft.rfft(x) * 10.0 ** (db * ramp / 20.0), n)


def _ui_tone(f0: float, f1: float, dur: float, harm: float = 0.35) -> np.ndarray:
    """f0 에서 f1 로 미끄러지는 짧은 음. 2배음을 조금 섞어 삐 소리가 아니라 '딩'이 되게 한다."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    # 지수 글라이드 — 선형보다 음정 변화가 자연스럽게 들린다.
    freq = f0 * (f1 / f0) ** (t / max(t[-1], 1e-9))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return (np.sin(phase) + harm * np.sin(2 * phase)) * _ui_env(n)


def synth_ui_open(_rng: np.random.Generator) -> np.ndarray:
    """팝업이 열린다 — 700 → 1080Hz 로 올라가는 짧은 딩."""
    return _ui_shelf(_ui_tone(700.0, 1080.0, 0.11))


def synth_ui_close(_rng: np.random.Generator) -> np.ndarray:
    """팝업이 닫힌다 — 열기의 역방향. 더 짧고 배음도 적게(정리하는 소리라 존재감을 낮춘다)."""
    return _ui_shelf(_ui_tone(1000.0, 660.0, 0.085, harm=0.22))


def synth_ui_select(_rng: np.random.Generator) -> np.ndarray:
    """선택 확정 — 두 음이 연달아 올라간다(880 → 1320Hz). '정했다'는 두 박자로 읽힌다."""
    # 두 음 다 0.8~3kHz 한가운데 두면 반복 시 피로한 대역만 쓰게 된다(§5). 배음을 키워
    # 200~800Hz 몸통을 함께 만들고, 첫 음을 조금 크게 해 피크가 앞에 오게 한다
    # (뒤에 오면 "때리는 순간이 없다"로 잡힌다 — 확정음은 누른 순간과 붙어야 한다).
    a = _ui_tone(720.0, 760.0, 0.055, harm=0.55)
    b = _ui_tone(1080.0, 1120.0, 0.105, harm=0.55)
    gap = int(0.045 * SR)
    out = np.zeros(gap + len(b))
    out[:len(a)] += a
    out[gap:] += b * 0.92
    return _ui_shelf(out)


def synth_ui_deny(_rng: np.random.Generator) -> np.ndarray:
    """거부 — 낮고 거친 맥놀이. 음정이 아니라 '떨림'이라 다른 셋과 확실히 갈린다.

    가까운 두 주파수를 겹치면 그 차이만큼 진폭이 뛴다(여기선 14Hz). 이것이 부저의 정체다.

    ⚠️ 처음엔 196/208Hz 로 만들었다가 측정에서 걸렀다 — 200Hz 이하가 50.4%, 폰 스피커
    체감이 나머지 셋보다 **8dB 낮았다.** 기기가 그 대역을 못 낸다(§2). 기음을 264Hz 로
    올리고 홀수 배음이 강한 파형(tanh 하드 드라이브)을 써서 792·1320·1848Hz 를 만든다 —
    거친 성격은 맥놀이가 유지하고, 들리는 몫은 배음이 낸다.
    """
    n = int(0.17 * SR)
    t = np.arange(n) / SR
    base = np.sin(2 * np.pi * 264.0 * t) + np.sin(2 * np.pi * 278.0 * t)
    body = np.tanh(base * 4.5)          # 세게 몰아 홀수 배음을 만든다(§2 익사이터)
    return _ui_shelf(body * _ui_env(n, attack=0.006, release=0.75), db=-14.0)


# ─────────────────────── P2-12: 비어 있던 자리를 메우는 소리들 ───────────────────────
#
# 검수에서 나온 공백은 두 종류였다. 하나는 **무기 모듈 10개 중 3개가 완전히 무음**인 것,
# 다른 하나는 **연출은 요란한데 소리는 잡몹과 같은 것**이다. 아래는 그중 절차적 합성이
# 정직하게 통하는 것만 만든다 — 기계·전기·구조물은 합성이 잘 되고, 생물의 목소리는 안 된다
# (SOUND_GUIDE §9). 보스 포효를 여기서 만들지 않은 이유가 그것이다.


def synth_chainsaw(rng: np.random.Generator) -> np.ndarray:
    """전기톱이 무는 순간 — 톱니가 살을 긁는 짧은 '브르릅'.

    체인소는 지속형이 아니라 **표적에 날아가 한 번 무는 펫**이다(Chainsaw.gd `_bite`).
    그래서 루프가 아니라 원샷이 맞고, 물기 간격(fire_interval)마다 한 번씩 난다.

    정체성은 **톱니가 훑는 주기성**에 있다. 그냥 노이즈를 깎으면 '치익' 하는 바람이 되고,
    톱니 주기를 정확히 일정하게 두면 기계음이 아니라 부저가 된다. 그래서 임펄스 열의
    간격을 매번 조금씩 흔들어(±12%) 날붙이가 살에 걸려 튀는 불규칙을 만든다.
    """
    n = int(0.20 * SR)
    t = np.arange(n) / SR
    env = np.minimum(1.0, t / 0.001) * np.exp(-t / 0.075)

    # 톱니 임펄스 열 — 초당 약 115회. 간격을 흔들어 '걸리는' 느낌을 만든다.
    teeth = np.zeros(n)
    pos = 0.0
    while pos < n:
        i = int(pos)
        if i < n:
            teeth[i] = rng.uniform(0.55, 1.0)
        pos += (SR / 115.0) * rng.uniform(0.88, 1.12)
    teeth = svf_bandpass(teeth * rng.standard_normal(n), np.full(n, 1700.0), q=0.8)
    saw = one_pole_lp(teeth, 4200.0) * env * 9.0

    # 모터 몸통 — 장비가 돌아간다는 무게. 다만 **아주 얇게만** 깐다.
    #
    # 처음엔 57.5Hz 톱니파를 0.55 로 깔았다가 실측에서 걸렸다: 200Hz 이하가 에너지의
    # 91% 를 먹어 폰 체감이 -23dB 로 주저앉고, 정작 정체성인 톱니는 3.1% 였다(§2).
    # 기음을 115Hz(톱니 주기와 같은)로 올리고 게인을 1/4 로 줄여, 무게는 배음으로 낸다.
    motor = np.zeros(n)
    for k, g in ((1, 0.45), (2, 0.34), (3, 0.22), (4, 0.12), (6, 0.06)):
        motor += g * np.sin(2 * np.pi * 115.0 * k * t + rng.uniform(0, 2 * np.pi))
    saw += motor * env * 0.65

    # 젖은 살점 — 이게 없으면 나무를 써는 소리가 된다. 대역은 중역으로 올려 둔다.
    saw += band_filter(rng.standard_normal(n), 300.0, 1500.0) * np.exp(-t / 0.03) * 1.3

    saw[-int(0.03 * SR):] *= np.linspace(1.0, 0.0, int(0.03 * SR))
    return saw


def synth_drone_shot(rng: np.random.Generator) -> np.ndarray:
    """드론의 작은 사격음 — 플레이어 총성과 **겹쳐도 서로 지우지 않게** 만든다.

    드론은 최대 여러 기가 동시에 쏘므로 `shoot` 을 돌려쓸 수 없다. 같은 키를 쓰면
    스로틀(45ms)을 공유해 플레이어 총성이 드론에 먹히거나 그 반대가 된다.

    그래서 대역을 아예 갈라 둔다 — 플레이어 총성은 저역 펀치(200Hz 이하 69%)이고,
    이쪽은 1.8→0.7kHz 하강 스윕의 얇은 '핑'이다. 동시에 나도 각각 들린다.
    """
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    env = np.minimum(1.0, t / 0.0008) * np.exp(-t / 0.022)
    sweep = 1800.0 * np.exp(-t / 0.030) + 700.0
    ping = np.sin(2 * np.pi * np.cumsum(sweep) / SR) * env
    ping += 0.35 * np.sin(4 * np.pi * np.cumsum(sweep) / SR) * env    # 2배음 — 얇게 반짝
    ping += one_pole_lp(rng.standard_normal(n), 5000.0) * np.exp(-t / 0.003) * 0.5   # 발사 클릭
    ping[-int(0.015 * SR):] *= np.linspace(1.0, 0.0, int(0.015 * SR))
    return ping


def synth_magnet(rng: np.random.Generator) -> np.ndarray:
    """골드 자석 버프 발동 — 무음이던 자리에 '빨아들이기 시작했다'를 알린다.

    같은 골드 계열인 `gold`(코인 띠링)와 헷갈리면 안 된다. §3 의 세 축으로 갈라 둔다 —
    `gold` 는 1.06초·고역·맑은 단음이고, 이쪽은 0.55초·중역·**상승 스윕**이다.
    올라가는 음형 자체가 '흡입이 시작됐다'는 뜻으로 읽힌다(내려가면 종료로 읽힌다).
    """
    n = int(0.55 * SR)
    t = np.arange(n) / SR
    env = np.minimum(1.0, t / 0.004) * np.exp(-t / 0.20)
    rise = 300.0 + 620.0 * np.clip(t / 0.30, 0.0, 1.0) ** 1.6      # 300 → 920Hz
    out = np.sin(2 * np.pi * np.cumsum(rise) / SR) * env
    out += 0.30 * np.sin(2 * np.pi * np.cumsum(rise * 1.5) / SR) * env      # 완전5도 — 밝게
    out += 0.14 * np.sin(2 * np.pi * np.cumsum(rise * 2.0) / SR) * env * 0.6
    # 자기장 떨림 — 스윕에 얹는 아주 옅은 진폭 변조. 순음이면 알림음처럼 밋밋하다.
    out *= 1.0 + 0.16 * np.sin(2 * np.pi * 23.0 * t)
    out += one_pole_lp(rng.standard_normal(n), 3000.0) * np.exp(-t / 0.006) * 0.30   # 흡착 클릭
    out[-int(0.06 * SR):] *= np.linspace(1.0, 0.0, int(0.06 * SR))
    return out


def synth_weather(rng: np.random.Generator) -> np.ndarray:
    """날씨 전환 — 배너만 뜨고 소리가 없던 자리.

    전환은 '사건'이 아니라 '상태가 바뀐다'는 신호다. 그래서 타격음이 아니라 바람 한 줄기로
    만든다. 여기서는 어택이 없는 것이 정상이다(§11) — 훅 소리는 부풀었다 빠져야 한다.

    노이즈를 그대로 두면 백색소음이라 아무 의미가 없다. 밴드패스 중심을 400→2200→500Hz
    로 훑어 '지나간다'는 방향감을 만든다. 어느 날씨로 바뀌는지는 호출부가 피치로 가른다.
    """
    n = int(0.90 * SR)
    t = np.arange(n) / SR
    u = t / t[-1]
    env = np.sin(np.pi * u) ** 1.4                        # 부풀었다 빠지는 대칭 포락선
    fc = 400.0 + 1400.0 * np.sin(np.pi * u) ** 2          # 400 → 1800 → 500Hz
    # ⚠ 밴드패스만으로는 고역이 새어 나온다. q=0.7 로 통과시켰더니 8kHz 이상이 22.9%,
    # 중심 5757Hz 로 '바람' 이 아니라 '치익' 이 됐다 — 뚜껑을 씌워 눌러야 바람이 된다(§5).
    air = one_pole_lp(svf_bandpass(rng.standard_normal(n), fc, q=0.7), 2400.0) * env * 9.0
    air += one_pole_lp(rng.standard_normal(n), 450.0) * env * 1.2       # 낮게 깔리는 두께
    air[-int(0.12 * SR):] *= np.linspace(1.0, 0.0, int(0.12 * SR))
    return air


def synth_boss_die(rng: np.random.Generator) -> np.ndarray:
    """보스 처치 — 런에서 가장 큰 순간인데 잡몹과 같은 소리가 나던 자리.

    연출은 이미 크다(4중 충격파 · 히트스톱 · 흔들림 11 · 코인 분수). 거기에 0.16초짜리
    `zombie_die` 가 붙어 있었다. 크기가 맞지 않는다.

    포효로 만들지 않은 이유 — 그건 생물의 목소리라 합성으로는 악기가 된다(§9).
    대신 **구조물이 무너지는 소리**로 간다. 화면에서 실제로 벌어지는 일이기도 하다.
      · 서브 드롭 — 110→32Hz. 폰에서 안 들리므로 배음을 만들어 얹는다(§2).
      · 폭발 버스트 — 0초의 '쾅'.
      · 파편 — 1.2초에 걸쳐 흩어지는 암석 파열. 여운이 길어야 '컸다'고 읽힌다.
      · 링아웃 — 낮은 금속 잔향. 잡몹 사망과 갈리는 결정적인 층이다.
    """
    n = int(1.70 * SR)
    t = np.arange(n) / SR

    drop_f = 32.0 + 78.0 * np.exp(-t / 0.16)                       # 110 → 32Hz
    sub = np.sin(2 * np.pi * np.cumsum(drop_f) / SR) * np.exp(-t / 0.30)
    # 저역은 **몸으로 느끼는 층**이지 들리는 층이 아니다. 처음에 sub 0.9 · 링아웃 0.55 로
    # 두었더니 200Hz 이하가 98.4% 를 먹어 폰 체감 -27.4dB — 세트에서 가장 조용한 축이
    # 됐다. 저역은 존재감만 남기고, 들리는 몫은 배음과 파편이 진다(§2).
    out = sub * 0.35 + _exciter(sub, 6.0, 1.10)

    blast = rng.standard_normal(n) * np.exp(-t / 0.055)
    out += band_filter(blast, 250.0, 2600.0) * 4.5

    # 파편 — 산발적인 암석 파열. 시간이 갈수록 뜸해지고 작아진다.
    debris = np.zeros(n)
    pos = 0.05 * SR
    while pos < 1.30 * SR:
        i = int(pos)
        ln = int(rng.uniform(0.010, 0.035) * SR)
        seg = rng.standard_normal(min(ln, n - i))
        seg *= np.exp(-np.arange(len(seg)) / (0.006 * SR)) * rng.uniform(0.3, 1.0)
        debris[i:i + len(seg)] += seg
        # 간격을 넓게 잡는다. 촘촘하면 개별 파열이 서로를 메워 '뭉개진 덩어리'가 된다
        # (§4 — 처음 0.020~0.075초로 뒀다가 초당 10회로 붙어 그렇게 됐다).
        pos += rng.uniform(0.045, 0.150) * SR * (1.0 + 2.2 * pos / (1.30 * SR))
    out += svf_bandpass(debris, np.full(n, 1400.0), q=0.9) * np.exp(-t / 0.55) * 5.0

    # 링아웃 — 낮은 금속 공명 셋. 이 층이 '큰 것이 쓰러졌다'를 만든다.
    for f0, g, dec in ((78.0, 0.16, 0.85), (131.0, 0.20, 0.62), (196.0, 0.22, 0.45)):
        out += g * np.sin(2 * np.pi * f0 * t + rng.uniform(0, 2 * np.pi)) * np.exp(-t / dec)

    out[-int(0.25 * SR):] *= np.linspace(1.0, 0.0, int(0.25 * SR))
    return out


def synth_defeat(_rng: np.random.Generator) -> np.ndarray:
    """게임오버 스팅어 — 지속부를 잘라 스팅어답게 만든다.

    **감쇠하는 스팅어가 아니라 2.2초까지 최대 음량을 유지하는 지속음이었다.**
    포락선을 재면 0.5초부터 2.2초까지 피크 대비 3dB 안에 머문다. 그래서 사망 후
    0.35초 만에 뜨는 패널에서 플레이어가 곧바로 메뉴로 나가면, 소리가 최대 음량인
    채로 메인 메뉴까지 따라 들어왔다(P2-23).

    음악적 진행은 그보다 훨씬 먼저 끝난다. 0.2초 간격으로 스펙트럼을 보면
      0.0s 111Hz 충격 → 0.2s 469Hz 화음 → 0.6~1.2s 310→293Hz 하강 → 1.3s 착지
    이고, **1.4초 이후는 293Hz 를 무한정 붙들고 있는 드론**이다. 진행이 끝난 자리에서
    끊고 페이드를 앞당긴다 — 잘리는 느낌이 없는 이유가 그것이다.

    길이 2.60 → 1.60초. 같은 층의 `wave_clear`(1.59초)와 나란해진다.
    """
    src = decode_pristine("assets/audio/sfx_defeat.ogg")
    body = int(1.35 * SR)          # 착지(1.3초)까지는 그대로 둔다
    fade = int(0.25 * SR)          # 드론 구간을 페이드로 소모해 끝을 닫는다
    x = src[:body + fade].copy()
    x[-fade:] *= np.linspace(1.0, 0.0, fade) ** 1.4   # 살짝 볼록 — 뚝 끊기지 않게
    return x


# 출력 포맷 — 기존 파일의 컨테이너·샘플레이트를 그대로 지킨다.
# 규격은 48kHz OGG 지만, 이 셋은 내용이 전부 저역이라 상향 리샘플이 용량만 늘린다.
# boom 은 heap_hunt.gd 가 WAV 대조군(_SOUND_WAV)으로 쓰고 있어 컨테이너를 바꾸면 안 된다.
SELF_NORMALIZED = {"shoot", "boom", "ui_click"}

FORMATS = {
    "shoot": ("sfx_shoot.ogg", 44100),
    "boom": ("sfx_boom.wav", 22050),
    "ui_click": ("sfx_ui_click.ogg", 44100),
    # UI 음은 대역이 좁아 44.1kHz 로 충분하다(48k 로 두면 용량만 는다).
    "ui_open": ("sfx_ui_open.ogg", 44100),
    "ui_close": ("sfx_ui_close.ogg", 44100),
    "ui_select": ("sfx_ui_select.ogg", 44100),
    "ui_deny": ("sfx_ui_deny.ogg", 44100),
}

GENERATORS = {
    "zombie_hit": synth_zombie_hit,
    "shoot": synth_shoot,
    "boom": synth_boom,
    "ui_click": synth_ui_click,
    "ui_open": synth_ui_open,
    "ui_close": synth_ui_close,
    "ui_select": synth_ui_select,
    "ui_deny": synth_ui_deny,
    "tesla_arc": synth_tesla_arc,
    "ult_quake": synth_ult_quake,
    "chainsaw": synth_chainsaw,
    "drone_shot": synth_drone_shot,
    "magnet": synth_magnet,
    "weather": synth_weather,
    "boss_die": synth_boss_die,
    "defeat": synth_defeat,
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
    for name in names:
        gen = GENERATORS.get(name)
        if gen is None:
            sys.exit(f"알 수 없는 사운드: {name} (가능: {', '.join(GENERATORS)})")
        rng = _rng_for(name)
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
