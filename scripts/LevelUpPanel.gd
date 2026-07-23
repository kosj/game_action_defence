extends CanvasLayer
## 레벨업 카드 선택(뱀서식 인게임 성장). 코인 수집으로 레벨업하면 게임을 잠시 멈추고
## 3개 강화 카드 중 하나를 고른다 → 즉시 적용되어 실시간으로 강해진다.
## 웨이브 간 상점(골드 소비)과 별개로 함께 굴러간다(강화는 같은 upgrade_* 카운터에 누적).

const _UIStyle := preload("res://scripts/UIStyle.gd")

const _WEAPON := Color(1.00, 0.75, 0.20)
const _ORB := Color(0.45, 0.82, 1.00)
const _LIGHT := Color(0.65, 0.55, 1.00)
const _SURV := Color(0.45, 0.85, 0.50)

# 강화 카드 풀. max=이 판에서 카드로 올릴 수 있는 상한. gate=선행 강화가 있어야 등장.
const PERKS: Array = [
	{"id": "bullet_damage",    "label": "Bullet Dmg",     "desc": "+1 bullet damage",   "color": _WEAPON, "max": 15},
	{"id": "atk_speed",        "label": "Atk Speed",      "desc": "-15% fire delay",    "color": _WEAPON, "max": 10},
	{"id": "speed",            "label": "Move Speed",     "desc": "+30 move speed",     "color": _WEAPON, "max": 10},
	{"id": "multi_bullet",     "label": "Multi-Shot",     "desc": "+1 extra bullet",    "color": _WEAPON, "max": 6},
	{"id": "crit",             "label": "Crit Chance",    "desc": "+8% double damage",  "color": _WEAPON, "max": 7},
	{"id": "orbs",             "label": "Orb Shield",     "desc": "+1 orbiting orb",    "color": _ORB,    "max": 8},
	{"id": "orb_damage",       "label": "Orb Dmg",        "desc": "+1 orb damage",      "color": _ORB,    "max": 8, "gate": "orbs"},
	{"id": "orb_speed",        "label": "Orb Speed",      "desc": "+35% orbit speed",   "color": _ORB,    "max": 7, "gate": "orbs"},
	{"id": "lightning_count",  "label": "Lightning Count","desc": "+1 lightning bolt",  "color": _LIGHT,  "max": 7},
	{"id": "lightning_damage", "label": "Lightning Dmg",  "desc": "+1 lightning damage","color": _LIGHT,  "max": 8, "gate": "lightning_count"},
	{"id": "max_health",       "label": "Max HP",         "desc": "+1 heart (heals)",   "color": _SURV,   "max": 10},
	{"id": "regen",            "label": "HP Regen",       "desc": "Regen HP over time", "color": _SURV,   "max": 6},
	{"id": "pickup_range",     "label": "Pickup Range",   "desc": "+30% magnet range",  "color": _SURV,   "max": 6},
]

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _card_box: VBoxContainer
var _pending: int = 0      # 대기 중인 레벨업 수(연속 레벨업 처리)
var _showing: bool = false
var _did_pause: bool = false   # 이 패널이 직접 일시정지를 걸었는가(상점 등 다른 정지와 충돌 방지)


func _ready() -> void:
	layer = 11   # 상점(10)보다 위. 실제로는 상점과 동시에 뜨지 않는다(상점=웨이브 간, 레벨업=전투 중).
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS   # 트리를 멈춰도 이 UI 는 동작해야 한다
	Events.level_up.connect(_on_level_up)
	_build_ui()


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.62)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.08, 0.09, 0.13, 0.97), Color(1.0, 0.82, 0.3), 22, 3))
	center.add_child(_panel)

	# 계층: panel → margin → vb(제목 + 카드 목록)
	var margin := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, 22)
	_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.custom_minimum_size = Vector2(440, 0)
	margin.add_child(vb)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vb.add_child(_title)

	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 12)
	vb.add_child(_card_box)


func _on_level_up(_level: int) -> void:
	_pending += 1
	if not _showing:
		_present()


