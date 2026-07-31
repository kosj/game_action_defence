extends WeaponModule
## 화염병: 주기적으로 최근접 적(무리) 위치에 화염병을 던져 불바다(GroundHazard) 장판을 남긴다.
## _data: fire_interval=투척 주기, proj_damage/dmg_per_level=장판 틱 피해, area_radius=장판 반경,
## area_duration=장판 지속, proj_speed 미사용(순간 착탄 + FX).

const _GroundHazard := preload("res://scripts/GroundHazard.gd")

const THROW_RANGE := 440.0
const THROW_AHEAD := 190.0   # 사거리 내 적이 없을 때 앞으로 던지는 거리

var _t: float = 0.0


func _ready() -> void:
	_t = 0.0


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	_t += delta
	var lvl := _level()
	var interval: float = maxf(_data.fire_interval * 0.6, _data.fire_interval * pow(0.95, float(lvl - 1)))
	if _t >= interval:
		_t = 0.0
		_throw(lvl)


func _throw(lvl: int) -> void:
	var target := _nearest_zombie(THROW_RANGE)
	var pos: Vector2
	if target != null:
		pos = target.global_position
		if absf(target.global_position.x - global_position.x) > 4.0:
			_facing = signf(target.global_position.x - global_position.x)
	else:
		pos = global_position + Vector2(_facing, 0.0) * THROW_AHEAD

	var r: float = _data.area_radius * (1.0 + 0.05 * float(lvl - 1)) * Events.area_mult()
	var dmg: int = _data.proj_damage + _data.dmg_per_level * (lvl - 1)
	var scene := get_tree().current_scene
	var hz := _GroundHazard.new()
	scene.add_child(hz)
	hz.setup(pos, r, dmg, _data.area_duration, _data.color)
	_FXBurst.spawn(scene, pos, _data.color, r * 0.9, 0.35)   # 착탄 연출
	SoundManager.play("boom", 0.12, 1.1)
