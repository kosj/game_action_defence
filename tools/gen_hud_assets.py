#!/usr/bin/env python3
"""HUD Phase 2 에셋 절차 생성 — 다크 건메탈 강철 + 오렌지골드 헤어라인 톤.

assets/ui/frames/(panel_frame 등) 및 AI 생성 시안의 스타일을 코드로 재현한다.
절차 생성의 장점: 투명 배경이 보장되고, 나인패치 가장자리가 완전한 직선이며,
크기·색을 픽셀 단위로 제어할 수 있다. 재실행하면 덮어쓴다.

사용:  python3 tools/gen_hud_assets.py [--preview 경로.png]
출력:  assets/ui/hud/*.png

나인패치 마진 계약(UIStyle/HUD 코드와 일치해야 함):
  hud_top_bar.png     512×96, L/R 30, T 6, B 14
  hud_gauge_frame.png 120×26, 사방 7 (모서리 반경 7)
  hud_gauge_fill.png  120×20, 사방 4 (모서리 반경 4)
  hud_slot_small.png   88×88, 사방 12 (모서리 반경 11)
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS = 4  # 슈퍼샘플 배율 — 4배로 그려 LANCZOS 축소(부드러운 AA)

# ── 팔레트 (기존 프레임 에셋 톤) ─────────────────────────────────────────
OUTLINE    = (10, 11, 13)
GOLD       = (232, 148, 32)
GOLD_HI    = (255, 199, 88)
GOLD_DK    = (146, 88, 12)
RECESS_TOP = (19, 20, 24)
RECESS_BOT = (12, 13, 16)

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "hud")


def canvas(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def vgrad_fill(img: Image.Image, mask: Image.Image, top, bot) -> None:
    """mask(L) 영역을 세로 그라데이션으로 채운다."""
    w, h = img.size
    t = np.linspace(0.0, 1.0, h)[:, None, None]
    grad = (np.array(top)[None, None, :] * (1 - t) + np.array(bot)[None, None, :] * t)
    rgb = np.tile(grad, (1, w, 1)).astype(np.uint8)
    a = np.asarray(mask, dtype=np.uint8)[:, :, None]
    layer = np.concatenate([rgb, a], axis=2)
    img.alpha_composite(Image.fromarray(layer, "RGBA"))


def brushed(img: Image.Image, mask: Image.Image, alpha: int = 26, seed: int = 7) -> None:
    """가로 브러시드 메탈 결 — 행 단위 미세 명암 노이즈를 mask 영역에 얹는다."""
    w, h = img.size
    rng = np.random.default_rng(seed)
    rows = (rng.random(size=(h // SS, 1)) < 0.3).astype(int) * 255  # 드문 밝은 결 행
    rows = np.repeat(rows, SS, axis=0)[:h]
    rgb = np.tile(rows[:, :, None], (1, w, 3)).astype(np.uint8)
    a = ((np.asarray(mask, dtype=np.uint8) / 255.0)
         * (rows[:, :] / 255.0) * alpha).astype(np.uint8)[:, :, None]
    img.alpha_composite(Image.fromarray(np.concatenate([rgb, a], axis=2), "RGBA"))


def shape_mask(w: int, h: int, box, radius: float, corners=None) -> Image.Image:
    m = Image.new("L", (w * SS, h * SS), 0)
    kw = {"radius": radius * SS, "fill": 255}
    if corners is not None:
        kw["corners"] = corners
    ImageDraw.Draw(m).rounded_rectangle([c * SS for c in box], **kw)
    return m


def inner_shadow_top(img: Image.Image, ch_mask: Image.Image, box, radius: float,
                     depth: float, alpha: int = 110, blur: float = 1.0) -> None:
    """채널 상단 안쪽 그림자 — 함몰감을 만든다."""
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    x0, y0, x1, _ = box
    ImageDraw.Draw(sh).rounded_rectangle(
        [x0 * SS, y0 * SS, x1 * SS, (y0 + depth) * SS], radius=radius * SS,
        fill=(0, 0, 0, alpha))
    sh = sh.filter(ImageFilter.GaussianBlur(SS * blur))
    img.alpha_composite(Image.composite(sh, Image.new("RGBA", img.size, (0, 0, 0, 0)),
                                        ch_mask))


def finish(img: Image.Image, w: int, h: int, name: str) -> None:
    out = img.resize((w, h), Image.LANCZOS)
    path = os.path.join(OUT_DIR, name)
    out.save(path)
    print("wrote", os.path.relpath(path))


def rivet(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float) -> None:
    """골드 리벳 — 어두운 홈 + 골드 돔 + 상단 하이라이트 점."""
    draw.ellipse([(cx - r - 1) * SS, (cy - r - 1) * SS, (cx + r + 1) * SS, (cy + r + 1) * SS],
                 fill=OUTLINE)
    draw.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=GOLD_DK)
    draw.ellipse([(cx - r * 0.72) * SS, (cy - r * 0.78) * SS,
                  (cx + r * 0.72) * SS, (cy + r * 0.62) * SS], fill=GOLD)
    draw.ellipse([(cx - r * 0.3) * SS, (cy - r * 0.55) * SS,
                  (cx + r * 0.15) * SS, (cy - r * 0.1) * SS], fill=GOLD_HI)


# ── 1. 상단바 512×96 — 하단만 둥근 강철 플레이트 + 하단 골드 라인 + 리벳 ──
def gen_top_bar():
    W, H = 512, 96
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    corners = (False, False, True, True)  # 하단만 둥글게
    body = shape_mask(W, H, (0, 0, W, H), 14, corners)
    vgrad_fill(img, body, (56, 60, 68), (27, 29, 34))
    brushed(img, body, alpha=5, seed=11)
    # 하단 스커트: 골드 라인 아래 어두운 강철 띠(라인이 "엣지 트림"으로 읽히게)
    skirt = shape_mask(W, H, (0, 84, W, H), 14, corners)
    vgrad_fill(img, skirt, (33, 35, 41), (20, 21, 25))
    # 골드 헤어라인(전폭, 가로 스트레치에 안전) + 위 1px 음영
    d.rectangle([0, 83 * SS, W * SS, 84 * SS], fill=(0, 0, 0, 150))
    d.rectangle([0, 84 * SS, W * SS, 86 * SS], fill=GOLD)
    d.rectangle([0, 84 * SS, W * SS, 85 * SS], fill=GOLD_HI)
    # 상단 1px 하이라이트, 최하단 아웃라인
    d.rectangle([0, 0, W * SS, 1 * SS], fill=(110, 116, 126, 150))
    bottom_edge = shape_mask(W, H, (0, H - 1.5, W, H), 1.5, corners)
    vgrad_fill(img, bottom_edge, OUTLINE, OUTLINE)
    # 리벳(좌우 마진 30 안쪽 — 나인패치로 늘여도 위치 고정)
    rivet(d, 21, 89.5, 3.2)
    rivet(d, W - 21, 89.5, 3.2)
    # 전체 미세 반투명(뒤 전장이 아주 살짝 비치게)
    img.putalpha(img.getchannel("A").point(lambda v: int(v * 0.97)))
    finish(img, W, H, "hud_top_bar.png")


# ── 2. 게이지 프레임 120×26 — 강철 림 + 골드 헤어라인 + 함몰 채널 ──────────
def gen_gauge_frame():
    W, H = 120, 26
    img = canvas(W, H)
    vgrad_fill(img, shape_mask(W, H, (0, 0, W, H), 7), OUTLINE, OUTLINE)
    vgrad_fill(img, shape_mask(W, H, (1, 1, W - 1, H - 1), 6), (150, 156, 166), (64, 68, 76))
    vgrad_fill(img, shape_mask(W, H, (3, 3, W - 3, H - 3), 5), GOLD_DK, GOLD)
    ch_box = (4, 4, W - 4, H - 4)
    ch = shape_mask(W, H, ch_box, 4)
    vgrad_fill(img, ch, RECESS_TOP, RECESS_BOT)
    inner_shadow_top(img, ch, ch_box, 4, depth=4)
    finish(img, W, H, "hud_gauge_frame.png")


# ── 3. 게이지 필 120×20 — 무채색 광택 스트립(코드가 색을 입힌다) ───────────
def gen_gauge_fill():
    W, H = 120, 20
    img = canvas(W, H)
    body = shape_mask(W, H, (0, 0, W, H), 4)
    vgrad_fill(img, body, (252, 252, 252), (170, 170, 170))
    # 상단 광택/하단 음영
    vgrad_fill(img, shape_mask(W, H, (1, 1, W - 1, 5), 2), (255, 255, 255), (253, 253, 253))
    vgrad_fill(img, shape_mask(W, H, (1, H - 5, W - 1, H - 1), 2), (152, 152, 152),
               (136, 136, 136))
    # 얇은 외곽 정의선
    ring = np.asarray(shape_mask(W, H, (0, 0, W, H), 4), int)
    inner = np.asarray(shape_mask(W, H, (1, 1, W - 1, H - 1), 3), int)
    edge = Image.fromarray(np.clip(ring - inner, 0, 255).astype(np.uint8), "L")
    lay = Image.new("RGBA", img.size, (112, 112, 112, 255))
    img.alpha_composite(Image.composite(lay, Image.new("RGBA", img.size, (0, 0, 0, 0)), edge))
    finish(img, W, H, "hud_gauge_fill.png")


# ── 4. 미니 슬롯 88×88 — 얇은 강철 림 + 골드 헤어라인 + 함몰 면 ────────────
# 아이콘은 함몰부 안에 앉으므로 림이 두꺼울수록 아이템이 작아 보인다. 44px 로 축소해 쓰는
# HUD 로드아웃에서 아이템이 최대한 크게 보이도록 림을 얇게 잡는다(함몰부 비율 = 아래 주석).
RIM_STEEL = 4.0     # 바깥 강철 림 두께(88px 기준)
RIM_GOLD = 1.4      # 골드 헤어라인 두께
# 함몰부 시작 = RIM_STEEL + RIM_GOLD = 5.4  →  안쪽 77.2/88 = 87.7%


def gen_slot_small():
    W, H = 88, 88
    img = canvas(W, H)
    vgrad_fill(img, shape_mask(W, H, (0, 0, W, H), 11), OUTLINE, OUTLINE)
    rim = shape_mask(W, H, (1.2, 1.2, W - 1.2, H - 1.2), 10)
    vgrad_fill(img, rim, (132, 138, 148), (52, 56, 63))
    brushed(img, rim, alpha=20, seed=23)
    g = RIM_STEEL
    vgrad_fill(img, shape_mask(W, H, (g, g, W - g, H - g), 7), GOLD_DK, GOLD)
    c = RIM_STEEL + RIM_GOLD
    ch_box = (c, c, W - c, H - c)
    ch = shape_mask(W, H, ch_box, 6)
    vgrad_fill(img, ch, (21, 22, 27), RECESS_BOT)
    inner_shadow_top(img, ch, ch_box, 6, depth=10, alpha=95, blur=1.5)
    finish(img, W, H, "hud_slot_small.png")


def _circle_mask(size_px: int, cx: float, cy: float, r: float) -> Image.Image:
    m = Image.new("L", (size_px, size_px), 0)
    ImageDraw.Draw(m).ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS],
                              fill=255)
    return m


def _ring(img, W, cx, cy, r_out, r_in, top, bot):
    outer = np.asarray(_circle_mask(W * SS, cx, cy, r_out), int)
    inner = np.asarray(_circle_mask(W * SS, cx, cy, r_in), int)
    ring = Image.fromarray(np.clip(outer - inner, 0, 255).astype(np.uint8), "L")
    vgrad_fill(img, ring, top, bot)


# ── 5. 원형 일시정지 버튼 88×88 — 강철 면 + 골드 링 + ⏸ 막대(베이크) ───────
def gen_btn_round():
    W = 88
    img = canvas(W, W)
    c = W / 2
    _ring(img, W, c, c, 43, 40.5, OUTLINE, OUTLINE)                    # 외곽선
    _ring(img, W, c, c, 40.5, 36.5, (150, 156, 166), (66, 70, 78))     # 강철 림
    _ring(img, W, c, c, 36.5, 33.5, GOLD_HI, GOLD_DK)                  # 골드 링
    _ring(img, W, c, c, 33.5, 32.5, OUTLINE, OUTLINE)                  # 분리선
    face = _circle_mask(W * SS, c, c, 32.5)
    vgrad_fill(img, face, (88, 93, 103), (44, 47, 54))
    brushed(img, face, alpha=16, seed=41)
    # 상반부 글로시 하이라이트
    gl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(gl).ellipse([(c - 30) * SS, (c - 31) * SS, (c + 30) * SS, (c + 6) * SS],
                               fill=(255, 255, 255, 30))
    img.alpha_composite(Image.composite(gl, Image.new("RGBA", img.size, (0, 0, 0, 0)), face))
    # 일시정지 막대 2개(음각 홈 + 밝은 막대)
    d = ImageDraw.Draw(img)
    for sx in (c - 12.5, c + 4.5):
        d.rounded_rectangle([(sx - 1) * SS, (c - 14) * SS, (sx + 9) * SS, (c + 14) * SS],
                            radius=3 * SS, fill=(20, 22, 26, 230))
        d.rounded_rectangle([sx * SS, (c - 13) * SS, (sx + 8) * SS, (c + 13) * SS],
                            radius=2.5 * SS, fill=(232, 237, 246, 255))
    finish(img, W, W, "hud_btn_round.png")


# ── 6. 레벨 뱃지 104×104 — 골드 트림 링 + 어두운 면(숫자는 코드가 그림) ────
def gen_badge_level():
    W = 104
    img = canvas(W, W)
    c = W / 2
    _ring(img, W, c, c, 51, 48.5, OUTLINE, OUTLINE)
    _ring(img, W, c, c, 48.5, 46, (150, 156, 166), (66, 70, 78))   # 바깥 강철 베젤(얇게)
    _ring(img, W, c, c, 46, 39.5, GOLD_HI, GOLD)                   # 골드 트림(두껍게)
    _ring(img, W, c, c, 39.5, 38.5, OUTLINE, OUTLINE)
    face = _circle_mask(W * SS, c, c, 38.5)
    vgrad_fill(img, face, (48, 52, 61), (27, 29, 35))
    gl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(gl).ellipse([(c - 34) * SS, (c - 37) * SS, (c + 34) * SS, (c - 2) * SS],
                               fill=(255, 255, 255, 30))
    img.alpha_composite(Image.composite(gl, Image.new("RGBA", img.size, (0, 0, 0, 0)), face))
    finish(img, W, W, "hud_badge_level.png")


# ── 미리보기(검수용) — Godot 처럼 나인패치로 늘여 실제 사용 크기로 배치 ────
def ninepatch(src: Image.Image, w: int, h: int, l: int, t: int, r: int, b: int) -> Image.Image:
    sw, sh = src.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    xs_src = [0, l, sw - r, sw]
    ys_src = [0, t, sh - b, sh]
    xs_dst = [0, l, w - r, w]
    ys_dst = [0, t, h - b, h]
    for i in range(3):
        for j in range(3):
            box = (xs_src[i], ys_src[j], xs_src[i + 1], ys_src[j + 1])
            dw, dh = xs_dst[i + 1] - xs_dst[i], ys_dst[j + 1] - ys_dst[j]
            if dw <= 0 or dh <= 0 or box[2] <= box[0] or box[3] <= box[1]:
                continue
            piece = src.crop(box).resize((dw, dh), Image.LANCZOS)
            out.alpha_composite(piece, (xs_dst[i], ys_dst[j]))
    return out


def gen_preview(path: str) -> None:
    bg = Image.new("RGBA", (760, 460), (86, 110, 62, 255))  # 풀밭 톤
    def load(name):
        return Image.open(os.path.join(OUT_DIR, name)).convert("RGBA")
    bg.alpha_composite(ninepatch(load("hud_top_bar.png"), 720, 96, 30, 6, 30, 14), (20, 10))
    # HP 게이지(296×26) + 필 60%
    frame = load("hud_gauge_frame.png")
    fill = load("hud_gauge_fill.png")
    bg.alpha_composite(ninepatch(frame, 296, 26, 7, 7, 7, 7), (30, 130))
    green = ninepatch(fill, 173, 18, 4, 4, 4, 4)
    tint = Image.new("RGBA", green.size, (77, 217, 90, 255))
    tint.putalpha(green.getchannel("A"))
    green = Image.composite(Image.blend(green, tint, 0.65), green, green.getchannel("A"))
    bg.alpha_composite(green, (34, 134))
    # 보스 게이지(400×16) + 필 75%
    bg.alpha_composite(ninepatch(frame, 400, 16, 7, 7, 7, 7), (30, 172))
    red = ninepatch(fill, 294, 8, 4, 4, 4, 4)
    tintr = Image.new("RGBA", red.size, (235, 56, 56, 255))
    tintr.putalpha(red.getchannel("A"))
    red = Image.composite(Image.blend(red, tintr, 0.65), red, red.getchannel("A"))
    bg.alpha_composite(red, (34, 176))
    # 슬롯 3개(44px)
    slot = load("hud_slot_small.png")
    for i in range(3):
        bg.alpha_composite(ninepatch(slot, 44, 44, 12, 12, 12, 12), (30 + i * 50, 215))
    # 버튼(44) + 뱃지(52)
    bg.alpha_composite(load("hud_btn_round.png").resize((44, 44), Image.LANCZOS), (30, 285))
    bg.alpha_composite(load("hud_badge_level.png").resize((52, 52), Image.LANCZOS), (100, 281))
    bg.save(path)
    print("wrote", path)


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    gen_top_bar()
    gen_gauge_frame()
    gen_gauge_fill()
    gen_slot_small()
    gen_btn_round()
    gen_badge_level()
    if len(sys.argv) > 2 and sys.argv[1] == "--preview":
        gen_preview(sys.argv[2])
