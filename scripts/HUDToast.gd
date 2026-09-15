class_name HUDToast
extends Control
## 화면 상단 토스트 레인 — 달성·과제·날씨·만렙 보상 알림이 **겹치지 않게** 줄을 선다.
##
## 왜 필요한가(UI_POLISH_PLAN §A-10): 예전에는 알림마다 그 자리에서 Label 을 만들어 띄웠고,
## 세로 위치는 호출부가 손으로 정한 상수(150 · 190 · 215)였다. 서로를 모르니 같은 순간에
## 둘이 뜨면 그대로 겹쳤다 — 후반에는 도전과제와 과제가 같은 처치 수에서 함께 달성된다.
##
## 여기서 정하는 규칙은 셋이다:
##   1. 동시에 보이는 것은 **1줄까지**. 그 이상은 앞줄이 사라진 뒤에 나온다.
##   2. 두 줄이 겹치지 않도록 뒤에 오는 줄은 앞줄보다 최소 SLOT_GAP 아래에 놓는다.
##   3. 같은 종류(kind)가 아직 떠 있으면 새 줄을 만들지 않고 **그 줄의 글자를 바꾼다**
##      — 날씨처럼 짧은 새에 여러 번 바뀌는 알림이 줄을 다 차지하지 않게.
##
## 호출부가 준 y 는 그대로 존중한다(각 알림의 자리는 다른 위젯을 피해 손으로 맞춘 값이다).
## 겹칠 때만 아래로 민다 — 한 줄만 뜰 때의 모습은 예전과 완전히 같다.
##
## 사용:
##     _toasts = HUDToast.make(self)
##     _toasts.push(text, color, 190.0, "quest")

const SLOT_GAP := 38.0     # 두 줄 사이 최소 간격(글꼴 22px + 외곽선 여유)
const MAX_VISIBLE := 1     # 동시에 보이는 줄 수
const RISE := 30.0         # 떠오르는 거리
const FONT_SIZE := 24

## [{node, y, kind, tw}] — 지금 화면에 있는 줄들.
var _active: Array = []
## [{text, col, y, kind}] — 자리가 나면 나갈 줄들.
var _queue: Array = []


static func make(parent: Node) -> HUDToast:
	var lane := HUDToast.new()
	lane.set_anchors_preset(Control.PRESET_FULL_RECT)
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lane)
	return lane


## 알림 한 줄. kind 를 주면 같은 종류가 떠 있을 때 새로 만들지 않고 갈아끼운다.
func push(text: String, col: Color, y: float, kind: String = "") -> void:
	if kind != "" and _replace_same_kind(text, col, kind):
		return
	if _active.size() >= MAX_VISIBLE:
		_queue.append({"text": text, "col": col, "y": y, "kind": kind})
		return
	_spawn(text, col, _free_y(y), kind)


## 같은 종류가 떠 있으면 글자만 바꾸고 머무는 시간을 다시 센다. 바꿨으면 true.
func _replace_same_kind(text: String, col: Color, kind: String) -> bool:
	for t in _active:
		if t["kind"] != kind:
			continue
		var lbl: Label = t["node"]
		if not is_instance_valid(lbl):
			continue
		lbl.text = text
		lbl.add_theme_color_override("font_color", col)
		if t["tw"] != null and t["tw"].is_valid():
			t["tw"].kill()
		# 이미 떠 있으므로 등장 연출은 생략하고 머무는 시간부터 다시 센다.
		lbl.modulate.a = 1.0
		t["tw"] = _hold_and_fade(lbl)
		return true
	return false


## 요청한 y 가 이미 쓰이고 있으면 그 아래로 민다.
func _free_y(want: float) -> float:
	var y := want
	for t in _active:
		if absf(t["y"] - y) < SLOT_GAP:
			y = t["y"] + SLOT_GAP
	return y


func _spawn(text: String, col: Color, y: float, kind: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	var screen := get_viewport_rect().size
	var portrait := screen.y > screen.x
	if portrait:
		# 세로 화면의 일반 알림도 우측 레인에 붙여 플레이어 주변을 가리지 않는다.
		lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		lbl.offset_left = -344
		lbl.offset_right = -24
	else:
		lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
		lbl.offset_left = -300
		lbl.offset_right = 300
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.offset_top = y
	lbl.offset_bottom = y + 52.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a = 0.0
	add_child(lbl)

	var entry := {"node": lbl, "y": y, "kind": kind, "tw": null}
	_active.append(entry)

	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, UIMotion.DUR_POP)
	tw.parallel().tween_property(lbl, "offset_top", y - RISE, UIMotion.DUR_POP)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entry["tw"] = tw
	tw.tween_callback(func() -> void:
		if is_instance_valid(lbl):
			entry["tw"] = _hold_and_fade(lbl))


## 머문 뒤 사라지고, 자리를 비우면서 대기 줄을 하나 꺼낸다.
func _hold_and_fade(lbl: Label) -> Tween:
	var tw := create_tween()
	tw.tween_interval(UIMotion.HOLD_INFO)
	tw.tween_property(lbl, "modulate:a", 0.0, UIMotion.DUR_OUT)
	tw.tween_callback(func() -> void: _retire(lbl))
	return tw


func _retire(lbl: Label) -> void:
	for i in range(_active.size() - 1, -1, -1):
		if _active[i]["node"] == lbl:
			_active.remove_at(i)
	if is_instance_valid(lbl):
		lbl.queue_free()
	if _queue.is_empty() or _active.size() >= MAX_VISIBLE:
		return
	var next: Dictionary = _queue.pop_front()
	_spawn(next["text"], next["col"], _free_y(next["y"]), next["kind"])


## 씬을 떠날 때 남은 예약을 비운다(트윈은 노드와 함께 정리된다).
func _exit_tree() -> void:
	_queue.clear()
