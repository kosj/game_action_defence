class_name WeaponModule
extends Node2D
## 데이터 구동 무기 모듈의 공통 베이스. Player 의 자식으로 붙어 자신의 WeaponData(GameData)
## 파라미터로 동작한다. 종류별 동작은 서브클래스가 _physics_process 에서 구현한다.

const _FXBurst := preload("res://scripts/FXBurst.gd")

var weapon_id: String = ""
var _data: WeaponData = null
var _facing: float = 1.0   # 조준 대상이 없을 때 쓰는 마지막 좌/우 방향


## Player 가 생성 직후 호출 — 어떤 무기인지 지정하고 데이터를 물어온다.
func setup(id: String) -> void:
	weapon_id = id
	_data = GameData.weapon_def(id)


## 현재 강화 레벨(1..max).
func _level() -> int:
	var m: int = _data.max_level if _data != null else 8
	return clampi(int(Events.weapons.get(weapon_id, 0)), 1, m)


## 사거리 내 최근접 좀비(프레임 공유 스냅샷 + distance_squared).
func _nearest_zombie(rng: float) -> Node2D:
	var nearest: Node2D = null
	var min_d := rng * rng
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		var d := global_position.distance_squared_to(z.global_position)
		if d < min_d:
			min_d = d
			nearest = z
	return nearest


## 최근접 적을 향한 조준 방향(정규화). 사거리 내 적이 없으면 마지막 좌/우 방향을 유지.
func _aim_dir(rng: float) -> Vector2:
	var target := _nearest_zombie(rng)
	if target != null:
		var d: Vector2 = (target.global_position - global_position).normalized()
		if absf(d.x) > 0.05:
			_facing = signf(d.x)
		return d
	return Vector2(_facing, 0.0)
