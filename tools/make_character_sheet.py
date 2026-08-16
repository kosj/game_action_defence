#!/usr/bin/env python3
"""생성 이미지(마젠타 배경) → 걷기 스프라이트 시트 조립.

docs/character-sprite-handoff.md 5장의 파이프라인을 스크립트로 고정한 것.
예전에는 세션마다 스크래치패드에 다시 작성해야 했으므로 여기 커밋해 둔다.

사용법:
    # 걷기 시트 (프레임 여러 장 → run_<id>.png)
    python tools/make_character_sheet.py -o assets/sprites/run_veteran.png raw/vet_*.png

    # 대기 이미지 (한 장 → idle_<id>.png, 시트 조립 없음)
    python tools/make_character_sheet.py -o assets/sprites/idle_veteran.png --single raw/vet_idle.png

    # 키잉 결과만 확인 (프레임별 PNG 를 디렉터리에 덤프)
    python tools/make_character_sheet.py -o out.png --debug-dir dbg raw/*.png
"""

from __future__ import annotations

import argparse
import glob
import itertools
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

# ── 파이프라인 상수 (문서 5장과 일치) ──────────────────────────────────
TARGET_H = 150            # 각 프레임을 이 높이로 개별 정규화
TOL_MAGENTA = 70          # 마젠타 배경 색거리 허용치
TOL_WHITE = 60            # 흰 배경일 때
HOLE_TOL_MAGENTA = 48     # 갇힌 배경 구멍 제거 허용치
HOLE_TOL_WHITE = 25       # 흰 배경은 크림색 옷을 지키려고 더 빡빡하게
HUE_TOL_DEG = 10.0        # 마젠타로 볼 색상 차(도)
SAT_MIN = 90              # 마젠타로 볼 최소 채도 (0-255)
MIN_AREA = 2000           # 이 면적을 넘으면 figure 앵커
ANCHOR_MIN_H_RATIO = 0.55 # 앵커 높이가 중앙값의 이 비율 미만이면 제목 텍스트로 간주
GROUND_ASPECT = 3.0       # 가로가 세로의 이 배를 넘는 작은 조각 = 지면선/그림자
MERGE_EXPAND = 12         # 앵커 바운딩박스를 이만큼 넓혀 조각 편입 판정
CELL_PAD_W = 8            # 셀 폭 = 최대 프레임 폭 + 이 값
CELL_PAD_H = 4            # 셀 높이 = 최대 프레임 높이 + 이 값
BOTTOM_MARGIN = 2         # 바닥 정렬 여백
MAX_LIFT = 14             # 공중 포즈에 반영할 최대 리프트
MIN_ADJ_DIFF = 0.25       # 인접 프레임 실루엣 차이가 이 미만이면 애니메이션으로 안 읽힘

ALPHA_SOLID = 8           # 성분 라벨링에서 불투명으로 칠 알파 하한

# 흰 헤일로 제거: 아트 디렉션상 실루엣 바깥선은 "굵은 검정"이므로 경계의 밝은 무채색
# 픽셀은 생성기가 스티커풍 흰 테두리를 그린 아티팩트다. 정상 프레임은 경계 흰 비율이 0%,
# 문제 프레임만 2~3% 나온다. 안쪽 흰 아트(베테랑 수염 등)는 검정 외곽선에 둘러싸여 있어
# 경계 밴드에 걸리지 않는다. 최대 HALO_PASSES 픽셀만 벗겨 과잉 침식을 막는다.
HALO_LUM = 200            # 이 휘도 이상이면 밝음
HALO_SAT = 40             # 이 채도 미만이면 무채색 (0-255)
HALO_PASSES = 3           # 벗겨낼 최대 두께 — 정규화(TARGET_H) 기준 px.
                          # 원본은 보통 8배 크므로 실제 반복 수는 해상도에 비례해 늘린다.


