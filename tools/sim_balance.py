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
    python3 tools/sim_balance.py --runs 10 --threat 5        # 위협 등급 5의 곡선(P1-12)
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

# 교전 이탈(도주 루프) 판별 — 오토플레이가 무리에게서 계속 도망치면 총구가 무리 반대쪽을
# 향해(사이드뷰 자동사격) 죽지도 죽이지도 않는 판이 된다. 사람의 플레이가 아니므로
# 중앙값에 섞으면 측정이 통째로 왜곡된다 — 분리해서 보고한다.
# 정상 교전 판은 분당 110~155 처치, 도주 판은 2~20 이라 경계가 뚜렷하다.
#
# 초반 구간은 스폰이 적어 분당 처치가 원래 낮다 — 일찍 죽은 판에 이 규칙을 적용하면
# 도주로 오분류된다(실제로 그렇게 새어 판정이 뒤집힌 적이 있다). 그래서 하한 시간을 둔다.
KILLS_PER_MIN_FLOOR = 40.0
ENGAGE_MIN_MINUTES = 4.0

# 판정 기준 — BALANCE.md §2 "층 2 — 오토플레이 게이트" 와 같은 값이어야 한다.
# 바꿀 땐 둘 다 바꾼다.
#
# ⛔ **생존 시간은 게이트가 아니다.** 손잡이 넷(체력 곡선·밀도·유입·이속)을 하나씩 바꿔 재 보니
#    생존 중앙값이 전부 하네스 자체의 흔들림(같은 조건 재측정에서 8.6분 vs 9.9분) 안에서만
#    움직였다(BALANCE.md §3-14). 조율할 수 없는 값을 목표로 걸면 무엇을 해도 "미달"만 나온다 —
#    실제로 이전 판이 그렇게 죽어 있었다. 생존 시간은 **참고로만 출력**한다.
TARGETS = {
    "first_hit_s":  (90.0, None),    # 첫 피격 중앙(초) — 하한만. 초반은 AI/사람 차이가 가장 작다
    "kills_at_6min": (660, 820),     # 6분 누적 처치 — 손잡이를 바꿔도 732~750 이던 값
    "maxed_rate":   (40.0, None),    # 무기 만렙(Lv8) 도달률 **%** (greedy 전용) — 진화의 전제 조건
}
## 무기 만렙 = 진화 조건. 카탈로그의 베이스 무기 max_level 과 같아야 한다.
WEAPON_MAX_LEVEL = 8
## 이 지표를 재는 시각(분) — 분당 스냅샷에서 뽑는다.
KILLS_SAMPLE_MIN = 6
## 페르소나 화력 비교에 필요한 최소 보스 조우 판수. 보스(10분)에 닿는 판이 적어 표본이
## 쉽게 1~2개가 되는데, 그 수로 부등호를 말하면 노이즈를 회귀로 읽는다.
BOSS_SAMPLE_MIN = 3


