#!/usr/bin/env python3
"""GDScript 정적 점검 — 엔진 없이 "파일이 통째로 파싱 실패"하는 사고를 막는다.

에디터가 없는 환경에서 스크립트를 수정하면 문법 오류를 실행 전까지 알 수 없다.
특히 **예상치 못한 들여쓰기 증가**는 GDScript 파서가 파일 전체를 거부하게 만들어,
해당 화면이 통째로 안 뜨는 형태로 나타난다(실제로 발생했다).

검사 항목:
  1. 예상치 못한 들여쓰기 증가 — 앞 줄이 블록을 여는 형태가 아닌데 깊어지는 경우
  2. 탭/스페이스 혼용 들여쓰기
  3. 괄호 짝 불일치(주석·문자열 제외)

사용:  python3 tools/check_gdscript.py [경로...]   (기본: scripts/**/*.gd)
"""
import glob
import re
import sys


def strip_code(line: str) -> str:
    """문자열 리터럴은 남기고 주석만 제거한다(따옴표 안의 # 는 주석이 아니다)."""
    out = []
    quote = None
    i = 0
    while i < len(line):
        ch = line[i]
        if quote:
            out.append(ch)
            if ch == "\\":
                if i + 1 < len(line):
                    out.append(line[i + 1])
                    i += 1
            elif ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
            out.append(ch)
        elif ch == "#":
            break
        else:
            out.append(ch)
        i += 1
    return "".join(out)


# 블록을 여는(다음 줄이 더 깊어도 되는) 줄의 끝 형태
OPENERS = (":", "\\", "(", "[", "{", ",", "+", "-", "*", "/", "=", "and", "or")


def check(path: str) -> list:
    errs = []
    raw = open(path, encoding="utf-8").read()
    lines = raw.split("\n")

    prev_indent = 0
    prev_code = ""
    prev_no = 0
    depth = 0   # 열려 있는 (), [], {} 깊이 — 0 보다 크면 "연속 줄"이라 들여쓰기 규칙이 없다
    for no, line in enumerate(lines, 1):
        code = strip_code(line)
        if not code.strip():
            continue
        in_continuation = depth > 0
        depth += sum(code.count(c) for c in "([{") - sum(code.count(c) for c in ")]}")
        depth = max(depth, 0)
        if in_continuation:
            prev_code, prev_no = code, no   # 들여쓰기 기준은 갱신하지 않는다
            continue
        body = code.lstrip("\t")
        indent = len(code) - len(body)
        if body.startswith(" "):
            errs.append((no, "들여쓰기에 스페이스 사용(탭이어야 함)", line.strip()[:60]))
        if indent > prev_indent and not prev_code.rstrip().endswith(OPENERS):
            errs.append((no, f"예상치 못한 들여쓰기 증가 {prev_indent}->{indent}",
                         f"앞줄({prev_no}): {prev_code.strip()[:50]}"))
        prev_indent, prev_code, prev_no = indent, code, no

    code_only = "\n".join(strip_code(l) for l in lines)
    for a, b in [("(", ")"), ("[", "]"), ("{", "}")]:
        if code_only.count(a) != code_only.count(b):
            errs.append((0, f"괄호 불일치 {a}{b}",
                         f"{a}={code_only.count(a)} {b}={code_only.count(b)}"))
    return errs


def main() -> None:
    paths = sys.argv[1:] or sorted(glob.glob("scripts/**/*.gd", recursive=True))
    total = 0
    for p in paths:
        for no, kind, ctx in check(p):
            print(f"{p}:{no}  {kind}  |  {ctx}")
            total += 1
    print(f"\n검사 {len(paths)}개 파일 · 문제 {total}건")
    sys.exit(1 if total else 0)


if __name__ == "__main__":
    main()
