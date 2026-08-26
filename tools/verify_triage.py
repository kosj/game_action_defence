#!/usr/bin/env python3
"""프리즈 트리아지 회귀 테스트 (P0-10).

왜 필요한가
-----------
`analyze_telemetry.py` 의 프리즈 판정은 **P0-5(프리즈 원인 규명)가 딛고 서는 바닥**이다.
그런데 그 바닥이 틀려 있었다 — 임계가 `frame_ms_max > 100` 하나뿐이라 **fps 30 · 프레임 80ms
인 판 셋을 전부 "지표 정상"으로 분류했고**, 그 판정을 믿고 P0-5 를 "성능 붕괴 아님"으로 좁혔다.
사람이 화면을 보고 "프레임이 엄청 떨어진다"고 말한 바로 그 판들이다.

도구가 조용히 틀리면 재현 기록을 아무리 더 받아도 같은 오답이 나온다. 그래서 그 세 판을
**고정 입력**(`tools/fixtures/freeze_triage.jsonl`)으로 박아 두고, 판정이 되돌아가지 않는지 잠근다.

    python3 tools/verify_triage.py
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURE = os.path.join(HERE, "fixtures", "freeze_triage.jsonl")


def block(out, header):
    """`중도 종료 N분 시점의 상태` 한 덩어리를 잘라 온다."""
    lines = out.splitlines()
    for i, ln in enumerate(lines):
        if ln.startswith(header):
            end = i + 1
            while end < len(lines) and lines[end].startswith("  "):
                end += 1
            return "\n".join(lines[i:end])
    return ""


def main():
    if not os.path.exists(FIXTURE):
        sys.exit("고정 입력이 없다: %s" % FIXTURE)
    p = subprocess.run([sys.executable, os.path.join(HERE, "analyze_telemetry.py"), FIXTURE],
                       capture_output=True, text=True)
    if p.returncode != 0:
        sys.exit("analyze_telemetry.py 가 실패했다(rc=%d)\n%s" % (p.returncode, p.stderr))
    out = p.stdout

    fails = []

    def check(desc, ok, detail=""):
        print("  %-4s %s%s" % ("ok" if ok else "FAIL", desc, ("  — " + detail) if detail and not ok else ""))
        if not ok:
            fails.append(desc)

    print("프리즈 트리아지 회귀 (P0-10)")

    # ① ② ③ — 옛 도구가 "지표 정상"으로 넘긴 세 판. 전부 성능 문제로 잡혀야 한다.
    for header, label in (("중도 종료 16.3분", "fps 32 · 80.5ms"),
                          ("중도 종료 24.3분", "fps 30 · 54.6ms"),
                          ("중도 종료 37.2분", "fps 31 · 75.7ms")):
        b = block(out, header)
        hit = ("성능 저하" in b) or ("성능 붕괴" in b)
        check("%s (%s) → 성능 저하/붕괴로 분류" % (header, label), hit, b or "덩어리를 못 찾았다")
        check("%s → '지표 정상' 이라고 하지 않는다" % header, "지표 정상" not in b, b)

    # ④ — 정상 판까지 저하로 잡으면 임계가 너무 빡빡한 것이다.
    b4 = block(out, "중도 종료 7.2분")
    check("중도 종료 7.2분 (fps 60) → 성능 문제로 잡지 않는다",
          "성능 저하" not in b4 and "성능 붕괴" not in b4, b4)

    # ⑤ — 누수가 실제로 있는 판. 세 지표 전부 잡고, 결론이 '지표 정상' 이면 안 된다.
    b5 = block(out, "중도 종료 20.0분")
    for key in ("고아 노드 누수 의심", "리소스 누수 의심", "VRAM 누수 의심"):
        check("누수 판 → %s" % key, key in b5, b5)
    check("누수 판 → '지표 정상' 이라고 하지 않는다", "지표 정상" not in b5, b5)

    # 옛 기록은 mem 이 웹에서 항상 0 이었다. 0 을 값처럼 보여 주면 "누수 없음"으로 오독된다.
    for header in ("중도 종료 16.3분", "중도 종료 24.3분", "중도 종료 37.2분"):
        b = block(out, header)
        check("%s → 누수 계수기를 '미계측' 으로 표시" % header, "미계측" in b, b)
    check("옛 기록의 mem 0 을 메모리 값처럼 찍지 않는다", "메모리 0.0MB" not in out and "메모리 0MB" not in out)

    if fails:
        print("\n트리아지 실패 %d건" % len(fails))
        return 1
    print("\n트리아지 OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
