extends Node2D
## 번개 패시브: 주기적으로 주변 좀비 1체를 타격 + 인근에 약한 스플래시 데미지.

const STRIKE_RADIUS := 450.0
const SPLASH_RADIUS := 60.0
const BASE_INTERVAL := 4.0

const _FXLightning := preload("res://scripts/FXLightning.gd")

# 구매(생성) 직후 첫 낙뢰가 최대 4초나 늦어 "산 게 효과가 없다"고 느껴지지 않도록,
# 첫 타이머는 거의 찬 상태로 시작해 ~0.8초 안에 첫 번개가 떨어지게 한다.
var _timer: float = BASE_INTERVAL - 0.8


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= BASE_INTERVAL:
		_timer = 0.0
		_strike()


func _strike() -> void:
	var candidates: Array = []
	for z in Events.live_zombies():
		if is_instance_valid(z) and z.is_in_group("zombies") \
				and global_position.distance_squared_to(z.global_position) < STRIKE_RADIUS * STRIKE_RADIUS:
			candidates.append(z)
	if candidates.is_empty():
		return

	# 동시에 때리는 번개 가닥 수 = 번개 업그레이드 레벨. 서로 다른 적을 무작위로 노린다.
	var bolts := maxi(1, Events.upgrade_lightning_count)
	candidates.shuffle()
	var hits := mini(bolts, candidates.size())
	var dmg := 2 + Events.upgrade_lightning_damage
	var splash_dmg := maxi(1, dmg / 2)

	for i in range(hits):
		var target: Node2D = candidates[i]
		if not is_instance_valid(target):
			continue
		target.take_damage(dmg)
		_spawn_fx(target.global_position)
		# 각 낙뢰 지점 주변 스플래시
		for z in candidates:
			if z == target or not is_instance_valid(z):
				continue
			if z.global_position.distance_squared_to(target.global_position) < SPLASH_RADIUS * SPLASH_RADIUS:
				z.take_damage(splash_dmg)


func _spawn_fx(world_pos: Vector2) -> void:
	var fx := _FXLightning.new()
	get_tree().current_scene.add_child(fx)
	fx.global_position = world_pos
