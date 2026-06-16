extends CanvasLayer
## 상점 패널: 웨이브 클리어 후 자동 등장. 골드로 캐릭터 업그레이드 구매.

const _UIStyle := preload("res://scripts/UIStyle.gd")

const UPGRADES: Array = [
	{"section": "WEAPON",    "id": "speed",            "label": "Move Speed",    "desc": "+30 move speed",           "costs": [10, 15, 20, 25]},
	{"section": "WEAPON",    "id": "atk_speed",        "label": "Atk Speed",     "desc": "-15% fire delay",          "costs": [15, 22, 30, 40]},
	{"section": "WEAPON",    "id": "bullet_damage",    "label": "Bullet Dmg",    "desc": "+1 bullet damage",         "costs": [20, 30, 45, 60]},
	{"section": "WEAPON",    "id": "multi_bullet",     "label": "Multi-Shot",    "desc": "+1 extra bullet",          "costs": [30, 50, 80]},
	{"section": "ORB",       "id": "orbs",             "label": "Orb Shield",    "desc": "+1 orbiting orb",          "costs": [25, 40, 60, 80]},
	{"section": "ORB",       "id": "orb_damage",       "label": "Orb Dmg",       "desc": "+1 orb damage",            "costs": [20, 30, 45, 60]},
	{"section": "LIGHTNING", "id": "lightning",        "label": "Lightning Bolt","desc": "Periodic strike + splash", "costs": [40, 65, 95, 130]},
	{"section": "LIGHTNING", "id": "lightning_damage", "label": "Lightning Dmg", "desc": "+1 lightning damage",      "costs": [20, 30, 45, 60]},
	{"section": "SURVIVAL",  "id": "max_health",       "label": "Max HP",        "desc": "+1 heart (heals)",         "costs": [12, 18, 26, 35]},
	{"section": "SURVIVAL",  "id": "heal",             "label": "Heal HP",       "desc": "Full HP restore",          "costs": [8,  8,  8,  8]},
]

const SECTION_COLORS: Dictionary = {
	"WEAPON":    Color(1.00, 0.75, 0.20),
	"ORB":       Color(0.45, 0.82, 1.00),
	"LIGHTNING": Color(0.65, 0.55, 1.00),
	"SURVIVAL":  Color(0.45, 0.85, 0.50),
}

var _panel: PanelContainer
var _wave_label: Label
var _gold_label: Label
var _buttons: Array = []
var _continue_btn: Button


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

	# 보유 골드
	_gold_label = _make_label("Gold: 0", 22, true)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	outer.add_child(_gold_label)

	outer.add_child(HSeparator.new())

	# 스크롤되는 업그레이드 목록 (섹션 헤더 포함)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var lbl := _make_label(section, 15)
	lbl.add_theme_color_override("font_color", SECTION_COLORS.get(section, Color.WHITE))
	return lbl


func _make_upgrade_button(upg: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 62)
	_apply_font(btn, 19)
	var id: String = upg["id"]
	var col: Color = SECTION_COLORS.get(upg["section"], Color(0.4, 0.4, 0.45))
	_UIStyle.apply_button_style(btn, col.darkened(0.82), col)
	btn.pressed.connect(_on_upgrade_pressed.bind(id))
	return btn


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
	_gold_label.text = "Gold: %d" % Events.total_gold
	for i in UPGRADES.size():
		var upg: Dictionary = UPGRADES[i]
		var id: String = upg["id"]
		var btn: Button = _buttons[i]
		var cost := _get_cost(upg)

		if id != "heal" and cost == -1:
			btn.text = "%s  [MAX]" % upg["label"]
			btn.disabled = true
		else:
			var lvl := _get_level(id)
			var max_lvl: int = upg["costs"].size()
			var lvl_str := (" Lv%d/%d" % [lvl, max_lvl]) if id != "heal" else ""
			btn.text = "%s%s  -%dG\n%s" % [upg["label"], lvl_str, cost, upg["desc"]]
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
