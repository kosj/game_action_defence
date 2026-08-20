extends Node2D
## 부메랑 투사체: 던진 방향으로 감속하며 날아가 정점에서 되돌아오고, 귀환 중에는 이동하는
## 플레이어를 추적해 손으로 돌아온다. 왕복 각각에서 적을 관통 타격(정점에서 피격 목록 리셋 —
## 갔다 오며 같은 적을 두 번 때릴 수 있다). 전용 아트가 있으면 스프라이트, 없으면 절차 드로잉.

const HIT_R := 37.5          # 타격 판정 반경(1.25x 확대)
const SPIN := 14.0           # 회전 속도(rad/s) — 빙글빙글 도는 맛
const RETURN_ACCEL := 2600.0 # 귀환 가속
const CATCH_R := 26.0        # 플레이어 도달 판정
const LIFE_MAX := 5.0        # 안전장치 — 어떤 이유로든 못 돌아오면 자멸

const _SPRITE_PATH := "res://assets/atlas/weapon_boomerang.tres"

var _player: Node2D = null
var _dir := Vector2.RIGHT
var _range := 260.0
var _damage := 3
var _knockback := 90.0
var _speed := 520.0
var _phase := 0              # 0=전진 1=귀환
var _out_t := 0.0
var _out_time := 1.0
var _ret_vel := Vector2.ZERO
var _hits: Dictionary = {}
var _life := 0.0
var _spr: Sprite2D = null


func setup(player: Node2D, dir: Vector2, rng: float, dmg: int, kb: float, speed: float) -> void:
	_player = player
	_dir = dir.normalized()
	_range = rng
	_damage = dmg
	_knockback = kb
	_speed = maxf(speed, 60.0)
	# 감속 비행으로 사거리 끝에서 속도 0 이 되도록 전진 시간 산출: range = speed*t - 0.5*(speed/t)*t^2 → t = 2*range/speed
	_out_time = 2.0 * _range / _speed


func _ready() -> void:
	z_index = 2
	if ResourceLoader.exists(_SPRITE_PATH):
		var tex = load(_SPRITE_PATH)
		if tex is Texture2D:
			_spr = Sprite2D.new()
			_spr.texture = tex
			var side := maxf(tex.get_size().x, tex.get_size().y)
			_spr.scale = Vector2.ONE * (55.0 / maxf(side, 1.0))   # 1.25x 확대
			add_child(_spr)


func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= LIFE_MAX or not is_instance_valid(_player):
		queue_free()
		return
	rotation += SPIN * delta
	if _phase == 0:
		# 전진: 선형 감속(정점에서 0) — 부메랑 특유의 "힘이 빠지며 멈칫"하는 궤적.
		_out_t += delta
		var k := clampf(1.0 - _out_t / _out_time, 0.0, 1.0)
		global_position += _dir * _speed * k * delta
		if _out_t >= _out_time:
			_phase = 1
			_hits.clear()   # 귀환길에는 같은 적을 다시 때릴 수 있다
			_ret_vel = _dir * _speed * 0.1
	else:
		# 귀환: 플레이어 방향으로 계속 가속(이동 중인 플레이어도 따라잡는다).
		var to_p := _player.global_position - global_position
		if to_p.length() <= CATCH_R:
			queue_free()
			return
		_ret_vel += to_p.normalized() * RETURN_ACCEL * delta
		_ret_vel = _ret_vel.limit_length(_speed * 1.6)
		global_position += _ret_vel * delta
	_hit_check()
	# 절차 드로잉은 로컬 좌표 기준 정적 — 회전은 노드 변환이 처리하므로 매 프레임 redraw 불필요.


func _hit_check() -> void:
	var travel := _dir if _phase == 0 else _ret_vel.normalized()
	for z in Events.zombies_near(global_position):
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		var id: int = z.get_instance_id()
		if _hits.has(id):
			continue
		if global_position.distance_squared_to(z.global_position) <= HIT_R * HIT_R:
			_hits[id] = true
			z.take_damage(_damage)
			if z.has_method("apply_knockback"):
				z.apply_knockback(travel, _knockback)


## 전용 아트가 없을 때의 절차 드로잉 — ㄱ자로 꺾인 두 날개 목재 부메랑.
func _draw() -> void:
	if _spr != null:
		return
	var wood := Color(0.78, 0.55, 0.28)
	var edge := Color(0.95, 0.78, 0.45)
	const S := 1.25   # 전체 1.25x 확대(타격 반경과 일치)
	for f in [1.0, -1.0]:
		var arm := PackedVector2Array([
			Vector2(0, 0) , Vector2(20.0 * S * f, -6.0 * S), Vector2(19.0 * S * f, 3.0 * S), Vector2(2.0 * S * f, 6.0 * S)])
		# batching-exempt: 텍스처가 없을 때만 도는 폴백 — 아틀라스에 그림이 있어 도달하지 않는다
		draw_colored_polygon(arm, wood)
		# batching-exempt: 텍스처가 없을 때만 도는 폴백 — 아틀라스에 그림이 있어 도달하지 않는다
		draw_polyline(PackedVector2Array([Vector2(0, -2.0 * S), Vector2(18.0 * S * f, -6.0 * S)]), edge, 2.5)
	# batching-exempt: 텍스처가 없을 때만 도는 폴백 — 아틀라스에 그림이 있어 도달하지 않는다
	draw_circle(Vector2.ZERO, 3.4 * S, edge)