func _present() -> void:
	_showing = true
	_did_pause = not get_tree().paused   # 이미 정지 중(상점 등)이면 우리가 해제하지 않는다
	get_tree().paused = true
	visible = true
	_refresh()
	_panel.scale = Vector2(0.85, 0.85)
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.2)


func _refresh() -> void:
	_title.text = "LEVEL %d  ·  CHOOSE AN UPGRADE" % Events.level
	for c in _card_box.get_children():
		_card_box.remove_child(c)
		c.queue_free()
	var choices := _draw_choices(3)
	if choices.is_empty():
		# 올릴 강화가 없다(전부 상한) — 그냥 넘어간다.
		_consume_and_advance()
		return
	for perk in choices:
		_card_box.add_child(_make_card(perk))


## 등장 가능한(상한 미만·선행 충족) 강화 중 무작위 n개.
func _draw_choices(n: int) -> Array:
	var avail: Array = []
	for perk in PERKS:
		if _perk_level(perk["id"]) >= int(perk["max"]):
			continue
		if perk.has("gate") and _perk_level(perk["gate"]) <= 0:
			continue
		avail.append(perk)
	avail.shuffle()
	return avail.slice(0, mini(n, avail.size()))


func _make_card(perk: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 72)
	btn.add_theme_font_size_override("font_size", 22)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lvl := _perk_level(perk["id"])
	btn.text = "%s  (Lv.%d)\n%s" % [perk["label"], lvl + 1, perk["desc"]]
	var col: Color = perk["color"]
	_UIStyle.apply_button_style(btn, Color(col.r * 0.28, col.g * 0.28, col.b * 0.28, 1.0), col)
	btn.pressed.connect(_on_pick.bind(String(perk["id"])))
	return btn


func _on_pick(id: String) -> void:
	_apply(id)
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("apply_upgrades"):
		player.apply_upgrades()   # shop_closed 를 쓰지 않는다(그건 새 웨이브를 시작시킨다)
	_consume_and_advance()


## 이번 레벨업을 소비하고, 남은 레벨업이 있으면 새 카드로 이어서, 없으면 닫고 게임 재개.
func _consume_and_advance() -> void:
	_pending -= 1
	if _pending > 0:
		_refresh()
	else:
		_showing = false
		visible = false
		if _did_pause:
			get_tree().paused = false


func _apply(id: String) -> void:
	match id:
		"speed":            Events.upgrade_speed += 1
		"atk_speed":        Events.upgrade_atk_speed += 1
		"bullet_damage":    Events.upgrade_bullet_damage += 1
		"multi_bullet":     Events.upgrade_multi_bullet += 1
		"orbs":             Events.upgrade_orbs += 1
		"orb_damage":       Events.upgrade_orb_damage += 1
		"orb_speed":        Events.upgrade_orb_speed += 1
		"lightning_count":  Events.upgrade_lightning_count += 1
		"lightning_damage": Events.upgrade_lightning_damage += 1
		"max_health":       Events.upgrade_max_health += 1
		"crit":             Events.upgrade_crit += 1
		"regen":            Events.upgrade_regen += 1
		"pickup_range":     Events.upgrade_pickup_range += 1


func _perk_level(id: String) -> int:
	match id:
		"speed":            return Events.upgrade_speed
		"atk_speed":        return Events.upgrade_atk_speed
		"bullet_damage":    return Events.upgrade_bullet_damage
		"multi_bullet":     return Events.upgrade_multi_bullet
		"orbs":             return Events.upgrade_orbs
		"orb_damage":       return Events.upgrade_orb_damage
		"orb_speed":        return Events.upgrade_orb_speed
		"lightning_count":  return Events.upgrade_lightning_count
		"lightning_damage": return Events.upgrade_lightning_damage
		"max_health":       return Events.upgrade_max_health
		"crit":             return Events.upgrade_crit
		"regen":            return Events.upgrade_regen
		"pickup_range":     return Events.upgrade_pickup_range
	return 0
