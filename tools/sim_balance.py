#!/usr/bin/env python3
"""밸런스 측정 배치 러너 — sim_balance.gd 를 N판 돌려 분포와 판정을 낸다.

왜 필요한가
-----------
밸런스는 한 판으로 말할 수 없다. 오토플레이가 레벨업 카드를 무작위로 고르기 때문에
한 판의 생존 시간은 빌드 운에 크게 흔들린다 — 분포를 봐야 한다.

사용법
------
    export GODOT=/path/to/godot            # 없으면 PATH 의 godot
    python3 tools/sim_balance.py                          # 기본 10판, 베테랑/교외
    python3 tools/sim_balance.py --runs 20 --character hunter
    python3 tools/sim_balance.py --runs 8 --all-characters --csv out.csv

판마다 프로세스를 새로 띄우고 user:// 를 비운다 — 메타 골드·과제·퀘스트가 뒤 판으로
새면 측정이 오염된다.

⚠️ 이 수치는 "운에 맡긴 빌드의 하한선"이다. 절대값을 게임 난이도로 읽지 말 것.
   판정 기준의 근거와 해석은 BALANCE.md 를 본다.
"""
import argparse
import concurrent.futures as cf
import json
import os
import re
import shutil
import statistics as st
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
USERDATA = os.path.expanduser("~/.local/share/godot/app_userdata/Zombie Buster")

# 교전 이탈(kiting) 판별 — 오토플레이 AI 가 좀비 반발에만 반응해 계속 도망치면,
# 죽지도 않고 죽이지도 않는 판이 나온다(실측: 10분간 처치 18, 좀비 175마리 누적).
# 사람의 플레이가 아니므로 중앙값에 섞으면 측정이 통째로 왜곡된다 — 분리해서 보고한다.
# 정상 교전 판은 분당 100~160 처치, 이탈 판은 2~20 이라 경계가 뚜렷하다.
KILLS_PER_MIN_FLOOR = 40.0

# 판정 기준 — BALANCE.md §판정 기준과 같은 값이어야 한다. 바꿀 땐 둘 다 바꾼다.
TARGETS = {
    "median_survive_min": (12.0, 18.0),   # 랜덤 빌드 생존 시간 중앙값(분)
    "boss_fight_s":       (20.0, 40.0),   # 보스전 소요(초)
    "first_hit_s":        (90.0, None),   # 첫 피격 시점(초) — 하한만
}


def run_one(godot, seed, character, theme, maxmin):
    """한 판 실행 → 결과 dict. 판마다 user:// 를 격리해 진행 상태가 새지 않게 한다."""
    env = dict(os.environ)
    tmp_home = tempfile.mkdtemp(prefix="simbal_")
    env["HOME"] = tmp_home                      # Godot 의 user:// 뿌리를 옮긴다
    cmd = [godot, "--headless", "--path", ROOT, "--fixed-fps", "60",
           "--script", "res://tools/sim_balance.gd", "--",
           "seed=%d" % seed, "character=%s" % character,
           "theme=%s" % theme, "maxmin=%g" % maxmin]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=1800, env=env)
        m = re.search(r"SIMRESULT (\{.*\})", p.stdout)
        if not m:
            return {"error": "SIMRESULT 없음 (exit=%d)" % p.returncode,
                    "tail": p.stdout[-400:] + p.stderr[-400:]}
        return json.loads(m.group(1))
    except subprocess.TimeoutExpired:
        return {"error": "timeout"}
    finally:
        shutil.rmtree(tmp_home, ignore_errors=True)


def is_engaged(r):
    """교전한 판인가 — 분당 처치 수로 오토플레이의 도망 루프를 걸러낸다."""
    mins = max(r["survived_s"] / 60.0, 0.1)
    return (r["kills"] / mins) >= KILLS_PER_MIN_FLOOR


def summarize(rows, label):
    done = [r for r in rows if "error" not in r]
    bad = [r for r in rows if "error" in r]
    ok = [r for r in done if is_engaged(r)]
    fled = [r for r in done if not is_engaged(r)]
    if not ok:
        print("  %-10s 전부 실패: %s" % (label, bad[0].get("error") if bad else "?"))
        return None
    surv = sorted(r["survived_s"] / 60.0 for r in ok)
    fights = [f for r in ok for f in r["boss_fight_s"]]
    hits = [r["first_hit_s"] for r in ok if r["first_hit_s"] > 0]
    cleared = sum(1 for r in ok if r["cleared"])
    s = {
        "label": label, "n": len(ok), "fail": len(bad),
        "median_min": st.median(surv), "min_min": surv[0], "max_min": surv[-1],
        "p25": surv[max(0, int(len(surv) * 0.25) - 0)] if surv else 0,
        "level": st.median(r["level"] for r in ok),
        "kills": st.median(r["kills"] for r in ok),
        "boss_kills": st.median(r["boss_kills"] for r in ok),
        "boss_fight_s": st.median(fights) if fights else None,
        "first_hit_s": st.median(hits) if hits else None,
        "cleared": cleared,
        "peak_z": max(r["peak_zombies"] for r in ok),
        "fled": len(fled),
    }
    print("  %-10s n=%-3d 생존 중앙값 %5.1f분 (범위 %.1f~%.1f) · 레벨 %.0f · 처치 %.0f · "
          "보스처치 %.0f · 클리어 %d/%d"
          % (label, s["n"], s["median_min"], s["min_min"], s["max_min"],
             s["level"], s["kills"], s["boss_kills"], cleared, len(ok)))
    if fled:
        print("             교전 이탈 %d판 제외 (오토플레이가 도망만 친 판 — 사람 플레이가 아니다)"
              % len(fled))
    if bad:
        print("             ⚠️ 실패 %d판: %s" % (len(bad), bad[0].get("error")))
    return s


