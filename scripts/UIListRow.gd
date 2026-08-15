class_name UIListRow
extends RefCounted
## 팝업 리스트의 공통 항목 카드 — 퀘스트·도전과제·보상함이 같은 문법으로 보이게 한다.
##
## 이전에는 패널마다 라벨을 직접 쌓아 올려(제목 한 줄, 설명 한 줄, 맨 진행바) 항목의
## 경계도 상태도 드러나지 않았다. 여기서는 한 장의 카드로 묶고, 좌측 아이콘 슬롯 +
## 진행 게이지 + 상태 테두리로 "완성된 목록"처럼 읽히게 한다.
##
## 배치:
##   ┌──────────────────────────────────────────┐
##   │ [슬롯]  제목 ····················  +보상  │
##   │  44px   설명 (진행수)                     │
##   │         ▓▓▓▓▓▓▓░░░░░░░░  게이지           │
##   └──────────────────────────────────────────┘
##
## 사용:
##   list.add_child(UIListRow.make({
##       "icon": "skull", "icon_color": Color(1, 0.6, 0.6),
##       "title": "Zombie Hunter X", "reward": 2307,
##       "desc": "Kill 10878 zombies", "cur": 2379, "goal": 10878,
##       "state": UIListRow.STATE_ACTIVE}))

const _UIStyle := preload("res://scripts/UIStyle.gd")

## 항목 상태 — 테두리·명도로 구분한다(아레나 카드의 선택/잠금 문법과 동일한 규칙).
enum { STATE_ACTIVE, STATE_READY, STATE_DONE }

const SLOT_PX := 44
const GAUGE_H := 20


## cfg 키(전부 선택):
##   icon:String, icon_color:Color, title:String, title_color:Color,
##   reward:int(0이면 숨김), desc:String, cur:int, goal:int(0이면 게이지 없음),
##   state:int, action:Dictionary{text, on_pressed:Callable, accent:Color}
static func make(cfg: Dictionary) -> Control:
	var state: int = int(cfg.get("state", STATE_ACTIVE))

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_box(state))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 9)
	pad.add_theme_constant_override("margin_bottom", 10)
	card.add_child(pad)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 11)
	pad.add_child(root)

	# ── 좌측 아이콘 슬롯 (HUD 의 미니 슬롯 프레임 재사용 — 신규 아트 없음) ──
	var kind := String(cfg.get("icon", ""))
	if kind != "":
		root.add_child(_slot(kind, cfg.get("icon_color", Color(0.85, 0.88, 0.95)), state))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.add_child(col)

	# ── 제목 줄: [제목 ······ +보상] ──
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)

	var title := Label.new()
	title.text = String(cfg.get("title", ""))
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", cfg.get("title_color", _title_color(state)))
	title.clip_text = true   # autowrap 은 컨테이너에서 최소 높이를 부풀린다 — 잘라내기로 처리
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var reward := int(cfg.get("reward", 0))
	if reward > 0:
		head.add_child(_reward_tag(reward, state))

	# ── 설명 줄 (진행 수치 포함) ──
	var desc_txt := String(cfg.get("desc", ""))
	if desc_txt != "":
		var desc := Label.new()
		desc.text = desc_txt
		desc.add_theme_font_size_override("font_size", 14)
		desc.add_theme_color_override("font_color", Color(0.70, 0.74, 0.80) if state != STATE_DONE else Color(0.50, 0.52, 0.58))
		desc.clip_text = true
		col.add_child(desc)

	# ── 진행 게이지 — 0% 에서도 트랙이 보이므로 "빈 행"으로 보이지 않는다 ──
	var goal := int(cfg.get("goal", 0))
	if goal > 0:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, GAUGE_H)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.max_value = float(goal)
		bar.value = clampf(float(cfg.get("cur", 0)), 0.0, float(goal))
		bar.show_percentage = false
		if state == STATE_READY:
			# 완료 항목은 채움을 초록으로. 스타일박스를 여기서 직접 만든다 —
			# static 함수에서 오토로드(UITheme)를 참조하지 않기 위해서다.
			var done_fill := StyleBoxFlat.new()
			done_fill.bg_color = Color(0.55, 1.0, 0.55)
			done_fill.set_corner_radius_all(6)
			done_fill.corner_detail = 6
			done_fill.anti_aliasing = true
			bar.add_theme_stylebox_override("fill", done_fill)
		col.add_child(bar)

	# ── 우측 액션 버튼(보상함의 CLAIM 등) ──
	var action: Dictionary = cfg.get("action", {})
	if not action.is_empty():
		var btn := Button.new()
		btn.text = String(action.get("text", ""))
		btn.custom_minimum_size = Vector2(96, 44)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.add_theme_font_size_override("font_size", 16)
		_UIStyle.apply_button_style(btn, UITheme.BTN_BG, action.get("accent", Color(0.5, 0.95, 0.5)))
		var cb = action.get("on_pressed")
		if typeof(cb) == TYPE_CALLABLE:
			btn.pressed.connect(cb)
		root.add_child(btn)

	return card


