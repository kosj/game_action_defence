extends Area2D
## 골드 자석 아이템: 맵에 등장하며 주우면 일정 시간 동안 필드의 모든 골드가
## 거리와 무관하게 플레이어에게 자동으로 빨려온다(자동 줍기). 방치 시 사라진다.
## 무기 픽업과 동일하게 풀링되며 "item_pickups" 그룹으로 동시 등장 수를 제한한다.

const _FXBurst := preload("res://scripts/FXBurst.gd")

@export var collect_radius: float = 34.0
@export var lifetime: float = 22.0
@export var fade_time: float = 3.0
@export var magnet_duration: float = 16.0   # 획득 시 부여되는 자동 줍기 지속 시간(초)

const ICON_COLOR := Color(1.0, 0.85, 0.2)

var player: Node2D = null
var _alive: bool = false
var _t: float = 0.0


func _ready() -> void:
	add_to_group("item_pickups")
	monitoring = false
	monitorable = false


func on_spawn() -> void:
	add_to_group("item_pickups")   # 재사용 시 멱등 재등록(안전)
	_alive = true
	_t = 0.0
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")


func on_despawn() -> void:
	_alive = false
	remove_from_group("item_pickups")


func _process(delta: float) -> void:
	if not _alive:
		return
	_t += delta
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		queue_redraw()
		return
	if global_position.distance_to(player.global_position) <= collect_radius:
		_collect()
		return
	if _t >= lifetime:
		_despawn()
		return
	queue_redraw()


func _collect() -> void:
	_alive = false
	if is_instance_valid(player) and player.has_method("activate_gold_magnet"):
		player.activate_gold_magnet(magnet_duration)
	SoundManager.play("gold", 0.05)
	_FXBurst.spawn(get_tree().current_scene, global_position, ICON_COLOR, 60.0, 0.4)
	_despawn()


func _despawn() -> void:
	_alive = false
	Pool.release(self)


func _draw() -> void:
	if not _alive:
		return
	var bob := sin(_t * 2.4) * 6.0
	var center := Vector2(0.0, bob)
	var pulse := 1.0 + sin(_t * 5.0) * 0.07

	var alpha := 1.0
	var remain := lifetime - _t
	if remain < fade_time:
		alpha = clampf(remain / fade_time, 0.0, 1.0)

	# 후광
	var glow_r := 22.0 * pulse
	draw_circle(center, glow_r, Color(ICON_COLOR.r, ICON_COLOR.g, ICON_COLOR.b, 0.30 * alpha))
	draw_arc(center, glow_r * 0.8, 0.0, TAU, 28, Color(ICON_COLOR.r, ICON_COLOR.g, ICON_COLOR.b, 0.6 * alpha), 2.5, true)

	# 끌어당김을 표현하는 회전 점들
	for i in 6:
		var a := _t * 2.0 + TAU * float(i) / 6.0
		var p := center + Vector2.from_angle(a) * (glow_r + 4.0)
		draw_circle(p, 2.2, Color(ICON_COLOR.r, ICON_COLOR.g, ICON_COLOR.b, 0.7 * alpha))

	# 코인 본체
	var r := 11.0 * pulse
	draw_circle(center, r, Color(ICON_COLOR.r, ICON_COLOR.g, ICON_COLOR.b, 0.92 * alpha))
	draw_circle(center, r * 0.55, Color(1.0, 1.0, 1.0, 0.85 * alpha))

	# 라벨
	var font := ThemeDB.fallback_font
	draw_string(font, center + Vector2(-60.0, -glow_r - 14.0), "Gold Magnet", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 14, Color(1.0, 1.0, 1.0, alpha))