def _key_color(rgb: np.ndarray) -> np.ndarray:
    """테두리 1px 링의 중앙값을 배경 키 컬러로 잡는다."""
    border = np.concatenate([
        rgb[0, :, :], rgb[-1, :, :], rgb[:, 0, :], rgb[:, -1, :],
    ], axis=0)
    return np.median(border, axis=0)


def _is_magenta(key: np.ndarray) -> bool:
    r, g, b = key
    return r > 120 and b > 120 and g < min(r, b) * 0.6


def _hue_deg(rgb: np.ndarray) -> np.ndarray:
    """RGB(float, 0-255) → 색상(도). 무채색은 0 으로 떨어지지만 채도로 걸러진다."""
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(
        mx == r, ((g - b) / d) % 6,
        np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4),
    )
    return h * 60.0


def key_out(img: Image.Image) -> tuple[Image.Image, np.ndarray]:
    """배경을 투명하게 만든 RGBA 이미지를 돌려준다."""
    rgb = np.asarray(img.convert("RGB"), dtype=np.float32)
    key = _key_color(rgb)
    magenta = _is_magenta(key)
    tol = TOL_MAGENTA if magenta else TOL_WHITE
    hole_tol = HOLE_TOL_MAGENTA if magenta else HOLE_TOL_WHITE

    dist = np.linalg.norm(rgb - key, axis=2)
    similar = dist <= tol

    if magenta:
        # 마젠타 계열은 색거리가 멀어도(그림자·글로우) 배경으로 본다.
        mx = rgb.max(axis=2)
        mn = rgb.min(axis=2)
        sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6) * 255.0, 0.0)
        dh = np.abs(_hue_deg(rgb) - _hue_deg(key[None, None, :])[0, 0])
        dh = np.minimum(dh, 360.0 - dh)
        similar |= (dh <= HUE_TOL_DEG) & (sat >= SAT_MIN)

    # 가장자리에서 닿는 성분만 진짜 배경 — 옷의 같은 색 면적은 살린다.
    lab, n = ndimage.label(similar, structure=np.ones((3, 3), dtype=np.uint8))
    edge_labels = set(lab[0, :]) | set(lab[-1, :]) | set(lab[:, 0]) | set(lab[:, -1])
    edge_labels.discard(0)
    bg = np.isin(lab, list(edge_labels)) if edge_labels else np.zeros_like(similar)

    # 갇힌 배경 구멍(팔 사이 틈 등)은 키 컬러에 충분히 가까울 때만 제거.
    trapped = similar & ~bg
    bg |= trapped & (dist <= hole_tol)

    alpha = np.where(bg, 0, 255).astype(np.uint8)

    # 경계 부드럽게: 침식본과 반반 섞고 살짝 블러 → 계단 현상 완화.
    a_img = Image.fromarray(alpha, mode="L")
    a_soft = Image.blend(a_img, a_img.filter(ImageFilter.MinFilter(5)), 0.5)
    a_soft = a_soft.filter(ImageFilter.GaussianBlur(0.8))
    af = np.asarray(a_soft, dtype=np.float32) / 255.0

    # 디스필: 반투명 픽셀에 남은 키 컬러 성분을 걷어낸다.
    safe = np.maximum(af, 1e-3)[..., None]
    out_rgb = np.clip((rgb - key * (1.0 - safe)) / safe, 0, 255)
    out_rgb = np.where(af[..., None] > 0, out_rgb, 0)

    rgba = np.dstack([out_rgb.astype(np.uint8), (af * 255).astype(np.uint8)])
    return Image.fromarray(rgba, mode="RGBA"), key


