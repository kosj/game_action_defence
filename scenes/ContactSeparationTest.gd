extends Node
## 몬스터-플레이어 겹침 방지 + 접촉 피해 회귀 테스트.
##
## 실행:
##   godot --headless --path . res://scenes/ContactSeparationTest.tscn
##
## 배경: 접촉 판정이 상대 크기와 무관하게 중심거리 26px 고정이었다. 플레이어 반폭이 32px 라
## 스프라이트가 뚜렷이 겹쳐 보이는데도 판정이 안 나는 사각지대가 있었고("겹쳤는데 안 아프다"),
## 좀비는 플레이어 안으로 그대로 파고들었다. 이제 겹침 해소 반경과 접촉 판정 반경이 같은
## 몸통 반경(sep_radius + player_body_radius)이라, 닿은 몬스터는 반드시 피해를 준다.
##
## 검사 항목
##   T1 좀비가 플레이어 몸통 안으로 파고들지 않는다
##   T2 밀려나 맞닿은 좀비가 접촉 피해를 준다(쿨다운 주기대로)
##   T3 큰 좀비일수록 더 멀리 선다(반경이 스프라이트 크기에서 유도된다)
##   T4 플레이어는 군중에 막히지 않는다(밀리는 쪽은 몬스터)
##   T5 스프라이트가 겹쳐 보이는 거리(옛 판정 반경 밖)에서도 피해가 들어간다 — 보고된 증상

const MAIN := preload("res://scenes/Main.tscn")
const ZOMBIE := preload("res://scenes/Zombie.tscn")

var _ok: int = 0
var _total: int = 0
var _pl: Node2D = null


func _ready() -> void:
	add_child(MAIN.instantiate())
	_run()


func _wait(sec: float) -> void:
	var until := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		_ok += 1
	print("%s %s" % ["PASS" if cond else "FAIL", name])


## 지정한 종류의 좀비를 플레이어 위에 겹쳐 놓는다(가장 가혹한 초기 상태).
func _spawn(zd, offset: Vector2) -> Node2D:
	var z := Pool.acquire(ZOMBIE, get_tree().current_scene)
	z.global_position = _pl.global_position + offset
	z.setup({"speed": 90.0, "max_health": 999999, "modulate": zd.modulate, "score": 1,
		"scale": zd.scale, "contact": 1, "behavior": "chase", "texture": zd.texture})
	return z


func _clear_zombies() -> void:
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()
	await get_tree().process_frame


func _run() -> void:
	Events.reset()
	await _wait(0.5)
	_pl = get_tree().get_first_node_in_group("player")
	var sp: Node = get_tree().current_scene.get_node_or_null("ZombieSpawner")
	if sp != null:
		sp.set_process(false)
	Events.upgrade_max_health = 900          # 테스트 중 사망하지 않게 넉넉히
	_pl.apply_upgrades()
	_pl.health = _pl.max_health
	await _clear_zombies()

	# --- T1/T2: 겹쳐 놓은 좀비 6마리가 밀려나고, 그 상태로 피해를 주는가 ---
	var walker = GameData.zombie_list[0]
	for i in 6:
		_spawn(walker, Vector2.from_angle(float(i)) * 5.0)
	await get_tree().process_frame
	_pl._hurt_timer = 0.0
	var hp0: int = _pl.health
	await _wait(2.0)

	var closest := 99999.0
	for z in get_tree().get_nodes_in_group("zombies"):
		closest = minf(closest, _pl.global_position.distance_to(z.global_position))
	var min_allowed: float = float(_pl.contact_radius) + _sep_of(walker)
	print("  최소 중심거리=%.1f (허용 하한 %.1f) / 2초 피해=%d" % [
		closest, min_allowed, hp0 - _pl.health])
	_check("T1 플레이어 몸통 안으로 파고들지 않음", closest >= min_allowed - 1.0)

	# 쿨다운(contact_cooldown)마다 1회 — 2초면 최소 4회는 맞아야 정상이다.
	var dmg: int = hp0 - _pl.health
	var expect: int = int(2.0 / GameData.balance.contact_cooldown) - 2
	_check("T2 맞닿은 몬스터가 접촉 피해를 줌 (%d 대미지, 기대 %d+)" % [dmg, expect], dmg >= expect)

	# --- T3: 큰 좀비는 더 멀리 선다 ---
	await _clear_zombies()
	var big = GameData.zombie_list[0]
	for zd in GameData.zombie_list:
		if _sep_of(zd) > _sep_of(big):
			big = zd
	_spawn(big, Vector2(4.0, 0.0))
	await _wait(1.0)
	var d_big := 0.0
	for z in get_tree().get_nodes_in_group("zombies"):
		d_big = _pl.global_position.distance_to(z.global_position)
	print("  큰 좀비(%s) 정지 거리=%.1f / 작은 좀비 정지 거리=%.1f" % [big.id, d_big, min_allowed])
	_check("T3 큰 몬스터일수록 더 멀리 선다", d_big > min_allowed + 1.0)

	# --- T4: 플레이어가 군중에 막히지 않는다 ---
	await _clear_zombies()
	for i in 10:
		_spawn(walker, Vector2(60.0 + 12.0 * float(i), 0.0))
	await get_tree().process_frame
	var from := _pl.global_position
	for i in 60:
		_pl.global_position += Vector2(3.0, 0.0)   # 군중 쪽으로 밀고 들어간다
		await get_tree().physics_frame
	var moved := _pl.global_position.distance_to(from)
	print("  플레이어 이동 거리=%.1f (기대 180)" % moved)
	_check("T4 플레이어는 군중에 막히지 않음", moved > 170.0)

	# --- T5: 옛 판정 반경(26px) 밖이지만 스프라이트는 겹치는 거리 — 보고된 사각지대 ---
	await _clear_zombies()
	var z5 := _spawn(walker, Vector2(40.0, 0.0))
	z5.set_physics_process(false)      # 그 자리에 고정해 거리를 통제한다
	await get_tree().process_frame
	_pl._hurt_timer = 0.0
	var hp5: int = _pl.health
	await _wait(1.0)
	var dmg5: int = hp5 - _pl.health
	print("  중심거리 40px(옛 판정 26px 밖) 1초 피해=%d" % dmg5)
	_check("T5 겹쳐 보이는 거리에서 피해가 들어감", dmg5 > 0)

	print("RESULT ok=%d/%d" % [_ok, _total])
	await get_tree().process_frame
	get_tree().quit(0 if _ok == _total else 1)


## 데이터에서 좀비 몸통 반경을 계산(Zombie.gd 의 유도식과 동일).
func _sep_of(zd) -> float:
	if zd.texture == null:
		return 16.0
	return zd.texture.get_size().x * zd.scale * 0.40
