extends CanvasLayer
## 레벨업 카드 선택(뱀서식 인게임 성장). 코인 수집으로 레벨업하면 게임을 잠시 멈추고
## 무기/패시브 아이템 3장 중 하나를 고른다(새 아이템 획득 또는 보유 아이템 레벨업).
## 카탈로그·슬롯 규칙은 ItemDB, 인벤토리는 Events.weapons/passives.

const _UIStyle := preload("res://scripts/UIStyle.gd")

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _card_box: VBoxContainer
var _pending: int = 0      # 대기 중인 레벨업 수(연속 레벨업 처리)
var _showing: bool = false
var _did_pause: bool = false   # 이 패널이 직접 일시정지를 걸었는가(상점 등 다른 정지와 충돌 방지)
var _evo_mode: bool = false     # 진화 선택 모드(진화 상자 개봉 시) — 일반 레벨업과 분리
var _evo_rules: Array = []      # 진화 모드에서 제시할 진화 규칙들


func _ready() -> void:
	layer = 11   # 상점(10)보다 위. 실제로는 상점과 동시에 뜨지 않는다(상점=웨이브 간, 레벨업=전투 중).
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS   # 트리를 멈춰도 이 UI 는 동작해야 한다
	Events.level_up.connect(_on_level_up)
	Events.evolution_offer.connect(_on_evolution_offer)
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


## 진화 보물상자 개봉 — 진화 선택지를 띄운다. 이미 다른 패널이 떠 있으면(전투 정지 중) 무시.
func _on_evolution_offer() -> void:
	if _showing:
		return
	var rules := Events.available_evolutions()
	if rules.is_empty():
		return
	_evo_mode = true
	_evo_rules = rules
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
	for c in _card_box.get_children():
		_card_box.remove_child(c)
		c.queue_free()
	if _evo_mode:
		_title.text = ">> EVOLUTION <<  CHOOSE ONE"
		if _evo_rules.is_empty():
			_close_evo()
			return
		for rule in _evo_rules:
			_card_box.add_child(_make_evolve_card(rule))
		_stagger_cards()
		return
	_title.text = "LEVEL %d  ·  CHOOSE AN UPGRADE" % Events.level
	var choices := _draw_choices(3)
	if choices.is_empty():
		# 올릴 아이템이 없다(전부 만렙·슬롯 꽉참) — 그냥 넘어간다.
		_consume_and_advance()
		return
	for ch in choices:
		_card_box.add_child(_make_card(ch))
	_stagger_cards()


## 카드 등장 연출 — 위에서부터 순차적으로(stagger) 페이드 인 해 선택지가 착착 깔리는 느낌을 준다.
func _stagger_cards() -> void:
	var i := 0
	for c in _card_box.get_children():
		c.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.05 * float(i))
		tw.tween_property(c, "modulate:a", 1.0, 0.22)
		i += 1


## 뽑기 후보: 보유 아이템(만렙 미만)은 "레벨업", 미보유 아이템은 슬롯 여유가 있으면 "새 아이템".
## 각 후보 = {"item": 카탈로그 dict, "lv": 현재레벨, "is_new": bool}. 무작위 n개.
func _draw_choices(n: int) -> Array:
	var choices: Array = []
	# 진화는 레벨업 카드가 아니라 "진화 보물상자" 개봉으로만 발동한다(Phase 3-B). 여기선 일반 아이템만.
	var avail: Array = []
	_collect(ItemDB.weapons(), Events.weapons, Events.weapons.size() < ItemDB.MAX_WEAPON_SLOTS, avail)
	_collect(ItemDB.passives(), Events.passives, Events.passives.size() < ItemDB.MAX_PASSIVE_SLOTS, avail)
	avail.shuffle()
	for a in avail:
		choices.append({"kind": "item", "data": a})
		if choices.size() >= n:
			break
	return choices


