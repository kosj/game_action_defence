extends CanvasLayer
## 새 게임 시작 시 한 줄씩 페이드인되는 풀스크린 인트로(서사) — "The Last Beacon".
## 모든 문구는 Locale 에서 가져와 다국어를 지원한다. 완료/건너뛰기/탭으로 마치면
## on_done 콜백을 정확히 1회 호출한다.
##
## 사용:  IntroStory.play(parent_node, func(): <게임 시작 전환>)

const _UIStyle := preload("res://scripts/UIStyle.gd")

## 순서대로 노출할 본문 줄(Locale 키). 줄 추가/순서 변경은 여기서만.
const LINE_KEYS: Array = ["intro_l1", "intro_l2", "intro_l3", "intro_l4", "intro_l5"]

const FADE := 0.6      # 한 줄 페이드인 시간(초)
const HOLD := 1.15     # 다음 줄로 넘어가기 전 유지 시간(초)

var _on_done: Callable
var _done: bool = false
var _running: bool = true
var _seq: Tween
var _lines: Array = []
var _begin_btn: Button


## 인트로를 parent 위에 띄우고 재생. 끝나면 on_done 을 호출한다.
static func play(parent: Node, on_done: Callable) -> void:
	var intro = (load("res://scripts/IntroStory.gd") as GDScript).new()
	intro._on_done = on_done
	parent.add_child(intro)


func _ready() -> void:
	layer = 50   # 메인 메뉴 위에 덮어쓴다
	_build_ui()
	_run_sequence()


func _build_ui() -> void:
	# 전체 화면 암전 배경 — 탭하면 본문을 빠르게 다 보여준다(스킵과는 별개).
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.02, 0.02, 0.03, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)

	# 제목 (상단, 곧바로 페이드인되어 인트로 내내 유지)
	var title := Label.new()
	title.text = Locale.t("intro_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 96.0
	title.offset_bottom = 156.0
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.95, 0.30, 0.25))
	UITheme.heading(title)
	title.modulate.a = 0.0
	add_child(title)
	var ttw := create_tween()
	ttw.tween_property(title, "modulate:a", 1.0, 0.9)

	# 본문: 화면 중앙 세로 정렬, 줄마다 라벨을 미리 만들어 두고 알파만 0→1.
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.anchor_left = 0.08
	center.anchor_right = 0.92
	center.anchor_top = 0.30
	center.anchor_bottom = 0.82
	center.add_theme_constant_override("separation", 30)
	add_child(center)

	_lines.clear()
	for key in LINE_KEYS:
		var lbl := Label.new()
		lbl.text = Locale.t(key)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))
		lbl.modulate.a = 0.0
		center.add_child(lbl)
		_lines.append(lbl)

	# 건너뛰기 (우상단) — 즉시 게임 시작
	var skip := Button.new()
	skip.text = Locale.t("intro_skip")
	skip.add_theme_font_size_override("font_size", 18)
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -132.0
	skip.offset_top = 40.0
	skip.offset_right = -24.0
	skip.offset_bottom = 92.0
	_UIStyle.apply_button_style(skip, Color(0.16, 0.17, 0.22), Color(0.45, 0.48, 0.56))
	skip.pressed.connect(_finish)
	add_child(skip)

	# 시작 버튼 (하단 중앙) — 본문이 다 나온 뒤 페이드인
	_begin_btn = Button.new()
	_begin_btn.text = Locale.t("intro_begin")
	_begin_btn.custom_minimum_size = Vector2(260, 68)
	_begin_btn.add_theme_font_size_override("font_size", 26)
	_begin_btn.anchor_left = 0.5
	_begin_btn.anchor_right = 0.5
	_begin_btn.anchor_top = 0.86
	_begin_btn.anchor_bottom = 0.86
	_begin_btn.offset_left = -130.0
	_begin_btn.offset_right = 130.0
	_begin_btn.offset_top = 0.0
	_begin_btn.offset_bottom = 68.0
	_UIStyle.apply_button_style(_begin_btn, Color(0.14, 0.40, 0.20), Color(0.4, 0.85, 0.45))
	_begin_btn.modulate.a = 0.0
	_begin_btn.disabled = true
	_begin_btn.pressed.connect(_finish)
	add_child(_begin_btn)


## 줄을 차례로 페이드인 → 마지막에 시작 버튼 노출.
func _run_sequence() -> void:
	_seq = create_tween()
	for lbl in _lines:
		_seq.tween_property(lbl, "modulate:a", 1.0, FADE)
		_seq.tween_interval(HOLD)
	_seq.tween_callback(_show_begin)


func _show_begin() -> void:
	_running = false
	if not is_instance_valid(_begin_btn):
		return
	_begin_btn.disabled = false
	var tw := create_tween()
	tw.tween_property(_begin_btn, "modulate:a", 1.0, 0.4)


## 배경 탭: 재생 중이면 본문을 한 번에 다 보여주고 시작 버튼을 띄운다(빨리 읽기).
func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _running:
			_fast_forward()


func _fast_forward() -> void:
	if _done or not _running:
		return
	if _seq and _seq.is_valid():
		_seq.kill()
	for lbl in _lines:
		if is_instance_valid(lbl):
			lbl.modulate.a = 1.0
	_show_begin()


## 인트로 종료 → on_done 호출(보통 게임 씬으로 전환하며 이 노드도 함께 해제됨).
func _finish() -> void:
	if _done:
		return
	_done = true
	if _seq and _seq.is_valid():
		_seq.kill()
	var cb := _on_done
	if cb.is_valid():
		cb.call()
	else:
		queue_free()