def recolor_white_halo(rgba: Image.Image, color: tuple[int, int, int]) -> tuple[Image.Image, int]:
    """스티커풍 흰 테두리를 다른 색으로 칠한다(지우지 않고 색만 바꾼다).

    UI 아이콘은 흰 테두리가 규약이지만, 월드에 놓이는 오브젝트는 좀비·플레이어와 같은
    검은 외곽선이어야 겉돌지 않는다. 판정 기준은 strip_white_halo 와 같다.
    """
    a = np.asarray(rgba).copy()
    rgb = a[..., :3].astype(np.float32)
    lum = rgb.mean(axis=2)
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6) * 255.0, 0.0)
    solid = a[..., 3] > ALPHA_SOLID
    hit = solid & (lum > HALO_LUM) & (sat < HALO_SAT)
    # 안쪽의 흰 아트(수염·하이라이트)를 건드리지 않도록 바깥 경계에 닿은 덩어리만 칠한다.
    lab, n = ndimage.label(hit, structure=np.ones((3, 3), dtype=np.uint8))
    if n > 0:
        outside = ~solid
        touching = set(np.unique(lab[ndimage.binary_dilation(
            outside, np.ones((3, 3), dtype=bool)) & hit]))
        touching.discard(0)
        hit = np.isin(lab, list(touching)) if touching else np.zeros_like(hit)
    a[..., 0] = np.where(hit, color[0], a[..., 0])
    a[..., 1] = np.where(hit, color[1], a[..., 1])
    a[..., 2] = np.where(hit, color[2], a[..., 2])
    return Image.fromarray(a, mode="RGBA"), int(np.count_nonzero(hit))


def strip_white_halo(rgba: Image.Image) -> tuple[Image.Image, int]:
    """실루엣 바깥 경계에 붙은 밝은 무채색 테두리를 벗겨낸다. (제거한 픽셀 수도 돌려줌)"""
    a = np.asarray(rgba).copy()
    rgb = a[..., :3].astype(np.float32)
    lum = rgb.mean(axis=2)
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6) * 255.0, 0.0)
    whiteish = (lum > HALO_LUM) & (sat < HALO_SAT)

    cross = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], dtype=bool)
    # 원본 해상도 기준으로 환산 — 정규화 후 HALO_PASSES px 만큼 벗겨진 효과가 나도록.
    passes = max(HALO_PASSES, round(HALO_PASSES * a.shape[0] / TARGET_H))
    removed = 0
    for _ in range(passes):
        solid = a[..., 3] > ALPHA_SOLID
        band = solid & ~ndimage.binary_erosion(solid, cross)
        hit = band & whiteish
        if not hit.any():
            break
        a[..., 3] = np.where(hit, 0, a[..., 3])
        removed += int(np.count_nonzero(hit))
    return Image.fromarray(a, mode="RGBA"), removed


def extract_figures(rgba: Image.Image) -> list[Image.Image]:
    """잡티·지면선·제목 텍스트를 걸러내고 figure 단위로 잘라낸다."""
    a = np.asarray(rgba)[..., 3]
    solid = a > ALPHA_SOLID
    lab, n = ndimage.label(solid, structure=np.ones((3, 3), dtype=np.uint8))
    if n == 0:
        return []

    objs = ndimage.find_objects(lab)
    areas = ndimage.sum(solid, lab, index=range(1, n + 1))

    anchors, frags = [], []
    for i, sl in enumerate(objs):
        if sl is None:
            continue
        (anchors if areas[i] > MIN_AREA else frags).append((i + 1, sl))

    if not anchors:
        return []

    # 앵커 높이가 중앙값의 55% 미만이면 제목 텍스트로 보고 제외.
    heights = [sl[0].stop - sl[0].start for _, sl in anchors]
    med = float(np.median(heights))
    anchors = [(l, sl) for (l, sl), h in zip(anchors, heights)
               if h >= med * ANCHOR_MIN_H_RATIO]
    if not anchors:
        return []

    keep = {l: [sl] for l, sl in anchors}
    for l, sl in frags:
        h = sl[0].stop - sl[0].start
        w = sl[1].stop - sl[1].start
        if w > h * GROUND_ASPECT:
            continue                      # 지면선·그림자
        for al, asl in anchors:
            if (sl[0].start < asl[0].stop + MERGE_EXPAND
                    and sl[0].stop > asl[0].start - MERGE_EXPAND
                    and sl[1].start < asl[1].stop + MERGE_EXPAND
                    and sl[1].stop > asl[1].start - MERGE_EXPAND):
                keep[al].append(sl)
                break                     # 겹치는 앵커에만 편입, 나머지는 버림

    src = np.asarray(rgba)
    out = []
    # 왼쪽→오른쪽 순으로 (한 장에 여러 포즈가 들어온 경우 대비)
    for al, asl in sorted(anchors, key=lambda t: t[1][1].start):
        parts = keep[al]
        y0 = min(s[0].start for s in parts)
        y1 = max(s[0].stop for s in parts)
        x0 = min(s[1].start for s in parts)
        x1 = max(s[1].stop for s in parts)
        member = np.isin(lab, [al] + [l for l, s in frags if s in parts])
        cut = src.copy()
        cut[..., 3] = np.where(member, cut[..., 3], 0)
        fig = Image.fromarray(cut[y0:y1, x0:x1], mode="RGBA")
        fig.info["src_bottom_gap"] = src.shape[0] - y1   # 원본 지면까지의 여백
        out.append(fig)
    return out


