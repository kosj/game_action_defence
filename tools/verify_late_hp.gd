extends SceneTree
## 후반 난이도 곡선 가드 (P1-20).
##
## 왜 필요한가
## -----------
## 30분 런의 사람 실측에서 분당 처치가 초반 110 → 20분대 490 → 35분대 **760** 으로 7배가 됐다.
## 빌드 파워가 적 체력 곡선을 앞질러 **좀비가 녹고**(지루함), 녹이느라 쏟아내는 탄이
## 곧 프레임을 먹는다(`BALANCE.md` §3-10/§3-11). 두 증상이 한 뿌리다.
##
## 그래서 원칙을 하나 정했다:
##
##   **초반은 유지하고, 중후반에는 체력과 물량이 함께 위협적으로 느껴질 만큼 올린다.**
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

## 30분 곡선을 20분에 같은 비율로 재생한다. 기존 15분/26분 기준점도 2/3로 줄여
## 같은 진행률의 난이도와 유입 압력을 지키는지 검사한다.
const LATE_START_MIN_S := 600.0
## 그 시점(10분) 체력 배수 상한. 넘으면 중반 난이도가 올라간 것이다.
const MID_HP_MAX := 14.0
## 기존 26분과 같은 진행률(17분 20초)의 체력 배수 하한. 밑돌면 후반이 다시 물러진다.
const LATE_HP_MIN := 45.0
## 같은 진행률의 **초당 스폰** 범위. 하한은 후반 화면이 비는 회귀를, 상한은 성능 폭주를 막는다.
const LATE_SPAWN_PER_S_MIN := 7.5
const LATE_SPAWN_PER_S_MAX := 8.0
## 같은 시점 **유입 압력** 상한 = 초당 스폰 × 체력 배수.
## 체력을 올리면서 스폰까지 그대로 두면 압력이 폭증한다 — 그 조합을 막는다.
const LATE_PRESSURE_MAX := 400.0
## 중후반 스웜은 연속 유입과 별개로 포위 압박을 만든다. 초반 수는 유지하고 16분에는 80마리 이상.
const EARLY_SWARM_MIN := 8.0
const LATE_SWARM_MIN := 16.0
const LATE_SWARM_COUNT_MIN := 80

const MID_MIN := 10.0
const LATE_MIN := 26.0 * 2.0 / 3.0

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


## `ZombieSpawner._swarm_count()` 와 같은 식.
func _swarm_count(b, mins: float) -> int:
	var el := mins * 60.0
	var count: int = b.swarm_base_count + int(el / 120.0) * b.swarm_count_per_2min
	if el > b.swarm_late_start_seconds:
		count += int((el - b.swarm_late_start_seconds) / 120.0) * b.swarm_late_count_per_2min
	return mini(count, b.swarm_count_max)


func _init() -> void:
	await process_frame
	var d = root.get_node("GameData").difficulty
	var b = root.get_node("GameData").balance

	var mid := _hp_mult(d, MID_MIN)
	var late := _hp_mult(d, LATE_MIN)
	var late_spawn := _spawn_per_s(d, LATE_MIN)
	var pressure := late * late_spawn
	var early_swarm := _swarm_count(b, EARLY_SWARM_MIN)
	var late_swarm := _swarm_count(b, LATE_SWARM_MIN)

	print("난이도 곡선 — 체력 배수 · 초당 스폰 · 유입 압력 · 동시 상한")
	for m in [5.0, 10.0, LATE_MIN, 20.0, 26.0]:
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
	_check("%.0f분 초당 스폰 %.1f 이상 (중후반 화면이 비지 않는다)"
		% [LATE_MIN, LATE_SPAWN_PER_S_MIN],
		late_spawn >= LATE_SPAWN_PER_S_MIN, "실제 %.2f/s" % late_spawn)
	_check("%.0f분 유입 압력 %.0f EHP/s 이하 (체력만 올려 압력을 폭증시키지 않는다)"
		% [LATE_MIN, LATE_PRESSURE_MAX],
		pressure <= LATE_PRESSURE_MAX, "실제 %.0f EHP/s" % pressure)
	_check("%.0f분 스웜은 기존 초반 곡선 유지" % EARLY_SWARM_MIN,
		early_swarm == b.swarm_base_count + int(EARLY_SWARM_MIN / 2.0) * b.swarm_count_per_2min,
		"실제 %d마리" % early_swarm)
	_check("%.0f분 스웜 %d마리 이상 (포위 위협 유지)" % [LATE_SWARM_MIN, LATE_SWARM_COUNT_MIN],
		late_swarm >= LATE_SWARM_COUNT_MIN, "실제 %d마리" % late_swarm)

	if _fail == 0:
		print("\n후반 난이도 곡선 OK")
		quit(0)
	else:
		print("\n실패 %d건" % _fail)
		quit(1)
