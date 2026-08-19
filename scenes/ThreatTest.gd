extends Node
## 위협 등급(Threat Rank) 회귀 테스트 — HANDOFF P1-12.
##
## 실행:
##   godot --headless --path . res://scenes/ThreatTest.tscn
## 마지막 줄의 "RESULT ok=<통과>/<전체>" 가 전부 통과가 아니면 회귀다.
##
## 검사 항목
##   T1 등급 1은 항등원이다 — 이게 깨지면 지금까지의 실측이 전부 기준선이 아니게 된다
##   T2 등급이 오를수록 압박이 단조 증가한다(수용 기준 ②의 데이터 층)
##   T3 잠긴 등급은 고를 수 없다
##   T4 보스를 잡아야 다음 등급이 열린다(사망만으로는 안 열린다)
##   T5 낮은 등급으로 돌아가 잡아도 사다리는 오르지 않는다
##   T6 등급별 최고 기록이 남고 재시작 후에도 유지된다
##   T7 Events 의 배수에 등급이 실제로 반영된다(적용 경로가 붙어 있는가)
##   T8 시작 체력 감소가 1 밑으로 내려가지 않는다

var _ok: int = 0
var _total: int = 0


func _ready() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		_ok += 1
	print("%s %s" % ["PASS" if cond else "FAIL", name])


## 판 한 번을 흉내낸다 — 보스 처치 수와 생존 시간만 있으면 해금/기록 판정이 돈다.
func _play(boss_kills: int, seconds: float) -> void:
	ThreatManager.begin_run()
	for i in range(boss_kills):
		Events.boss_died.emit()
	Events.elapsed_time = seconds
	Events.player_died.emit()


func _run() -> void:
	ThreatManager.reset_all()

	# --- T1: 등급 1 = 항등원 ---
	var r1 := ThreatManager.data(1)
	_check("T1 등급 1 체력 배수 1.0", is_equal_approx(r1.enemy_hp_mult, 1.0))
	_check("T1 등급 1 이속 배수 1.0", is_equal_approx(r1.enemy_speed_mult, 1.0))
	_check("T1 등급 1 보스 체력 배수 1.0", is_equal_approx(r1.boss_hp_mult, 1.0))
	_check("T1 등급 1 상자/엘리트 주기 1.0",
		is_equal_approx(r1.chest_interval_mult, 1.0) and is_equal_approx(r1.elite_interval_mult, 1.0))
	_check("T1 등급 1 증감 0",
		r1.boss_heal_charges_add == 0 and r1.start_health_add == 0)

	# --- T2: 단조성 ---
	var mono := true
	var n := ThreatManager.count()
	for i in range(2, n + 1):
		var a := ThreatManager.data(i - 1)
		var b := ThreatManager.data(i)
		if b.enemy_hp_mult < a.enemy_hp_mult or b.enemy_speed_mult < a.enemy_speed_mult \
				or b.boss_hp_mult < a.boss_hp_mult or b.chest_interval_mult < a.chest_interval_mult \
				or b.elite_interval_mult > a.elite_interval_mult \
				or b.boss_heal_charges_add < a.boss_heal_charges_add \
				or b.start_health_add > a.start_health_add:
			mono = false
	_check("T2 등급이 오를수록 압박이 단조 증가", mono)
	_check("T2 마지막 등급은 등급 1보다 확실히 어렵다",
		ThreatManager.data(n).enemy_hp_mult > 1.0 and ThreatManager.data(n).start_health_add < 0)
	_check("T2 등급 수 = 20", n == 20)

	# --- T3: 잠금 ---
	_check("T3 잠긴 등급은 선택 실패", not ThreatManager.select(2))
	_check("T3 선택은 등급 1 그대로", ThreatManager.selected_rank() == 1)
	_check("T3 범위 밖도 선택 실패", not ThreatManager.select(0) and not ThreatManager.select(999))

	# --- T4: 해금 조건 ---
	_play(0, 300.0)
	_check("T4 보스를 못 잡으면 안 열린다", ThreatManager.max_rank() == 1)
	_play(1, 620.0)
	_check("T4 보스를 잡으면 다음 등급이 열린다", ThreatManager.max_rank() == 2)
	_check("T4 열린 등급은 선택된다", ThreatManager.select(2))

	# --- T5: 낮은 등급으로 되돌아가 잡아도 사다리는 안 오른다 ---
	ThreatManager.select(1)
	_play(2, 700.0)
	_check("T5 낮은 등급의 보스 처치로는 안 열린다", ThreatManager.max_rank() == 2)

	# --- T6: 등급별 기록 ---
	_check("T6 등급 1 기록이 남았다", ThreatManager.best_seconds(1) >= 700.0)
	ThreatManager.select(2)
	_play(0, 400.0)
	_check("T6 등급 2 기록은 따로 쌓인다", is_equal_approx(ThreatManager.best_seconds(2), 400.0))
	_check("T6 낮은 기록은 최고를 덮지 않는다", ThreatManager.best_seconds(1) >= 700.0)
	ThreatManager._max_rank = 1
	ThreatManager._selected = 1
	ThreatManager._best = {}
	ThreatManager._load()
	_check("T6 재시작 후에도 해금 등급이 남는다", ThreatManager.max_rank() == 2)
	_check("T6 재시작 후에도 기록이 남는다", ThreatManager.best_seconds(1) >= 700.0)

	# --- T7: 적용 경로 ---
	ThreatManager._max_rank = ThreatManager.count()
	ThreatManager.select(1)
	var hp1 := Events.diff_enemy_hp_mult()
	var sp1 := Events.diff_enemy_speed_mult()
	var bhp1 := Events.diff_boss_hp_mult()
	var score1 := Events.diff_score_mult()
	ThreatManager.select(20)
	_check("T7 적 체력 배수에 반영된다", Events.diff_enemy_hp_mult() > hp1)
	_check("T7 적 이속 배수에 반영된다", Events.diff_enemy_speed_mult() > sp1)
	_check("T7 보스 체력 배수에 반영된다", Events.diff_boss_hp_mult() > bhp1)
	_check("T7 점수 배수는 등급과 무관하다(랭킹 오염 방지)",
		is_equal_approx(Events.diff_score_mult(), score1))

	# --- T8: 시작 체력 하한 ---
	var worst := ThreatManager.data(ThreatManager.count()).start_health_add
	_check("T8 시작 체력 감소가 기본 체력을 넘지 않는다", 5 + worst >= 1)

	ThreatManager.reset_all()
	print("RESULT ok=%d/%d" % [_ok, _total])
	await get_tree().process_frame
	get_tree().quit(0 if _ok == _total else 1)