def normalize(fig: Image.Image) -> tuple[Image.Image, float]:
    """높이 TARGET_H 로 개별 리사이즈. (원본이 장마다 크기가 다르다)"""
    w, h = fig.size
    scale = TARGET_H / float(h)
    new = fig.resize((max(1, round(w * scale)), TARGET_H), Image.LANCZOS)
    return new, scale


def silhouette_diff(a: np.ndarray, b: np.ndarray) -> float:
    """실루엣 대칭차 / 합집합. 0 이면 동일, 1 이면 완전히 다름."""
    union = np.count_nonzero(a | b)
    if union == 0:
        return 0.0
    return np.count_nonzero(a ^ b) / union


def best_cycle(masks: list[np.ndarray]) -> list[int]:
    """인접 프레임 차이 합이 최대가 되는 순환 순서. (프레임 수가 적어 완전탐색)"""
    n = len(masks)
    if n < 3:
        return list(range(n))
    d = [[silhouette_diff(masks[i], masks[j]) for j in range(n)] for i in range(n)]
    best, best_score = None, -1.0
    for perm in itertools.permutations(range(1, n)):
        order = (0,) + perm
        score = sum(d[order[i]][order[(i + 1) % n]] for i in range(n))
        if score > best_score:
            best, best_score = order, score
    return list(best)


def assemble(figs: list[Image.Image], scales: list[float]) -> tuple[Image.Image, float]:
    """프레임들을 바닥 정렬 시트로 조립. (시트, 최소 인접 차이) 를 돌려준다."""
    cell_w = max(f.width for f in figs) + CELL_PAD_W

    # 공중 포즈 리프트: 원본 지면 여백을 정규화 배율로 환산해 가장 낮은 프레임 기준 상대값.
    lifts_raw = [f.info.get("src_bottom_gap", 0) * s for f, s in zip(figs, scales)]
    base = min(lifts_raw)
    lifts = [min(MAX_LIFT, max(0, round(l - base))) for l in lifts_raw]

    # 리프트만큼 위로 올라가므로 셀 높이에 미리 반영해야 오프셋이 음수가 되지 않는다.
    cell_h = max(f.height + l for f, l in zip(figs, lifts)) + CELL_PAD_H

    masks = []
    for f, lift in zip(figs, lifts):
        m = np.zeros((cell_h, cell_w), dtype=bool)
        ox = (cell_w - f.width) // 2
        oy = cell_h - f.height - BOTTOM_MARGIN - lift
        m[oy:oy + f.height, ox:ox + f.width] = np.asarray(f)[..., 3] > ALPHA_SOLID
        masks.append(m)

    order = best_cycle(masks)
    sheet = Image.new("RGBA", (cell_w * len(figs), cell_h), (0, 0, 0, 0))
    for slot, idx in enumerate(order):
        f, lift = figs[idx], lifts[idx]
        ox = slot * cell_w + (cell_w - f.width) // 2
        oy = cell_h - f.height - BOTTOM_MARGIN - lift
        sheet.paste(f, (ox, oy))

    n = len(order)
    min_diff = min(silhouette_diff(masks[order[i]], masks[order[(i + 1) % n]])
                   for i in range(n)) if n > 1 else 1.0
    return sheet, min_diff


