extends SceneTree
## 후반 난이도 곡선 가드 (P1-20).
##
## 왜 필요한가
## -----------
## 사람 실측에서 분당 처치가 초반 110 → 20분대 490 → 35분대 **760** 으로 7배가 됐다.
## 빌드 파워가 적 체력 곡선을 앞질러 **좀비가 녹고**(지루함), 녹이느라 쏟아내는 탄이
## 곧 프레임을 먹는다(`BALANCE.md` §3-10/§3-11). 두 증상이 한 뿌리다.
##
## 그래서 원칙을 하나 정했다:
##
##   **유입 압력(초당 스폰 × 체력 배수)은 유지하되, 초당 스폰을 낮추고 개체당 체력을 올린다.**
##
## 왜 "동시 상한"이 아니라 "초당 스폰"인가 — 사람의 후반은 **DPS 제한이 아니라 스폰 제한**이다.
## 동시 좀비가 22~45마리인데 상한은 320이라 나오는 족족 죽는다. 그래서 분당 처치도, 처치마다
## 터지는 젬·이펙트도 전부 **스포너의 출력**이 정한다. 동시 상한을 낮추면 0분부터 선형으로
## 깎여 초반 성장만 눌린다(실측에서 레벨 28→23).
##
## 이 파일은 그 원칙이 데이터에서 깨지지 않는지 본다. `difficulty.tres` 의 어느 값을 만져도
## 아래 넷 중 하나가 깨지면 CI 에서 걸린다.
##
##   godot --headless --path . --script res://tools/verify_late_hp.gd
##
## ⚠️ 임계값은 **현재 값 바로 바깥**에 놓은 것이지 최적값의 증명이 아니다.
## 의도를 바꾸려면 상수를 고치기 전에 이 주석부터 다시 쓸 것.

## 중반은 건드리지 않는다 — 사람이 지루하다고 말한 구간은 20분 이후다.
## 이 시각 이전에 후반 가속이 시작되면 중반이 조용히 어려워진다.
const LATE_START_MIN_S := 900.0
## 그 시점(15분) 체력 배수 상한. 넘으면 중반 난이도가 올라간 것이다.
const MID_HP_MAX := 14.0
## 클리어 포맷의 기준점(26분) 체력 배수 하한. 밑돌면 후반이 다시 물러진다.
const LATE_HP_MIN := 45.0
## 26분 시점 **초당 스폰** 상한. 개체 유입이 곧 프레임 비용이자 처치 수다(P1-18/P1-19).
const LATE_SPAWN_PER_S_MAX := 7.0
## 같은 시점 **유입 압력** 상한 = 초당 스폰 × 체력 배수.
## 체력을 올리면서 스폰까지 그대로 두면 압력이 폭증한다 — 그 조합을 막는다.
const LATE_PRESSURE_MAX := 360.0

const MID_MIN := 15.0
const LATE_MIN := 26.0

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   %s" % label)
	else:
		_fail += 1
		print("  FAIL %s%s" % [label, ("  — " + detail) if detail != "" else ""])


## `ZombieSpawner._hp_mult()` 와 같은 식(위협 등급 배수는 뺀 순수 시간 곡선).
func _hp_mult(d, mins: float) -> float:
	var m: float = 1.0 + mins * d.hp_per_min + mins * mins * d.hp_accel_per_min2
	var el := mins * 60.0
	if el > d.late_hp_start_s:
		m += ((el - d.late_hp_start_s) / 60.0) * d.late_hp_per_min
	if el > d.clear_seconds:
		m += ((el - d.clear_seconds) / 60.0) * d.overtime_hp_per_min
	return m


## `ZombieSpawner._max_z()` 와 같은 식.
func _max_z(d, mins: float) -> float:
	var t: float = clampf(mins * 60.0 / d.max_z_full_at, 0.0, 1.0)
	return lerpf(float(d.max_z_base), float(d.max_z_cap), t)


## `ZombieSpawner._spawn_interval()` 과 같은 식 → 초당 스폰 수.
func _spawn_per_s(d, mins: float) -> float:
	var t: float = clampf(mins * 60.0 / d.spawn_interval_full_at, 0.0, 1.0)
	var iv: float = lerpf(d.spawn_interval_base, d.spawn_interval_min, t)
	var el := mins * 60.0
	if el > d.late_hp_start_s:
		iv *= 1.0 + ((el - d.late_hp_start_s) / 60.0) * d.late_spawn_slow_per_min
	return 1.0 / maxf(iv, 0.0001)


func _init() -> void:
	await process_frame
	var d = root.get_node("GameData").difficulty

	var mid := _hp_mult(d, MID_MIN)
	var late := _hp_mult(d, LATE_MIN)
	var late_spawn := _spawn_per_s(d, LATE_MIN)
	var pressure := late * late_spawn

	print("난이도 곡선 — 체력 배수 · 초당 스폰 · 유입 압력 · 동시 상한")
	for m in [5.0, 10.0, 15.0, 20.0, 26.0, 30.0, 35.0]:
		var h := _hp_mult(d, m)
		var sp := _spawn_per_s(d, m)
		print("  %4.0f분  체력 x%6.1f   스폰 %5.2f/s   유입 %6.0f EHP/s   동시상한 %4.0f"
			% [m, h, sp, h * sp, _max_z(d, m)])
	print("")

	_check("후반 가속 시작이 %.0f분 이후 — 중반은 건드리지 않는다" % (LATE_START_MIN_S / 60.0),
		float(d.late_hp_start_s) >= LATE_START_MIN_S,
		"실제 %.0f분" % (float(d.late_hp_start_s) / 60.0))
	_check("%.0f분 체력 배수 %.1f 이하 (중반 난이도 유지)" % [MID_MIN, MID_HP_MAX],
		mid <= MID_HP_MAX, "실제 x%.1f" % mid)
	_check("%.0f분 체력 배수 %.0f 이상 (후반이 다시 물러지지 않는다)" % [LATE_MIN, LATE_HP_MIN],
		late >= LATE_HP_MIN, "실제 x%.1f" % late)
	_check("%.0f분 초당 스폰 %.1f 이하 (개체 유입이 곧 프레임 비용이자 처치 수다)"
		% [LATE_MIN, LATE_SPAWN_PER_S_MAX],
		late_spawn <= LATE_SPAWN_PER_S_MAX, "실제 %.2f/s" % late_spawn)
	_check("%.0f분 유입 압력 %.0f EHP/s 이하 (체력만 올려 압력을 폭증시키지 않는다)"
		% [LATE_MIN, LATE_PRESSURE_MAX],
		pressure <= LATE_PRESSURE_MAX, "실제 %.0f EHP/s" % pressure)

	if _fail == 0:
		print("\n후반 난이도 곡선 OK")
		quit(0)
	else:
		print("\n실패 %d건" % _fail)
		quit(1)