def verdict(s):
    """판정 — 목표 구간과 대조해 사람이 읽을 결론을 낸다."""
    if s is None:
        return
    print("\n판정 (목표 대비)")
    lo, hi = TARGETS["median_survive_min"]
    v = s["median_min"]
    mark = "OK  " if lo <= v <= hi else ("낮음" if v < lo else "높음")
    print("  [%s] 생존 중앙값 %.1f분  (목표 %.0f~%.0f분)" % (mark, v, lo, hi))
    if s["boss_fight_s"] is not None:
        lo, hi = TARGETS["boss_fight_s"]
        v = s["boss_fight_s"]
        mark = "OK  " if lo <= v <= hi else ("짧음" if v < lo else "김  ")
        print("  [%s] 보스전 %.1f초       (목표 %.0f~%.0f초)" % (mark, v, lo, hi))
    else:
        print("  [--  ] 보스전 데이터 없음 — 보스(10분)에 도달한 판이 없다")
    if s["first_hit_s"] is not None:
        lo, _ = TARGETS["first_hit_s"]
        v = s["first_hit_s"]
        print("  [%s] 첫 피격 %.0f초      (목표 %.0f초 이후)"
              % ("OK  " if v >= lo else "이름", v, lo))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=10)
    ap.add_argument("--character", default="veteran")
    ap.add_argument("--theme", default="suburb")
    ap.add_argument("--maxmin", type=float, default=30.0)
    ap.add_argument("--seed-start", type=int, default=1000)
    ap.add_argument("--all-characters", action="store_true",
                    help="veteran/hunter/engineer 를 같은 시드 집합으로 비교")
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument("--csv", help="판별 원자료를 CSV 로 저장")
    a = ap.parse_args()

    godot = os.environ.get("GODOT", "godot")
    if shutil.which(godot) is None and not os.path.isfile(godot):
        sys.exit("godot 실행 파일을 찾을 수 없다. GODOT 환경변수로 경로를 지정하라.")

    chars = ["veteran", "hunter", "engineer"] if a.all_characters else [a.character]
    seeds = [a.seed_start + i for i in range(a.runs)]
    print("밸런스 측정 — %d판 × %s · 테마 %s · 최대 %g분 · 병렬 %d"
          % (a.runs, "/".join(chars), a.theme, a.maxmin, a.jobs))
    print("(오토플레이는 레벨업 카드를 무작위로 고른다 — 이 수치는 하한선이다)\n")

    all_rows, summaries = [], []
    with cf.ThreadPoolExecutor(max_workers=a.jobs) as ex:
        futs = {ex.submit(run_one, godot, s, c, a.theme, a.maxmin): (c, s)
                for c in chars for s in seeds}
        rows_by_char = {c: [] for c in chars}
        for f in cf.as_completed(futs):
            c, _ = futs[f]
            r = f.result()
            r["_character"] = c
            rows_by_char[c].append(r)
            all_rows.append(r)
    for c in chars:
        summaries.append(summarize(rows_by_char[c], c))

    if len(chars) == 1:
        verdict(summaries[0])

    if a.csv:
        import csv
        with open(a.csv, "w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["character", "seed", "survived_s", "died", "cleared", "level",
                        "kills", "hits", "first_hit_s", "boss_kills", "peak_zombies",
                        "hp_mult_at_end", "weapons", "passives"])
            for r in all_rows:
                if "error" in r:
                    continue
                w.writerow([r["character"], r["seed"], r["survived_s"], r["died"],
                            r["cleared"], r["level"], r["kills"], r["hits"],
                            r["first_hit_s"], r["boss_kills"], r["peak_zombies"],
                            r["hp_mult_at_end"],
                            " ".join("%s:%d" % kv for kv in sorted(r["weapons"].items())),
                            " ".join("%s:%d" % kv for kv in sorted(r["passives"].items()))])
        print("\nCSV 저장: %s" % a.csv)


if __name__ == "__main__":
    main()
