@tool
extends SceneTree

## 보스 자가 회복 스킬 검증 — 헤드리스로 보스를 세워 두고 실제 프레임을 돌리며
## 시전 조건 · 회복량 · 저지(인터럽트) · 횟수 상한을 확인한다. 게임 화면 없이 검증할 수 있는
## 유일한 수단이라 시나리오를 코드로 재생한다.
##
##   godot --headless --fixed-fps 60 --script res://tools/verify_boss_heal.gd
##
## 1부: 근접형으로 시전→완주→쿨타임→저지→횟수 소진까지 상세 검증.
## 2부: 나머지 아키타입 일괄 확인 — 각자의 예비 동작(사격/소환/돌진)에 막혀 회복이
##      영영 발동하지 못하는 교착이 없는지 본다(_can_start_heal 게이트 회귀 방지).
##
## 종료 코드 0 = 전부 통과, >0 = 실패 건수.

const DT := 1.0 / 60.0
const MAX_HP := 1000
const PART1_T := 46.0        # 1부 길이(초)
const SWEEP_T := 12.0        # 2부 아키타입당 관찰 시간(초)
const SWEEP := ["gunner", "summoner", "bomber", "berserk"]

var _boss: Node2D = null
var _t: float = 0.0
var _fail: int = 0
var _done: Dictionary = {}   # 1회성 스텝 실행 표시
var _channeling: bool = false
var _channel_pos: Vector2 = Vector2.ZERO
var _channel_start: float = 0.0
var _starts: Array[float] = []   # 현재 보스가 시전을 시작한 시각들
var _bal: Resource = null        # BalanceData — 아래 주석대로 오토로드는 실행 시점에 찾는다
var _part: int = 1
var _sweep_i: int = -1
var _sweep_t: float = 0.0


func _process(_delta: float) -> bool:
	if _bal == null:
		_setup()
		return false
	_t += DT
	_watch_channel()
	if _part == 1:
		_step()
		if _t >= PART1_T:
			_end_part1()
		return false
	return _sweep(DT)


## 오토로드/장면 준비. --script 로 띄운 메인 루프는 오토로드가 등록되기 *전에* 컴파일되므로
## Events/GameData 를 식별자로 쓸 수 없다(컴파일 에러). 노드는 실행 시점엔 있으니 트리에서 찾는다.
func _setup() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	# 근접 강타 사거리(300) 밖에 세워 둔다 — 보스가 다른 스킬에 정신 팔리지 않게(이속도 0).
	var player := CharacterBody2D.new()
	player.add_to_group("player")
	player.global_position = Vector2(2000, 0)
	scene.add_child(player)
	root.get_node("Events").trait_damage_mult = 1.0
	_bal = root.get_node("GameData").balance
	print("─ 보스 자가 회복 검증 ─ HP %d · 발동 %.0f%% · 회복 %d · 저지 임계 %d · 횟수 %d" % [
		MAX_HP, _bal.boss_heal_trigger * 100.0,
		int(round(MAX_HP * _bal.boss_heal_ratio)),
		int(round(MAX_HP * _bal.boss_heal_break_ratio)), _bal.boss_heal_charges])
	print("[1부] 근접형 상세 시나리오")
	_spawn("melee")


func _spawn(archetype: String) -> void:
	if _boss != null:
		_boss.queue_free()
	_boss = load("res://scenes/Boss.tscn").instantiate()
	current_scene.add_child(_boss)
	_boss.setup({
		"max_health": MAX_HP, "speed": 0.0, "contact_damage": 2,
		"score": 0, "gold": 0, "archetype": archetype, "name": archetype.to_upper(),
	})
	_starts.clear()
	_channeling = false


## 시전 시작/종료를 감지해 기록한다(시작 시각·정지 여부 검증용).
func _watch_channel() -> void:
	var ch: bool = _boss._heal_t > 0.0
	if ch and not _channeling:
		_starts.append(_t)
		_channel_pos = _boss.global_position
		_channel_start = _t
		print("  [%5.2fs] 시전 시작   HP %d  남은횟수 %d" % [_t, _boss.health, _boss._heal_left])
	elif not ch and _channeling:
		print("  [%5.2fs] 시전 끝     HP %d  남은횟수 %d  (%.2fs 지속)" % [
			_t, _boss.health, _boss._heal_left, _t - _channel_start])
	if ch:
		_expect_once("still_" + str(_boss._archetype),
				_boss.global_position.distance_to(_channel_pos) < 0.01,
				"%s: 시전 중에는 보스가 움직이지 않는다(무방비)" % _boss._archetype)
	_channeling = ch


