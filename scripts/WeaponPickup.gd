extends Area2D
## 무기 픽업: 맵 랜덤 위치에 등장. 플레이어가 가까이 가면 즉시 장착되고,
## 방치되면 일정 시간 후 사라진다(자리 순환). 희귀도가 높을수록 더 크고 화려하게 표현.

const _FXBurst := preload("res://scripts/FXBurst.gd")

@export var collect_radius: float = 34.0
@export var lifetime: float = 25.0
@export var fade_time: float = 3.0

var stats: Dictionary = {}
var player: Node2D = null
var _alive: bool = false
var _t: float = 0.0


func _ready() -> void:
	add_to_group("weapon_pickups")
	monitoring = false
	monitorable = false


## 스포너가 풀에서 꺼낸 직후 무기 데이터를 주입.
func setup(weapon_stats: Dictionary) -> void:
	stats = weapon_stats


func on_spawn() -> void:
	add_to_group("weapon_pickups")   # 재사용 시 멱등 재등록(안전)
	_alive = true
	_t = 0.0
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")


func on_despawn() -> void:
	_alive = false
	remove_from_group("weapon_pickups")


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
	if is_instance_valid(player) and player.has_method("equip_weapon"):
		player.equip_weapon(stats)
	SoundManager.play("gold", 0.05)
	var fx := _FXBurst.new()
	fx.color = stats.get("tier_color", Color.WHITE)
	fx.max_radius = 26.0 + 10.0 * (stats.get("tier_mult", 1.0) - 1.0)
	fx.duration = 0.32
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
	_despawn()


func _despawn() -> void:
	_alive = false
	Pool.release(self)


func _draw() -> void:
	if not _alive or stats.is_empty():
		return
	var bob := sin(_t * 2.4) * 6.0
	var center := Vector2(0.0, bob)
	var tier_mult: float = stats.get("tier_mult", 1.0)
	var base_color: Color = stats.get("color", Color.WHITE)
	var tier_color: Color = stats.get("tier_color", Color.WHITE)
	var scale_pulse := 1.0 + sin(_t * 5.0) * 0.06
	var icon_radius := (10.0 + 3.0 * (tier_mult - 1.0)) * scale_pulse

	var alpha := 1.0
	var remain := lifetime - _t
	if remain < fade_time:
		alpha = clampf(remain / fade_time, 0.0, 1.0)

	# 희귀도 후광 — 강력할수록 크고 밝다
	var glow_r := (22.0 + 10.0 * (tier_mult - 1.0)) * scale_pulse
	draw_circle(center, glow_r, Color(tier_color.r, tier_color.g, tier_color.b, 0.30 * alpha))
	draw_arc(center, glow_r * 0.78, 0.0, TAU, 28, Color(tier_color.r, tier_color.g, tier_color.b, 0.55 * alpha), 2.5, true)

	# 무기별 아이콘(회전)
	var rot := _t * 1.1
	_draw_icon(stats.get("shape", "circle"), center, icon_radius, rot, base_color, tier_color, alpha)

	# 이름 / 희귀도 라벨
	var font := ThemeDB.fallback_font
	var label_pos := center + Vector2(-60.0, -glow_r - 14.0)
	draw_string(font, label_pos, stats.get("name", ""), HORIZONTAL_ALIGNMENT_CENTER, 120.0, 15, Color(1.0, 1.0, 1.0, alpha))
	if stats.get("tier_id", "common") != "common":
		var tier_pos := label_pos + Vector2(0.0, 16.0)
		draw_string(font, tier_pos, stats.get("tier_name", ""), HORIZONTAL_ALIGNMENT_CENTER, 120.0, 13, Color(tier_color.r, tier_color.g, tier_color.b, alpha))


func _draw_icon(shape: String, center: Vector2, r: float, rot: float, base_color: Color, tier_color: Color, alpha: float) -> void:
	var fill := Color(base_color.r, base_color.g, base_color.b, 0.85 * alpha)
	var rim := Color(tier_color.r, tier_color.g, tier_color.b, alpha)
	var core := Color(1.0, 1.0, 1.0, 0.9 * alpha)
	match shape:
		"circle":
			draw_circle(center, r, fill)
			draw_arc(center, r, 0.0, TAU, 24, rim, 2.0, true)
			draw_circle(center, r * 0.35, core)
		"triangle", "pentagon", "hexagon":
			var sides: int = {"triangle": 3, "pentagon": 5, "hexagon": 6}[shape]
			var pts := _make_ngon(center, r, sides, rot)
			draw_colored_polygon(pts, fill)
			draw_polyline(pts + PackedVector2Array([pts[0]]), rim, 2.0, true)
			draw_circle(center, r * 0.3, core)
		"diamond":
			var pts := _make_ngon(center, r, 4, rot)
			draw_colored_polygon(pts, fill)
			draw_polyline(pts + PackedVector2Array([pts[0]]), rim, 2.0, true)
			draw_circle(center, r * 0.3, core)
		"long_diamond":
			var dir := Vector2.from_angle(rot)
			var perp := dir.orthogonal()
			var pts := PackedVector2Array([
				center + dir * r * 1.6,
				center + perp * r * 0.45,
				center - dir * r * 1.6,
				center - perp * r * 0.45,
			])
			draw_colored_polygon(pts, fill)
			draw_polyline(pts + PackedVector2Array([pts[0]]), rim, 2.0, true)
			draw_circle(center, r * 0.25, core)


func _make_ngon(center: Vector2, r: float, sides: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a := rot + TAU * float(i) / sides
		pts.append(center + Vector2.from_angle(a) * r)
	return pts
