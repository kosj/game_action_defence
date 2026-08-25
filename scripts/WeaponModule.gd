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


## 캐릭터가 들고 쏘는 무기의 발사 원점 — 그림 속 총구 위치(캐릭터마다 다르다).
## 모듈은 Player 의 자식이라 global_position 이 캐릭터 중심이므로, 그대로 쓰면 발사체가
## 몸통 한가운데서 튀어나온다. Player 가 없는 상황(테스트 등)에서는 모듈 위치로 폴백.
func _muzzle() -> Vector2:
	var p := get_parent()
	if p != null and p.has_method("muzzle_position"):
		return p.muzzle_position()
	return global_position


## 현재 강화 레벨(1..max).
func _level() -> int:
	var m: int = _data.max_level if _data != null else 8
	return clampi(int(Events.weapons.get(weapon_id, 0)), 1, m)


## 사거리 내 최근접 좀비. 조준은 매 물리 프레임 갱신되므로 전체 좀비 스캔이면 무기 1종당
## 프레임당 O(좀비 수)를 낸다(화염방사기·체인소·터렛이 동시에 있으면 수천 회) — 공간 해시의
## 반경 질의로 후보를 사거리 안으로 좁힌다. 결과 의미는 이전과 같다(사거리 밖이면 null).
func _nearest_zombie(rng: float) -> Node2D:
	var nearest: Node2D = null
	var min_d := rng * rng
	for z in Events.zombies_in_radius(global_position, rng):
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
