class_name HUDMilestone
extends Control
## Completion notices are queued individually: consecutive milestones never
## overwrite each other. Purely cosmetic, with no reward or pause side effects.
const HOLD := 2.8
var pending: Array[Dictionary] = []
var current: Dictionary = {}
var _card: Panel
var _heading: Label
var _title: Label
var _detail: Label
var _fx: Control
var _tween: Tween
var _accent := Color.GOLD
var _burst := 0.0:
	set(value):
		_burst = value
		if is_instance_valid(_fx): _fx.queue_redraw()
var _progress := 1.0:
	set(value):
		_progress = value
		if is_instance_valid(_fx): _fx.queue_redraw()

static func make(parent: Node) -> HUDMilestone:
	var notice := HUDMilestone.new()
	parent.add_child(notice)
	return notice

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = Panel.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_heading = _label(20,Vector2(100,14),Vector2(394,27))
	_title = _label(24,Vector2(100,43),Vector2(394,60))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.max_lines_visible = 2
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail = _label(18,Vector2(100,109),Vector2(394,26))
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_fx)
	_fx.draw.connect(_draw_fx)
	get_viewport().size_changed.connect(_layout)
	Events.player_died.connect(clear)
	_card.hide()
	_layout()

func _label(font_size: int, at: Vector2, extent: Vector2) -> Label:
	var label := Label.new()
	label.position = at
	label.size = extent
	label.add_theme_font_size_override("font_size",font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(label)
	return label

func _layout() -> void:
	var screen := get_viewport_rect().size
	_card.size = Vector2(minf(520,screen.x-48),148)
	var portrait := screen.y>screen.x
	_card.position = Vector2((screen.x-_card.size.x)*0.5 if portrait else screen.x-_card.size.x-24,310 if portrait else 120)
	for label in [_heading,_title,_detail]:
		label.size.x = _card.size.x-126
	_card.pivot_offset = _card.size*0.5

func push(title: String, achievement: bool, reward: int = 0) -> void:
	pending.append({"title":title,"achievement":achievement,"reward":reward})
	if current.is_empty(): _next()

func _next() -> void:
	if pending.is_empty():
		current = {}
		_card.hide()
		return
	current = pending.pop_front()
	_accent = Color(1,0.79,0.27) if current.achievement else Color(0.33,0.9,0.73)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.055,0.08,0.10,0.96)
	box.border_color = _accent.darkened(0.35)
	box.set_border_width_all(2)
	box.border_width_left = 5
	box.set_corner_radius_all(10)
	box.shadow_color = Color(0,0,0,0.35)
	box.shadow_size = 8
	_card.add_theme_stylebox_override("panel",box)
	_heading.text = Locale.t("milestone_achievement" if current.achievement else "milestone_quest")
	_heading.add_theme_color_override("font_color",_accent)
	_title.text = current.title
	_detail.text = Locale.t("milestone_recorded") if current.achievement else Locale.t("milestone_reward") % current.reward
	_detail.add_theme_color_override("font_color",Color(0.73,0.79,0.80))
	_layout()
	_card.show()
	_card.modulate.a = 0
	_card.scale = Vector2.ONE*0.92
	_burst = 0
	_progress = 1
	SoundManager.play_ui("gold",0,1.3 if current.achievement else 1.15)
	_tween = create_tween()
	_tween.tween_property(_card,"modulate:a",1.0,0.18)
	_tween.parallel().tween_property(_card,"scale",Vector2.ONE,0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self,"_burst",1.0,0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self,"_progress",0.0,HOLD)
	_tween.tween_property(_card,"modulate:a",0.0,0.25)
	_tween.parallel().tween_property(_card,"scale",Vector2.ONE*0.97,0.25)
	_tween.tween_callback(_next)

func _draw_fx() -> void:
	var origin := Vector2(52,70)
	_fx.draw_circle(origin,30,_accent.darkened(0.78))
	_fx.draw_arc(origin,32,0,TAU,48,_accent,2,true)
	if current.get("achievement",false):
		var star := PackedVector2Array()
		for i in 10:
			star.append(origin+Vector2.from_angle(-PI*0.5+i*PI/5)*(20 if i%2==0 else 9))
		_fx.draw_colored_polygon(star,_accent)
	else:
		_fx.draw_polyline(PackedVector2Array([origin+Vector2(-16,0),origin+Vector2(-4,12),origin+Vector2(18,-14)]),_accent,5,true)
	for i in 8:
		var ray := Vector2.from_angle(i*TAU/8)
		var col := _accent
		col.a = 1-_burst
		_fx.draw_line(origin+ray*(32+_burst*18),origin+ray*(36+_burst*25),col,2,true)
	_fx.draw_line(Vector2(16,141),Vector2(16+(_card.size.x-32)*_progress,141),_accent,2,true)

func clear() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	pending.clear()
	current = {}
	if is_instance_valid(_card): _card.hide()
