#!/usr/bin/env python3
"""UI 텍스트가 위젯 밖으로 넘치는지 실제 폰트로 검사한다.

번역(en/ko/ja)에 따라 길이가 크게 달라지고, 데이터(무기·도전과제·캐릭터)에서 오는
문자열은 코드만 봐서는 길이를 알 수 없다. 여기서는 번들 폰트로 실제 픽셀 폭을 재서
"고정 폭이라 늘어날 수 없는" 위젯과 대조한다.

컨테이너 안의 위젯은 내용에 맞춰 넓어지므로 대상이 아니다 — 앵커/오프셋이나
custom_minimum_size 로 폭이 고정된 위젯만 본다.

여유(headroom)가 HEADROOM_WARN 미만이면 경고한다. 글꼴 렌더러 차이·자간 반올림으로
실측이 몇 px 달라질 수 있어, 딱 맞는 것도 사실상 넘친 것으로 본다.

사용:  python3 tools/check_text_fit.py
"""
import re
import sys

from PIL import ImageFont

REG = "assets/fonts/NotoSansCJK-Subset.otf"
BOLD = "assets/fonts/NotoSansCJK-Subset-Bold.otf"

# UIStyle.button_box 의 좌우 콘텐츠 여백(버튼 텍스트가 쓸 수 없는 폭)
BTN_PAD = 36
HEADROOM_WARN = 0.12   # 12% 미만이면 경고

_fonts = {}


def tw(text: str, size: int, bold: bool = False) -> float:
    """여러 줄이면 가장 긴 줄의 폭."""
    key = (size, bold)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(BOLD if bold else REG, size)
    return max((_fonts[key].getlength(l) for l in text.split("\n")), default=0.0)


def load_locale() -> dict:
    src = open("scripts/Locale.gd", encoding="utf-8").read()
    out = {}
    for key, body in re.findall(r'"([a-z0-9_]+)":\s*\{([^}]*)\}', src, re.S):
        out[key] = {lang: v.replace("\\n", "\n")
                    for lang, v in re.findall(r'"(en|ko|ja)":\s*"((?:[^"\\]|\\.)*)"', body)}
    return out


def res_strings(path: str, prop: str) -> list:
    """리소스(.tres)의 문자열 속성 값들. (출처, 문자열) 튜플로 돌려 다른 후보와 형식을 맞춘다."""
    try:
        raw = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return []
    vals = sorted(set(re.findall(rf'{prop}\s*=\s*"((?:[^"\\]|\\.)*)"', raw)))
    return [("data", v) for v in vals]


