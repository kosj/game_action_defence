#!/usr/bin/env python3
"""메뉴/공용 버튼 플레이트 생성 — 다크 건메탈 + 밝은 림 + 리벳 + 스크래치 그런지.

기존 frames/button_plate.png 은 151x93 의 "거의 흰색 광택면"(세로 밝기 255 -> 203)이라
채도 높은 색으로 틴트하면 필연적으로 사탕/플라스틱 색이 나왔다. 좀비물 금속이 되려면
바탕이 어둡고 채도가 낮아야 한다.

여기서는 **중간 밝기의 무채색 금속판** 하나만 만든다. UIStyle 이 modulate 로 색을 입히므로
(최종색 = 플레이트 × accent), 바탕이 중간 톤이면 어떤 accent 를 줘도 금속처럼 보인다.
판을 여러 장 만들지 않아 상점/레벨업 등 다른 화면도 자동으로 같은 톤을 얻는다.

나인패치 계약: 256x96, 사방 마진 14 (리벳과 모서리가 마진 안에 들어온다)

사용:  python3 tools/gen_menu_plates.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw

SS = 4  # 슈퍼샘플 배율

W, H = 256, 96
RADIUS = 11
MARGIN = 14          # 나인패치 마진(UIStyle._BTN_PLATE_MARGIN 과 일치해야 함)

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "frames", "btn_plate_metal.png")


def shape_mask(box, radius: float) -> Image.Image:
    m = Image.new("L", (W * SS, H * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle([c * SS for c in box], radius=radius * SS, fill=255)
    return m


def vgrad_fill(img: Image.Image, mask: Image.Image, top, bot) -> None:
    w, h = img.size
    t = np.linspace(0.0, 1.0, h)[:, None, None]
    grad = np.array(top)[None, None, :] * (1 - t) + np.array(bot)[None, None, :] * t
    rgb = np.tile(grad, (1, w, 1)).astype(np.uint8)
    a = np.asarray(mask, dtype=np.uint8)[:, :, None]
    img.alpha_composite(Image.fromarray(np.concatenate([rgb, a], axis=2), "RGBA"))


def brushed(img: Image.Image, mask: Image.Image, alpha: int, seed: int) -> None:
    """가로 브러시드 결 — 드문 밝은 행만 아주 옅게 얹는다."""
    w, h = img.size
    rng = np.random.default_rng(seed)
    rows = (rng.random(size=(h // SS, 1)) < 0.28).astype(int) * 255
    rows = np.repeat(rows, SS, axis=0)[:h]
    rgb = np.tile(rows[:, :, None], (1, w, 3)).astype(np.uint8)
    a = ((np.asarray(mask, dtype=np.uint8) / 255.0) * (rows / 255.0) * alpha).astype(np.uint8)
    img.alpha_composite(Image.fromarray(np.concatenate([rgb, a[:, :, None]], axis=2), "RGBA"))


def scratches(img: Image.Image, mask: Image.Image, seed: int = 51) -> None:
    """긁힘 그런지 — 매끈한 플라스틱으로 보이지 않게 하는 핵심."""
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    rng = np.random.default_rng(seed)
    for _ in range(22):
        x0 = rng.uniform(0.04, 0.92) * W
        y0 = rng.uniform(0.18, 0.86) * H
        ln = rng.uniform(0.03, 0.20) * W
        bright = rng.random() < 0.55
        col = (255, 255, 255, int(rng.uniform(14, 34))) if bright else (0, 0, 0, int(rng.uniform(18, 40)))
        d.line([x0 * SS, y0 * SS, (x0 + ln) * SS, (y0 + rng.uniform(-1.2, 1.2)) * SS],
               fill=col, width=max(1, int(SS * 0.35)))
    img.alpha_composite(Image.composite(lay, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask))


def rivet(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float) -> None:
    d.ellipse([(cx - r - 0.8) * SS, (cy - r - 0.8) * SS, (cx + r + 0.8) * SS, (cy + r + 0.8) * SS],
              fill=(24, 24, 26, 210))
    d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=(150, 150, 154, 255))
    d.ellipse([(cx - r * 0.55) * SS, (cy - r * 0.7) * SS, (cx + r * 0.45) * SS, (cy + r * 0.1) * SS],
              fill=(212, 212, 216, 255))


def main() -> None:
    img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))

    # 1) 바깥 어두운 외곽선
    vgrad_fill(img, shape_mask((0, 0, W, H), RADIUS), (16, 16, 18), (10, 10, 12))
    # 2) 베벨 — 위는 밝고 아래는 어둡게(입체감)
    vgrad_fill(img, shape_mask((1.5, 1.5, W - 1.5, H - 1.5), RADIUS - 1), (196, 198, 204), (58, 58, 62))
    # 3) 본체 — 중간 밝기 무채색 금속(틴트가 얹힐 바탕). 위→아래로 완만하게 어두워진다.
    body_box = (3.5, 4.0, W - 3.5, H - 4.5)
    body = shape_mask(body_box, RADIUS - 3)
    vgrad_fill(img, body, (170, 172, 176), (112, 113, 118))
    brushed(img, body, alpha=16, seed=11)
    scratches(img, body)

    d = ImageDraw.Draw(img)
    # 4) 상단 스페큘러 하이라이트 — 얇게 한 줄만(넓은 광택 띠는 플라스틱으로 보인다)
    hl = shape_mask((5.0, 5.0, W - 5.0, 9.0), 3)
    vgrad_fill(img, hl, (226, 228, 232), (188, 190, 195))
    # 5) 하단 내부 그림자
    sh = shape_mask((4.5, H - 12.0, W - 4.5, H - 5.0), 4)
    vgrad_fill(img, sh, (88, 89, 93), (66, 67, 70))

    # 6) 모서리 리벳 4개 — 나인패치 마진(14) 안쪽이라 늘려도 위치가 유지된다
    for cx in (8.5, W - 8.5):
        for cy in (8.5, H - 8.5):
            rivet(d, cx, cy, 2.6)

    out = img.resize((W, H), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)

    a = np.asarray(out.convert("L"), dtype=float)
    print("wrote", os.path.relpath(OUT), f"{W}x{H} 나인패치 마진 {MARGIN}")
    print(f"  평균 밝기 {a.mean():.0f} (기존 button_plate.png 는 227 — 이 값이 낮아야 금속으로 보인다)")


if __name__ == "__main__":
    main()
