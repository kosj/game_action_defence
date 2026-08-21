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

# ── 프리즈 트리아지 임계 (P0-10) ─────────────────────────────────────────
# 60fps 대상 게임이다. 예전 임계는 `frame_ms_max > 100` 하나뿐이라 **fps 30 · 프레임 80ms
# 인 판을 "지표 정상"으로 분류했고**, 그 판정 위에서 P0-5 를 "성능 붕괴 아님"으로 좁혔다.
# 사람이 화면을 보고 "엄청 떨어진다"고 말한 판이 도구에서는 정상이었던 것이다.
FPS_DEGRADED = 45          # 이 아래는 이미 체감되는 저하
FPS_COLLAPSE = 30          # 목표의 절반. **이하**를 붕괴로 본다(fps 30 을 정상으로 넘기지 않는다)
FRAME_MS_DEGRADED = 33.0   # 2프레임 분량(60fps 기준)
FRAME_MS_COLLAPSE = 100.0  # 6프레임 분량 — 눈에 띄는 멈칫


## 누수 계수기 한 줄. 옛 기록(P0-10 이전)은 `mem` 이 웹에서 항상 0 이었으므로 **값처럼
## 보여 주면 안 된다** — "누수 없음"으로 오독된다. 명시적으로 미계측이라고 적는다.
def _leak_line(d):
    if "objects" not in d:
        return ("누수 계수기 미계측 — 이 기록은 P0-10 이전 빌드다"
                + (" (당시 mem_mb 는 웹에서 항상 0 이라 의미가 없다)" if "mem_mb" in d else ""))
    return ("객체 %s · 리소스 %s · 고아 노드 %s · VRAM %sMB"
            % (d.get("objects"), d.get("res"), d.get("orphans"), d.get("vram")))


