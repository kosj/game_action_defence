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
`--check` 가 실패한다. 저장소의 폰트는 이미 축소돼 있어 빠진 글리프를 되살릴 수 없다.
**서브셋 이전 원본(각 1.2MB)이 git 히스토리에 남아 있으므로 내려받을 필요가 없다** — 되살린 뒤
다시 서브셋하면 그 자리에서 다시 100KB 로 줄어든다:

    git fetch --unshallow    # 이 저장소는 얕은 클론으로 시작한다 — 없으면 026b6f7 이 안 보인다
    git cat-file -p 026b6f7:assets/fonts/NotoSansCJK-Subset.otf      > assets/fonts/NotoSansCJK-Subset.otf
    git cat-file -p 026b6f7:assets/fonts/NotoSansCJK-Subset-Bold.otf > assets/fonts/NotoSansCJK-Subset-Bold.otf
    python3 tools/subset_fonts.py

⚠️ **원본 복구를 빠뜨리면 스크립트가 거부한다**(P2-9). 예전에는 그냥 돌아가면서 이미 빠져 있던
한글 36자를 "원본에도 없는 글자"로 판정해 `font_known_absent.txt` 에 올렸고, CI 게이트가 그걸
**금지어**로 신뢰해 이후 세션이 멀쩡한 한국어를 피해 쓰게 됐다. 지금은 입력 폰트의 한글 수를
세어 원본이 아니면 아무것도 건드리지 않고 멈춘다.

한자는 89자뿐이다 (중요)
------------------------
번들 원본은 "Noto Sans CJK 전체"가 아니라 **한글 위주 빌드**다 — 한글 음절 11,172자는 전부
있지만 한자는 89자뿐이고, 그마저 기존 ja 문자열이 쓰는 글자에 맞춰진 것이다. 그래서
**일본어에 새 한자를 쓰면 되살릴 방법이 없다**(雨/雪/霧/砂/嵐/晴 전부 없음). ja 문자열은
가나로 적어라 — 게임 HUD 에서 가타카나 외래어 표기는 일본어로도 자연스럽다.
정말 한자가 필요하면 그때는 진짜 원본을 받아 폰트를 통째로 교체해야 한다(용량 재검토 필요):
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
# 화면에 뜨지 않는 텍스트는 수집하지 않는다:
#   scenes/*Test.gd   회귀 테스트 — 검사 이름을 print 로 찍을 뿐이다
#   tools/**          전부. 개발 도구는 화면에 글자를 그리지 않는다 — 콘솔 출력뿐이다.
#
# 예전에는 tools/{check,verify,shot}_* 만 뺐다. 그러자 bench_lategame·probe_batching·
# gen_damage_digits 의 **진행 메시지에 쓰인 한글 36자**가 "표시 문자"로 잡혀 `--check` 가
# 영구히 빨간 상태였다(P2-9 작업 중 확인). 예외를 하나씩 늘리는 대신 규칙을 뒤집는다.
#
# ⚠️ 카탈로그 생성기(gen_item_catalog 등)의 표시 이름도 이제 여기서 안 잡힌다. 괜찮다 —
# 그 이름은 생성물인 `data/**.tres` 에 들어가고 그쪽은 계속 훑는다. .tres 에 없는 이름은
# 화면에도 안 뜬다(생성기를 고쳤으면 재생성하는 것이 규약이다 — CLAUDE.md §2).
# CI 게이트인 check_font_coverage.gd 도 같은 범위(Locale.STRINGS + data/*.tres)를 본다.
SCAN_SKIP = (".godot/", "tools/", "Test.gd")

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


def _strip_gd_comments(text: str) -> str:
    """GDScript 소스에서 주석을 걷어낸다(따옴표 안의 `#` 은 주석이 아니다).

    완전한 파서가 아니라 줄 단위 스캐너다 — 여러 줄 문자열(\"\"\")은 다루지 않는다.
    이 용도(표시 문자열 수집)에는 충분하고, 틀리는 쪽이 "덜 수집"이라 폰트가 커지지 않는다.
    """
    out = []
    for line in text.split("\n"):
        quote = ""
        for i, ch in enumerate(line):
            if quote:
                if ch == quote and (i == 0 or line[i - 1] != "\\"):
                    quote = ""
            elif ch in "\"'":
                quote = ch
            elif ch == "#":
                line = line[:i]
                break
        out.append(line)
    return "\n".join(out)