func _collect(catalog: Array, inv: Dictionary, slot_free: bool, out: Array) -> void:
	for item in catalog:
		var lv: int = int(inv.get(item["id"], 0))
		if item.get("evolved", false):
			# 진화 무기는 새 카드로 등장하지 않음(진화로만 획득). 보유 시 레벨업만 허용.
			if lv > 0 and lv < int(item["max"]):
				out.append({"item": item, "lv": lv, "is_new": false})
			continue
		if lv > 0:
			if lv < int(item["max"]):
				out.append({"item": item, "lv": lv, "is_new": false})
		elif slot_free:
			out.append({"item": item, "lv": 0, "is_new": true})


func _make_card(ch: Dictionary) -> Button:
	if ch["kind"] == "evolve":
		return _make_evolve_card(ch["rule"])
	return _make_item_card(ch["data"])


func _make_item_card(a: Dictionary) -> Button:
	var item: Dictionary = a["item"]
	var btn := _new_card_button()
	var tag: String = "NEW!" if a["is_new"] else "Lv.%d → %d" % [a["lv"], int(a["lv"]) + 1]
	btn.text = "%s  (%s)\n%s" % [item["name"], tag, item["desc"]]
	var col: Color = item["color"]
	_UIStyle.apply_button_style(btn, Color(col.r * 0.28, col.g * 0.28, col.b * 0.28, 1.0), col)
	_set_card_icon(btn, item.get("icon"))
	btn.pressed.connect(_on_pick.bind(String(item["id"])))
	return btn


func _make_evolve_card(rule: Dictionary) -> Button:
	var into := ItemDB.meta(rule["into"])
	var btn := _new_card_button()
	btn.text = ">> EVOLVE <<  %s\n%s" % [into["name"], into["desc"]]
	var gold := Color(1.0, 0.82, 0.28)
	_UIStyle.apply_button_style(btn, Color(0.34, 0.26, 0.06, 1.0), gold)
	btn.add_theme_color_override("font_color", gold)
	_set_card_icon(btn, into.get("icon"))
	btn.pressed.connect(_on_evolve.bind(String(rule["base"]), String(rule["into"])))
	return btn


const _SLOT_PX := 68
const _SLOT_LEFT := 12

## 카드 버튼 왼쪽에 아이템 슬롯 프레임(아이콘 포함)을 붙인다(아이콘 없으면 기존 색상 카드 그대로).
func _set_card_icon(btn: Button, icon) -> void:
	if icon == null or not (icon is Texture2D):
		return
	var slot := _UIStyle.make_item_slot(icon, _SLOT_PX)
	slot.anchor_top = 0.5
	slot.anchor_bottom = 0.5
	slot.offset_left = _SLOT_LEFT
	slot.offset_right = _SLOT_LEFT + _SLOT_PX
	slot.offset_top = -_SLOT_PX / 2.0
	slot.offset_bottom = _SLOT_PX / 2.0
	btn.add_child(slot)
	# 라벨이 슬롯을 넘지 않도록 좌측 여백을 슬롯 폭만큼 확보하고 왼쪽 정렬로 읽히게 한다.
	_UIStyle.set_button_content_margin_left(btn, _SLOT_LEFT + _SLOT_PX + 12)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT


func _new_card_button() -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 88)   # 좌측 슬롯 프레임(68px)이 들어갈 여유
	btn.add_theme_font_size_override("font_size", 22)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return btn


func _on_pick(id: String) -> void:
	Events.grant_item(id)   # 인벤토리 레벨 +1 후 upgrade_* 재계산
	_apply_and_advance()


func _on_evolve(base_id: String, into_id: String) -> void:
	Events.evolve(base_id, into_id)
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("apply_upgrades"):
		player.apply_upgrades()
	if _evo_mode:
		_close_evo()   # 진화 선택은 레벨업 대기열과 무관 — 바로 닫는다
	else:
		_consume_and_advance()   # (레거시 경로 — 현재는 진화가 카드로 안 뜨므로 사실상 미사용)


## 진화 선택 패널 닫기(게임 재개).
func _close_evo() -> void:
	_evo_mode = false
	_evo_rules = []
	_showing = false
	visible = false
	if _did_pause:
		get_tree().paused = false


func _apply_and_advance() -> void:
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
