extends WeaponModule
## 화염방사기: 조준 방향으로 부채꼴(콘) 지속 피해. 투사체 없이 매 틱마다 콘 안의 좀비를 태운다.
## 시각은 CPUParticles2D 불꽃 분사로 표현(밝은 바닥 위에서도 잘 보인다). inferno(진화)도 같은 모듈.
## _data: spread=콘 반각(rad), area_radius=콘 길이, proj_damage/dmg_per_level=틱 피해, fire_interval=틱 간격.
##
## 불길은 **캐릭터가 아니라 떠다니는 소환 버너(pod)에서** 나간다. 예전에는 모듈(=플레이어
## 중심)을 조준 방향으로 통째로 돌려서, 좌우 플립만 있는 캐릭터 그림과 어긋나 등 뒤나
## 머리 위에서 불이 뿜어져 나왔다. 독립된 부유 장치가 쏘면 어느 방향이든 자연스럽다
## (드론·터렛과 같은 문법).

const POD_RADIUS := 52.0     # 캐릭터에서 떨어져 떠 있는 거리
const POD_SQUASH := 0.62     # 사이드뷰라 위아래 오프셋을 눌러 붕 떠 보이지 않게
const POD_SPEED := 260.0     # 자리를 옮기는 속도(px/s)
const AIM_TOLERANCE := 0.16  # 이 각도(rad) 안으로 정렬되면 발사 개시
## 표적이 없을 때 대기 위치 — 캐릭터 머리 위. 몸(150px 아트 × sprite_scale 0.52 ≈ 78px)의
## 위쪽 끝이 원점에서 약 -39 이므로 그보다 조금 더 위에 띄운다.
const IDLE_POS := Vector2(0.0, -58.0)
const _SPRITE_PATH := "res://assets/atlas/flame_pod.tres"   # 있으면 절차 드로잉 대신 사용

var _t: float = 0.0
var _aim: Vector2 = Vector2.RIGHT
var _fire: CPUParticles2D
var _core: CPUParticles2D
var _pod: Node2D            # 불길이 실제로 나오는 부유 버너
var _tex: Texture2D = null
var _lit: bool = false      # 자리를 잡고 조준이 맞아 실제로 분사 중인가


func _ready() -> void:
	z_index = 1   # 불꽃은 바닥 위, 유닛과 비슷한 높이로 확실히 보이게
	if ResourceLoader.exists(_SPRITE_PATH):
		var t = load(_SPRITE_PATH)
		if t is Texture2D:
			_tex = t
	_pod = _FlamePod.new()
	_pod.tex = _tex
	add_child(_pod)
	_fire = _make_emitter(70, Color(1.0, 0.55, 0.12), 0.9)    # 주 불길(주황)
	_core = _make_emitter(40, Color(1.0, 0.92, 0.55), 0.55)   # 안쪽 뜨거운 코어(밝은 노랑)
	_pod.add_child(_fire)
	_pod.add_child(_core)


