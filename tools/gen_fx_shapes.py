#!/usr/bin/env python3
"""무기 비주얼용 텍스처를 생성한다 — 프리미티브를 텍스처 쿼드로 바꾸기 위한 것.

왜
--
Godot 캔버스 배처는 한 CanvasItem 안에서도 **프리미티브 종류가 다르면 배치를 끊는다**
(색은 정점 데이터라 안 끊는다 — ASSET_PIPELINE.md 1절). 무기 비주얼이 `_draw()` 에서
draw_circle / draw_line / draw_polyline / draw_colored_polygon 을 루프로 발행해
드로우 콜을 크게 먹고 있었다(실측: 오브 +121, 테슬라 +112, 마늘 +91).

원칙
----
**성능 때문에 아트를 바꾸지 않는다.** 여기서 만드는 것은 새 그림이 아니라 기존 `_draw` 가
그리던 도형을 픽셀 그대로 옮긴 것이다. 그래서 손으로 그리거나 생성 아트를 쓰지 않고
같은 좌표·같은 색으로 절차 생성한다 — 상수가 바뀌면 이 파일도 같이 고친다.

크기는 ASSET_PIPELINE.md 의 "표시 크기 × 2" 기준이다.

    python3 tools/gen_fx_shapes.py        # 재생성
    python3 tools/build_atlas.py          # 아틀라스에 반영
"""
from __future__ import annotations

import pathlib
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Pillow 가 필요합니다:  pip install pillow", file=sys.stderr)
    raise

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "sprites"
SS = 4          # 슈퍼샘플 배율 — Godot 의 antialiased 그리기와 눈높이를 맞춘다


def _canvas(px: int) -> tuple[Image.Image, ImageDraw.ImageDraw, int]:
    n = px * SS
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im), n


def _over(base: Image.Image, px: int) -> Image.Image:
    """슈퍼샘플 해제. Godot 의 알파 블렌딩과 같은 결과가 되도록 straight alpha 로 축소한다."""
    return base.resize((px, px), Image.LANCZOS)


def _c(r: float, g: float, b: float, a: float = 1.0) -> tuple[int, int, int, int]:
    """Godot Color(0~1) → PIL RGBA(0~255)."""
    f = lambda v: max(0, min(255, int(round(v * 255.0))))
    return (f(r), f(g), f(b), f(a))


def _layer(size: int):
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def gen_orb() -> None:
    """scripts/Orb.gd `_draw()` 를 그대로 옮긴다.

    상수: HIT_RADIUS 28 · BLADE_LEN 24 · BLADE_W 7.5. 모양이 완전히 정적이라(회전은 노드
    변환) 통째로 한 장이면 된다 — 9커맨드가 쿼드 1개가 된다.
    """
    HIT_R, BL, BW = 28.0, 24.0, 7.5
    PX = int(HIT_R * 2 * 2)              # 표시 56px × 2 = 112
    im, _, n = _canvas(PX)
    c = n / 2.0
    k = n / (HIT_R * 2.0)                # 월드 좌표 → 픽셀

    def P(x: float, y: float) -> tuple[float, float]:
        return (c + x * k, c + y * k)

    def blend(draw_fn) -> None:
        """Godot 은 명령마다 알파 블렌딩한다 — 레이어를 따로 그려 순서대로 합성한다."""
        nonlocal im
        lay = _layer(n)
        draw_fn(ImageDraw.Draw(lay))
        im = Image.alpha_composite(im, lay)

    # 모션 잔상(리치 반경)
    blend(lambda d: d.ellipse([P(-HIT_R, -HIT_R), P(HIT_R, HIT_R)],
                              fill=_c(0.70, 0.88, 1.0, 0.08)))

    tip, s1 = (BL, 0.0), (BL * 0.28, -BW)
    back, s2 = (-BL * 0.42, 0.0), (BL * 0.28, BW)
    steel = _c(0.85, 0.92, 1.0, 0.96)
    steel_dim = _c(0.62, 0.74, 0.92, 0.92)
    edge = _c(1.0, 1.0, 1.0, 0.95)
    neg = lambda p: (-p[0], -p[1])

    # 가로 칼날 + 능선
    blend(lambda d: d.polygon([P(*tip), P(*s1), P(*back), P(*s2)], fill=steel))
    blend(lambda d: d.line([P(*back), P(*tip)], fill=edge, width=max(1, int(1.6 * k))))
    blend(lambda d: d.polygon([P(*neg(tip)), P(*neg(s1)), P(*neg(back)), P(*neg(s2))],
                              fill=steel_dim))
    blend(lambda d: d.line([P(*neg(back)), P(*neg(tip))], fill=edge, width=max(1, int(1.4 * k))))

    # 세로 칼날(직교)
    tipv, v1 = (0.0, BL), (BW, BL * 0.28)
    backv, v2 = (0.0, -BL * 0.42), (-BW, BL * 0.28)
    blend(lambda d: d.polygon([P(*tipv), P(*v1), P(*backv), P(*v2)], fill=steel_dim))
    blend(lambda d: d.polygon([P(*neg(tipv)), P(*neg(v1)), P(*neg(backv)), P(*neg(v2))],
                              fill=steel_dim))

    # 중심 허브
    blend(lambda d: d.ellipse([P(-4.5, -4.5), P(4.5, 4.5)], fill=_c(0.95, 0.97, 1.0, 1.0)))
    blend(lambda d: d.ellipse([P(-2.0, -2.0), P(2.0, 2.0)], fill=_c(0.45, 0.6, 0.85, 1.0)))

    _save(_over(im, PX), "fx_orb_blade.png")