## 누수 추이 — 마지막 값 한 장으로는 "늘고 있었나"를 못 본다. 분당 샘플의 기울기를 본다.
## 판정하는 값은 셋이다: 고아 노드(해제 누락) · 리소스(로드한 것이 안 풀림) · VRAM(텍스처).
## 노드 수는 개체 수에 따라 판 안에서 오르내리므로 그 자체로는 누수 신호가 아니다 —
## 실제로 사람 기록에서 323~675 를 오갔지만 판을 거듭해도 기준선이 오르지 않았다.
def _leak_trend(r):
    pts = [x for x in r.get("samples", []) if "objects" in x]
    if len(pts) < 3:
        if any("mem" in x for x in r.get("samples", [])):
            print("  → 누수 추이 미계측 — 옛 빌드의 mem 은 웹에서 0 직선이다")
        return []
    first, last = pts[0], pts[-1]
    span = max(last.get("min", 0) - first.get("min", 0), 1)
    found = []
    for key, label, per_min in (("orphans", "고아 노드", 1.0),
                                ("res", "리소스", 5.0),
                                ("vram", "VRAM", 0.5)):
        a, b = first.get(key) or 0, last.get(key) or 0
        rate = (b - a) / span
        unit = "MB/분" if key == "vram" else "/분"
        print("  → %s %s → %s (%+.1f%s, %d분간)" % (label, a, b, rate, unit, span))
        if rate > per_min:
            found.append("%s 누수 의심 — 분당 %+.1f%s"
                         % (label, rate, "MB" if key == "vram" else "개"))
    if not found:
        print("  → 고아·리소스·VRAM 안정 — 누수 아님")
    return found


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
    # 손상된 기록(P0-9) — 분당 샘플이 요약 수치보다 크면 두 시점이 섞인 레코드다.
    # 판 도중 Events.reset() 이 일어난 뒤 진행 스냅샷이 덮인 경우로, 요약만 0 에 가깝다.
    # 수정 전 빌드의 기록에 남아 있으므로 여기서 걸러 낸다 — 안 거르면 생존 0분으로 집계돼
    # 중앙값을 끌어내리고, 하필 그게 클리어 판이라 상단이 통째로 사라진다.
    def _corrupt(r):
        sm = r.get("samples") or []
        if not sm:
            return False
        last = sm[-1]
        return (int(last.get("kills", 0)) > int(r.get("kills", 0))
                or int(last.get("level", 0)) > int(r.get("level", 0)))

    broken = [r for r in rows if _corrupt(r)]
    if broken:
        rows = [r for r in rows if not _corrupt(r)]
        print("손상된 기록 %d판을 제외했다 — 판 도중 리셋으로 요약이 덮인 것이다(P0-9)." % len(broken))
        for r in broken:
            sm = r["samples"][-1]
            print("  %s %s분경 · 샘플 처치 %s/레벨 %s ↔ 요약 처치 %s/레벨 %s%s"
                  % (r.get("character", "?"), sm.get("min", "?"), sm.get("kills"), sm.get("level"),
                     r.get("kills"), r.get("level"), "  ★클리어" if r.get("cleared") else ""))
        print("")
    if not rows:
        sys.exit("손상된 기록을 제외하니 남는 기록이 없다.")

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

    # 프레임 추이(P1-18) — 종료 시점 한 장으로는 "언제부터 무너졌나"를 못 본다.
    # 분당 샘플에 fps 가 실린 기록만 대상이다(그 이전 빌드는 이 줄이 안 나온다).
    curves = [r for r in rows if any("fps" in x for x in (r.get("samples") or []))]
    if curves:
        print("\n분당 프레임 추이 (fps · 최악 프레임 · 좀비)")
        for r in curves:
            pts = [x for x in r["samples"] if "fps" in x]
            # 이어하기 판의 선두 "몰아쓴" 행을 버린다(P0-11). begin_run 이 _next_sample 을
            # 60초로 고정하던 시절, 재개 직후 한 프레임에 한 줄씩 수십 줄이 쏟아졌다 —
            # 전부 재개 직전 상태(좀비 0 · 처치 고정)라 곡선이 아니다.
            dropped = 0
            while len(pts) > 1 and pts[0].get("zombies") == 0 \
                    and pts[0].get("kills") == pts[1].get("kills"):
                pts.pop(0)
                dropped += 1
            if not pts:
                continue
            print("  %s %.1f분 — 레벨 %s%s" % (r.get("character", "?"),
                                              r["survived_s"] / 60.0, r.get("level"),
                                              ("   [이어하기 몰아쓴 %d행 버림]" % dropped) if dropped else ""))
            for x in pts:
                fps = int(x.get("fps", 0))
                bar = "#" * max(0, min(30, int(fps / 2)))
                print("    %3d분 %3dfps %-30s 최악 %5.1fms · 좀비 %s"
                      % (x.get("min", 0), fps, bar, float(x.get("frame_ms", 0)),
                         x.get("zombies", "?")))

    # 후반 이속(P1-5) — 이속 합계가 낮은 판만 유독 짧게 끝나면 이속이 선택이 아니라 세금이다.
    # 추월 시점 자체는 게임 데이터에서 계산된다: tools/verify_late_speed.gd 참고.
    sp = [r for r in rows if r.get("speed_lv") is not None]
    if sp:
        by_sp = collections.defaultdict(list)
        for r in sp:
            by_sp[int(r["speed_lv"])].append(r["survived_s"] / 60.0)
        print("\n이속 투자별 (speed_lv = 운동화 + 메타 신속 + 캐릭터 보정)")
        for lv, v in sorted(by_sp.items()):
            print("  합계 %-2d n=%-3d 중앙 %.1f분 · 최장 %.1f분"
                  % (lv, len(v), st.median(v), max(v)))

    # 프리즈 진단(P0-4 · 임계 재설정 P0-10) — 중도 종료 기록의 마지막 상태가 "멈추기 직전"이다.
    #
    # ⚠️ 갈래는 **배타적이지 않다.** 성능이 무너진 상태에서 크래시가 날 수 있다. 예전 판정은
    #    `if not flags: 지표 정상` 이라 성능 항목이 하나도 안 걸리면 곧바로 "정상"으로 넘어갔고,
    #    그래서 **fps 30 · 프레임 80ms 인 판 셋을 전부 "지표 정상"으로 분류했다.** 60fps 대상
    #    게임에서 그건 정상이 아니다. 그 오분류 위에서 P0-5 를 "성능 붕괴 아님"으로 좁혔다.
    for r in [x for x in all_rows if x.get("outcome") == "abandoned" and x.get("diag")]:
        d = r["diag"]
        flags = []
        fps = d.get("fps")
        fms = d.get("frame_ms_max", 0)
        # 성능 — 저하와 붕괴를 가른다. 60fps 대상이므로 45 아래는 이미 체감되는 저하다.
        if (fps is not None and fps <= FPS_COLLAPSE) or fms > FRAME_MS_COLLAPSE:
            flags.append("성능 붕괴 — fps %s · 최악 프레임 %.0fms" % (fps, fms))
        elif (fps is not None and fps < FPS_DEGRADED) or fms > FRAME_MS_DEGRADED:
            flags.append("성능 저하 — fps %s · 최악 프레임 %.0fms" % (fps, fms))
        if d.get("paused"):
            flags.append("정지 상태 · 소유자 %s" % (d.get("pause_owners") or "없음(고아)"))
        if abs(d.get("time_scale", 1.0) - 1.0) > 0.01:
            flags.append("배속 %.3f 비정상" % d["time_scale"])
        if d.get("watchdog"):
            flags.append("워치독 %d회 발동" % len(d["watchdog"]))
        print("\n중도 종료 %.1f분 시점의 상태" % (r["survived_s"] / 60.0))
        print("  좀비 %s · 픽업 %s · 젬 %s · fps %s · 노드 %s"
              % (d.get("zombies"), d.get("pickups"), d.get("gems"), d.get("fps"),
                 d.get("nodes", "?")))
        print("  " + _leak_line(d))
        flags += _leak_trend(r)   # 추이 줄을 먼저 찍고 판정만 받아 온다
        # 아무 갈래도 안 걸렸을 때만 "그냥 끊겼다"이다. 걸린 게 있으면 그것과 **함께**
        # 크래시했을 수 있으므로 마지막 줄을 그렇게 적는다 — 배타적으로 읽히면 안 된다.
        flags.append("지표 정상 — 기록이 그냥 끊겼다(무한 루프/크래시 의심)" if not flags
                     else "위 상태에서 기록이 끊겼다 — 성능 붕괴·누수와 크래시는 배타적이지 않다")
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