def run_one(godot, seed, character, theme, maxmin, persona="random", threat=1, diff="", bal=""):
    """한 판 실행 → 결과 dict. 판마다 user:// 를 격리해 진행 상태가 새지 않게 한다."""
    env = dict(os.environ)
    tmp_home = tempfile.mkdtemp(prefix="simbal_")
    env["HOME"] = tmp_home                      # Godot 의 user:// 뿌리를 옮긴다
    cmd = [godot, "--headless", "--path", ROOT, "--fixed-fps", "60",
           "--script", "res://tools/sim_balance.gd", "--",
           "seed=%d" % seed, "character=%s" % character, "persona=%s" % persona,
           "theme=%s" % theme, "maxmin=%g" % maxmin, "threat=%d" % threat]
    if diff:
        cmd.append("diff=%s" % diff)
    if bal:
        cmd.append("bal=%s" % bal)
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
    """교전한 판인가 — 분당 처치 수로 오토플레이의 도주 루프를 걸러낸다.
    일찍 죽은 판은 스폰이 적은 구간만 살았으므로 이 규칙의 대상이 아니다(그대로 집계한다)."""
    mins = max(r["survived_s"] / 60.0, 0.1)
    if mins < ENGAGE_MIN_MINUTES:
        return True
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
    # 6분 시점 누적 처치 — 죽은 시각과 무관한 **같은 시각 비교**라 손잡이 변화가 여기 나타난다.
    k6 = [sm["kills"] for r in ok for sm in r.get("samples", [])
          if sm["min"] == KILLS_SAMPLE_MIN]
    # 무기 만렙 도달률 — 진화 조건(베이스 만렙 + 짝꿍 패시브 1)의 앞쪽 절반.
    maxed = sum(1 for r in ok
                if max(list(r["weapons"].values()) + [0]) >= WEAPON_MAX_LEVEL)
    # 보스 조우 시점의 화력 — 보스 잔여 체력. 같은 시각(10:00)에 재므로 페르소나 비교에 쓴다.
    bhp = [r["boss_hp_left_pct"] for r in ok if r.get("boss_hp_left_pct", -1) >= 0]
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
        "kills_at_6min": st.median(k6) if k6 else None,
        "maxed": maxed,
        "maxed_rate": maxed / float(len(ok)),
        "boss_hp_left": st.median(bhp) if bhp else None,
        "boss_n": len(bhp),
    }
    print("  %-10s n=%-3d 생존 중앙값 %5.1f분 (범위 %.1f~%.1f) · 레벨 %.0f · 처치 %.0f · "
          "보스처치 %.0f · 클리어 %d/%d"
          % (label, s["n"], s["median_min"], s["min_min"], s["max_min"],
             s["level"], s["kills"], s["boss_kills"], cleared, len(ok)))
    print("             6분 처치 %s · 무기 만렙 %d/%d · 보스 잔여 체력 %s"
          % ("%.0f" % s["kills_at_6min"] if s["kills_at_6min"] is not None else "—",
             s["maxed"], len(ok),
             "%.0f%%" % s["boss_hp_left"] if s["boss_hp_left"] is not None else "—"))
    if fled:
        print("             교전 이탈 %d판 제외 (오토플레이가 도망만 친 판 — 사람 플레이가 아니다)"
              % len(fled))
    if bad:
        print("             ⚠️ 실패 %d판: %s" % (len(bad), bad[0].get("error")))
    return s


def _band(label, v, key, fmt="%.0f", unit=""):
    """게이트 한 줄 — 목표 구간과 대조한다. 상한이 None 이면 하한만 본다."""
    if v is None:
        print("  [--  ] %s — 표본 없음" % label)
        return
    lo, hi = TARGETS[key]
    ok = (v >= lo) and (hi is None or v <= hi)
    mark = "OK  " if ok else ("낮음" if v < lo else "높음")
    tgt = ("%s%s 이상" % (fmt % lo, unit)) if hi is None \
        else ("%s~%s%s" % (fmt % lo, fmt % hi, unit))
    print("  [%s] %s %s%s  (목표 %s)" % (mark, label, fmt % v, unit, tgt))


def verdict(s, personas=None):
    """판정 — BALANCE.md §2 층 2 게이트와 대조해 사람이 읽을 결론을 낸다.

    ⛔ 생존 시간은 판정하지 않는다(§3-14). 손잡이를 바꿔도 하네스의 흔들림 안에서만
       움직이는 값이라, 목표로 걸면 무엇을 해도 "미달"만 출력된다."""
    if s is None:
        return
    print("\n판정 — BALANCE.md §2 층 2 게이트")
    _band("첫 피격 중앙", s["first_hit_s"], "first_hit_s", unit="초")
    _band("6분 누적 처치", s["kills_at_6min"], "kills_at_6min")
    # 만렙 도달률은 **greedy 전용**이다 — random 은 애초에 집중하지 않으므로
    # 이 게이트를 적용하면 설계대로 동작하는 상태를 회귀로 오분류한다.
    # personas 를 안 받았을 때는 라벨("veteran/greedy")로 판별한다.
    pn = personas if personas else ("greedy" if "greedy" in s["label"] else "random")
    if pn == "greedy":
        _band("무기 만렙 도달률", 100.0 * s["maxed_rate"], "maxed_rate", unit="%")
    else:
        print("  [--  ] 무기 만렙 도달률 %.0f%% — random 은 판정 대상이 아니다(greedy 전용 게이트)"
              % (100.0 * s["maxed_rate"]))
    print("  (참고 · 판정 안 함) 생존 중앙값 %.1f분 · 보스전 %s · 클리어 %d판"
          % (s["median_min"],
             "%.1f초" % s["boss_fight_s"] if s["boss_fight_s"] is not None else "도달 없음",
             s["cleared"]))
    print("  ↳ 생존 시간을 게이트로 쓰지 않는 이유는 BALANCE.md §3-14 를 볼 것.")


