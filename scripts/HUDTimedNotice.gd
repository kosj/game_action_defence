class_name HUDTimedNotice
extends Control
## Live notices update in place, independently of the milestone queue.
var boss := false
var remaining := 0.0
var duration := 1.0
var arrived := false
var direction := 0.0
var active := false
var title: Label
var detail: Label
var _phase := 0.0
var _second := -1
var _tween: Tween
var _pulse: Tween
var _accent := Color(0.35,0.85,1)
var _box := StyleBoxFlat.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_box.bg_color = Color(0.035,0.06,0.075,0.94)
	_box.set_border_width_all(2)
	_box.set_corner_radius_all(12)
	title = Label.new()
	title.position = Vector2(92,13)
	title.add_theme_font_size_override("font_size",24)
	detail = Label.new()
	detail.position = Vector2(92,48)
	detail.add_theme_font_size_override("font_size",20)
	for label in [title,detail]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	get_viewport().size_changed.connect(_layout)
	Events.player_died.connect(clear)
	_layout()
	hide()
	set_process(false)

func _layout() -> void:
	var screen := get_viewport_rect().size
	var portrait := screen.y>screen.x
	size = Vector2(600 if boss else 420,100)
	position = Vector2((screen.x-size.x)*0.5,120) if boss else Vector2((screen.x-size.x)*0.5 if portrait else 24,480 if portrait else 310)
	pivot_offset = size*0.5
	for label in [title,detail]: label.size.x = size.x-112

func update_notice(text: String, subtitle: String, seconds: float, ready: bool = false, angle: float = 0.0) -> void:
	var entering := not active
	var reached := ready and not arrived
	if entering or seconds>remaining+1.1:
		duration = maxf(seconds,1)
	remaining = maxf(seconds,0)
	arrived = ready
	direction = angle
	active = true
	title.text = text
	title.position.y = 13 if boss else 31
	detail.text = subtitle
	_accent = Color(0.4,1,0.7) if arrived else (Color(1,0.7,0.25) if boss else Color(0.35,0.85,1))
	if remaining<=3 and not arrived: _accent = Color(1,0.43,0.3)
	title.add_theme_color_override("font_color",_accent)
	if entering:
		if _tween != null and _tween.is_valid(): _tween.kill()
		show()
		set_process(true)
		modulate.a = 0
		scale = Vector2.ONE*0.9
		_tween = create_tween()
		_tween.tween_property(self,"modulate:a",1.0,0.2)
		_tween.parallel().tween_property(self,"scale",Vector2.ONE,0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if boss: SoundManager.play_ui("warn_boss",0,1)
	if reached: SoundManager.play_ui("gold",0,1.2)
	var second := ceili(remaining)
	if second!=_second and second<=3 and not arrived:
		if _pulse != null and _pulse.is_valid(): _pulse.kill()
		title.scale = Vector2.ONE*1.08
		_pulse = create_tween()
		_pulse.tween_property(title,"scale",Vector2.ONE,0.3)
	_second = second
	queue_redraw()

func dismiss() -> void:
	if not active: return
	active = false
	if _tween != null and _tween.is_valid(): _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self,"modulate:a",0.0,0.35)
	_tween.tween_callback(func() -> void: hide(); set_process(false))

func clear() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	if _pulse != null and _pulse.is_valid(): _pulse.kill()
	active = false
	arrived = false
	_second = -1
	hide()
	set_process(false)

func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()

func _draw() -> void:
	_box.border_color = _accent.darkened(0.4)
	draw_style_box(_box,Rect2(Vector2.ZERO,size))
	var origin := Vector2(46,48)
	draw_arc(origin,31,-PI/2,-PI/2+TAU*clampf(remaining/duration,0.001,1),48,_accent,3,true)
	if arrived:
		draw_polyline(PackedVector2Array([origin+Vector2(-14,0),origin+Vector2(-3,11),origin+Vector2(15,-12)]),_accent,4,true)
	elif boss:
		var arrow := PackedVector2Array()
		for p in [Vector2(18,0),Vector2(-12,-12),Vector2(-5,0),Vector2(-12,12)]:
			arrow.append(origin+p.rotated(direction)*(1+0.08*sin(_phase*5)))
		draw_colored_polygon(arrow,_accent)
	else:
		draw_arc(origin+Vector2(0,-3),15,0,PI,24,_accent,6,true)
		for side in [-1,1]:
			draw_line(origin+Vector2(side*15,-15),origin+Vector2(side*15,-3),_accent,6,true)
			var dot := origin+Vector2(side*(24-8*fmod(_phase,1)), -20+12*fmod(_phase,1))
			draw_circle(dot,2,_accent)
	draw_line(Vector2(16,91),Vector2(16+(size.x-32)*clampf(remaining/duration,0,1),91),_accent,3,true)
