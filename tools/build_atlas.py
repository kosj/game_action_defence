#!/usr/bin/env python3
"""스프라이트를 텍스처 아틀라스 한 장으로 묶고 AtlasTexture 리소스를 생성한다.

왜 필요한가
-----------
Godot 의 2D 배칭은 "연속된 아이템이 같은 텍스처·같은 머티리얼"일 때만 하나로 묶인다.
이 게임은 Main 이 y_sort 라 좀비들이 Y 순서로 정렬되는데, 좀비 하나가
Shadow(shadow.png) + Body(좀비별 텍스처) 두 스프라이트다. 그래서 그리는 순서가

    shadow.png -> zombie_walker.png -> shadow.png -> zombie_brute.png -> ...

이 되어 **아이템마다 텍스처가 바뀌고 배칭이 한 번도 성립하지 않는다**(좀비 300마리 = 약 600 드로우 콜).
이 스프라이트들을 아틀라스 한 장에 넣으면 텍스처 교체가 사라져 배치가 크게 접힌다.

동작
----
- ATLASES 에 정의된 글롭으로 원본 PNG 를 모아 선반(shelf) 방식으로 한 장에 배치한다.
- 결과: assets/atlas/<이름>.png (아틀라스) + assets/atlas/<스프라이트>.tres (AtlasTexture)
- AtlasTexture 의 region 은 원본과 정확히 같은 크기라 get_size()·스케일 계산이 그대로 유지된다.
- 각 항목 둘레에 PADDING 만큼 투명 여백을 둔다. 선형 필터링·손실 압축에서 이웃 스프라이트
  색이 번지는 것을 막기 위한 것이다(AtlasTexture.filter_clip 도 함께 켠다).

새 스프라이트를 추가하려면
--------------------------
1. PNG 를 assets/sprites/ 아래 (ATLASES 글롭에 걸리는 위치)에 넣는다
2. `python3 tools/build_atlas.py` 실행
3. 씬/데이터/스크립트에서 **PNG 가 아니라** assets/atlas/<이름>.tres 를 참조한다

3번을 빠뜨리면 그 스프라이트만 아틀라스 밖 텍스처가 되어 다시 배칭이 끊긴다.
CI 의 `tools/check_atlas.gd` 가 이걸 검사해 빌드를 실패시킨다.

    python3 tools/build_atlas.py            # 아틀라스 재생성
    python3 tools/build_atlas.py --check    # 원본과 아틀라스가 최신인지만 확인
"""

from __future__ import annotations

import argparse
import glob
import pathlib
import sys

try:
    from PIL import Image
except ImportError:
    print("Pillow 가 필요합니다:  pip install pillow", file=sys.stderr)
    raise

OUT_DIR = "assets/atlas"
PADDING = 4          # 항목 사이 투명 여백(px) — 필터링·손실 압축 번짐 방지
MAX_SIZE = 2048      # 아틀라스 한 변 상한(모바일 GL 호환 안전선)

## 아틀라스 구성. 키 = 아틀라스 이름, 값 = 원본 글롭 목록.
## y_sort 스트림에 섞여 그려지는(= 배칭이 깨지는) 스프라이트를 한 장에 모으는 것이 목적이다.
## 타일(tiles/)은 texture_repeat 로 반복 샘플링해야 해서 아틀라스에 넣을 수 없다 — 제외.
ATLASES: dict[str, list[str]] = {
    "gameplay": [
        "assets/sprites/zombie_*.png",
        "assets/sprites/boss_*.png",
        "assets/sprites/shadow.png",
        "assets/sprites/xp_gem.png",
        "assets/sprites/bullet.png",
        # 투사체 아트(#291 이후 총알은 텍스처로 그린다) — 총알은 화면에 수십 개가 동시에 뜬다.
        "assets/sprites/proj_*.png",
        # FX 스프라이트도 같은 y_sort 스트림에 섞여 그려진다(SpriteFX z_index=3).
        "assets/sprites/fx/*.png",
    ],
}


def _sources(root: pathlib.Path, patterns: list[str]) -> list[pathlib.Path]:
    out: list[pathlib.Path] = []
    for pat in patterns:
        out += [pathlib.Path(p) for p in glob.glob(str(root / pat))]
    # 경로 순 정렬 — 배치 결과가 실행마다 동일해야 diff 가 안정된다.
    return sorted(set(out))