def cross_persona_verdict(summaries):
    """층 2 의 마지막 게이트 — **greedy 화력 ≥ random**.

    값이 아니라 부등호다. 상한 근사(greedy)가 하한선(random)보다 약해지면
    "빌드를 짜면 강해진다"는 이 게임의 전제가 깨진 것이므로 절대값과 무관하게 회귀다
    (2026-09-08 에 실제로 뒤집혀 있었다 — BALANCE.md §3-14 ③)."""
    by = {}
    for s in summaries:
        if s is None:
            continue
        for pn in ("greedy", "random"):
            if s["label"].endswith(pn) or s["label"] == pn:
                by[pn] = s
    if len(by) < 2:
        return
    g, r = by["greedy"], by["random"]
    print("\n판정 — 집중이 보상받는가 (greedy vs random)")
    # **판정은 무기 만렙 도달률로 한다.** 이 게이트가 묻는 것은 "집중이 보상받는가"이고,
    # 만렙 도달은 그것을 직접 재는 값이다(진화 조건의 앞쪽 절반이기도 하다).
    ok = g["maxed_rate"] >= r["maxed_rate"]
    print("  [%s] 무기 만렙 도달률 greedy %.0f%% vs random %.0f%%"
          % ("OK  " if ok else "역전", 100 * g["maxed_rate"], 100 * r["maxed_rate"]))
    # 보스 잔여 체력은 **참고**다. 사망 시점에 재는 값이라 "보스전 몇 초째에 죽었나"가 섞여
    # 들어가고, 보스에 닿는 판 자체가 적어 표본이 쉽게 한 자리다 — 몇 pp 차이는 노이즈다.
    if g["boss_n"] >= BOSS_SAMPLE_MIN and r["boss_n"] >= BOSS_SAMPLE_MIN:
        print("  (참고) 보스 잔여 체력 greedy %.0f%%(n=%d) vs random %.0f%%(n=%d) — "
              "낮을수록 화력이 높지만 표본이 작아 몇 pp 는 읽지 않는다"
              % (g["boss_hp_left"], g["boss_n"], r["boss_hp_left"], r["boss_n"]))
    else:
        print("  (참고) 보스 조우 표본 부족 (greedy %d · random %d · 최소 %d)"
              % (g["boss_n"], r["boss_n"], BOSS_SAMPLE_MIN))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=10)
    ap.add_argument("--character", default="veteran")
    ap.add_argument("--theme", default="suburb")
    ap.add_argument("--maxmin", type=float, default=30.0)
    ap.add_argument("--seed-start", type=int, default=1000)
    ap.add_argument("--persona", default="random", choices=["random", "greedy"],
                    help="random=하한선(무작위 카드) · greedy=상한 근사(진화 지향)")
    ap.add_argument("--both-personas", action="store_true",
                    help="random 과 greedy 를 같은 시드로 비교")
    ap.add_argument("--all-characters", action="store_true",
                    help="veteran/hunter/engineer 를 같은 시드 집합으로 비교")
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument("--csv", help="판별 원자료를 CSV 로 저장")
    ap.add_argument("--threat", type=int, default=1,
                    help="위협 등급(P1-12). 1=기존 밸런스와 동일한 기준선")
    ap.add_argument("--diff", default="",
                    help="난이도 손잡이 임시 덮어쓰기 — 'hp_accel_per_min2:0.028,max_z_cap:260'. "
                         "data/difficulty.tres 를 고치지 않고 실험을 병렬로 돌리기 위한 것이다. "
                         "채택하면 tools/gen_difficulty_data.gd 쪽 기본값에 반영할 것(CLAUDE.md §2)")
    ap.add_argument("--bal", default="",
                    help="밸런스 표 임시 덮어쓰기 — 'levelup_focus_weight:0'. --diff 와 같은 목적이다")
    ap.add_argument("--jsonl", help="판별 SIMRESULT 원본(JSON 한 줄씩)을 저장 — 분당 샘플이 여기 있다")
    a = ap.parse_args()

    godot = os.environ.get("GODOT", "godot")
    if shutil.which(godot) is None and not os.path.isfile(godot):
        sys.exit("godot 실행 파일을 찾을 수 없다. GODOT 환경변수로 경로를 지정하라.")

    chars = ["veteran", "hunter", "engineer"] if a.all_characters else [a.character]
    personas = ["random", "greedy"] if a.both_personas else [a.persona]
    seeds = [a.seed_start + i for i in range(a.runs)]
    print("밸런스 측정 — %d판 × %s × %s · 테마 %s · 위협 등급 %d · 최대 %g분 · 병렬 %d"
          % (a.runs, "/".join(chars), "/".join(personas), a.theme, a.threat, a.maxmin, a.jobs))
    if a.diff:
        print("난이도 덮어쓰기: %s" % a.diff)
    if a.bal:
        print("밸런스 덮어쓰기: %s" % a.bal)
    print("(random=하한선 · greedy=상한 근사. 자세한 해석은 BALANCE.md)\n")

    all_rows, summaries = [], []
    keys = [(c, pn) for c in chars for pn in personas]
    with cf.ThreadPoolExecutor(max_workers=a.jobs) as ex:
        futs = {ex.submit(run_one, godot, s, c, a.theme, a.maxmin, pn, a.threat, a.diff, a.bal): (c, pn)
                for (c, pn) in keys for s in seeds}
        rows_by_key = {k: [] for k in keys}
        for f in cf.as_completed(futs):
            k = futs[f]
            r = f.result()
            r["_character"] = k[0]
            rows_by_key[k].append(r)
            all_rows.append(r)
    for k in keys:
        label = k[0] if len(personas) == 1 else "%s/%s" % k
        summaries.append(summarize(rows_by_key[k], label))

    if len(keys) == 1:
        verdict(summaries[0], personas[0])
    elif len(chars) == 1 and len(personas) == 2:
        for sm in summaries:
            verdict(sm)
        cross_persona_verdict(summaries)

    if a.jsonl:
        with open(a.jsonl, "w") as fh:
            for r in all_rows:
                if "error" not in r:
                    fh.write(json.dumps(r) + "\n")
        print("\nJSONL 저장: %s" % a.jsonl)

    if a.csv:
        import csv
        with open(a.csv, "w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["character", "persona", "seed", "survived_s", "died", "cleared", "level",
                        "kills", "hits", "first_hit_s", "boss_kills", "boss_fight_s",
                        "boss_hp_left_pct", "player_hp_at_boss", "peak_zombies",
                        "hp_mult_at_end", "weapons", "passives"])
            for r in all_rows:
                if "error" in r:
                    continue
                w.writerow([r["character"], r.get("persona", "random"), r["seed"],
                            r["survived_s"], r["died"],
                            r["cleared"], r["level"], r["kills"], r["hits"],
                            r["first_hit_s"], r["boss_kills"],
                            " ".join("%.1f" % f for f in r.get("boss_fight_s", [])),
                            r.get("boss_hp_left_pct", -1), r.get("player_hp_at_boss", -1),
                            r["peak_zombies"],
                            r["hp_mult_at_end"],
                            " ".join("%s:%d" % kv for kv in sorted(r["weapons"].items())),
                            " ".join("%s:%d" % kv for kv in sorted(r["passives"].items()))])
        print("\nCSV 저장: %s" % a.csv)


if __name__ == "__main__":
    main()
