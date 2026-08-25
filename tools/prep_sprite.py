#!/usr/bin/env python3
"""생성형 툴에서 받은 스프라이트를 게임에 넣을 수 있게 다듬는다.

생성 결과는 "투명 배경"이라고 해도 실제로는 **체커보드가 픽셀로 구워진 RGB** 인 경우가
많다(알파 채널 자체가 없다). 그대로 넣으면 회색 격자 사각형이 그려진다.

하는 일:
  1. 배경 판정 — 무채색(R≈G≈B)이면서 밝은 픽셀 = 체커보드 후보
  2. 테두리에서 flood fill 로 "바깥과 이어진" 후보만 배경으로 확정
     (오브젝트 안쪽의 밝은 회색 하이라이트에 구멍이 뚫리지 않는다)
  3. 경계 1px 침식 — 배경과 섞인 반투명 테두리 픽셀(흰 띠)을 잘라낸다
  4. 색 번짐(bleed) — 투명 영역을 이웃 불투명 색으로 채워, 축소할 때 흰색이
     빨려 들어와 생기는 흰 테두리(halo)를 막는다
  5. 내용에 맞춰 트리밍 후 긴 변을 --size 로 리샘플

사용:
  python3 tools/prep_sprite.py <입력.png> [입력2.png ...] [--size 128] [--inplace]
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

GRAY_TOL = 14      # R,G,B 최대-최소 차가 이 이하면 무채색으로 본다
BRIGHT_MIN = 180   # 가장 어두운 채널이 이 이상이면 밝은 색으로 본다


def background_alpha(rgb: np.ndarray) -> np.ndarray:
    """체커보드 배경을 0, 오브젝트를 255 로 하는 알파 마스크."""
    mx = rgb.max(axis=2).astype(int)
    mn = rgb.min(axis=2).astype(int)
    cand = ((mx - mn) <= GRAY_TOL) & (mn >= BRIGHT_MIN)

    # 테두리와 이어진 후보만 배경. 안쪽의 밝은 회색(금속 하이라이트 등)은 남긴다.
    # .copy() 필수: Image.fromarray 는 numpy 버퍼를 공유해서, 그대로 두면 floodfill 의
    # 쓰기가 반영되지 않고 조용히 사라진다(배경이 하나도 지워지지 않는다).
    m = Image.fromarray(np.where(cand, 255, 0).astype(np.uint8), "L").copy()
    h, w = cand.shape
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    for sx, sy in seeds:
        if m.getpixel((sx, sy)) == 255:
            ImageDraw.floodfill(m, (sx, sy), 128)
    reached = np.asarray(m) == 128
    return np.where(reached, 0, 255).astype(np.uint8)


def bleed_colors(rgb: np.ndarray, alpha: np.ndarray, rounds: int = 6) -> np.ndarray:
    """투명 영역을 이웃 불투명 색으로 점점 채운다(축소 시 흰 테두리 방지)."""
    out = rgb.copy()
    known = alpha > 0
    for _ in range(rounds):
        if known.all():
            break
        # 상하좌우로 한 칸씩 밀어 아직 모르는 자리를 채운다
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            src = np.roll(known, (dy, dx), axis=(0, 1))
            srcv = np.roll(out, (dy, dx), axis=(0, 1))
            fill = src & ~known
            out[fill] = srcv[fill]
            known = known | fill
    return out


def prep(path: str, size: int, inplace: bool) -> None:
    im = Image.open(path)
    src_mode, src_size = im.mode, im.size

    if im.mode == "RGBA" and np.asarray(im)[:, :, 3].min() < 250:
        rgba = np.asarray(im.convert("RGBA")).copy()
        alpha = rgba[:, :, 3]
        rgb = rgba[:, :, :3]
        note = "이미 알파 있음 — 배경 판정 생략"
    else:
        rgb = np.asarray(im.convert("RGB")).copy()
        alpha = background_alpha(rgb)
        note = "체커보드 배경 제거"

    # 경계 1px 침식 — 배경과 섞인 흰 띠 제거
    alpha = np.asarray(Image.fromarray(alpha, "L").filter(ImageFilter.MinFilter(3)))
    rgb = bleed_colors(rgb, alpha)

    ys, xs = np.where(alpha > 8)
    if len(xs) == 0:
        raise SystemExit(f"{path}: 오브젝트를 찾지 못했다(전부 배경으로 판정)")
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)

    out = Image.fromarray(np.dstack([rgb, alpha]), "RGBA").crop(box)
    k = size / max(out.size)
    out = out.resize((max(1, round(out.width * k)), max(1, round(out.height * k))), Image.LANCZOS)

    dst = path if inplace else os.path.splitext(path)[0] + "_prep.png"
    out.save(dst)
    kb = os.path.getsize(dst) / 1024
    print(f"{os.path.basename(path)}: {src_mode} {src_size[0]}x{src_size[1]} → "
          f"RGBA {out.size[0]}x{out.size[1]} ({kb:.0f}KB) · {note}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--size", type=int, default=128, help="출력 긴 변 픽셀")
    ap.add_argument("--inplace", action="store_true", help="원본을 덮어쓴다")
    args = ap.parse_args()
    for p in args.paths:
        prep(p, args.size, args.inplace)


if __name__ == "__main__":
    main()
