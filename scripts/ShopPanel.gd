extends CanvasLayer
## 상점 패널: 웨이브 클리어 후 자동 등장. 골드로 캐릭터 업그레이드 구매.

# id, 표시명, 설명, 레벨별 비용 배열 (배열 길이 = 최대 구매 횟수)
const UPGRADES: Array = [
	{"id": "speed",      "label": "이동 속도",    "desc": "이동속도 +30",       "costs": [10, 15, 20, 25]},
	{"id": "atk_speed",  "label": "공격 속도",    "desc": "발사 간격 -15%",     "costs": [15, 22, 30, 40]},
	{"id": "damage",     "label": "총알 데미지",  "desc": "총알 데미지 +1",     "costs": [20, 30, 45, 60]},
	{"id": "max_health", "label": "최대 체력",    "desc": "+1 하트 (즉시 회복)", "costs": [12, 18, 26, 35]},
	{"id": "heal",       "label": "체력 회복",    "desc": "체력 완전 회복",     "costs": [8,  8,  8,  8 ]},
]

var _kr_font = null
var _wave_label: Label
var _gold_label: Label
var _buttons: Array = []
var _continue_btn: Button


func _ready() -> void:
	layer = 10
	visible = false
	_kr_font = _load_kr_font()
	Events.wave_complete.connect(_on_wave_complete)
	_build_ui()


## .bin 파일에서 raw TTF 바이트를 읽어 FontFile.data 에 직접 주입 (HUD와 동일한 방식)
func _load_kr_font() -> Font:
	var fa := FileAccess.open("res://assets/fonts/NotoSansKR.bin", FileAccess.READ)
	if fa:
		var font := FontFile.new()
		font.data = fa.get_buffer(fa.get_length())
		fa.close()
		return font
	return null


func _on_wave_complete(wave: int) -> void:
	_wave_label.text = "Wave %d 클리어!" % wave
	_refresh_buttons()
	await get_tree().create_timer(2.1).timeout
	if not is_instance_valid(self):
		return
	visible = true


func _build_ui() -> void:
	# 전체화면 어두운 오버레이
	var overlay := ColorRect.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0, 0, 0, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 중앙 패널
	var panel := ColorRect.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -310.0
	panel.offset_top  = -370.0
	panel.offset_right = 310.0
	panel.offset_bottom = 370.0
	panel.color = Color(0.12, 0.13, 0.18, 1.0)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left",   20)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# 웨이브 클리어 제목
	_wave_label = _make_label("Wave 클리어!", 36, true)
	_wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(_wave_label)

	# 보유 골드
	_gold_label = _make_label("Gold: 0", 24, true)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vbox.add_child(_gold_label)

	vbox.add_child(HSeparator.new())

	# 업그레이드 버튼
	_buttons.clear()
	for upg: Dictionary in UPGRADES:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 72)
		_apply_font(btn, 20)
		var id: String = upg["id"]
		btn.pressed.connect(_on_upgrade_pressed.bind(id))
		vbox.add_child(btn)
		_buttons.append(btn)

	vbox.add_child(HSeparator.new())

	# 계속 버튼
	_continue_btn = Button.new()
	_continue_btn.text = "Continue ->"
	_continue_btn.custom_minimum_size = Vector2(0, 70)
	_apply_font(_continue_btn, 26)
	_continue_btn.pressed.connect(_on_continue)
	vbox.add_child(_continue_btn)


func _make_label(txt: String, size: int, centered: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	_apply_font(lbl, size)
	if centered:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _apply_font(node: Control, size: int) -> void:
	node.add_theme_font_size_override("font_size", size)
	if _kr_font:
		node.add_theme_font_override("font", _kr_font)


func _get_level(id: String) -> int:
	match id:
		"speed":      return Events.upgrade_speed
		"atk_speed":  return Events.upgrade_atk_speed
		"damage":     return Events.upgrade_damage
		"max_health": return Events.upgrade_max_health
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
		"speed":      Events.upgrade_speed += 1
		"atk_speed":  Events.upgrade_atk_speed += 1
		"damage":     Events.upgrade_damage += 1
		"max_health": Events.upgrade_max_health += 1
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