def _pack(sizes: list[tuple[int, int]]) -> tuple[list[tuple[int, int]], int, int]:
    """선반(shelf) 배치. (배치좌표들, 폭, 높이) 반환. 항목 수가 적어 이걸로 충분하다."""
    order = sorted(range(len(sizes)), key=lambda i: -sizes[i][1])
    for side in (256, 512, 1024, MAX_SIZE):
        pos: list[tuple[int, int] | None] = [None] * len(sizes)
        x = y = shelf_h = 0
        ok = True
        for i in order:
            w, h = sizes[i][0] + PADDING * 2, sizes[i][1] + PADDING * 2
            if w > side:
                ok = False
                break
            if x + w > side:            # 다음 선반으로
                x = 0
                y += shelf_h
                shelf_h = 0
            if y + h > side:
                ok = False
                break
            pos[i] = (x + PADDING, y + PADDING)
            x += w
            shelf_h = max(shelf_h, h)
        if ok and all(p is not None for p in pos):
            return [p for p in pos if p is not None], side, side
    raise SystemExit(f"아틀라스가 {MAX_SIZE}x{MAX_SIZE} 를 넘습니다 — ATLASES 를 나누세요.")


def _tres(atlas_res: str, x: int, y: int, w: int, h: int) -> str:
    """AtlasTexture 리소스 텍스트. filter_clip 은 region 밖 샘플링을 막아 번짐을 방지한다."""
    return (
        '[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
        f'[ext_resource type="Texture2D" path="{atlas_res}" id="1"]\n\n'
        "[resource]\n"
        'atlas = ExtResource("1")\n'
        f"region = Rect2({x}, {y}, {w}, {h})\n"
        "filter_clip = true\n"
    )


def build(root: pathlib.Path, check_only: bool) -> int:
    out_dir = root / OUT_DIR
    changed = False
    for name, patterns in ATLASES.items():
        srcs = _sources(root, patterns)
        if not srcs:
            print(f"[ATLAS] {name}: 원본을 찾지 못했습니다 — 건너뜁니다")
            continue
        imgs = [Image.open(p).convert("RGBA") for p in srcs]
        positions, aw, ah = _pack([im.size for im in imgs])

        sheet = Image.new("RGBA", (aw, ah), (0, 0, 0, 0))
        for im, (x, y) in zip(imgs, positions):
            sheet.paste(im, (x, y))

        png_path = out_dir / f"{name}.png"
        buf = png_path.parent
        buf.mkdir(parents=True, exist_ok=True)
        new_bytes = _png_bytes(sheet)
        old_bytes = png_path.read_bytes() if png_path.exists() else b""
        if new_bytes != old_bytes:
            changed = True
            if not check_only:
                png_path.write_bytes(new_bytes)

        atlas_res = f"res://{OUT_DIR}/{name}.png"
        for src, im, (x, y) in zip(srcs, imgs, positions):
            tres_path = out_dir / f"{src.stem}.tres"
            text = _tres(atlas_res, x, y, im.width, im.height)
            old = tres_path.read_text(encoding="utf-8") if tres_path.exists() else ""
            if old != text:
                changed = True
                if not check_only:
                    tres_path.write_text(text, encoding="utf-8")

        total = sum(im.width * im.height for im in imgs)
        print(f"[ATLAS] {name}: {len(srcs)}장 -> {aw}x{ah} "
              f"(점유 {total / (aw * ah) * 100:.0f}%, 여백 {PADDING}px)")
        for src, (x, y), im in zip(srcs, positions, imgs):
            print(f"         {src.name:28s} -> {OUT_DIR}/{src.stem}.tres  "
                  f"region({x},{y},{im.width},{im.height})")

    if check_only:
        if changed:
            print("\n[ATLAS] 아틀라스가 원본과 어긋나 있습니다 — "
                  "`python3 tools/build_atlas.py` 를 실행해 다시 만드세요.")
            return 1
        print("[ATLAS] 최신 상태입니다.")
    return 0


def _png_bytes(img: Image.Image) -> bytes:
    import io
    b = io.BytesIO()
    img.save(b, format="PNG", optimize=True)
    return b.getvalue()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true",
                    help="파일을 쓰지 않고 최신 여부만 확인(CI 용)")
    args = ap.parse_args()
    root = pathlib.Path(__file__).resolve().parent.parent
    return build(root, args.check)


if __name__ == "__main__":
    sys.exit(main())