# ── 1부: 근접형 상세 시나리오 ────────────────────────────────────────
func _step() -> void:
	# 2.0s — 만피 구간에서는 시전하지 않는다. 이후 50% 로 깎아 발동 조건을 만든다.
	_at(2.0, "dmg1", func() -> void:
		_expect(_starts.is_empty(), "발동 체력(55%) 위에서는 시전하지 않는다")
		_boss.take_damage(500)
		_expect(_boss.health == 500, "피해 500 적용 → HP 500/1000 (50%)")
		_expect(not _channeling, "피격 즉시 시전이 시작되지는 않는다(첫 시전 유예)"))

	# 첫 시전은 유예(3.0s) 뒤 — 그대로 두면 완주해 15% 회복.
	_at(5.6, "chk1", func() -> void:
		_expect(_starts.size() == 1, "발동 체력 도달 후 유예를 지나면 시전을 시작한다")
		_expect(_channeling, "시전은 %.1f초간 이어진다" % _boss.HEAL_CHANNEL))
	_at(7.2, "chk2", func() -> void:
		_expect(not _channeling, "방해가 없으면 시전이 완주된다")
		_expect(_boss.health == 650, "완주 → HP 500 + 150 = 650 (실제 %d)" % _boss.health)
		_expect(_boss._heal_left == 1, "횟수 1회 소모 → 남은 횟수 1"))

	# 회복으로 발동선(55%) 위로 올라간 동안에는 다음 쿨타임이 흐르지 않는다.
	_at(9.0, "chk3", func() -> void:
		_expect(is_equal_approx(_boss._heal_cd, _bal.boss_heal_cooldown),
				"발동선 위(65%%)에서는 쿨타임이 흐르지 않는다(cd %.2f)" % _boss._heal_cd)
		_boss.take_damage(200)
		_expect(_boss.health == 450, "피해 200 추가 → HP 450/1000 (45%)"))

	# 쿨타임(15s)이 지나면 두 번째 시전 — 발동선 아래로 다시 내려간 9.0s 부터 재므로 24.0s 경.
	_at(24.2, "chk4", func() -> void:
		_expect(_starts.size() == 2, "쿨타임이 지나면 다시 시전한다")
		_expect(_channeling, "두 번째 시전 진행 중"))
	# 이번엔 임계 피해를 넣어 저지한다(시전 시작 24.0s + 1.4s = 25.4s 완주 전).
	_at(24.7, "break", func() -> void:
		var need: int = int(round(MAX_HP * _bal.boss_heal_break_ratio))
		_boss.take_damage(need)
		_expect(_boss._heal_t <= 0.0, "임계 피해를 주면 시전이 즉시 끊긴다")
		_expect(_boss.health == 450 - need, "저지해도 준 피해는 그대로 들어간다 (HP %d)" % _boss.health)
		_expect(_boss._heal_left == 0, "저지당한 시전도 횟수를 소모한다 → 남은 횟수 0"))
	_at(25.6, "chk5", func() -> void:
		_expect(_starts.size() == 2, "저지 직후 곧바로 재시전하지 않는다"))


func _end_part1() -> void:
	var need: int = int(round(MAX_HP * _bal.boss_heal_break_ratio))
	_expect(_starts.size() == 2, "횟수(%d)를 다 쓰면 이후 %.0f초 동안 시전이 없다" % [
		_bal.boss_heal_charges, PART1_T - 25.0])
	_expect(_boss.health == 450 - need, "남은 시간 동안 체력이 저절로 오르지 않는다 (HP %d)" % _boss.health)
	_expect(_boss.health <= _boss.max_health, "회복은 최대 체력을 넘지 않는다")
	print("[2부] 아키타입별 발동 확인 — 예비 동작에 막혀 교착되지 않는지")
	_part = 2


# ── 2부: 아키타입 일괄 확인 ──────────────────────────────────────────
## 아키타입마다 보스를 새로 세우고 50% 로 깎은 뒤, 관찰 시간 안에 회복 1회가 성립하는지 본다.
func _sweep(delta: float) -> bool:
	_sweep_t -= delta
	if _sweep_t > 0.0:
		return false
	if _sweep_i >= 0:
		var a: String = SWEEP[_sweep_i]
		_expect(_starts.size() == 1, "%s: 관찰 %ds 안에 회복을 1회 시전한다(교착 없음)" % [a, SWEEP_T])
		_expect(_boss.health == 650, "%s: 완주 회복 → HP 650 (실제 %d)" % [a, _boss.health])
	_sweep_i += 1
	if _sweep_i >= SWEEP.size():
		return _report()
	_spawn(SWEEP[_sweep_i])
	_boss.take_damage(500)
	_sweep_t = SWEEP_T
	return false


func _report() -> bool:
	print("결과: %s" % ("전부 통과" if _fail == 0 else "%d건 실패" % _fail))
	# 정적 풀에 보관된 오르팬 노드 정리 — 게임에선 Main._clean_slate 가 하는 일.
	for path in ["res://scripts/FXBurst.gd", "res://scripts/DamageNumber.gd", "res://scripts/BossShell.gd"]:
		(load(path) as GDScript).clear_pool()
	quit(_fail)
	return true


func _at(t: float, key: String, fn: Callable) -> void:
	if _t >= t and not _done.has(key):
		_done[key] = true
		fn.call()


func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   %s" % msg)
	else:
		_fail += 1
		print("  FAIL %s" % msg)


## 매 프레임 확인하는 조건 — 실패했을 때 한 번만 보고한다(로그 폭주 방지).
func _expect_once(key: String, cond: bool, msg: String) -> void:
	if cond or _done.has(key):
		return
	_done[key] = true
	_fail += 1
	print("  FAIL %s" % msg)
