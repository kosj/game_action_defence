extends Node
## 화면 디버그 로거 (Autoload "ScreenLog")
## ScreenLog.info("msg") / .warn("msg") / .err("msg") 로 어디서든 화면 출력

const MAX_LINES := 18
const LINE_H := 20

var _layer: CanvasLayer
var _vbox: VBoxContainer
var _lines: Array = []   # Array[Label]


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 99
	add_child(_layer)

	var bg := ColorRect.new()
	bg.anchor_right = 0.65
	bg.offset_top = 120.0
	bg.offset_bottom = 120.0 + MAX_LINES * LINE_H + 8
	bg.color = Color(0, 0, 0, 0.72)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(bg)

	_vbox = VBoxContainer.new()
	_vbox.anchor_right = 0.65
	_vbox.offset_top = 122.0
	_vbox.offset_bottom = bg.offset_bottom
	_vbox.add_theme_constant_override("separation", 1)
	_layer.add_child(_vbox)

	info("[ScreenLog] ready")


func info(text: String) -> void:
	_add(text, Color.WHITE)

func warn(text: String) -> void:
	_add(text, Color(1.0, 0.85, 0.2))

func err(text: String) -> void:
	_add(text, Color(1.0, 0.35, 0.35))

func ok(text: String) -> void:
	_add(text, Color(0.4, 1.0, 0.5))


func _add(text: String, col: Color) -> void:
	print("[DBG] ", text)
	if _lines.size() >= MAX_LINES:
		var old: Label = _lines.pop_front()
		old.queue_free()
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", col)
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.clip_text = true
	_vbox.add_child(lbl)
	_lines.append(lbl)
