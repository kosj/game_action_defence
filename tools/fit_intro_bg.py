#!/usr/bin/env python3
"""인트로 배경 원본(정사각 등)을 세로 9:16 화면용으로 맞춘다.

생성 AI 는 보통 정사각(1:1)으로 뽑히는데, 게임 화면은 720x1280(9:16)이라
그대로 cover 로 깔면 좌우가 크게 잘려 송신탑이 화면 밖으로 나간다.
이 그림은 위쪽이 평탄한 밤하늘, 아래쪽이 어두운 지면이라 **세로로 캔버스를 늘리는**
방식이면 이어붙인 티 없이 9:16 을 만들 수 있다(재생성 불필요).

하는 일:
  1. 송신탑 꼭대기(마스트 끝) 위치를 자동 검출 — 하늘보다 뚜렷이 어두운 최상단 픽셀.
  2. 꼭대기가 목표 높이 비율(--tip-at)에 오도록 위/아래 확장량을 계산.
  3. 위는 최상단 행 색을 이어 올리며 살짝 더 어둡게 + 별 약간, 아래는 최하단 행을 이어 내린다.
  4. assets/ui/bg_intro.png 로 저장하고, IntroBackdrop.gd 의 ART_BEACON 에 넣을 값을 출력.

사용:
  python3 tools/fit_intro_bg.py <원본.png> [--tip-at 0.26] [--width 1080]
"""
import argparse
import os
import random

import numpy as np
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "bg_intro.png")


def detect_tip(img: Image.Image, x_lo: float = 0.55, x_hi: float = 0.97) -> tuple:
    """오른쪽 영역에서 하늘보다 뚜렷이 어두운 최상단 픽셀(=철탑 마스트 끝)을 찾는다."""
    a = np.asarray(img.convert("L"), dtype=float)
    h, w = a.shape
    c0, c1 = int(w * x_lo), int(w * x_hi)
    for y in range(h):
        row = a[y, c0:c1]
        if row.size == 0:
            continue
        # 그 행의 하늘 밝기(중앙값)보다 크게 어두운 픽셀 = 구조물
        thr = np.median(a[y]) * 0.55
        hits = np.flatnonzero(row < thr)
        if hits.size >= 2:
            return (c0 + int(np.median(hits)), y)
    return (int(w * 0.78), int(h * 0.12))


def extend(img: Image.Image, top: int, bottom: int, seed: int = 913) -> Image.Image:
    """위/아래로 캔버스를 늘린다. 위는 하늘 색을 이어 올리고(더 어둡게 + 별), 아래는 지면 색."""
    w, h = img.size
    out = Image.new("RGB", (w, h + top + bottom))
    out.paste(img, (0, top))

    if top > 0:
        # 최상단 몇 행의 평균을 기준색으로 삼아 위로 갈수록 어둡게(밤하늘 깊이).
        head = np.asarray(img.convert("RGB").crop((0, 0, w, min(6, h))), dtype=float)
        base = head.mean(axis=0)                     # 열별 평균색 (w,3)
        ramp = np.linspace(0.34, 1.0, top)[:, None, None]   # 위(어두움) → 아래(원본색)
        sky = (base[None, :, :] * ramp).astype(np.uint8)
        out.paste(Image.fromarray(sky, "RGB"), (0, 0))
        # 별 — 원본 하늘의 별 밀도와 비슷하게 뿌린다.
        d = ImageDraw.Draw(out)
        rng = random.Random(seed)
        for _ in range(max(8, top * w // 26000)):
            sx, sy = rng.randrange(w), rng.randrange(top)
            r = rng.choice([0, 0, 1])
            v = rng.randint(120, 210)
            d.ellipse([sx - r, sy - r, sx + r, sy + r], fill=(v, v, int(v * 0.96)))

    if bottom > 0:
        foot = np.asarray(img.convert("RGB").crop((0, h - 3, w, h)), dtype=float)
        base = foot.mean(axis=0)
        ground = np.tile(base[None, :, :], (bottom, 1, 1)).astype(np.uint8)
        out.paste(Image.fromarray(ground, "RGB"), (0, h + top))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--tip-at", type=float, default=0.26,
                    help="철탑 꼭대기가 놓일 최종 높이 비율(제목 아래·본문 위)")
    ap.add_argument("--width", type=int, default=1080, help="출력 가로 픽셀")
    ap.add_argument("--aspect", type=float, default=16.0 / 9.0, help="출력 세로/가로 비")
    args = ap.parse_args()

    img = Image.open(args.src).convert("RGB")
    tip_x, tip_y = detect_tip(img)
    w, h = img.size
    print(f"원본 {w}x{h} · 검출된 철탑 꼭대기 = ({tip_x}, {tip_y})  비율 ({tip_x/w:.3f}, {tip_y/h:.3f})")

    target_h = int(round(w * args.aspect))
    add = target_h - h
    if add < 0:
        raise SystemExit(f"원본이 이미 목표보다 세로로 길다({h} > {target_h}). 수동 조정 필요.")
    # (tip_y + top) / target_h == tip_at  →  top = tip_at*target_h - tip_y
    top = int(round(args.tip_at * target_h - tip_y))
    top = max(0, min(add, top))
    bottom = add - top
    print(f"확장: 위 +{top}px, 아래 +{bottom}px → {w}x{target_h}")

    out = extend(img, top, bottom)
    if args.width != w:
        out = out.resize((args.width, int(round(args.width * args.aspect))), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    print("wrote", os.path.relpath(OUT))

    fh = out.size[1]
    print(f"\nIntroBackdrop.gd 에 넣을 값:")
    print(f"  const ART_BEACON := Vector2({tip_x / w:.3f}, {(tip_y + top) / (h + top + bottom):.3f})")


if __name__ == "__main__":
    main()