## 카드 배경 — 상태별 테두리. 수령 대기(READY)만 금색으로 튀게 해 시선을 끈다.
static func _card_box(state: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(9)
	sb.corner_detail = 6
	sb.anti_aliasing = true
	sb.set_border_width_all(1)
	match state:
		STATE_READY:
			sb.bg_color = Color(0.14, 0.12, 0.05, 0.92)
			sb.border_color = Color(1.0, 0.82, 0.30, 0.85)
			sb.set_border_width_all(2)
		STATE_DONE:
			sb.bg_color = Color(0.06, 0.07, 0.09, 0.55)
			sb.border_color = Color(0.30, 0.33, 0.38, 0.45)
		_:
			sb.bg_color = Color(0.07, 0.08, 0.11, 0.80)
			sb.border_color = Color(0.36, 0.40, 0.48, 0.55)
	return sb


static func _title_color(state: int) -> Color:
	match state:
		STATE_READY: return Color(1.0, 0.88, 0.42)
		STATE_DONE:  return Color(0.58, 0.62, 0.68)
		_:           return Color(0.93, 0.95, 0.99)


## 아이콘 슬롯 — HUD 미니 슬롯 프레임(hud_slot_small.png)이 있으면 그 위에 아이콘을 얹고,
## 없으면 둥근 사각 폴백으로 그린다.
static func _slot(kind: String, col: Color, state: int) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
	root.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := _UIStyle.hud_tex("hud_slot_small.png")
	if tex:
		frame.add_theme_stylebox_override("panel", _UIStyle.tex_box(tex, 12))
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.05, 0.08, 0.8)
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.35, 0.38, 0.45, 0.6)
		frame.add_theme_stylebox_override("panel", sb)
	root.add_child(frame)

	var ic := UIIcon.make(kind, 24, col if state != STATE_DONE else col.darkened(0.45))
	ic.set_anchors_preset(Control.PRESET_CENTER)
	ic.offset_left = -12.0
	ic.offset_right = 12.0
	ic.offset_top = -12.0
	ic.offset_bottom = 12.0
	root.add_child(ic)

	# 완료 표시 — 슬롯 우하단에 작은 초록 체크(달성/수령 완료를 한눈에).
	if state == STATE_DONE:
		var chk := Label.new()
		chk.text = "v"
		chk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chk.add_theme_font_size_override("font_size", 13)
		chk.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
		chk.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		chk.add_theme_constant_override("outline_size", 4)
		chk.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		chk.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		chk.grow_vertical = Control.GROW_DIRECTION_BEGIN
		chk.offset_right = -2.0
		chk.offset_bottom = 0.0
		chk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(chk)
	return root


## 보상 표시 — "+2307 gold" 텍스트 대신 코인 아이콘 + 숫자(언어에 무관하고 눈에 빠르다).
static func _reward_tag(amount: int, state: int) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dim := state == STATE_DONE
	box.add_child(UIIcon.make("coin", 16, Color(1.0, 0.82, 0.30) if not dim else Color(0.5, 0.45, 0.3)))
	var lbl := Label.new()
	lbl.text = "%d" % amount
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42) if not dim else Color(0.52, 0.48, 0.38))
	box.add_child(lbl)
	return box
