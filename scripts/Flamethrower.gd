extends WeaponModule
## 화염방사기: 조준 방향으로 부채꼴(콘) 지속 피해. 투사체 없이 매 틱마다 콘 안의 좀비를 태운다.
## 시각은 CPUParticles2D 불꽃 분사로 표현(밝은 바닥 위에서도 잘 보인다). inferno(진화)도 같은 모듈.
## _data: spread=콘 반각(rad), area_radius=콘 길이, proj_damage/dmg_per_level=틱 피해, fire_interval=틱 간격.
##
## 불길은 **캐릭터가 아니라 떠다니는 소환 버너(pod)에서** 나간다. 예전에는 모듈(=플레이어
## 중심)을 조준 방향으로 통째로 돌려서, 좌우 플립만 있는 캐릭터 그림과 어긋나 등 뒤나
## 머리 위에서 불이 뿜어져 나왔다. 독립된 부유 장치가 쏘면 어느 방향이든 자연스럽다
## (드론·터렛과 같은 문법).

const POD_RADIUS := 44.0    # 캐릭터에서 떨어져 떠 있는 거리
const POD_ORBIT := 1.05     # 공전 각속도(rad/s) — 느리게 돌아 존재감만 준다
const POD_SQUASH := 0.55    # 궤도를 납작하게(사이드뷰라 정원이면 붕 떠 보인다)
const _SPRITE_PATH := "res://assets/sprites/flame_pod.png"   # 있으면 절차 드로잉 대신 사용

var _t: float = 0.0
var _aim: Vector2 = Vector2.RIGHT
var _fire: CPUParticles2D
var _core: CPUParticles2D
var _pod: Node2D            # 불길이 실제로 나오는 부유 버너
var _orbit: float = 0.0
var _tex: Texture2D = null


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
	p.emitting = true
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


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	# 버너는 캐릭터 주위를 천천히 공전하고, 조준은 버너 위치 기준으로 잡는다.
	_orbit += delta * POD_ORBIT
	_pod.position = Vector2(cos(_orbit), sin(_orbit) * POD_SQUASH) * POD_RADIUS
	_aim = _pod_aim(_length())
	_pod.rotation = _aim.angle()
	_update_emitters()
	_t += delta
	var interval: float = maxf(_data.fire_interval * 0.6, _data.fire_interval * pow(0.96, float(_level() - 1)))
	if _t >= interval:
		_t = 0.0
		_burn()


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


## 버너 위치에서 본 최근접 적 방향. 적이 없으면 캐릭터 바깥쪽(공전 진행 방향)을 향해 뿜는다.
func _pod_aim(rng: float) -> Vector2:
	var from := _pod.global_position
	var nearest: Node2D = null
	var min_d := rng * rng
	for z in Events.zombies_in_radius(from, rng):
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		var d := from.distance_squared_to(z.global_position)
		if d < min_d:
			min_d = d
			nearest = z
	if nearest != null:
		return (nearest.global_position - from).normalized()
	var out := _pod.position
	return out.normalized() if out.length() > 1.0 else Vector2.RIGHT


## 부유 버너 본체 — 전용 아트가 있으면 그걸 쓰고, 없으면 노즐 모양을 절차적으로 그린다.
class _FlamePod extends Node2D:
	const DRAW_SIDE := 40.0   # 긴 변 기준 화면 크기(드론과 같은 규약 — 원본 해상도와 무관하게)

	var tex: Texture2D = null

	func _draw() -> void:
		if tex != null:
			var side := maxf(tex.get_size().x, tex.get_size().y)
			var sz: Vector2 = tex.get_size() * (DRAW_SIDE / maxf(side, 1.0))
			draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false)
			return
		# 로컬 +X 가 분사 방향. 뒤쪽이 두툼한 탱크, 앞쪽이 좁아지는 노즐.
		draw_circle(Vector2(-5, 0), 7.0, Color(0.22, 0.24, 0.28))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-6, -5), Vector2(9, -3), Vector2(9, 3), Vector2(-6, 5)]),
			Color(0.34, 0.36, 0.40))
		draw_line(Vector2(9, 0), Vector2(13, 0), Color(1.0, 0.62, 0.20, 0.95), 4.0, true)
		draw_circle(Vector2(-5, 0), 3.0, Color(1.0, 0.55, 0.15, 0.85))