def project_charset(root: pathlib.Path) -> set[str]:
    """프로젝트가 화면에 표시할 수 있는 문자 + 기본 문자.

    .gd 는 **주석을 걷어낸 뒤 문자열 리터럴만** 본다 — 주석의 한글까지 포함하면 폰트가
    불필요하게 커지고, 무엇보다 주석을 고칠 때마다 커버리지 검사가 깨져 쓸모없는 실패를 낸다
    (주석은 표시되지 않는다). 예전에는 파일 전체에 정규식을 돌려서, **주석 안에 따옴표로 인용한
    한글이 표시 문자열로 잡혔다** — 설명을 한 줄 쓰는 것만으로 검사가 깨졌다.
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
                for lit in re.findall(r'"([^"\n]*)"|\'([^\'\n]*)\'', _strip_gd_comments(text)):
                    cs |= set(lit[0]) | set(lit[1])
            else:
                cs |= set(text)
    return cs


## 원본 폰트 판정 임계. 실측(2026-08-21):
##   원본(026b6f7)  전체 11,973 · 한글 11,172 · 한자 89
##   서브셋 산출물  전체  1,004 · 한글    376 · 한자 53
## 30배 차이라 어디에 그어도 되지만, 서브셋이 자라도 안전하도록 원본 쪽에 가깝게 잡는다.
HANGUL_SOURCE_MIN = 10000
HANGUL_RANGE = (0xAC00, 0xD7A3)


def hangul_count(path: pathlib.Path) -> int:
    """폰트 cmap 의 한글 음절 수 — 원본/서브셋을 가르는 가장 단순한 지표."""
    from fontTools.ttLib import TTFont   # 지연 임포트(다른 함수와 같은 방식)

    lo, hi = HANGUL_RANGE
    with TTFont(str(path), lazy=True) as f:
        return sum(1 for cp in f.getBestCmap() if lo <= cp <= hi)


def _is_hangul(ch: str) -> bool:
    return HANGUL_RANGE[0] <= ord(ch) <= HANGUL_RANGE[1]


def assert_source_fonts(root: pathlib.Path) -> int:
    """입력이 **원본**인지 확인한다. 서브셋 산출물이면 거부한다(P2-9).

    왜 필요한가: `assets/fonts/*.otf` 는 원본이 아니라 **이미 서브셋된 100KB 산출물**이다.
    그대로 다시 서브셋하면 이미 빠져 있는 글자가 "원본에도 없는 글자"로 판정돼
    `font_known_absent.txt` 에 올라간다. 그 목록은 CI 게이트가 **되살릴 수 없는 글자**로
    신뢰하므로, 결과적으로 **원본에 멀쩡히 있는 한글이 금지어가 된다** — 이후 세션이
    쓸 수 있는 한국어를 피해 가며 문구를 쓰게 된다.

    문서에 절차가 적혀 있어도 "문서를 안 읽고 스크립트만 돌리면 조용히 망가지는" 형태였다.
    그래서 문서가 아니라 코드가 막는다.
    """
    for rel in FONTS:
        path = root / rel
        if not path.exists():
            print(f"[FONT] 없음: {rel}")
            return 1
        n = hangul_count(path)
        if n < HANGUL_SOURCE_MIN:
            print(
                f"[FONT] 거부: {rel} 는 원본이 아니라 이미 서브셋된 산출물이다"
                f" (한글 {n}자 < 기준 {HANGUL_SOURCE_MIN}자).\n"
                "        이대로 서브셋하면 원본에 있는 한글이 '되살릴 수 없는 글자'로\n"
                "        font_known_absent.txt 에 올라가 CI 게이트가 그것을 금지어로 취급한다.\n"
                "        원본을 먼저 복구할 것:\n"
                "          git fetch --unshallow    # 이 저장소는 얕은 클론으로 시작한다\n"
                "          git cat-file -p 026b6f7:assets/fonts/NotoSansCJK-Subset.otf"
                "      > assets/fonts/NotoSansCJK-Subset.otf\n"
                "          git cat-file -p 026b6f7:assets/fonts/NotoSansCJK-Subset-Bold.otf"
                " > assets/fonts/NotoSansCJK-Subset-Bold.otf"
            )
            return 1
    return 0


def font_charset(path: pathlib.Path) -> set[str]:
    from fontTools.ttLib import TTFont

    with TTFont(str(path), lazy=True) as f:
        return {chr(cp) for cp in f.getBestCmap().keys()}


def _known_absent(root: pathlib.Path) -> set[str]:
    """원본 폰트 자체에 없어서 서브셋 전에도 렌더 불가였던 문자.

    이 목록은 서브셋 실행 시 자동으로 갱신된다. 여기서는 면제로 쓴다 — 이 도구의 수집 대상
    (project_charset)에는 _base_charset() 의 구두점 범위처럼 **화면에 뜨지 않는 글자**가
    섞여 있어, 그것까지 실패로 부르면 매번 노이즈가 난다.

    "이 글자를 쓰면 두부(□)가 뜬다"는 판정은 **tools/check_font_coverage.gd 가 맡는다**
    (수집 대상이 Locale.STRINGS + data/*.tres 로 좁아 표시 문자와 정확히 일치한다).
    그쪽이 CI 게이트이고, 이 목록을 면제가 아니라 금지로 쓴다(HANDOFF P1-17).
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

    # 입력이 원본인지 먼저 확인한다 — 서브셋 산출물을 다시 서브셋하면 금지 목록이 오염된다(P2-9).
    rc = assert_source_fonts(root)
    if rc != 0:
        return rc

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
    # 기존 목록과 **합집합**으로 유지한다. 이 파일은 "원본 폰트에 무엇이 없는가"라는 사실의
    # 기록이지, "지금 쓰는 글자 중 없는 것"의 목록이 아니다. 지웠다가는 문구를 고쳐 그 글자를
    # 안 쓰게 되는 순간 경고가 같이 사라져, 다음 사람이 같은 글자를 다시 쓴다(P1-17 이
    # 그 함정이었다 — 23자를 걷어낸 직후 목록에서도 사라질 뻔했다).
    fresh = {c for c in want if c not in have and c.isprintable()}
    # 한글은 이 목록에 들어올 수 없다 — 원본이 한글 11,172자를 전부 담은 한국어 빌드다.
    # 여기에 한글이 있다면 그건 "원본에 없다"가 아니라 **입력이 원본이 아니었다**는 뜻이고,
    # 위 게이트가 막지 못한 경로가 있다는 신호다. 목록을 오염시키느니 멈춘다(P2-9).
    hangul_leak = sorted(c for c in fresh if _is_hangul(c))
    if hangul_leak:
        print(
            f"[FONT] 중단: 한글 {len(hangul_leak)}자가 '원본에 없는 글자'로 잡혔다"
            f" → {''.join(hangul_leak[:40])}\n"
            "        원본은 한글을 전부 담고 있으므로 이건 입력이 원본이 아니라는 뜻이다.\n"
            "        금지 목록을 건드리지 않고 멈춘다 — 원본을 복구한 뒤 다시 실행할 것."
        )
        return 1
    # 기존 목록과 **합집합**으로 유지한다. 이 파일은 "원본 폰트에 무엇이 없는가"라는 사실의
    # 기록이지, "지금 쓰는 글자 중 없는 것"의 목록이 아니다. 지웠다가는 문구를 고쳐 그 글자를
    # 안 쓰게 되는 순간 경고가 같이 사라져, 다음 사람이 같은 글자를 다시 쓴다(P1-17 이
    # 그 함정이었다 — 23자를 걷어낸 직후 목록에서도 사라질 뻔했다).
    # ⚠️ 합집합이라 **한 번 들어간 글자는 스스로 빠지지 않는다.** 그래서 위에서 한글을
    # 막고, 아래에서 과거에 새어 들어간 한글은 걷어낸다(오염된 목록의 자가 복구).
    absent = sorted((set(_known_absent(root)) | fresh) - set(filter(_is_hangul, _known_absent(root))))
    (root / KNOWN_ABSENT).write_text(
        "# 원본 Noto Sans CJK 서브셋에도 없던 문자 — tools/subset_fonts.py 가 자동 생성한다.\n"
        "# **이 글자들은 쓰면 안 된다.** 되살릴 방법이 없어 화면에 두부(□)로 뜬다.\n"
        "# tools/check_font_coverage.gd(CI 게이트)가 표시 문자열에서 이 글자를 찾으면 실패시킨다.\n"
        "# 일본어에 한자가 필요하면 가나 표기로 우회한다 — scripts/Locale.gd 의 선례 참고.\n"
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