## 부드러운 원형 텍스처 + 불꽃 컬러램프를 가진 콘 분사 파티클(로컬 +X = 조준 방향, rotation 으로 정렬).
func _make_emitter(amount: int, tint: Color, scale: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _soft_tex()
	p.local_coords = false           # 방출된 불꽃은 월드에 남아 흘러 스트림처럼 보인다
	p.amount = amount
	p.lifetime = 0.42
	p.direction = Vector2(1, 0)
	p.gravity = Vector2.ZERO
	p.scale_amount_min = scale * 0.7
	p.scale_amount_max = scale * 1.15
	var sc := Curve.new()            # 방출 직후 커졌다가 식으며 작아짐
	sc.add_point(Vector2(0.0, 0.5)); sc.add_point(Vector2(0.25, 1.0)); sc.add_point(Vector2(1.0, 0.15))
	p.scale_amount_curve = sc
	var ramp := Gradient.new()       # 흰노랑 → 주황 → 붉게 → 소멸
	ramp.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
	ramp.set_color(1, Color(0.7, 0.15, 0.06, 0.0))
	ramp.add_point(0.12, Color(1.0, 0.95, 0.7, 0.9))
	ramp.add_point(0.45, Color(tint.r, tint.g, tint.b, 0.75))
	ramp.add_point(0.8, Color(0.85, 0.25, 0.08, 0.35))
	p.color_ramp = ramp
	p.emitting = false   # 분사 on/off 는 _set_lit 가 관리한다(자리+조준이 맞을 때만)
	return p


func _soft_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 32
	gt.height = 32
	return gt


func _length() -> float:
	return _data.area_radius * (1.0 + 0.05 * float(_level() - 1)) * Events.area_mult()


## 버너는 공전하지 않는다. 캐릭터에서 POD_RADIUS 만큼 떨어진 채 **표적 쪽 방향으로** 자리를
## 옮기고, 그 자리에 도착해 조준이 맞으면 그때 분사한다. 늘 돌고 있으면 불길이 표적과
## 무관하게 휘둘러져 조준하고 있다는 느낌이 안 산다.
func _physics_process(delta: float) -> void:
	if _data == null:
		return
	var target := _nearest_zombie(_length() + POD_RADIUS)
	var want_pos: Vector2
	if target != null:
		var bearing: Vector2 = (target.global_position - global_position).normalized()
		want_pos = Vector2(bearing.x, bearing.y * POD_SQUASH).normalized() * POD_RADIUS
	else:
		want_pos = IDLE_POS   # 표적이 없으면 캐릭터 머리 위에서 대기
	_pod.position = _pod.position.move_toward(want_pos, POD_SPEED * delta)

	if target != null:
		_aim = (target.global_position - _pod.global_position).normalized()
		if absf(_aim.x) > 0.05:
			_facing = signf(_aim.x)
	else:
		_aim = Vector2(_facing, 0.0)
	_pod.set_aim(_aim.angle())

	# 자리를 잡았고(도착) 조준이 맞았을 때만 불을 뿜는다.
	var in_place := _pod.position.distance_to(want_pos) <= 6.0
	var aimed := target != null and absf(_aim.angle_to(target.global_position - _pod.global_position)) <= AIM_TOLERANCE
	_set_lit(target != null and in_place and aimed)

	_update_emitters()
	if not _lit:
		return
	_t += delta
	var interval: float = maxf(_data.fire_interval * 0.6, _data.fire_interval * pow(0.96, float(_level() - 1)))
	if _t >= interval:
		_t = 0.0
		_burn()


func _set_lit(on: bool) -> void:
	if on == _lit:
		return
	_lit = on
	_fire.emitting = on
	_core.emitting = on
	if not on:
		_t = 0.0


## 콘 길이/반각을 파티클 속도·확산에 반영(사거리가 커지면 불길도 길어짐). 속도×수명 ≈ 사거리.
func _update_emitters() -> void:
	var reach := _length()
	var spread_deg := rad_to_deg(_data.spread)
	var v := reach / 0.42
	_fire.spread = spread_deg
	_fire.initial_velocity_min = v * 0.75
	_fire.initial_velocity_max = v * 1.15
	_core.spread = spread_deg * 0.6
	_core.initial_velocity_min = v * 0.6
	_core.initial_velocity_max = v * 0.9


func _burn() -> void:
	var lvl := _level()
	var dmg: int = _data.proj_damage + _data.dmg_per_level * (lvl - 1)
	var reach := _length()
	var reach_sq := reach * reach
	var half := _data.spread
	var apex := _pod.global_position   # 콘의 꼭짓점은 버너 — 그림과 판정을 일치시킨다
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		var to: Vector2 = z.global_position - apex
		if to.length_squared() > reach_sq:
			continue
		if absf(to.angle_to(_aim)) <= half:   # 콘(부채꼴) 안에 있는가
			z.take_damage(dmg)


## 부유 버너 본체 — 전용 아트가 있으면 그걸 쓰고, 없으면 노즐 모양을 절차적으로 그린다.
##
## 노드 자체는 조준 각도로 회전한다(자식 파티클이 그 방향으로 분사해야 하므로). 그런데
## 왼쪽을 조준하면 회전이 ±90°를 넘어 그림이 위아래로 뒤집힌 채 보인다 — 사이드뷰 아트라
## 180° 돌린 모습은 "뒤집힌 버너"로 읽힌다. 그래서 그럴 때만 세로로 한 번 더 미러링해
## 똑바로 선 채 왼쪽을 보게 만든다(좀비·플레이어의 좌우 플립과 같은 결과).
class _FlamePod extends Node2D:
	## 긴 변 기준 화면 크기(드론과 같은 규약 — 원본 해상도와 무관하게).
	## 40 은 좀비 옆에서 존재감이 약해 1.5배로 키웠다.
	const DRAW_SIDE := 60.0

	var tex: Texture2D = null
	var _flipped: bool = false


	## 조준 각도를 적용한다. 좌/우가 바뀌는 순간에만 다시 그린다(매 프레임 redraw 방지).
	func set_aim(ang: float) -> void:
		rotation = ang
		var f := cos(ang) < 0.0
		if f != _flipped:
			_flipped = f
			queue_redraw()

	func _draw() -> void:
		var fy := -1.0 if _flipped else 1.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, fy))
		if tex != null:
			var side := maxf(tex.get_size().x, tex.get_size().y)
			var sz: Vector2 = tex.get_size() * (DRAW_SIDE / maxf(side, 1.0))
			draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false)
		else:
			# 로컬 +X 가 분사 방향. 뒤쪽이 두툼한 탱크, 앞쪽이 좁아지는 노즐.
			draw_circle(Vector2(-5, 0), 7.0, Color(0.22, 0.24, 0.28))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-6, -5), Vector2(9, -3), Vector2(9, 3), Vector2(-6, 5)]),
				Color(0.34, 0.36, 0.40))
			draw_line(Vector2(9, 0), Vector2(13, 0), Color(1.0, 0.62, 0.20, 0.95), 4.0, true)
			draw_circle(Vector2(-5, 0), 3.0, Color(1.0, 0.55, 0.15, 0.85))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
