#!/usr/bin/env python3
"""플레이 기록(텔레메트리) 분석 — 사람 데이터를 오토플레이 측정과 같은 표로 본다.

왜 이 도구가 따로 있나
----------------------
지금까지 밸런스 판단의 근거는 전부 오토플레이(`tools/sim_balance.py`)였고, 모든 결론에
"AI 기준"이라는 단서가 붙어 있다. AI 는 보스 접촉 회피에 특히 서툴다 — 사람은 그걸 학습으로
해결한다. 그래서 스키마를 일부러 같게 맞췄다. **두 출처를 나란히 놓고 어긋나는 지점이
곧 "AI 가 틀린 곳"이다.**

기록 얻는 법
------------
개발 빌드 일시정지 > CHEATS > COPY TELEMETRY 로 클립보드에 복사한 뒤 파일로 저장하거나,
데스크톱이면 `user://telemetry.jsonl` 을 그대로 넘긴다(경로는 OS 별 Godot user 디렉터리).

사용법
------
    python3 tools/analyze_telemetry.py telemetry.jsonl
    python3 tools/analyze_telemetry.py telemetry.jsonl --compare sim.csv
"""
import argparse
import collections
import json
import statistics as st
import sys


def load(path):
    rows = []
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                print("경고: 파싱 실패한 줄을 건너뛴다", file=sys.stderr)
    return rows


def histogram(vals, width=40, bucket=2.0):
    """생존 시간 분포 — 어디서 죽는지가 이 데이터의 핵심이라 눈으로 보이게 찍는다."""
    if not vals:
        return
    buckets = collections.Counter(int(v // bucket) for v in vals)
    top = max(buckets.values())
    for b in range(0, max(buckets) + 1):
        n = buckets.get(b, 0)
        bar = "#" * int(round(width * n / top)) if top else ""
        print("  %4.0f~%4.0f분 | %-*s %d" % (b * bucket, (b + 1) * bucket, width, bar, n))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path", help="telemetry.jsonl")
    ap.add_argument("--compare", help="sim_balance --csv 산출물과 나란히 비교")
    ap.add_argument("--include-cheated", action="store_true",
                    help="치트를 쓴 판도 포함(기본은 제외 — 사람 데이터가 아니다)")
    a = ap.parse_args()

    rows = load(a.path)
    if not rows:
        sys.exit("기록이 없다.")
    # 치트가 발동한 판은 사람 플레이가 아니다 — 섞으면 이 데이터의 존재 이유가 사라진다.
    cheated = [r for r in rows if r.get("cheated")]
    if cheated and not a.include_cheated:
        rows = [r for r in rows if not r.get("cheated")]
        print("치트를 쓴 %d판을 제외했다 (--include-cheated 로 포함)\n" % len(cheated))
    if not rows:
        sys.exit("치트를 제외하니 남는 기록이 없다.")
    died = [r for r in rows if r.get("outcome") == "died"]
    quit_ = [r for r in rows if r.get("outcome") == "abandoned"]
    surv = sorted(r["survived_s"] / 60.0 for r in rows)

    print("플레이 기록 %d판 (사망 %d · 중도 이탈 %d)\n" % (len(rows), len(died), len(quit_)))
    print("생존 시간 분포")
    histogram(surv)
    print("\n  중앙값 %.1f분 · 범위 %.1f~%.1f분" % (st.median(surv), surv[0], surv[-1]))

    fights = [f for r in rows for f in r.get("boss_fight_s", [])]
    bk = sum(r.get("boss_kills", 0) for r in rows)
    bs = sum(r.get("boss_spawns", 0) for r in rows)
    print("  보스 조우 %d · 처치 %d%s" % (bs, bk,
          (" · 전투 중앙 %.0f초" % st.median(fights)) if fights else ""))
    print("  레벨 중앙 %.0f · 처치 중앙 %.0f"
          % (st.median(r["level"] for r in rows), st.median(r["kills"] for r in rows)))
    cleared = sum(1 for r in rows if r.get("cleared"))
    print("  30분 클리어 %d/%d" % (cleared, len(rows)))

    # 중도 이탈은 "어렵다"와 다른 신호다 — 지루함·세션 길이 문제일 수 있어 따로 본다.
    if quit_:
        qs = sorted(r["survived_s"] / 60.0 for r in quit_)
        print("\n중도 이탈 %d판 — 중앙 %.1f분에서 그만둔다" % (len(qs), st.median(qs)))

    by_char = collections.defaultdict(list)
    for r in rows:
        by_char[r.get("character", "?")].append(r["survived_s"] / 60.0)
    if len(by_char) > 1:
        print("\n캐릭터별")
        for c, v in sorted(by_char.items(), key=lambda kv: -st.median(kv[1])):
            print("  %-10s n=%-3d 중앙 %.1f분" % (c, len(v), st.median(v)))

    if a.compare:
        import csv
        sim = list(csv.DictReader(open(a.compare)))
        if sim:
            ss = sorted(float(r["survived_s"]) / 60.0 for r in sim)
            print("\n사람 vs 오토플레이")
            print("  사람      n=%-3d 중앙 %.1f분 · 보스처치 %d" % (len(surv), st.median(surv), bk))
            print("  오토플레이 n=%-3d 중앙 %.1f분 · 보스처치 %d"
                  % (len(ss), st.median(ss), sum(int(r["boss_kills"]) for r in sim)))
            print("  → 두 값이 크게 어긋나면 그 지점이 'AI 가 틀린 곳'이다.")


if __name__ == "__main__":
    main()
