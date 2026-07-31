extends WeaponModule
## 지뢰 부설기: 주기적으로 플레이어 주변 바닥에 지뢰(LandMine)를 설치한다. 동시 설치 수 상한이 있어
## 레벨이 오르면 더 자주·더 많이 깔 수 있다. _data: fire_interval=설치 주기, proj_damage/dmg_per_level=
## 폭발 피해, area_radius=폭발 반경, knockback=폭발 넉백, area_duration=지뢰 수명.

const _LandMine := preload("res://scripts/LandMine.gd")

const PLACE_MIN := 40.0
const PLACE_MAX := 110.0   # 플레이어로부터 설치 거리 범위

var _t: float = 0.0
var _mines: Array = []     # 활성 지뢰 추적(상한 관리)


func _max_mines(lvl: int) -> int:
	return 3 + int(lvl / 2)


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	# 폭발/소멸한 지뢰 정리
	_mines = _mines.filter(func(m): return is_instance_valid(m))
	_t += delta
	var lvl := _level()
	var interval: float = maxf(_data.fire_interval * 0.6, _data.fire_interval * pow(0.95, float(lvl - 1)))
	if _t >= interval and _mines.size() < _max_mines(lvl):
		_t = 0.0
		_deploy(lvl)


func _deploy(lvl: int) -> void:
	var pos := global_position + Vector2.from_angle(randf() * TAU) * randf_range(PLACE_MIN, PLACE_MAX)
	var r: float = _data.area_radius * (1.0 + 0.05 * float(lvl - 1)) * Events.area_mult()
	var dmg: int = _data.proj_damage + _data.dmg_per_level * (lvl - 1)
	var mine := _LandMine.new()
	get_tree().current_scene.add_child(mine)
	mine.setup(pos, r, dmg, _data.knockback, _data.area_duration, _data.color)
	_mines.append(mine)
