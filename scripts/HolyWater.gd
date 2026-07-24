extends Node2D
## 성수(무기): 주기적으로 플레이어 주변 무작위 지점에 광역 피해 구역을 떨어뜨린다.
## 레벨(upgrade_holy)로 동시 투척 수·피해가 커진다. FXBurst 로 착탄 연출, live_zombies 로 판정.

const INTERVAL := 3.4       # 투척 주기(초)
const ZONE_RADIUS := 74.0   # 착탄 광역 반경
const CAST_MIN := 40.0
const CAST_MAX := 230.0     # 플레이어로부터 착탄 거리 범위

const _FXBurst := preload("res://scripts/FXBurst.gd")

var _t: float = INTERVAL - 0.8   # 획득 직후 빠르게 첫 투척


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= INTERVAL:
		_t = 0.0
		_cast()


func _cast() -> void:
	var lv := maxi(1, Events.upgrade_holy)
	var count := 1 + int(lv / 2)      # 레벨이 오르면 동시에 여러 곳에 투척
	var dmg := 2 + int(lv / 2)
	var scene := get_tree().current_scene
	var r_sq := ZONE_RADIUS * ZONE_RADIUS
	for i in range(count):
		var pos := global_position + Vector2.from_angle(randf() * TAU) * randf_range(CAST_MIN, CAST_MAX)
		_FXBurst.spawn(scene, pos, Color(0.4, 0.82, 1.0), ZONE_RADIUS, 0.4)
		for z in Events.live_zombies():
			if is_instance_valid(z) and z.is_in_group("zombies") \
					and pos.distance_squared_to(z.global_position) < r_sq:
				z.take_damage(dmg)
