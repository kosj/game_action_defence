#!/usr/bin/env python3
"""프로젝트가 실제로 표시하는 글자만 남겨 CJK 폰트를 서브셋한다.

왜 필요한가
-----------
Noto Sans CJK 는 한글 음절 11,172자를 전부 담고 있어 Regular+Bold 합계 2.4MB 다.
웹 빌드의 pck 는 전량 다운로드해야 첫 프레임이 뜨므로 이게 곧 초기 로딩 시간이다.
이 게임의 표시 문자는 전부 정적이다(사용자 텍스트 입력 UI 가 없다) — 그래서 실제로 표시될 수
있는 문자만 남기면 0.22MB 로 줄어든다.

주의: 지원 언어는 en/ko/**ja** 세 가지다(Locale.SUPPORTED). 일본어를 지원하므로
"한국어 전용으로 줄인다"는 접근은 쓸 수 없고, 세 언어에서 쓰는 글자를 모두 남긴다.

사용법
------
    python3 tools/subset_fonts.py --check     # 커버리지만 검사(CI 용, 파일 수정 없음)
    python3 tools/subset_fonts.py             # 폰트를 서브셋해서 덮어쓴다

새 문자를 추가했다면
--------------------
`--check` 가 실패한다. 저장소의 폰트는 이미 축소돼 있어 빠진 글리프를 되살릴 수 없으니,
원본을 다시 받아 assets/fonts 의 두 파일을 덮어쓴 뒤 다시 실행해야 한다:
    https://github.com/notofonts/noto-cjk  (Sans/OTF/Korean/NotoSansCJKkr-{Regular,Bold}.otf)
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

FONTS = [
    "assets/fonts/NotoSansCJK-Subset.otf",
    "assets/fonts/NotoSansCJK-Subset-Bold.otf",
]

# 문자를 수집할 소스(.gd 는 문자열 리터럴만 — project_charset 설명 참고).
SCAN_GLOBS = ("**/*.gd", "**/*.tres", "**/*.tscn", "**/*.godot", "**/*.json")
SCAN_SKIP = (".godot/", "tools/_")

# 원본 폰트에도 없던 문자 목록(서브셋 실행 시 자동 갱신). 아래 check() 설명 참고.
KNOWN_ABSENT = "tools/font_known_absent.txt"


def _base_charset() -> set[str]:
    """언어와 무관하게 항상 남겨야 하는 기본 문자."""
    cs: set[str] = set()
    cs |= {chr(c) for c in range(0x20, 0x7F)}      # ASCII 인쇄 가능
    cs |= {chr(c) for c in range(0xA0, 0x100)}     # Latin-1 보충
    cs |= {chr(c) for c in range(0x2000, 0x2070)}  # 일반 구두점(…—''"" 등)
    cs |= {chr(c) for c in range(0x3000, 0x3040)}  # CJK 구두점(、。「」 등)
    cs |= {chr(c) for c in range(0x3040, 0x30A0)}  # 히라가나 전체
    cs |= {chr(c) for c in range(0x30A0, 0x3100)}  # 가타카나 전체
    cs |= {chr(c) for c in range(0xFF01, 0xFF61)}  # 전각 영숫자/기호
    return cs


def project_charset(root: pathlib.Path) -> set[str]:
    """프로젝트가 화면에 표시할 수 있는 문자 + 기본 문자.

    .gd 는 **문자열 리터럴만** 본다 — 주석의 한글까지 포함하면 폰트가 불필요하게 커지고,
    무엇보다 주석을 고칠 때마다 커버리지 검사가 깨져 쓸모없는 실패를 낸다(주석은 표시되지 않는다).
    .tres/.tscn/.json 은 사실상 데이터라 전체를 훑는다.
    """
    cs = _base_charset()
    for pat in SCAN_GLOBS:
        for p in root.glob(pat):
            rel = str(p.relative_to(root)).replace("\\", "/")
            if any(s in rel for s in SCAN_SKIP):
                continue
            try:
                text = p.read_text(encoding="utf-8")
            except (UnicodeDecodeError, OSError):
                continue
            if rel.endswith(".gd"):
                for lit in re.findall(r'"([^"\n]*)"|\'([^\'\n]*)\'', text):
                    cs |= set(lit[0]) | set(lit[1])
            else:
                cs |= set(text)
    return cs


def font_charset(path: pathlib.Path) -> set[str]:
    from fontTools.ttLib import TTFont

    with TTFont(str(path), lazy=True) as f:
        return {chr(cp) for cp in f.getBestCmap().keys()}


def _known_absent(root: pathlib.Path) -> set[str]:
    """원본 폰트 자체에 없어서 서브셋 전에도 렌더 불가였던 문자.

    이 목록은 서브셋 실행 시 자동으로 갱신된다. 서브셋 때문에 사라진 것이 아니므로
    CI 를 막지 않는다 — 다만 여기 실제 표시 문자가 들어 있으면 그건 별개의 버그다.
    """
    p = root / KNOWN_ABSENT
    if not p.exists():
        return set()
    out: set[str] = set()
    for line in p.read_text(encoding="utf-8").splitlines():
        if line.startswith("#"):
            continue
        out |= set(line)
    return out


def check(root: pathlib.Path) -> int:
    want = project_charset(root)
    absent = _known_absent(root)
    failed = False
    for rel in FONTS:
        path = root / rel
        if not path.exists():
            print(f"[FONT] 없음: {rel}")
            failed = True
            continue
        have = font_charset(path)
        missing = sorted(
            c for c in want
            if c not in have and c.isprintable() and c not in absent
        )
        if missing:
            failed = True
            print(f"[FONT] {rel}: 글리프 {len(missing)}자 누락 → {''.join(missing[:60])}")
        else:
            print(f"[FONT] {rel}: OK (폰트 {len(have)}자 / 프로젝트 요구 {len(want)}자)")
    if failed:
        print(
            "\n[FONT] 서브셋 폰트에 없는 글자가 프로젝트에 새로 추가되었습니다.\n"
            "        원본 Noto Sans CJK 를 받아 tools/subset_fonts.py 를 다시 실행하세요\n"
            "        (자세한 안내는 이 스크립트 상단 docstring 참고)."
        )
    return 1 if failed else 0


def build(root: pathlib.Path) -> int:
    from fontTools import subset

    want = project_charset(root)
    text = "".join(sorted(want))
    for rel in FONTS:
        src = root / rel
        if not src.exists():
            print(f"[FONT] 없음: {rel}")
            return 1
        before = src.stat().st_size
        out = src.with_suffix(".subset.tmp")
        subset.main([
            str(src),
            f"--output-file={out}",
            f"--text={text}",
            "--layout-features=*",
            "--glyph-names",
            "--no-hinting",
            "--drop-tables+=DSIG",
            "--passthrough-tables",
        ])
        after = out.stat().st_size
        out.replace(src)
        print(f"[FONT] {rel}: {before // 1024}KB → {after // 1024}KB")
    # 요청했지만 원본에 없어 담지 못한 문자를 기록해 둔다 — check() 가 이걸 제외해야
    # "원래부터 없던 글자" 때문에 CI 가 영구히 실패하지 않는다.
    have = font_charset(root / FONTS[0])
    absent = sorted(c for c in want if c not in have and c.isprintable())
    (root / KNOWN_ABSENT).write_text(
        "# 원본 Noto Sans CJK 서브셋에도 없던 문자 — tools/subset_fonts.py 가 자동 생성한다.\n"
        "# 이 중 실제로 화면에 표시되는 글자가 있으면 그건 폰트 커버리지 버그다.\n"
        + "".join(absent) + "\n",
        encoding="utf-8",
    )
    print(f"[FONT] 대상 문자 {len(want)}자, 원본에 없어 제외 {len(absent)}자")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true", help="커버리지만 검사(파일 수정 없음)")
    args = ap.parse_args()
    root = pathlib.Path(__file__).resolve().parent.parent
    return check(root) if args.check else build(root)


if __name__ == "__main__":
    sys.exit(main())
