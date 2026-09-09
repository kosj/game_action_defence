extends Node2D
## Standalone F6 preview; does not change the game's Player or atlas.
const SHEET = preload("res://output/hunter_walk_sample/rig_v3/hunter_walk_24x8.png")
const LABELS = ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
const LAYOUT = [Vector2(1, 2), Vector2(0, 2), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(2, 1), Vector2(2, 2)]
var elapsed := 0.0
var paused := false

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		paused = not paused

func _process(delta: float) -> void:
	if not paused:
		elapsed = fmod(elapsed + delta, 0.96)
	queue_redraw()

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("20323d"))
	var cell := minf(viewport_size.x / 3.0, viewport_size.y / 3.0)
	var origin := (viewport_size - Vector2(cell * 3.0, cell * 3.0)) / 2.0
	var frame := mini(23, int(elapsed / 0.04))
	for direction in range(8):
		var top_left: Vector2 = origin + LAYOUT[direction] * cell
		draw_texture_rect_region(SHEET, Rect2(top_left, Vector2.ONE * cell), Rect2(frame * 256, direction * 256, 256, 256))
		draw_string(ThemeDB.fallback_font, top_left + Vector2(12, 22), LABELS[direction], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(ThemeDB.fallback_font, origin + Vector2(cell + 12, cell * 1.5), "IK WALK / SPACE: PAUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
