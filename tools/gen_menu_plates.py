#!/usr/bin/env python3
"""메뉴/공용 버튼 플레이트 생성 — 다크 건메탈 + 밝은 림 + 리벳 + 스크래치 그런지.

기존 frames/button_plate.png 은 151x93 의 "거의 흰색 광택면"(세로 밝기 255 -> 203)이라
채도 높은 색으로 틴트하면 필연적으로 사탕/플라스틱 색이 나왔다. 좀비물 금속이 되려면
바탕이 어둡고 채도가 낮아야 한다.

**무채색 한 장 + modulate** 로 시작했고 그것으로 대부분의 버튼은 해결된다 — 최종색이
플레이트 x accent 라 바탕이 중간 톤이면 어떤 accent 를 줘도 금속처럼 보이고, 판을 하나만
두면 레벨업/HUD 등 apply_button_style 을 쓰는 모든 화면이 함께 통일된다.

그런데 **modulate 는 픽셀 전체를 곱한다.** 채도 높은 accent(1차 CTA 의 핏빛)를 주면 몸통만이
아니라 **리벳과 상단 스페큘러까지 같이 물든다** — 강철 하드웨어가 빨간 플라스틱 못처럼 보이고
크림색이어야 할 하이라이트가 붉어진다(실렌더 확인, HANDOFF P2-2). 한 장의 modulate 로는
부위를 가릴 수 없으니 구조상 고칠 수 없다.

그래서 **재질이 곧 메시지인 자리**에는 색을 구워 넣은 판을 따로 쓴다(MENU_UI_PLAN Phase 2):

    steel  기본 - 무채색. 지금까지처럼 accent 로 틴트해 쓰는 판(확인=초록/위험=빨강 구분 유지)
    blood  1차 CTA 전용 - 몸통만 핏빛이고 **리벳은 강철, 하이라이트는 크림**으로 남는다
    dark   3차/비활성 - 채도와 밝기를 더 낮춘 판. 보조 버튼 6개가 한 덩어리로 가라앉는다

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

FRAMES = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "frames")

# 판별 색 사양. body = 몸통 세로 그라데이션(위->아래), hl = 상단 스페큘러, bevel = 테두리 베벨.
# 리벳은 세 판 모두 강철색으로 고정한다 - 하드웨어는 도색되지 않는다는 것이 이 판의 논리다.
PLATES = {
    "steel": {
        "bevel": ((196, 198, 204), (58, 58, 62)),
        "body": ((170, 172, 176), (112, 113, 118)),
        "hl": ((226, 228, 232), (188, 190, 195)),
        "shadow": ((88, 89, 93), (66, 67, 70)),
    },
    # 1차 CTA - 로고의 핏빛. 몸통만 붉고 하이라이트는 크림으로 남겨 "빨간 금속"이 되게 한다
    # (전체를 붉히면 빨간 플라스틱이 된다).
    "blood": {
        "bevel": ((196, 120, 116), (62, 26, 26)),
        "body": ((150, 34, 34), (86, 18, 20)),
        "hl": ((242, 214, 206), (206, 150, 142)),
        "shadow": ((62, 18, 20), (44, 13, 15)),
    },
    # 3차/비활성 - 채도 0 에 밝기를 더 낮춘다. 6개가 배경처럼 한 덩어리로 읽혀야 한다.
    "dark": {
        "bevel": ((120, 121, 126), (38, 38, 41)),
        "body": ((92, 93, 97), (58, 59, 62)),
        "hl": ((138, 139, 144), (112, 113, 117)),
        "shadow": ((48, 48, 51), (36, 36, 38)),
    },
}


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


def build(spec: dict, seed: int) -> Image.Image:
    img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))

    # 1) 바깥 어두운 외곽선
    vgrad_fill(img, shape_mask((0, 0, W, H), RADIUS), (16, 16, 18), (10, 10, 12))
    # 2) 베벨 - 위는 밝고 아래는 어둡게(입체감)
    vgrad_fill(img, shape_mask((1.5, 1.5, W - 1.5, H - 1.5), RADIUS - 1), *spec["bevel"])
    # 3) 본체 - 위->아래로 완만하게 어두워진다.
    body_box = (3.5, 4.0, W - 3.5, H - 4.5)
    body = shape_mask(body_box, RADIUS - 3)
    vgrad_fill(img, body, *spec["body"])
    brushed(img, body, alpha=16, seed=seed)
    scratches(img, body, seed=seed + 40)

    d = ImageDraw.Draw(img)
    # 4) 상단 스페큘러 하이라이트 - 얇게 한 줄만(넓은 광택 띠는 플라스틱으로 보인다)
    hl = shape_mask((5.0, 5.0, W - 5.0, 9.0), 3)
    vgrad_fill(img, hl, *spec["hl"])
    # 5) 하단 내부 그림자
    sh = shape_mask((4.5, H - 12.0, W - 4.5, H - 5.0), 4)
    vgrad_fill(img, sh, *spec["shadow"])

    # 6) 모서리 리벳 4개 - 나인패치 마진(14) 안쪽이라 늘려도 위치가 유지된다.
    #    세 판 모두 강철색이다: 하드웨어는 도색되지 않는다(modulate 방식이 못 하던 것).
    for cx in (8.5, W - 8.5):
        for cy in (8.5, H - 8.5):
            rivet(d, cx, cy, 2.6)

    return img.resize((W, H), Image.LANCZOS)


def main() -> None:
    os.makedirs(FRAMES, exist_ok=True)
    for i, (name, spec) in enumerate(PLATES.items()):
        out_path = os.path.join(FRAMES, "btn_plate_%s.png" % name)
        out = build(spec, seed=11 + i * 7)
        out.save(out_path)
        a = np.asarray(out.convert("L"), dtype=float)
        print("wrote", os.path.relpath(out_path), f"{W}x{H} margin {MARGIN}  mean {a.mean():.0f}")
    print("(button_plate.png 는 평균 227 - 이 값이 낮아야 금속으로 보인다)")


if __name__ == "__main__":
    main()