def gen_wedge() -> None:
    """중심에서 퍼지는 쐐기(부채꼴 근사). GarlicAura 의 god-ray 용.

    왼쪽 변 중앙이 꼭짓점, 오른쪽 변에서 최대 폭이 되는 삼각형. 쓰는 쪽에서
    draw_set_transform 으로 각도를 주고 Rect2 의 폭/높이로 길이와 벌어짐을 정한다.
    """
    W, H = 128, 64
    n_w, n_h = W * SS, H * SS
    im = Image.new("RGBA", (n_w, n_h), (0, 0, 0, 0))
    ImageDraw.Draw(im).polygon(
        [(0, n_h / 2.0), (n_w - 1, 0), (n_w - 1, n_h - 1)], fill=(255, 255, 255, 255))
    _save(im.resize((W, H), Image.LANCZOS), "fx_wedge.png")


def gen_ring() -> None:
    """가는 링. draw_arc(원 전체) 대체용 — 두께는 텍스처에 고정이라 반지름에 비례해 늘어난다.

    쓰는 쪽에서 그 비례를 원치 않으면 세그먼트 쿼드로 그린다(QuadDraw.ring 참고).
    여기서는 얇은 테두리 강조용으로만 쓴다.
    """
    PX = 256
    im, _, n = _canvas(PX)
    lay = _layer(n)
    d = ImageDraw.Draw(lay)
    outer = n / 2.0 - 1
    thick = n * (2.5 / PX) * 2.0            # 256px 기준 5px — 표시 크기의 절반에서 2.5px
    d.ellipse([1, 1, n - 2, n - 2], outline=(255, 255, 255, 255), width=max(1, int(thick)))
    im = Image.alpha_composite(im, lay)
    _save(_over(im, PX), "fx_ring.png")


def gen_solid() -> None:
    """완전 불투명 흰 사각형. draw_rect 대체 — 색은 쓰는 쪽에서 틴트로 넣는다.

    작아도 되지만 아틀라스 패딩(4px)에 먹히지 않게 16px 로 둔다.
    """
    im = Image.new("RGBA", (16, 16), (255, 255, 255, 255))
    _save(im, "fx_solid.png")


def _save(im: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    p = OUT / name
    im.save(p)
    print("  %-24s %dx%-4d %5.1fKB" % (name, im.width, im.height, p.stat().st_size / 1024))


def main() -> int:
    print("[FX] 무기 비주얼 텍스처 생성")
    gen_orb()
    gen_wedge()
    gen_ring()
    gen_solid()
    print("[FX] 완료 — python3 tools/build_atlas.py 로 아틀라스에 반영하세요")
    return 0


if __name__ == "__main__":
    sys.exit(main())
