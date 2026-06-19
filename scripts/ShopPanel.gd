extends CanvasLayer
## 상점 패널: 웨이브 클리어 후 자동 등장. 골드로 캐릭터 업그레이드 구매.

const _UIStyle := preload("res://scripts/UIStyle.gd")
const _COIN_ICON := preload("res://assets/ui/ui_coin.png")

const UPGRADES: Array = [
	{"section": "WEAPON",    "id": "speed",            "label": "Move Speed",    "desc": "+30 move speed",           "costs": [10, 15, 20, 25, 32, 40, 50, 62, 76, 92]},
	{"section": "WEAPON",    "id": "atk_speed",        "label": "Atk Speed",     "desc": "-15% fire delay",          "costs": [15, 22, 30, 40, 52, 66, 82, 100, 120, 142]},
	{"section": "WEAPON",    "id": "bullet_damage",    "label": "Bullet Dmg",    "desc": "+1 bullet damage",         "costs": [20, 30, 45, 60, 80, 105, 135, 170, 210, 255]},
	{"section": "WEAPON",    "id": "multi_bullet",     "label": "Multi-Shot",    "desc": "+1 extra bullet",          "costs": [30, 50, 80, 120, 170, 230]},
	{"section": "ORB",       "id": "orbs",             "label": "Orb Shield",    "desc": "+1 orbiting orb",          "costs": [25, 40, 60, 80, 105, 135, 170, 210]},
	{"section": "ORB",       "id": "orb_damage",       "label": "Orb Dmg",       "desc": "+1 orb damage",            "costs": [20, 30, 45, 60, 80, 105, 135, 170]},
	{"section": "LIGHTNING", "id": "lightning",        "label": "Lightning Bolt","desc": "Faster strikes",           "costs": [40, 65, 95, 130, 170, 215, 265, 320]},
	{"section": "LIGHTNING", "id": "lightning_damage", "label": "Lightning Dmg", "desc": "+1 lightning damage",      "costs": [20, 30, 45, 60, 80, 105, 135, 170]},
	{"section": "SURVIVAL",  "id": "max_health",       "label": "Max HP",        "desc": "+1 heart (heals)",         "costs": [12, 18, 26, 35, 46, 58, 72, 88, 106, 126]},
	{"section": "SURVIVAL",  "id": "heal",             "label": "Heal HP",       "desc": "Full HP restore",          "costs": [8,  8,  8,  8]},
]

const SECTION_COLORS: Dictionary = {
	"WEAPON":    Color(1.00, 0.75, 0.20),
	"ORB":       Color(0.45, 0.82, 1.00),
	"LIGHTNING": Color(0.65, 0.55, 1.00),
	"SURVIVAL":  Color(0.45, 0.85, 0.50),
}

## 누른 지점에서 이만큼(px) 이상 드래그되면 탭이 아니라 스크롤로 간주해 구매를 취소.
const SCROLL_TAP_THRESHOLD := 12.0

var _panel: PanelContainer
var _wave_label: Label
var _gold_label: Label
var _buttons: Array = []
var _continue_btn: Button
var _scroll: ScrollContainer
var _dragging: bool = false
var _drag_total: float = 0.0


func _ready() -> void:
	layer = 10
	visible = false
	Events.wave_complete.connect(_on_wave_complete)
	_build_ui()


func _on_wave_complete(wave: int) -> void:
	_wave_label.text = "Wave %d Clear!" % wave
	_refresh_buttons()
	await get_tree().create_timer(2.1).timeout
	if not is_instance_valid(self):
		return
	visible = true
	_panel.scale = Vector2(0.85, 0.85)
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.2)


