#!/usr/bin/env python3
"""Locale.gd 의 모든 표시 문자열이 **번들 서브셋 폰트에 실제로 있는지** 검사한다.

왜 또 하나 만드는가: 같은 일을 하는 `tools/check_font_coverage.gd` 는 Godot 이 있어야 돈다.
그런데 문자열을 고치는 작업(번역 추가·문구 수정)은 대부분 에디터 없이 하고, 없는 글자를 쓰면
화면에 두부(□)가 뜨는데 **로컬 실렌더로는 그것조차 안 보인다** — 개발 컨테이너에는 시스템 CJK
폰트가 있어 Godot 이 대신 그려 주기 때문이다(CLAUDE.md §2). 웹 빌드에는 그 폴백이 없다.

그래서 이 검사는 폰트 파일의 cmap 을 직접 읽는다. 사람의 기억이나 금지 목록이 아니라
**번들된 폰트가 실제로 가진 글자**가 기준이다.

  python3 tools/check_locale_glyphs.py            # 검사(종료 코드 0/1)
  python3 tools/check_locale_glyphs.py --list ko  # 쓸 수 있는 한글 음절을 보여준다

새 문구를 쓸 때는 --list 로 먼저 쓸 수 있는 글자를 보는 편이 빠르다. 서브셋에는 한글 음절이
376자밖에 없어서, 흔한 낱말도 못 쓰는 경우가 있다(예: "희귀"·"영웅"·"레벨업"의 '업').

의존성: fontTools (`pip install fonttools`)
"""
import argparse
import os
import re
import sys

from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = [
    os.path.join(ROOT, "assets/fonts/NotoSansCJK-Subset.otf"),
    os.path.join(ROOT, "assets/fonts/NotoSansCJK-Subset-Bold.otf"),
]
LOCALE = os.path.join(ROOT, "scripts/Locale.gd")
ABSENT = os.path.join(ROOT, "tools/font_known_absent.txt")

# 서식 문자열의 제어 문자 — 화면에 글자로 그려지지 않는다.
IGNORE = set("\n\t")


def font_chars() -> set:
    """두 폰트 **모두**에 있는 글자만 안전하다(제목은 Bold 로 그려진다)."""
    common = None
    for path in FONTS:
        cps = set()
        for table in TTFont(path)["cmap"].tables:
            cps |= set(table.cmap.keys())
        chars = {chr(c) for c in cps}
        common = chars if common is None else common & chars
    return common or set()


def locale_strings() -> list:
    """[(줄번호, 키, 언어, 문자열)] — Locale.gd 의 표시 문자열 전부."""
    src = open(LOCALE, encoding="utf-8").read()
    out = []
    for m in re.finditer(r'"([a-z0-9_]+)":\s*\{(.*?)\}', src, re.S):
        key, body = m.group(1), m.group(2)
        base = src[:m.start()].count("\n") + 1
        for lm in re.finditer(r'"(en|ko|ja)":\s*"((?:[^"\\]|\\.)*)"', body):
            line = base + body[:lm.start()].count("\n")
            out.append((line, key, lm.group(1), lm.group(2).replace("\\n", "\n")))
    return out


def known_absent() -> set:
    """되살릴 수 없다고 기록된 글자들 — 있으면 더 친절한 메시지를 낸다."""
    if not os.path.exists(ABSENT):
        return set()
    chars = set()
    for line in open(ABSENT, encoding="utf-8"):
        if not line.startswith("#"):
            chars |= set(line.strip())
    return chars


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", metavar="LANG", choices=["ko", "ja", "all"],
                    help="쓸 수 있는 글자를 보여준다(ko=한글 음절, ja=가나)")
    args = ap.parse_args()

    chars = font_chars()
    if args.list:
        if args.list in ("ko", "all"):
            han = sorted(c for c in chars if 0xAC00 <= ord(c) <= 0xD7A3)
            print("한글 음절 %d자:\n%s\n" % (len(han), "".join(han)))
        if args.list in ("ja", "all"):
            kana = sorted(c for c in chars if 0x3040 <= ord(c) <= 0x30FF)
            print("가나 %d자:\n%s\n" % (len(kana), "".join(kana)))
            kanji = sorted(c for c in chars if 0x4E00 <= ord(c) <= 0x9FFF)
            print("한자 %d자:\n%s" % (len(kanji), "".join(kanji)))
        return 0

    absent = known_absent()
    rows = locale_strings()
    bad = []
    for line, key, lang, text in rows:
        miss = sorted({c for c in text if c not in chars and c not in IGNORE})
        if miss:
            bad.append((line, key, lang, text, miss))

    for line, key, lang, text, miss in bad:
        tag = " (font_known_absent 목록)" if set(miss) & absent else ""
        print("Locale.gd:%d  %s[%s]  없는 글자: %s%s\n    %s"
              % (line, key, lang, "".join(miss), tag, text.replace("\n", "\\n")))
    print("\n문자열 %d개 · 폰트 글리프 %d자 · 문제 %d건"
          % (len(rows), len(chars), len(bad)))
    if bad:
        print("→ 그 글자는 화면에 두부(□)로 뜬다. 다른 표기로 바꾸거나(권장),")
        print("  정말 필요하면 원본 폰트를 복원해 tools/subset_fonts.py 를 다시 돌려야 한다.")
        print("  쓸 수 있는 글자는 --list ko / --list ja 로 확인한다.")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
