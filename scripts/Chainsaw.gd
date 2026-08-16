extends WeaponModule
## 체인소(부유 소환물): 전기톱이 캐릭터 주위를 떠다니다가 적을 찾으면 날아가 달라붙어
## 일정 시간 갈아낸 뒤, 다음 표적을 찾아 옮겨간다. 표적이 없으면 캐릭터 곁으로 돌아온다.
##
## 예전에는 캐릭터가 든 짧은 원호였는데, 조준이 360° 자동이라 좌우 플립뿐인 그림과 어긋나
## 등 뒤를 갈아댔다. 독립 소환물이면 어느 방향으로 움직여도 자연스럽다(드론·터렛과 같은 문법).
##
## _data: fire_interval=피해 틱 간격, proj_damage/dmg_per_level=틱 피해, knockback=약넉백,
## area_radius=표적 탐색 반경의 기준.

const HOVER_RADIUS := 54.0    # 대기 중 캐릭터 주위를 도는 반경
const HOVER_ORBIT := 1.3      # 대기 공전 각속도(rad/s)
const HOVER_SQUASH := 0.5     # 사이드뷰라 궤도를 납작하게
const FLY_SPEED := 430.0      # 표적으로 날아가는 속도(px/s)
const RETURN_SPEED := 300.0   # 대기 위치로 돌아오는 속도
const GRIND_TIME := 1.1       # 한 표적을 갈아내는 시간(초)
const GRIND_PER_LEVEL := 0.06 # 레벨당 갈기 시간 증가
const GRIND_OFFSET := 16.0    # 표적 중심에서 이만큼 앞에 붙는다(겹쳐 가리지 않게)
const SEARCH_MULT := 4.2      # 탐색 반경 = area_radius × 이 값 (날아다니므로 넓게)
const ARRIVE_DIST := 22.0     # 이 거리 안이면 붙은 것으로 본다
const _SPRITE_PATH := "res://assets/sprites/chainsaw_summon.png"

enum { HOVER, SEEK, GRIND }

var _saw: Node2D
var _state: int = HOVER
var _target: Node2D = null
var _grind_left: float = 0.0
var _tick: float = 0.0
var _orbit: float = 0.0
var _spin: float = 0.0
var _tex: Texture2D = null


func _ready() -> void:
	z_index = 1
	if ResourceLoader.exists(_SPRITE_PATH):
		var t = load(_SPRITE_PATH)
		if t is Texture2D:
			_tex = t
	_saw = _Saw.new()
	_saw.tex = _tex
	# 월드 좌표로 움직인다 — 부모(Player)를 따라 끌려다니면 멀리 있는 표적에 붙어 있을 수 없다.
	_saw.top_level = true
	add_child(_saw)
	_saw.global_position = global_position


func _search_range() -> float:
	return _data.area_radius * SEARCH_MULT * Events.area_mult()


## 대기 위치 — 캐릭터 주위를 천천히 도는 지점.
func _hover_point() -> Vector2:
	return global_position + Vector2(cos(_orbit), sin(_orbit) * HOVER_SQUASH) * HOVER_RADIUS


func _physics_process(delta: float) -> void:
	if _data == null or _saw == null:
		return
	_orbit += delta * HOVER_ORBIT
	_spin += delta * 30.0
	_saw.spin = _spin

	if not _target_alive():
		_target = null
		if _state == GRIND or _state == SEEK:
			_state = SEEK   # 표적을 잃으면 즉시 다음 표적 탐색
	match _state:
		HOVER:
			_move_to(_hover_point(), RETURN_SPEED, delta)
			_acquire()
		SEEK:
			if _target == null:
				if not _acquire():
					_state = HOVER
			else:
				var to: Vector2 = _target.global_position - _saw.global_position
				_saw.face(to)
				if to.length() <= ARRIVE_DIST + GRIND_OFFSET:
					_state = GRIND
					_grind_left = GRIND_TIME + GRIND_PER_LEVEL * float(_level() - 1)
					_tick = 0.0
				else:
					_move_to(_target.global_position, FLY_SPEED, delta)
		GRIND:
			# 표적 바로 앞에 붙어 있는다(플레이어 쪽에서 다가온 방향 기준).
			var anchor: Vector2 = _target.global_position
			var away := (_saw.global_position - anchor)
			if away.length() < 1.0:
				away = Vector2.RIGHT
			_saw.global_position = anchor + away.normalized() * GRIND_OFFSET
			_saw.face(anchor - _saw.global_position)
			_grind_left -= delta
			_tick += delta
			if _tick >= _data.fire_interval:
				_tick = 0.0
				_bite()
			if _grind_left <= 0.0:
				_target = null
				if not _acquire():
					_state = HOVER
				else:
					_state = SEEK
	_saw.queue_redraw()


