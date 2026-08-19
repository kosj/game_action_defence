extends Node2D
## 공전 칼날: 플레이어를 중심으로 "적당한 고정 거리"에서 회전만 한다(맥동 확장 없음).
## 외형은 빠르게 자전하는 이중 칼날. 회전속도는 orb_speed 업그레이드로 빨라진다.

const ORBIT_RADIUS := 120.0   # 캐릭터로부터의 고정 공전 반경(적당한 거리)
const ORBIT_SPEED := 2.6      # 기본 공전 각속도(rad/s)
const ORB_SPEED_STEP := 0.35  # orb_speed 업그레이드 1레벨당 공전 각속도 +35%
const SPIN_SPEED := 15.0      # 칼날 자전 각속도(rad/s) — 공격적인 회전 느낌
const HIT_COOLDOWN := 0.6     # 같은 적 재타격 간격
const HIT_RADIUS := 28.0      # 피해 판정 반경(칼날 리치)

const BLADE_LEN := 24.0
const BLADE_W := 7.5

const _FXBurst := preload("res://scripts/FXBurst.gd")
## 칼날 텍스처는 HIT_RADIUS 지름(56px)의 2배로 구워져 있다(고DPI 여유 — ASSET_PIPELINE.md).
## 상수(HIT_RADIUS/BLADE_LEN/BLADE_W)를 바꾸면 tools/gen_fx_shapes.py 도 같이 고칠 것.
const _BLADE_TEX := preload("res://assets/atlas/fx_orb_blade.tres")

var _orbit_angle: float = 0.0
var _spin: float = 0.0
var _timers: Dictionary = {}


## 여러 칼날을 각도만 균등 분산 — 모두 고정 반경에서 같은 속도로 캐릭터를 중심으로 회전한다.
func init_angle(a: float) -> void:
	_orbit_angle = a


func _physics_process(delta: float) -> void:
	# 회전속도 업그레이드(orb_speed) 반영 — 레벨당 +35%.
	var orbit_speed := ORBIT_SPEED * (1.0 + ORB_SPEED_STEP * Events.upgrade_orb_speed)
	_orbit_angle += orbit_speed * delta
	_spin += SPIN_SPEED * delta

	position = Vector2.from_angle(_orbit_angle) * ORBIT_RADIUS
	rotation = _spin

	# 재타격 쿨다운 감쇠
	for id in _timers.keys():
		_timers[id] -= delta
		if _timers[id] <= 0.0:
			_timers.erase(id)

	# 칼날 리치 안의 좀비에게 피해 — 전체 그룹 풀 스캔 대신 공간 해시 주변 후보만 검사
	# (칼날 6개 × 좀비 수백에서 프레임당 수천 번의 거리 계산이 수십 번으로 줄어든다).
	var dmg := 1 + Events.upgrade_orb_damage
	var r_sq := HIT_RADIUS * HIT_RADIUS
	for z in Events.zombies_near(global_position):
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		if global_position.distance_squared_to(z.global_position) < r_sq:
			var id: int = z.get_instance_id()
			if not _timers.has(id):
				z.take_damage(dmg)
				_timers[id] = HIT_COOLDOWN
				_spawn_hit_fx(z.global_position)
	# 그리기는 로컬 좌표 기준 정적 — 회전은 노드 변환이 처리하므로 매 프레임 redraw 불필요.


## 칼날 한 장. 모양이 완전히 정적이라(회전은 노드 변환이 한다) 통째로 구워 뒀다 —
## 예전에는 draw_circle 3 + draw_colored_polygon 4 + draw_line 2 = 9커맨드였고, Godot
## 캔버스 배처는 한 아이템 안에서도 **프리미티브 종류가 다르면 배치를 끊는다**.
## 오브는 최대 6개가 유닛 사이(y_sort)에서 돌아 그 끊김이 주변 배치까지 갈랐다 —
## 실측 드로우 콜 +121. 쿼드 하나로 바꾸니 게임플레이 아틀라스 배치에 그대로 합류한다.
## 그림을 바꾼 것이 아니라 같은 좌표·같은 색을 텍스처로 옮긴 것이다(tools/gen_fx_shapes.py).
func _draw() -> void:
	draw_texture_rect(_BLADE_TEX,
		Rect2(-HIT_RADIUS, -HIT_RADIUS, HIT_RADIUS * 2.0, HIT_RADIUS * 2.0), false)


func _spawn_hit_fx(world_pos: Vector2) -> void:
	_FXBurst.spawn(get_tree().current_scene, world_pos, Color(0.75, 0.9, 1.0), 20.0, 0.20)