def main() -> None:
    L = load_locale()

    def loc(key, fmt=None):
        out = []
        for lang, v in L.get(key, {}).items():
            s = v
            if fmt is not None:
                try:
                    s = v % fmt
                except (TypeError, ValueError):
                    pass
            out.append((lang, s))
        return out

    def lit(*texts):
        return [("-", t) for t in texts]

    # 보물 상자 카드에 실제로 올라가는 문구 전체(ChestRewardPanel 의 _roll_* 참고)
    chest_texts = ([("data", "NEW  %s" % n) for _, n in res_strings("data/item_catalog.tres", "display")]
                   + [("data", "%s  Lv+1" % n) for _, n in res_strings("data/item_catalog.tres", "display")]
                   + lit("+999 Gold", "+9999 XP", "XP Magnet  8s", "FREE LEVEL UP",
                         "Full Heal", "+1 REVIVE", "+99 Meta Gold", "JACKPOT\n+999 Gold"))

    # (화면·위젯, 사용 가능 폭 px, 글꼴 크기, 굵게, 후보 문자열들, [mode])
    cases = [
        # ── 인트로 (앵커 고정) ─────────────────────────────────
        ("인트로 · 건너뛰기 버튼", 132 - BTN_PAD, 18, True, loc("intro_skip")),
        ("인트로 · 시작 버튼", 260 - BTN_PAD, 26, True, loc("intro_begin")),
        ("인트로 · 제목", 720, 44, True, loc("intro_title")),
        ("인트로 · 본문", 604, 26, False,
         [t for k in ("intro_l1", "intro_l2", "intro_l3", "intro_l4", "intro_l5") for t in loc(k)]),
        ("인트로 · 목표 한 줄", 720, 20, False, loc("hud_goal_fmt", "30:00")),

        # ── HUD (씬/코드 고정 오프셋) ──────────────────────────
        ("HUD · 골드", 168, 20, False, lit("999999")),
        ("HUD · HP 라벨", 296, 16, False, lit("HP 999 / 999")),
        ("HUD · 처치 수", 226, 18, False, loc("hud_kills_fmt", 99999)),
        ("HUD · 타이머", 226, 28, False, lit("88:88")),
        ("HUD · 연장전 타이머", 226, 19, False,
         [(l, "%s +99:59" % s) for l, s in loc("hud_overtime")]),
        ("HUD · 무기 라벨", 290, 20, False,
         [("data", "%s  99s" % n) for _, n in res_strings("data/item_catalog.tres", "display")]),
        ("HUD · 버프 라벨", 290, 18, False, loc("hud_magnet_fmt", 99)),
        ("HUD · 레벨 뱃지", 64, 20, False, lit("999")),
        ("HUD · AUTO 태그", 48, 15, False, lit("AUTO")),
        ("HUD · 스웜 배너", 720, 30, False, loc("hud_swarm") + loc("hud_elite")),
        ("HUD · 보스 이름", 400, 18, False, res_strings("data/zombies.tres", "display")),
        ("HUD · 웨이브 클리어", 580, 48, True, loc("run_cleared") + loc("wave_clear_fmt", 99)),
        ("HUD · 일시정지 제목", 300, 34, True, loc("pause_title")),
        ("HUD · 생존 시간", 300, 18, False, loc("pause_time_fmt", "99:59")),
        ("HUD · 부활 버튼", 400 - BTN_PAD, 22, True, loc("hud_revive")),
        ("게임오버 · 제목", 400, 44, True, lit("GAME OVER") + loc("go_victory")),
        ("게임오버 · 다시하기", 400 - BTN_PAD, 28, True, loc("go_retry")),
        ("게임오버 · 메인메뉴", 400 - BTN_PAD, 22, True, loc("go_menu")),

        # ── 메인 메뉴 (버튼은 컨테이너가 넓혀 주지만 화면 폭은 넘으면 안 된다) ──
        ("메뉴 · 1차 버튼", 320 - BTN_PAD, 27, True, loc("menu_new_game")),
        ("메뉴 · 2차 버튼", 320 - BTN_PAD, 24, True, loc("menu_continue")),
        ("메뉴 · 3차 버튼", 284 - 56 - 18, 19, True,
         [t for k in ("menu_achievements", "menu_quests", "menu_rewards",
                      "menu_ranking", "menu_powerup", "menu_options") for t in loc(k)]),
        ("메뉴 · 버전 라벨", 320, 14, False, lit("v1.0.0 · 8f52771 · 2026-08-13 09:45 UTC")),

        # ── 상점 (패널 640 고정) ───────────────────────────────
        ("상점 · 업그레이드 버튼", 640 - 36 - 44 - 26 - 18, 19, True,
         [(lang, "%s Lv9" % v) for k, m in L.items() if k.startswith("upg_") and k.endswith("_name")
          for lang, v in m.items()]
         + [(lang, "-999G   %s" % v) for k, m in L.items()
            if k.startswith("upg_") and k.endswith("_desc") for lang, v in m.items()]),
        ("상점 · 광고 골드 버튼", 640 - 36 - 44 - BTN_PAD, 20, True,
         loc("shop_ad_gold_fmt", 250) + loc("shop_ad_unavail") + loc("shop_ad_claimed")),
        ("상점 · 계속 버튼", 640 - 36 - 44 - BTN_PAD, 24, True, loc("shop_continue")),
        ("상점 · 제목", 640 - 36 - 44, 34, True, loc("shop_clear_title", 99)),

        # ── 팝업 리스트 행 (전체화면 팝업: 720-24-36-48=612, 슬롯 44 + 간격 11 + 여백 22) ──
        ("팝업 행 · 제목", 612 - 22 - 44 - 11 - 90, 18, False,
         res_strings("data/achievements.tres", "display")
         + res_strings("data/item_catalog.tres", "display")),
        ("팝업 행 · 설명", 612 - 22 - 44 - 11, 14, False,
         [("data", "%s   (9999 / 9999)" % d) for _, d in res_strings("data/achievements.tres", "desc")]),

        # ── 아레나 카드 (전체화면 팝업 안, 카드 여백 16*2) ─────
        ("아레나 카드 · 이름", 612 - 32, 22, True, res_strings("data/themes.tres", "display")),
        ("아레나 카드 · 설명", 612 - 32, 15, False, res_strings("data/themes.tres", "desc")),

        # ── 타이틀 화면 ────────────────────────────────────────
        ("타이틀 · 태그라인", 720, 22, True, loc("title_tagline")),
        ("타이틀 · 탭 안내", 720, 26, True, loc("title_tap")),
        ("타이틀 · 버전 라벨", 346, 16, False,
         lit("v1.0.0 · 8f52771 · 2026-08-13 09:45 UTC")),

        # ── 보상 광고 오버레이(AdManager) — 패널 폭 420, 마진 24*2 ──
        ("광고 · 제목", 420 - 36 - 48, 26, True, loc("ad_title")),
        ("광고 · 안내", 420 - 36 - 48, 14, False, loc("ad_demo_hint"), "word"),
        ("광고 · 버튼", 420 - 36 - 48 - BTN_PAD, 22, True,
         loc("ad_watch_fmt", 5) + loc("ad_finished") + loc("ad_claim")),

        # ── 보상 카드(보물 상자) — 카드 폭이 고정이라 이름이 카드를 넘칠 수 있다.
        # 카드 128(4장) / 140(3장) / 152(2장 이하), 콘텐츠 여백 10*2.
        # 줄바꿈이 켜져 있으므로 "가장 긴 단어"가 기준이다.
        ("보상 카드 · 이름(4장)", 128 - 20, 14, False, chest_texts, "word"),
        ("보상 카드 · 이름(3장)", 140 - 20, 14, False, chest_texts, "word"),

        # ── 레벨업 카드 — vb 440, 좌측 슬롯(12+68+12=92) + 우측 여백 18 ──
        ("레벨업 카드", 440 - 92 - 18, 19, True,
         [("data", "%s  (%s)" % (n, "NEW")) for _, n in res_strings("data/item_catalog.tres", "display")]
         + res_strings("data/item_catalog.tres", "desc"), "word"),

        # ── 캐릭터 선택 카드 — 전체화면 팝업 612, 좌측 썸네일 여백 172 + 우측 18 ──
        ("캐릭터 카드", 612 - 172 - 18, 19, True,
         res_strings("data/character_db.tres", "display")
         + res_strings("data/character_db.tres", "desc"), "word"),

        # ── 영구 강화 카드 — 좌측 여백 86 ──
        ("영구 강화 카드", 612 - 86 - 18, 19, True,
         res_strings("data/meta_upgrades.tres", "display")
         + res_strings("data/meta_upgrades.tres", "desc"), "word"),
    ]

    # 줄바꿈(autowrap)이 켜진 위젯은 전체 문자열이 아니라 "쪼갤 수 없는 가장 긴 단어"가
    # 한 줄에 들어가야 한다. 그보다 넓으면 줄바꿈으로도 해결되지 않아 밖으로 삐져나온다.
    # (보물상자 카드가 정확히 이 경우였다 — 전체 길이만 보면 통과라 놓쳤다.)
    def worst_token(texts, size, bold):
        best = None
        for lang, s_ in texts:
            for tok in s_.replace("\n", " ").split():
                px = tw(tok, size, bold)
                if best is None or px > best[0]:
                    best = (px, lang, tok)
        return best

    print(f"{'위젯':26} {'가용':>5} {'실측':>6} {'여유':>7}  최악 후보")
    print("-" * 96)
    over, warn = [], []
    for case in cases:
        name, avail, size, bold, texts = case[:5]
        mode = case[5] if len(case) > 5 else "full"
        texts = [t for t in texts if t[1]]
        if not texts:
            continue
        if mode == "word":
            got = worst_token(texts, size, bold)
            if got is None:
                continue
            px, lang, s = got
        else:
            lang, s = max(texts, key=lambda t: tw(t[1], size, bold))
            px = tw(s, size, bold)
        head = (avail - px) / avail if avail else -1
        mark = "OK  "
        if px > avail:
            mark, _ = "넘침", over.append((name, avail, px, lang, s))
        elif head < HEADROOM_WARN:
            mark, _ = "빠듯", warn.append((name, avail, px, lang, s))
        flat = s.replace("\n", " / ")
        print(f"{name:26} {avail:5.0f} {px:6.0f} {head*100:6.1f}%  {mark} [{lang}] {flat[:34]!r}")

    print(f"\n넘침 {len(over)}건 · 빠듯(여유 {HEADROOM_WARN*100:.0f}% 미만) {len(warn)}건")
    for n, a, px_, lang, s in over + warn:
        print(f"  - {n}: 가용 {a:.0f}px < 실측 {px_:.0f}px  [{lang}] {s.replace(chr(10),' / ')!r}")

    missing = coverage_gaps()
    if missing:
        print("\n미검증 파일(텍스트 위젯이 있는데 위 목록에 케이스가 없다):")
        for f, n in missing:
            print(f"  - {f}: 텍스트 위젯 {n}곳")
    sys.exit(1 if over or warn or missing else 0)


