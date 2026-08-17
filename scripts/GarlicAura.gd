extends Node2D
## 햇빛 오라(무기, id=garlic): 플레이어를 둘러싼 "좀비가 싫어하는 햇살" — 반경 안의 좀비에게
## 주기적으로 지속 피해. Player 의 자식으로 항상 플레이어 위치에 있으며, 레벨(upgrade_garlic)로
## 반경·피해가 커진다. 지면 효과처럼 유닛 아래에 깔린다(z_index=-1).
## 연출: 따뜻한 금빛 다층 글로우 + 천천히 도는 햇살 살(god-ray) + 은은한 맥동(가산 블렌드).

const _FXMaterial := preload("res://scripts/FXMaterial.gd")
const BASE_RADIUS := 92.0
const RADIUS_PER_LV := 13.0
const TICK := 0.5          # 이 간격마다 반경 내 전원에게 1회 피해
const RAYS := 9            # 햇살 살 개수
const RAY_SPIN := 0.25     # 햇살 회전 속도(rad/s) — 아주 천천히 돈다

var _t: float = 0.0
var _pulse: float = 0.0
var _ray_buf := PackedVector2Array()   # 햇살 살 삼각형 — 드로우마다 재사용


func _ready() -> void:
	z_index = -1   # 좀비·플레이어 아래(지면 위)에 그려지는 오라
	material = _FXMaterial.additive()   # 공유 인스턴스 — 개별 생성 시 드로우 배치가 쪼개진다   # 겹칠수록 빛나는 햇살 발광


func _radius() -> float:
	return (BASE_RADIUS + RADIUS_PER_LV * float(maxi(1, Events.upgrade_garlic) - 1)) * Events.area_mult()


## 재드로우 주기(물리 프레임 수). 연출 변화가 느린 숨쉬기(_pulse*3)와 회전(0.25 rad/s)뿐이라
## 60Hz 로 다시 그릴 이유가 없다 — 20Hz 로 낮추면 절차 드로우 비용이 1/3 이 된다.
const REDRAW_EVERY := 3


func _physics_process(delta: float) -> void:
	_pulse += delta
	_t += delta
	if _t >= TICK:
		_t = 0.0
		var lv := maxi(1, Events.upgrade_garlic)
		var dmg := 1 + int(lv / 2)
		# 반경 질의로 후보를 좁힌다(전수 스캔 제거). take_damage 를 부르는 동안 공유 버퍼가
		# 덮이지 않도록 즉시 지역 배열로 복사한다(0.5초에 한 번이라 비용은 무시할 수준).
		var targets: Array = []
		for z in Events.zombies_in_radius(global_position, _radius()):
			if z.is_in_group("zombies"):
				targets.append(z)
		for z in targets:
			if is_instance_valid(z):
				z.take_damage(dmg)
	if Engine.get_physics_frames() % REDRAW_EVERY == 0:
		queue_redraw()


func _draw() -> void:
	var r := _radius()
	var breathe := 1.0 + 0.03 * sin(_pulse * 3.0)
	var rr := r * breathe
	# 다층 금빛 글로우 — 바깥으로 갈수록 옅어지는 햇살 웅덩이.
	draw_circle(Vector2.ZERO, rr, Color(1.0, 0.85, 0.45, 0.07))
	draw_circle(Vector2.ZERO, rr * 0.72, Color(1.0, 0.90, 0.55, 0.07))
	draw_circle(Vector2.ZERO, rr * 0.45, Color(1.0, 0.95, 0.70, 0.08))
	# 천천히 도는 햇살 살(god-ray) — 중심에서 가장자리로 퍼지는 쐐기들.
	var base_a := _pulse * RAY_SPIN
	# 살(ray) 삼각형 버퍼는 재사용한다 — 매 드로우마다 PackedVector2Array 를 RAYS 개(9개)
	# 새로 만들면 그리기 빈도만큼 할당이 쌓인다.
	if _ray_buf.size() != 3:
		_ray_buf.resize(3)
		_ray_buf[0] = Vector2.ZERO
	for i in RAYS:
		var ang := base_a + TAU * float(i) / float(RAYS)
		var half := 0.10 + 0.03 * sin(_pulse * 2.0 + float(i) * 1.7)   # 살마다 폭이 살짝 숨쉰다
		_ray_buf[1] = Vector2.from_angle(ang - half) * rr
		_ray_buf[2] = Vector2.from_angle(ang + half) * rr
		draw_colored_polygon(_ray_buf, Color(1.0, 0.92, 0.60, 0.06))
	# 가장자리 림 — 은은한 노을빛 경계 + 반짝이는 하이라이트 호.
	draw_arc(Vector2.ZERO, rr, 0.0, TAU, 56, Color(1.0, 0.82, 0.40, 0.30), 2.5, true)
	var hl := fmod(_pulse * 0.7, TAU)
	draw_arc(Vector2.ZERO, rr, hl, hl + 0.9, 14, Color(1.0, 0.97, 0.80, 0.45), 3.0, true)