func _target_alive() -> bool:
	return _target != null and is_instance_valid(_target) and _target.is_in_group("zombies")


## 톱 위치에서 가장 가까운 적을 새 표적으로. 찾으면 true.
func _acquire() -> bool:
	var from := _saw.global_position
	var rng := _search_range()
	var nearest: Node2D = null
	var min_d := rng * rng
	for z in Events.zombies_in_radius(from, rng):
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		var d := from.distance_squared_to(z.global_position)
		if d < min_d:
			min_d = d
			nearest = z
	if nearest == null:
		return false
	_target = nearest
	_state = SEEK
	return true


func _move_to(dest: Vector2, speed: float, delta: float) -> void:
	var to: Vector2 = dest - _saw.global_position
	var step := speed * delta
	if to.length() <= step:
		_saw.global_position = dest
	else:
		_saw.global_position += to.normalized() * step
		_saw.face(to)


## 붙어 있는 표적을 한 번 갈아낸다.
func _bite() -> void:
	if not _target_alive():
		return
	var lvl := _level()
	var dmg: int = _data.proj_damage + _data.dmg_per_level * (lvl - 1)
	_target.take_damage(dmg)
	if _data.knockback > 0.0 and _target.has_method("apply_knockback"):
		var dir: Vector2 = (_target.global_position - _saw.global_position)
		if dir.length() > 0.01:
			_target.apply_knockback(dir.normalized(), _data.knockback)


## 전기톱 본체 — 전용 아트가 있으면 쓰고, 없으면 몸통 + 회전 톱날을 절차적으로 그린다.
class _Saw extends Node2D:
	const DRAW_SIDE := 46.0   # 긴 변 기준 화면 크기

	var tex: Texture2D = null
	var spin: float = 0.0
	var _facing_x: float = 1.0

	## 진행/표적 방향으로 좌우만 뒤집는다(사이드뷰 규약 — 회전시키면 톱이 뒤집혀 보인다).
	func face(dir: Vector2) -> void:
		if absf(dir.x) > 4.0:
			_facing_x = signf(dir.x)

	func _draw() -> void:
		var f := _facing_x
		if tex != null:
			# 긴 변 기준 화면 크기로 정규화(드론과 같은 규약 — 원본 해상도와 무관).
			var side := maxf(tex.get_size().x, tex.get_size().y)
			var sz: Vector2 = tex.get_size() * (DRAW_SIDE / maxf(side, 1.0))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(f, 1.0))
			draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(f, 1.0))
		# 몸통(손잡이 쪽) + 앞으로 뻗은 바
		draw_colored_polygon(PackedVector2Array([
			Vector2(-13, -7), Vector2(-2, -6), Vector2(-2, 6), Vector2(-13, 8)]),
			Color(0.86, 0.44, 0.12))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-2, -4), Vector2(17, -3), Vector2(17, 3), Vector2(-2, 4)]),
			Color(0.55, 0.58, 0.65))
		# 바를 따라 도는 톱니 — spin 으로 흐르게 해 '돌아가는 중'이 읽히게 한다
		var teeth := 7
		for i in range(teeth):
			var p := fposmod(spin * 0.35 + float(i) / float(teeth), 1.0)
			var x: float = -2.0 + p * 19.0
			draw_line(Vector2(x, -4.5), Vector2(x, -2.5), Color(0.95, 0.96, 1.0, 0.95), 1.6, true)
			draw_line(Vector2(x, 2.5), Vector2(x, 4.5), Color(0.95, 0.96, 1.0, 0.95), 1.6, true)
		draw_circle(Vector2(-7, 0), 3.0, Color(0.30, 0.32, 0.36))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