# 케이스 이름 앞머리 → 어느 파일을 검증하는지 매핑. 새 화면을 만들면 여기에도 추가해야
# 커버리지 검사를 통과한다(이번에 보물 상자를 통째로 빠뜨린 재발을 막는 장치).
COVERED_BY = {
    "MainMenu.gd": ("메뉴", "팝업 행", "아레나", "캐릭터", "영구 강화"),
    "HUD.gd": ("HUD", "게임오버"),
    "IntroStory.gd": ("인트로",),
    "ShopPanel.gd": ("상점",),
    "ChestRewardPanel.gd": ("보상 카드",),
    "LevelUpPanel.gd": ("레벨업",),
    "UIListRow.gd": ("팝업 행",),
    "TitleScreen.gd": ("타이틀",),
    "AdManager.gd": ("광고",),
    "HUD.tscn": ("HUD", "게임오버"),
}
# 검증 대상이 아닌 곳과 그 이유.
EXEMPT = {
    "PerfOverlay.gd": "개발용 성능 오버레이 — 출시 화면이 아니고 폭 제약도 없다",
}


def coverage_gaps() -> list:
    """텍스트 위젯이 있는 파일 중 케이스도 면제도 없는 곳을 돌려준다."""
    import glob
    counts = {}
    for path in glob.glob("scripts/*.gd") + glob.glob("scenes/*.tscn"):
        name = path.replace("\\", "/").split("/")[-1]
        raw = open(path, encoding="utf-8", errors="replace").read()
        n = len(re.findall(r"\b(?:Label|Button)\.new\(\)", raw))
        n += len(re.findall(r'\[node name="\w+" type="(?:Label|Button)"', raw))
        if n:
            counts[name] = n
    return sorted((f, n) for f, n in counts.items()
                  if f not in COVERED_BY and f not in EXEMPT)


if __name__ == "__main__":
    main()
