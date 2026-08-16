#!/usr/bin/env python3
"""효과음 진단 — 소리가 이상할 때 '왜'를 숫자로 좁힌다.

귀로 "뭔가 아닌데"까지는 알아도 무엇을 고칠지는 안 나온다. 이 스크립트가 재는 값들은
전부 실제로 문제를 짚어낸 적이 있는 것들이다(각 항목의 의미는 SOUND_GUIDE.md 참고).

사용:
  python3 tools/analyze_sfx.py sfx_ult_arrow.ogg            # 파일명만 줘도 assets/audio 에서 찾는다
  python3 tools/analyze_sfx.py ult_arrow zombie_hit         # sfx_ 접두사도 생략 가능
  python3 tools/analyze_sfx.py --compare horde level_up     # 두 소리가 헷갈리는지 진단
  python3 tools/analyze_sfx.py --all                        # assets/audio 전체
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
AUDIO_DIR = Path(__file__).resolve().parent.parent / "assets" / "audio"


def resolve(name: str) -> Path:
    """이름을 관대하게 받는다 — 경로 / 파일명 / sfx_ 없는 짧은 이름 모두."""
    for cand in (Path(name), AUDIO_DIR / name, AUDIO_DIR / f"{name}.ogg",
                 AUDIO_DIR / f"sfx_{name}.ogg", AUDIO_DIR / f"sfx_{name}.wav"):
        if cand.is_file():
            return cand
    sys.exit(f"찾을 수 없다: {name}")


def decode(path: Path, channels: int = 1) -> np.ndarray:
    out = subprocess.run(
        [FFMPEG, "-v", "error", "-i", str(path), "-f", "f32le", "-ac", str(channels),
         "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    x = np.frombuffer(out, dtype=np.float32).astype(np.float64)
    return x.reshape(-1, channels) if channels > 1 else x


def db(v: float) -> float:
    return 20.0 * np.log10(max(float(v), 1e-12))


def a_weighted(x: np.ndarray) -> float:
    """A-가중 체감 음량 — 귀는 저역에 둔하고 2~5kHz 에 예민하다.

    RMS 가 같아도 저역 위주 소리는 조용하게, 중역 위주 소리는 크게 들린다. 파일 음량만
    맞춰 놓고 "왜 안 들리지"를 할 때 이 값이 답을 준다.
    """
    n = len(x)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1e-6)
    f2 = f ** 2
    ra = (12194 ** 2 * f2 ** 2) / ((f2 + 20.6 ** 2) * np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2))
                                   * (f2 + 12194 ** 2))
    y = np.fft.irfft(np.fft.rfft(x) * 10 ** ((20 * np.log10(np.maximum(ra, 1e-12)) + 2.0) / 20), n)
    return db(np.sqrt(np.mean(y ** 2)))


def phone_level(x: np.ndarray) -> float:
    """폰 스피커 근사 — 300Hz 이하를 급격히 깎은 뒤의 음량.

    소형 스피커는 저역을 거의 못 낸다. 서브베이스 덩어리로 만든 소리가 개발자 헤드폰에서만
    잘 들리고 실제 기기에서는 무음인 사고를 잡는다.
    """
    n = len(x)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1e-6)
    hp = (f / 300.0) ** 2 / (1 + (f / 300.0) ** 2)
    return db(np.sqrt(np.mean(np.fft.irfft(np.fft.rfft(x) * hp, n) ** 2)))


def spectrum(x: np.ndarray):
    n = min(4096, len(x))
    frames = [np.abs(np.fft.rfft(x[i:i + n] * np.hanning(n)))
              for i in range(0, max(1, len(x) - n), max(1, n // 2)) if len(x[i:i + n]) == n]
    if not frames:
        pad = np.pad(x, (0, max(0, n - len(x))))[:n]
        frames = [np.abs(np.fft.rfft(pad * np.hanning(n)))]
    s = np.mean(frames, axis=0)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    p = s ** 2
    return f, s, p / max(p.sum(), 1e-12)


def envelope_stats(x: np.ndarray) -> tuple:
    """10ms 해상도 포락선 — 개별 타격이 살아있는지, 뭉개진 소리인지 가른다.

    피크-중앙이 크면 타격 사이가 조용해 하나하나 들리고, 작으면 끊김 없는 덩어리다
    (파리떼 17dB 수준이면 '웅웅거림', 유리 깨짐 29dB 수준이면 '또렷한 타격').
    """
    b = int(0.010 * SR)
    if len(x) < b * 4:
        return 0.0, 0.0
    e = np.array([np.sqrt(np.mean(x[i:i + b] ** 2)) for i in range(0, len(x) - b, b)])
    d = 20 * np.log10(np.maximum(e, 1e-9))
    d = d[d > d.max() - 45]
    return float(np.percentile(d, 95) - np.percentile(d, 50)), float(np.percentile(d, 95) - np.percentile(d, 10))


def impact_rate(x: np.ndarray) -> float:
    """초당 타격 수 — 에너지가 급상승하는 지점을 센다."""
    h = 480
    if len(x) < h * 4:
        return 0.0
    e = np.array([np.sqrt(np.mean(x[i:i + h] ** 2)) for i in range(0, len(x) - h, h)])
    d = np.diff(np.log(np.maximum(e, 1e-9)))
    hits = [i for i in range(1, len(d)) if d[i] > 0.55 and d[i] > d[i - 1]]
    return len(hits) / (len(x) / SR)


def report(path: Path) -> dict:
    st = decode(path, 2)
    stereo = bool(np.any(np.abs(st[:, 0] - st[:, 1]) > 1e-4))
    x = st.mean(axis=1)          # 분석은 모노 합으로 — 대역·구조는 채널 합이 기준
    f, s, p = spectrum(x)

    def band(lo, hi):
        return float(p[(f >= lo) & (f < hi)].sum()) * 100

    sp = np.maximum(s, 1e-12)
    flat = float(np.exp(np.log(sp).mean()) / sp.mean())
    loud = np.where(np.abs(x) > 10 ** (-50 / 20))[0]
    onset = loud[0] / SR * 1000 if len(loud) else -1.0
    pk_med, pk_floor = envelope_stats(x)
    # 스테레오는 채널별로 재야 한다 — 모노 합만 보면 상관도 높은 소리가 실제보다 크게 나온다.
    ch_rms = [db(np.sqrt(np.mean(st[:, i] ** 2))) for i in range(2)] if stereo else None
    m = dict(name=path.stem.replace("sfx_", ""), dur=len(x) / SR, stereo=stereo,
             rms=max(ch_rms) if ch_rms else db(np.sqrt(np.mean(x ** 2))),
             peak=db(np.abs(st).max()), mono_peak=db(np.abs(x).max()), onset=onset, aw=a_weighted(x), phone=phone_level(x),
             centroid=float((f * p).sum()), flat=flat, pk_med=pk_med, pk_floor=pk_floor,
             rate=impact_rate(x), sub=band(0, 200), low=band(200, 800), mid=band(800, 3000),
             hi=band(3000, 8000), air=band(8000, 24000))

    print(f"\n═══ {m['name']}  ({m['dur']:.2f}s) ═══")
    ch = "스테레오" if m["stereo"] else "모노"
    print(f"  음량      RMS={m['rms']:6.1f}dB  피크={m['peak']:6.1f}dB  온셋={m['onset']:5.1f}ms  ({ch})"
          f"{'  ← 어택이 늦다(화면 연출과 어긋남)' if m['onset'] > 15 else ''}")
    if m["stereo"] and m["mono_peak"] > -1.0:
        print("  ⚠ 모노로 합쳐지면 피크가 넘친다 — 폰 스피커(모노 재생)에서 찌그러진다")
    print(f"  체감      A-가중={m['aw']:6.1f}dB  폰스피커={m['phone']:6.1f}dB"
          f"{'  ← 폰에서 거의 안 들린다' if m['phone'] < -32 else ''}")
    print(f"  대역      ~200={m['sub']:4.1f}%  200-800={m['low']:4.1f}%  0.8-3k={m['mid']:4.1f}%  "
          f"3-8k={m['hi']:4.1f}%  8k+={m['air']:4.1f}%")
    print(f"  음색      중심={m['centroid']:5.0f}Hz  플랫니스={m['flat']:.4f}"
          f"  ({'노이즈성' if m['flat'] > 0.02 else '음정성'})")
    # 구조 지표는 '여러 사건이 이어지는 소리'에만 의미가 있다. 단발 타격음은 애초에
    # 사건이 하나라 피크-중앙이 작게 나오는 게 정상이므로 재지 않는다.
    if m["dur"] >= 1.0:
        print(f"  구조      피크-중앙={m['pk_med']:5.1f}dB  피크-바닥={m['pk_floor']:5.1f}dB  "
              f"타격={m['rate']:4.1f}회/초"
              f"{'  ← 뭉개진 덩어리(개별 사건이 서로 메워짐)' if m['pk_med'] < 12 else ''}")
    if m["air"] > 15:
        print("  ⚠ 8kHz 이상이 두껍다 — 쨍하게 박혀 반복 재생 시 피로하다(고역 셸프 검토)")
    if m["sub"] > 85:
        print("  ⚠ 저역 덩어리 — 폰 스피커가 못 내는 대역에 에너지가 몰려 있다(배음 생성 검토)")
    return m


def compare(a: dict, b: dict) -> None:
    """두 소리가 헷갈리는지 — 길이·중심 주파수·음색 세 축에서 얼마나 떨어져 있나."""
    print(f"\n═══ 혼동 진단: {a['name']} vs {b['name']} ═══")
    ratio = a["dur"] / b["dur"] if b["dur"] else 0
    print(f"  길이비      {ratio * 100:5.0f}%  {'← 비슷하다' if 0.75 < ratio < 1.33 else '충분히 다름'}")
    gap = abs(a["centroid"] - b["centroid"])
    print(f"  중심 주파수 {gap:5.0f}Hz 차이  {'← 가깝다' if gap < 700 else '충분히 다름'}")
    fr = a["flat"] / b["flat"] if b["flat"] else 0
    print(f"  플랫니스비  {fr:5.2f}배  {'← 같은 성격(둘 다 음정성/둘 다 노이즈성)' if 0.5 < fr < 2.0 else '충분히 다름'}")
    print("  → 세 축 중 둘 이상이 '비슷하다'면 실제로 헷갈린다. 하나를 확실히 벌려야 한다.")


def main() -> None:
    ap = argparse.ArgumentParser(description="효과음 진단")
    ap.add_argument("names", nargs="*", help="파일 경로 또는 사운드 이름")
    ap.add_argument("--compare", nargs=2, metavar=("A", "B"), help="두 소리의 혼동 가능성 진단")
    ap.add_argument("--all", action="store_true", help="assets/audio 전체")
    args = ap.parse_args()

    if args.compare:
        compare(*[report(resolve(n)) for n in args.compare])
        return
    names = args.names
    if args.all:
        names = sorted(p.name for p in AUDIO_DIR.glob("sfx_*"))
    if not names:
        ap.error("진단할 사운드를 지정하거나 --all 을 쓴다")
    for n in names:
        report(resolve(n))


if __name__ == "__main__":
    main()