def main() -> int:
    # 윈도 콘솔 기본 코드페이지(cp949/cp932)로는 한글 출력이 깨지거나 예외가 난다.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("inputs", nargs="+", help="생성 이미지 경로 (glob 가능)")
    ap.add_argument("-o", "--out", required=True, help="출력 PNG 경로")
    ap.add_argument("--single", action="store_true",
                    help="시트 조립 없이 figure 한 장만 저장 (대기 이미지용)")
    ap.add_argument("--debug-dir", help="키잉된 프레임을 개별 PNG 로 덤프할 디렉터리")
    args = ap.parse_args()

    paths: list[str] = []
    for pat in args.inputs:
        hits = sorted(glob.glob(pat))
        paths.extend(hits if hits else [pat])
    if not paths:
        print("입력 이미지가 없습니다.", file=sys.stderr)
        return 1

    figs: list[Image.Image] = []
    scales: list[float] = []
    for p in paths:
        rgba, key = key_out(Image.open(p))
        rgba, halo = strip_white_halo(rgba)
        found = extract_figures(rgba)
        if not found:
            print(f"  !! figure 를 찾지 못함: {p}", file=sys.stderr)
            continue
        if len(found) > 1:
            print(f"  ** {Path(p).name}: figure {len(found)}개 검출 "
                  f"(한 장에 여러 포즈가 들어온 듯 — 확인 필요)")
        for f in found:
            gap = f.info.get("src_bottom_gap", 0)
            nf, sc = normalize(f)
            nf.info["src_bottom_gap"] = gap
            figs.append(nf)
            scales.append(sc)
        print(f"  {Path(p).name}: key=({int(key[0])},{int(key[1])},{int(key[2])}) "
              f"figures={len(found)}"
              + (f" halo={halo}px 제거" if halo else ""))

    if not figs:
        print("추출된 figure 가 없습니다.", file=sys.stderr)
        return 1

    if args.debug_dir:
        d = Path(args.debug_dir)
        d.mkdir(parents=True, exist_ok=True)
        for i, f in enumerate(figs):
            f.save(d / f"frame_{i:02d}.png")
        print(f"디버그 프레임 {len(figs)}장 → {d}")

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)

    if args.single:
        figs[0].save(out)
        print(f"저장: {out}  ({figs[0].width}x{figs[0].height})")
        return 0

    sheet, min_diff = assemble(figs, scales)
    sheet.save(out)
    cell_w = sheet.width // len(figs)
    print(f"저장: {out}  ({sheet.width}x{sheet.height}), "
          f"frames={len(figs)}, cell={cell_w}x{sheet.height}")
    assert sheet.width % len(figs) == 0, "시트 폭이 프레임 수로 나누어떨어지지 않음"
    print(f"인접 프레임 최소 실루엣 차이: {min_diff:.1%} "
          f"({'OK' if min_diff >= MIN_ADJ_DIFF else 'FAIL — 포즈 재생성 필요'})")
    print(f"data/character_db.tres 의 run_frames 를 {len(figs)} 로 설정할 것")
    return 0 if min_diff >= MIN_ADJ_DIFF else 2


if __name__ == "__main__":
    sys.exit(main())
