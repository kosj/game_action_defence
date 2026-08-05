extends Node2D
## 연구소 기믹: 폭주 테슬라 코일. 예고 후 주변에 방전해 범위 내 좀비·플레이어에게 피해. 주기 반복.
## 방전 순간 대상까지 번개 선이 그려진다 — 예고 링이 차오르면 방전 임박.

const _FXBurst := preload("res://scripts/FXBurst.gd")

const TELEGRAPH := 0.8
const ACTIVE := 0.3
const COOLDOWN := 1.0
const ARC_R := 96.0
const ZOMBIE_DMG := 14
const PLAYER_DMG := 1
const LIFE := 12.0

var _player: Node2D = null
var _age: float = 0.0
var _life: float = LIFE
var _phase_t: float = 0.0
var _fired: bool = false
var _arcs: Array = []   # 방전 순간의 대상 상대좌표(그릴 끝점)


func _ready() -> void:
	z_index = 1   # 코일·아크가 유닛 위로
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_age += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_phase_t += delta
	var ph := fmod(_phase_t, TELEGRAPH + ACTIVE + COOLDOWN)
	if ph < TELEGRAPH:
		_fired = false
	elif ph < TELEGRAPH + ACTIVE and not _fired:
		_fired = true
		_discharge()
	queue_redraw()


func _discharge() -> void:
	_arcs.clear()
	var r_sq := ARC_R * ARC_R
	for z in Events.live_zombies():
		if is_instance_valid(z) and z.is_in_group("zombies") \
				and global_position.distance_squared_to(z.global_position) < r_sq:
			z.take_damage(ZOMBIE_DMG)
			_arcs.append(z.global_position - global_position)
	if is_instance_valid(_player) and _player.global_position.distance_squared_to(global_position) < r_sq \
			and _player.has_method("take_hit"):
		_player.take_hit(PLAYER_DMG)
		_arcs.append(_player.global_position - global_position)
	_FXBurst.spawn(get_tree().current_scene, global_position, Color(0.6, 0.8, 1.0), ARC_R * 0.5, 0.25)
	Events.shake(4.0)
	SoundManager.play("shoot", 0.05, 1.6)


func _draw() -> void:
	var ph := fmod(_phase_t, TELEGRAPH + ACTIVE + COOLDOWN)
	# 코일 기둥 + 헤드
	draw_rect(Rect2(-4.0, -22.0, 8.0, 26.0), Color(0.3, 0.32, 0.4, 1.0))
	draw_circle(Vector2(0.0, -24.0), 6.0, Color(0.5, 0.6, 0.85, 1.0))
	if ph < TELEGRAPH:
		var p := ph / TELEGRAPH
		draw_arc(Vector2.ZERO, ARC_R, 0.0, TAU, 32, Color(0.5, 0.7, 1.0, 0.12 + 0.3 * p), 2.0, true)
		draw_circle(Vector2(0.0, -24.0), 6.0 + 4.0 * p, Color(0.7, 0.85, 1.0, 0.4 * p))
	elif ph < TELEGRAPH + ACTIVE:
		for e in _arcs:
			_draw_bolt(Vector2(0.0, -24.0), e)


## 지그재그 번개 선.
func _draw_bolt(a: Vector2, b: Vector2) -> void:
	var segs := 5
	var prev := a
	var perp := (b - a).orthogonal().normalized()
	for i in range(1, segs + 1):
		var t := float(i) / float(segs)
		var mid := a.lerp(b, t)
		if i < segs:
			mid += perp * (sin(t * 9.0 + _age * 30.0) * 7.0)
		draw_line(prev, mid, Color(0.7, 0.85, 1.0, 0.9), 2.0)
		prev = mid
