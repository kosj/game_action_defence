#!/usr/bin/env python3
"""생성 이미지(마젠타 배경) → 아이콘/스프라이트 PNG.

무기 아이콘(assets/ui/icons/weapon_*.png)과 소환물 스프라이트(assets/sprites/*.png)는
"배경 투명 + 내용에 맞춰 크롭 + 긴 변을 지정 크기로" 규약을 따른다. 키잉은
make_character_sheet.py 의 것을 그대로 재사용한다(같은 마젠타 파이프라인).

사용법:
    python tools/make_icon.py -o assets/ui/icons/weapon_sawblade.png --max 128 raw/blade.png
    python tools/make_icon.py -o assets/sprites/flame_pod.png --max 256 raw/pod.png
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_character_sheet import (  # noqa: E402
    key_out, strip_white_halo, recolor_white_halo, ALPHA_SOLID)


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--max", type=int, default=128, help="긴 변 목표 픽셀")
    ap.add_argument("--strip-halo", action="store_true",
                    help="흰 테두리를 벗겨낸다. UI 아이콘은 흰 스티커 외곽선이 스타일의"
                         " 일부라 기본은 유지 — 캐릭터 시트와 반대다.")
    ap.add_argument("--black-halo", action="store_true",
                    help="흰 테두리를 검게 칠한다. 월드에 놓이는 오브젝트용 — 좀비·플레이어와"
                         " 같은 검은 외곽선이라야 겉돌지 않는다.")
    args = ap.parse_args()

    rgba, key = key_out(Image.open(args.input))
    if args.strip_halo:
        rgba, removed = strip_white_halo(rgba)
        print(f"흰 테두리 {removed}px 제거")
    elif args.black_halo:
        rgba, painted = recolor_white_halo(rgba, (18, 18, 20))
        print(f"흰 테두리 {painted}px 를 검정으로")

    a = np.asarray(rgba)
    solid = a[..., 3] > ALPHA_SOLID
    if not solid.any():
        print("내용을 찾지 못했습니다(전부 배경으로 키잉됨).", file=sys.stderr)
        return 1
    rows = np.where(solid.any(axis=1))[0]
    cols = np.where(solid.any(axis=0))[0]
    cut = rgba.crop((cols.min(), rows.min(), cols.max() + 1, rows.max() + 1))

    scale = args.max / float(max(cut.size))
    if scale < 1.0:
        cut = cut.resize((max(1, round(cut.width * scale)),
                          max(1, round(cut.height * scale))), Image.LANCZOS)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    cut.save(out)
    print(f"저장: {out}  {cut.width}x{cut.height}  "
          f"key=({int(key[0])},{int(key[1])},{int(key[2])})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
