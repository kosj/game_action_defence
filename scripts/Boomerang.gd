extends WeaponModule
## 부메랑: 주기적으로 최근접 적 방향에 회전 부메랑을 던진다. 감속 비행 → 정점 → 플레이어에게
## 귀환하며 왕복 모두 관통 타격. 레벨 5+ 는 반대 방향으로 1개 더 던진다.
## _data: fire_interval=투척 주기, area_radius=비행 사거리, proj_speed=투척 속도,
## proj_damage/dmg_per_level=피해, knockback=넉백.

const _Proj := preload("res://scripts/BoomerangProj.gd")

var _t: float = 0.0


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	_t += delta
	var interval: float = maxf(_data.fire_interval * 0.55, _data.fire_interval * pow(0.95, float(_level() - 1)))
	if _t >= interval:
		_t = 0.0
		_throw()


func _throw() -> void:
	var lvl := _level()
	var dmg: int = _data.proj_damage + _data.dmg_per_level * (lvl - 1) + Events.upgrade_bullet_damage
	var rng: float = _data.area_radius * (1.0 + 0.05 * float(lvl - 1)) * (1.0 + 0.10 * Events.upgrade_area)
	var dir := _aim_dir(rng * 1.3)
	var n := 1 + int((lvl - 1) / 4)   # Lv5+ 2개(반대 방향)
	for i in n:
		var d := dir if i == 0 else -dir
		var b: Node2D = _Proj.new()
		get_tree().current_scene.add_child(b)
		b.global_position = global_position + d * 14.0
		b.setup(get_parent(), d, rng, dmg, _data.knockback, _data.proj_speed)
	SoundManager.play("shoot", 0.12, 0.72)   # 낮은 휙 소리
