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

# scripts/Telemetry.gd 의 PARTIAL_INTERVAL 과 같은 값이어야 한다 — 중도 종료 기록은 이 주기의
# 스냅샷이라 실제 플레이 시간을 최대 이만큼 과소보고한다(사람 실측에서 확인됨).
PARTIAL_SNAPSHOT_S = 10


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
    ap.add_argument("--include-resumed", action="store_true",
                    help="이어하기로 시작한 판도 포함(기본은 제외 — 수치가 재개 이후만 세어진다)")
    a = ap.parse_args()

    rows = load(a.path)
    if not rows:
        sys.exit("기록이 없다.")
    all_rows = list(rows)   # 세션 분할 판정은 기록 순서를 봐야 한다 — 필터 전에 보관
    # 치트가 발동한 판은 사람 플레이가 아니다 — 섞으면 이 데이터의 존재 이유가 사라진다.
    cheated = [r for r in rows if r.get("cheated")]
    if cheated and not a.include_cheated:
        rows = [r for r in rows if not r.get("cheated")]
        print("치트를 쓴 %d판을 제외했다 (--include-cheated 로 포함)\n" % len(cheated))
    if not rows:
        sys.exit("치트를 제외하니 남는 기록이 없다.")
    # 이어하기 판은 elapsed_time 만 복원되고 피격·보스 수치는 재개 이후만 세어진다.
    # survived_s 만 맞고 나머지가 어긋나므로 섞으면 표가 통째로 거짓말을 한다.
    resumed = [r for r in rows if r.get("resumed")]
    if resumed and not a.include_resumed:
        rows = [r for r in rows if not r.get("resumed")]
        print("이어하기로 시작한 %d판을 제외했다 (--include-resumed 로 포함)\n" % len(resumed))
    if not rows:
        sys.exit("이어하기 판을 제외하니 남는 기록이 없다.")
    died = [r for r in rows if r.get("outcome") == "died"]
    # "left" = 메뉴로 나간 정상 종료 · "abandoned" = 탭 닫힘·크래시. 섞으면 크래시 조사가 흐려진다.
    left = [r for r in rows if r.get("outcome") == "left"]
    quit_ = [r for r in rows if r.get("outcome") == "abandoned"]
    surv = sorted(r["survived_s"] / 60.0 for r in rows)

    print("플레이 기록 %d판 (사망 %d · 정상 종료 %d · 비정상 종료 %d)\n"
          % (len(rows), len(died), len(left), len(quit_)))
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
    print("  30분 클리어 %d/%d%s" % (cleared, len(rows), "  ★" if cleared else ""))

    # 중도 종료는 "어렵다"와 다른 신호다 — 따로 본다.
    # 다만 **이어하기로 돌아온 판은 이탈이 아니라 세션 분할**이다(모바일 웹에서 정상 행동).
    # 기록은 시간순으로 쌓이므로, 중도 종료 바로 뒤에 resumed 기록이 오면 복귀로 본다.
    if quit_:
        qs = sorted(r["survived_s"] / 60.0 for r in quit_)
        returned = 0
        for i, r in enumerate(all_rows):
            if r.get("outcome") != "abandoned":
                continue
            nxt = all_rows[i + 1] if i + 1 < len(all_rows) else None
            if nxt is not None and nxt.get("resumed"):
                returned += 1
        print("\n비정상 종료(탭 닫힘·크래시) %d판 — 중앙 %.1f분 시점" % (len(qs), st.median(qs)))
        if returned:
            print("  그중 %d판은 이어하기로 복귀했다 — 이탈이 아니라 세션 분할이다" % returned)
        if returned < len(qs):
            print("  복귀가 확인되지 않은 %d판이 진짜 이탈 후보다" % (len(qs) - returned))
        print("  ※ 중도 종료 기록은 %ds 스냅샷이라 실제 플레이 시간을 최대 그만큼 과소보고한다"
              % PARTIAL_SNAPSHOT_S)

    by_char = collections.defaultdict(list)
    for r in rows:
        by_char[r.get("character", "?")].append(r["survived_s"] / 60.0)
    if len(by_char) > 1:
        print("\n캐릭터별")
        for c, v in sorted(by_char.items(), key=lambda kv: -st.median(kv[1])):
            print("  %-10s n=%-3d 중앙 %.1f분" % (c, len(v), st.median(v)))

    # 프리즈 진단(P0-4) — 중도 종료 기록의 마지막 상태가 곧 "멈추기 직전"이다.
    # 원인을 세 갈래로 가른다: 성능 붕괴 / 정지 갇힘 / 무한 루프·크래시.
    for r in [x for x in all_rows if x.get("outcome") == "abandoned" and x.get("diag")]:
        d = r["diag"]
        flags = []
        if d.get("frame_ms_max", 0) > 100:
            flags.append("프레임 %.0fms — 성능 붕괴 의심" % d["frame_ms_max"])
        if d.get("paused"):
            flags.append("정지 상태 · 소유자 %s" % (d.get("pause_owners") or "없음(고아)"))
        if abs(d.get("time_scale", 1.0) - 1.0) > 0.01:
            flags.append("배속 %.3f 비정상" % d["time_scale"])
        if d.get("watchdog"):
            flags.append("워치독 %d회 발동" % len(d["watchdog"]))
        if not flags:
            flags.append("지표 정상 — 기록이 그냥 끊겼다(무한 루프/크래시 의심)")
        print("\n중도 종료 %.1f분 시점의 상태" % (r["survived_s"] / 60.0))
        print("  좀비 %s · 픽업 %s · 젬 %s · fps %s · 메모리 %sMB · 노드 %s"
              % (d.get("zombies"), d.get("pickups"), d.get("gems"), d.get("fps"),
                 d.get("mem_mb", "?"), d.get("nodes", "?")))
        # 누수 판정 — 분당 샘플의 메모리·노드 추이를 본다. 마지막 값만으로는 알 수 없다.
        mem = [(x["min"], x["mem"], x.get("nodes")) for x in r.get("samples", []) if "mem" in x]
        if len(mem) >= 3:
            first, last = mem[0], mem[-1]
            dm = last[1] - first[1]
            dn = (last[2] or 0) - (first[2] or 0)
            print("  메모리 %.1f → %.1fMB (%+.1f) · 노드 %s → %s (%+d) · %d분간"
                  % (first[1], last[1], dm, first[2], last[2], dn, last[0] - first[0]))
            span = max(last[0] - first[0], 1)
            if dm / span > 1.0:
                print("  → 분당 %.1fMB 증가 — **누수 의심**" % (dm / span))
            elif dn / span > 50:
                print("  → 분당 노드 %+d — 씬 트리 누수 의심" % (dn / span))
            else:
                print("  → 메모리·노드 안정 — 누수 아님")
        for f in flags:
            print("  → %s" % f)
        for w in (d.get("watchdog") or [])[:5]:
            print("     워치독: %s" % w)

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
