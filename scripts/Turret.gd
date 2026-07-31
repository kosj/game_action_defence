extends WeaponModule
## 터렛 배치기: 주기적으로 플레이어 주변에 터렛(TurretUnit)을 설치한다. 동시 설치 수 상한이 있고
## 레벨이 오르면 더 자주·더 많이 깐다. _data: fire_interval=설치 주기, area_duration=터렛 수명,
## proj_damage/dmg_per_level=터렛 탄 피해, area_radius=터렛 사거리, proj_speed=탄속.

const _TurretUnit := preload("res://scripts/TurretUnit.gd")

const PLACE_MIN := 30.0
const PLACE_MAX := 90.0

var _t: float = 0.0
var _turrets: Array = []


func _max_turrets(lvl: int) -> int:
	return 1 + int(lvl / 2)


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	_turrets = _turrets.filter(func(t): return is_instance_valid(t))
	_t += delta
	var lvl := _level()
	var interval: float = maxf(_data.fire_interval * 0.6, _data.fire_interval * pow(0.95, float(lvl - 1)))
	if _t >= interval and _turrets.size() < _max_turrets(lvl):
		_t = 0.0
		_deploy(lvl)


func _deploy(lvl: int) -> void:
	var pos := global_position + Vector2.from_angle(randf() * TAU) * randf_range(PLACE_MIN, PLACE_MAX)
	var dmg: int = _data.proj_damage + _data.dmg_per_level * (lvl - 1)
	var turret := _TurretUnit.new()
	get_tree().current_scene.add_child(turret)
	turret.setup(pos, dmg, _data.proj_speed, _data.area_radius * Events.area_mult(), _data.area_duration, _data.color)
	_turrets.append(turret)