func _build_ui() -> void:
	# 전체화면 어두운 오버레이
	var overlay := ColorRect.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 중앙 패널 (둥근 모서리 + 테두리 + 그림자)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -320.0
	_panel.offset_top  = -460.0
	_panel.offset_right = 320.0
	_panel.offset_bottom = 460.0
	_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.10, 0.11, 0.16, 0.97), Color(0.35, 0.38, 0.5)))
	add_child(_panel)
	call_deferred("_init_pivot")

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   22)
	margin.add_theme_constant_override("margin_right",  22)
	margin.add_theme_constant_override("margin_top",    22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	# 웨이브 클리어 제목
	_wave_label = _make_label("Wave Clear!", 34, true)
	_wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	outer.add_child(_wave_label)

	# 보유 골드 (코인 아이콘 + 수량)
	var gold_row := HBoxContainer.new()
	gold_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_row.add_theme_constant_override("separation", 6)
	outer.add_child(gold_row)

	var coin_icon := TextureRect.new()
	coin_icon.texture = _COIN_ICON
	coin_icon.custom_minimum_size = Vector2(26, 26)
	coin_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_row.add_child(coin_icon)

	_gold_label = _make_label("0", 22)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	gold_row.add_child(_gold_label)

	outer.add_child(HSeparator.new())

	# 스크롤되는 업그레이드 목록 (섹션 헤더 포함)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.gui_input.connect(_on_scroll_gui_input)
	outer.add_child(scroll)
	_scroll = scroll

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# PASS: 버튼이 누름은 그대로 처리하면서도 드래그 이벤트가 위의 scroll 까지 전달되게 한다.
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(list)

	_buttons.clear()
	var last_section := ""
	for upg: Dictionary in UPGRADES:
		var section: String = upg["section"]
		if section != last_section:
			list.add_child(_make_section_header(section))
			last_section = section
		var btn := _make_upgrade_button(upg)
		list.add_child(btn)
		_buttons.append(btn)

	outer.add_child(HSeparator.new())

	# 계속 버튼
	_continue_btn = Button.new()
	_continue_btn.text = "Continue ->"
	_continue_btn.custom_minimum_size = Vector2(0, 66)
	_apply_font(_continue_btn, 26)
	_UIStyle.apply_button_style(_continue_btn, Color(0.14, 0.40, 0.20), Color(0.4, 0.85, 0.45))
	_continue_btn.pressed.connect(_on_continue)
	outer.add_child(_continue_btn)


func _init_pivot() -> void:
	_panel.pivot_offset = _panel.size * 0.5


func _make_section_header(section: String) -> Label:
	var lbl := _make_label("-- %s" % section, 15)
	lbl.add_theme_color_override("font_color", SECTION_COLORS.get(section, Color.WHITE))
	return lbl


func _make_upgrade_button(upg: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 62)
	_apply_font(btn, 19)
	var id: String = upg["id"]
	var col: Color = SECTION_COLORS.get(upg["section"], Color(0.4, 0.4, 0.45))
	_UIStyle.apply_button_style(btn, col.darkened(0.82), col)
	# 섹션 색상의 굵은 좌측 띠로 카테고리를 한눈에 구분
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var sb := btn.get_theme_stylebox(state_name) as StyleBoxFlat
		if sb:
			sb.border_width_left = 7
	btn.icon = _COIN_ICON
	btn.add_theme_constant_override("icon_max_width", 26)
	btn.add_theme_constant_override("h_separation", 10)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS   # 드래그를 위 scroll 으로도 전달
	btn.pressed.connect(_on_upgrade_tap.bind(id))
	return btn


## 모바일 터치 드래그로 스크롤 — Godot ScrollContainer 는 터치 드래그를 안정적으로
## 처리하지 못해(특히 버튼 위에서) 직접 입력을 받아 scroll_vertical 을 갱신한다.
func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_drag_total = 0.0
	elif event is InputEventMouseMotion and _dragging:
		_scroll.scroll_vertical -= int(event.relative.y)
		_drag_total += absf(event.relative.y)


## 버튼 클릭이 일정 거리 이상의 드래그(스크롤)였다면 구매로 처리하지 않는다.
func _on_upgrade_tap(id: String) -> void:
	if _drag_total > SCROLL_TAP_THRESHOLD:
		return
	_on_upgrade_pressed(id)


func _make_label(txt: String, size: int, centered: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	_apply_font(lbl, size)
	if centered:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _apply_font(node: Control, size: int) -> void:
	node.add_theme_font_size_override("font_size", size)


func _get_level(id: String) -> int:
	match id:
		"speed":            return Events.upgrade_speed
		"atk_speed":        return Events.upgrade_atk_speed
		"bullet_damage":    return Events.upgrade_bullet_damage
		"orb_damage":       return Events.upgrade_orb_damage
		"lightning_damage": return Events.upgrade_lightning_damage
		"multi_bullet":     return Events.upgrade_multi_bullet
		"orbs":             return Events.upgrade_orbs
		"lightning":        return Events.upgrade_lightning
		"max_health":       return Events.upgrade_max_health
	return 0


func _get_cost(upg: Dictionary) -> int:
	var costs: Array = upg["costs"]
	var lvl := _get_level(upg["id"])
	if lvl >= costs.size():
		return -1   # 최대 레벨
	return costs[lvl]


func _refresh_buttons() -> void:
	_gold_label.text = "%d" % Events.total_gold
	for i in UPGRADES.size():
		var upg: Dictionary = UPGRADES[i]
		var id: String = upg["id"]
		var btn: Button = _buttons[i]
		var cost := _get_cost(upg)

		if id != "heal" and cost == -1:
			btn.text = "%s  [MAX]\n%s" % [upg["label"], upg["desc"]]
			btn.disabled = true
		else:
			var lvl := _get_level(id)
			var max_lvl: int = upg["costs"].size()
			var lvl_str := ("  (%d/%d)" % [lvl, max_lvl]) if id != "heal" else ""
			btn.text = "%s%s\n-%dG   %s" % [upg["label"], lvl_str, cost, upg["desc"]]
			btn.disabled = Events.total_gold < cost


func _on_upgrade_pressed(id: String) -> void:
	var matches := UPGRADES.filter(func(u: Dictionary) -> bool: return u["id"] == id)
	if matches.is_empty():
		return
	var upg: Dictionary = matches[0]
	var cost := _get_cost(upg)
	if cost == -1 or not Events.spend_gold(cost):
		return

	match id:
		"speed":            Events.upgrade_speed += 1
		"atk_speed":        Events.upgrade_atk_speed += 1
		"bullet_damage":    Events.upgrade_bullet_damage += 1
		"orb_damage":       Events.upgrade_orb_damage += 1
		"lightning_damage": Events.upgrade_lightning_damage += 1
		"multi_bullet":     Events.upgrade_multi_bullet += 1
		"orbs":             Events.upgrade_orbs += 1
		"lightning":        Events.upgrade_lightning += 1
		"max_health":       Events.upgrade_max_health += 1
		"heal":
			var player := get_tree().get_first_node_in_group("player")
			if player and player.has_method("heal_full"):
				player.heal_full()

	if id != "heal":
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("apply_upgrades"):
			player.apply_upgrades()

	_refresh_buttons()


func _on_continue() -> void:
	visible = false
	Events.shop_closed.emit()
