extends Node2D
## 번개 패시브: 주기적으로 주변 좀비 1체를 타격 + 인근에 약한 스플래시 데미지.

const STRIKE_RADIUS := 450.0
const SPLASH_RADIUS := 60.0
const BASE_INTERVAL := 4.0

const _FXLightning := preload("res://scripts/FXLightning.gd")

var _timer: float = 0.0


func _physics_process(delta: float) -> void:
	var interval := BASE_INTERVAL * pow(0.82, maxi(Events.upgrade_lightning - 1, 0))
	_timer += delta
	if _timer >= interval:
		_timer = 0.0
		_strike()


func _strike() -> void:
	var candidates: Array = []
	for z in get_tree().get_nodes_in_group("zombies"):
		if is_instance_valid(z) and global_position.distance_squared_to(z.global_position) < STRIKE_RADIUS * STRIKE_RADIUS:
			candidates.append(z)
	if candidates.is_empty():
		return

	var target: Node2D = candidates[randi() % candidates.size()]
	var dmg := 2 + Events.upgrade_lightning_damage
	target.take_damage(dmg)
	_spawn_fx(target.global_position)

	var splash_dmg := maxi(1, dmg / 2)
	for z in candidates:
		if z == target or not is_instance_valid(z):
			continue
		if z.global_position.distance_squared_to(target.global_position) < SPLASH_RADIUS * SPLASH_RADIUS:
			z.take_damage(splash_dmg)


func _spawn_fx(world_pos: Vector2) -> void:
	var fx := _FXLightning.new()
	get_tree().current_scene.add_child(fx)
	fx.global_position = world_pos
