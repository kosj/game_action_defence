extends CanvasLayer
## 카드 선택 패널: 웨이브 클리어 후 자동 등장.
## 골드를 내고 뒤집힌 카드(?) 한 벌을 뽑은 뒤, 그 중 하나를 골라 "까서"
## 랜덤 업그레이드 1개를 획득한다. 골드가 부족하면 뽑을 수 없다.

const _UIStyle := preload("res://scripts/UIStyle.gd")
const _COIN_ICON := preload("res://assets/ui/ui_coin.png")

const UPGRADES: Array = [
	{"section": "WEAPON",    "id": "speed",            "costs": [10, 15, 20, 25, 32, 40, 50, 62, 76, 92]},
	{"section": "WEAPON",    "id": "atk_speed",        "costs": [15, 22, 30, 40, 52, 66, 82, 100, 120, 142]},
	{"section": "WEAPON",    "id": "bullet_damage",    "costs": [20, 30, 45, 60, 80, 105, 135, 170, 210, 255]},
	{"section": "WEAPON",    "id": "multi_bullet",     "costs": [30, 50, 80, 120, 170, 230]},
	{"section": "ORB",       "id": "orbs",             "costs": [25, 40, 60, 80, 105, 135, 170, 210]},
	{"section": "ORB",       "id": "orb_damage",       "costs": [20, 30, 45, 60, 80, 105, 135, 170]},
	{"section": "LIGHTNING", "id": "lightning",        "costs": [40, 65, 95, 130, 170, 215, 265, 320]},
	{"section": "LIGHTNING", "id": "lightning_damage", "costs": [20, 30, 45, 60, 80, 105, 135, 170]},
	{"section": "SURVIVAL",  "id": "max_health",       "costs": [12, 18, 26, 35, 46, 58, 72, 88, 106, 126]},
	{"section": "SURVIVAL",  "id": "heal",             "costs": [8,  8,  8,  8]},
]

const SECTION_COLORS: Dictionary = {
	"WEAPON":    Color(1.00, 0.75, 0.20),
	"ORB":       Color(0.45, 0.82, 1.00),
	"LIGHTNING": Color(0.65, 0.55, 1.00),
	"SURVIVAL":  Color(0.45, 0.85, 0.50),
}

## 섹션별 대표 아이콘(UIIcon kind).
const SECTION_ICON: Dictionary = {
	"WEAPON": "sword", "ORB": "orb", "LIGHTNING": "bolt", "SURVIVAL": "heart",
}

## 뽑기 비용 = 기본 + 웨이브 보정 + 이번 등장에서 뽑은 횟수 * 증가분.
## 뽑을수록 비싸져 무한 뽑기를 막고, 후반 웨이브일수록 기본가가 오른다.
const DRAW_BASE := 12
const DRAW_WAVE_MULT := 4
const DRAW_STEP := 12

const CARD_COUNT := 3

var _panel: PanelContainer
var _wave_label: Label
var _gold_label: Label
var _result_label: Label
var _draw_btn: Button
var _continue_btn: Button
var _ad_gold_btn: Button
var _cards_row: HBoxContainer
var _cards: Array = []          # [{btn, q, face, icon, name}, ...]
var _deal: Array = []           # 이번 한 벌에 배정된 UPGRADES 인덱스(카드별)
var _ad_gold_claimed: bool = false   # 등장당 보상형 골드 1회만
var _draws_done: int = 0        # 이번 등장에서 뽑은 횟수
var _wave: int = 1
var _busy: bool = false         # 까는 연출 중
var _selectable: bool = false   # 카드를 고를 수 있는 상태(뽑은 직후)
var _hint_tween: Tween = null


func _ready() -> void:
	layer = 10
	visible = false
	Events.wave_complete.connect(_on_wave_complete)
	AdManager.rewarded_granted.connect(_on_rewarded_granted)
	_build_ui()


func _on_wave_complete(wave: int) -> void:
	_wave = wave
	_wave_label.text = Locale.t("wave_clear_fmt") % wave
	_ad_gold_claimed = false
	_draws_done = 0
	_busy = false
	_selectable = false
	_reset_cards_facedown()
	_result_label.text = Locale.t("pick_intro")
	_refresh()
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
	# 전체화면 어두운 그라데이션 오버레이(입력 차단)
	var overlay := UITheme.make_gradient_bg(Color(0.07, 0.08, 0.12, 0.85), Color(0.0, 0.0, 0.0, 0.92))
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 중앙 패널
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -320.0
	_panel.offset_top  = -420.0
	_panel.offset_right = 320.0
	_panel.offset_bottom = 420.0
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
	_wave_label = _make_label(Locale.t("shop_clear_title"), 34, true)
	_wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	UITheme.heading(_wave_label)
	outer.add_child(_wave_label)

	# 보유 골드
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

	# 보상형 광고: 보유 골드 보너스(최대 2배). 등장당 1회.
	_ad_gold_btn = Button.new()
	_ad_gold_btn.custom_minimum_size = Vector2(0, 48)
	_apply_font(_ad_gold_btn, 17)
	_ad_gold_btn.icon = _COIN_ICON
	_ad_gold_btn.add_theme_constant_override("icon_max_width", 22)
	_ad_gold_btn.add_theme_constant_override("h_separation", 8)
	_UIStyle.apply_button_style(_ad_gold_btn, Color(0.42, 0.30, 0.06), Color(1.0, 0.78, 0.22))
	_ad_gold_btn.pressed.connect(_on_ad_gold_pressed)
	outer.add_child(_ad_gold_btn)

	outer.add_child(HSeparator.new())

	# "테이블" 위의 미스터리 카드 한 벌
	var table := PanelContainer.new()
	table.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.06, 0.05, 0.09, 0.92), Color(0.30, 0.18, 0.34), 18, 2))
	outer.add_child(table)

	var table_margin := MarginContainer.new()
	table_margin.add_theme_constant_override("margin_left",   14)
	table_margin.add_theme_constant_override("margin_right",  14)
	table_margin.add_theme_constant_override("margin_top",    16)
	table_margin.add_theme_constant_override("margin_bottom", 16)
	table.add_child(table_margin)

	_cards_row = HBoxContainer.new()
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_row.add_theme_constant_override("separation", 12)
	table_margin.add_child(_cards_row)

	_cards.clear()
	for i in CARD_COUNT:
		var card := _make_card(i)
		_cards.append(card)
		_cards_row.add_child(card["btn"])

	# 결과 / 안내 텍스트
	_result_label = _make_label(Locale.t("pick_intro"), 22, true)
	_result_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
	_result_label.custom_minimum_size = Vector2(0, 32)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_result_label)

	# 뽑기 버튼 (골드 소모) — 뽑으면 카드가 선택 가능해진다.
	_draw_btn = Button.new()
	_draw_btn.custom_minimum_size = Vector2(0, 64)
	_apply_font(_draw_btn, 24)
	_draw_btn.icon = _COIN_ICON
	_draw_btn.add_theme_constant_override("icon_max_width", 26)
	_draw_btn.add_theme_constant_override("h_separation", 10)
	_UIStyle.apply_button_style(_draw_btn, Color(0.44, 0.20, 0.46), Color(0.85, 0.45, 0.95))
	_draw_btn.pressed.connect(_on_draw)
	outer.add_child(_draw_btn)

	outer.add_child(HSeparator.new())

	# 계속 버튼
	_continue_btn = Button.new()
	_continue_btn.text = Locale.t("shop_continue")
	_continue_btn.custom_minimum_size = Vector2(0, 58)
	_apply_font(_continue_btn, 24)
	_UIStyle.apply_button_style(_continue_btn, Color(0.14, 0.40, 0.20), Color(0.4, 0.85, 0.45))
	_continue_btn.pressed.connect(_on_continue)
	outer.add_child(_continue_btn)

	_reset_cards_facedown()


func _init_pivot() -> void:
	_panel.pivot_offset = _panel.size * 0.5


# ---------------------------------------------------------------- card build
func _make_card(idx: int) -> Dictionary:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(118, 152)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_UIStyle.apply_button_style(btn, Color(0.17, 0.12, 0.22), Color(0.60, 0.42, 0.75))
	btn.pressed.connect(_on_card_pressed.bind(idx))

	# 앞면/뒷면이 같은 자리에 겹치도록 CenterContainer 사용(각 자식이 중앙 정렬됨).
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(cc)

	# 뒷면: 큰 물음표
	var q := Label.new()
	q.text = "?"
	q.add_theme_font_size_override("font_size", 58)
	q.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.heading(q)
	cc.add_child(q)

	# 앞면(공개 시): 아이콘 + 이름
	var face := VBoxContainer.new()
	face.alignment = BoxContainer.ALIGNMENT_CENTER
	face.add_theme_constant_override("separation", 8)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.visible = false
	cc.add_child(face)

	var icon := UIIcon.make("star", 46, Color.WHITE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.add_child(icon)

	var nm := _make_label("", 15, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(104, 0)
	face.add_child(nm)

	return {"btn": btn, "q": q, "face": face, "icon": icon, "name": nm}


## 모든 카드를 비활성 뒷면(?) 상태로 되돌린다.
func _reset_cards_facedown() -> void:
	_stop_card_hint()
	for card: Dictionary in _cards:
		var btn: Button = card["btn"]
		btn.disabled = true
		btn.scale = Vector2.ONE
		btn.modulate = Color.WHITE
		card["q"].visible = true
		card["face"].visible = false


# ---------------------------------------------------------------- locale / font helpers
func _upg_name(upg: Dictionary) -> String:
	return Locale.t("upg_%s_name" % upg["id"])


func _make_label(txt: String, size: int, centered: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	_apply_font(lbl, size)
	if centered:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _apply_font(node: Control, size: int) -> void:
	node.add_theme_font_size_override("font_size", size)


# ---------------------------------------------------------------- upgrade state
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


## 최대 레벨 여부 (heal 은 반복 가능하므로 항상 false).
func _is_maxed(upg: Dictionary) -> bool:
	if upg["id"] == "heal":
		return false
	return _get_level(upg["id"]) >= int(upg["costs"].size())


## 카드에 배정 가능한 후보(최대치가 아닌 업그레이드) 인덱스 목록.
func _available_indices() -> Array:
	var arr: Array = []
	for i in UPGRADES.size():
		if not _is_maxed(UPGRADES[i]):
			arr.append(i)
	return arr


## 한 벌(CARD_COUNT장)에 배정할 업그레이드 인덱스 — 가능하면 서로 다르게.
func _deal_indices() -> Array:
	var pool := _available_indices()
	pool.shuffle()
	var out: Array = []
	for i in CARD_COUNT:
		out.append(pool[i % pool.size()])
	return out


func _draw_cost() -> int:
	return DRAW_BASE + _wave * DRAW_WAVE_MULT + _draws_done * DRAW_STEP


# ---------------------------------------------------------------- ad gold
func _ad_gold_bonus() -> int:
	return clampi(Events.total_gold, 30, 300)


func _update_ad_gold_btn() -> void:
	if _ad_gold_claimed:
		_ad_gold_btn.text = Locale.t("shop_ad_claimed")
		_ad_gold_btn.disabled = true
	elif not AdManager.is_rewarded_ready():
		_ad_gold_btn.text = Locale.t("shop_ad_unavail")
		_ad_gold_btn.disabled = true
	else:
		_ad_gold_btn.text = Locale.t("shop_ad_gold_fmt") % _ad_gold_bonus()
		_ad_gold_btn.disabled = _busy or _selectable


func _on_ad_gold_pressed() -> void:
	if _ad_gold_claimed or _busy or _selectable or not AdManager.is_rewarded_ready():
		return
	AdManager.show_rewarded("shop_gold")


func _on_rewarded_granted(placement: String) -> void:
	if placement != "shop_gold" or _ad_gold_claimed:
		return
	_ad_gold_claimed = true
	Events.add_gold(_ad_gold_bonus())
	_refresh()


# ---------------------------------------------------------------- refresh
func _refresh() -> void:
	_gold_label.text = "%d" % Events.total_gold
	_update_ad_gold_btn()

	var cost := _draw_cost()
	if _selectable:
		# 카드를 고르는 동안에는 뽑기 버튼을 숨긴다(행동은 카드 탭).
		_draw_btn.visible = false
	else:
		_draw_btn.visible = true
		if _busy:
			_draw_btn.disabled = true
		elif Events.total_gold < cost:
			_draw_btn.text = "%s  (-%dG)" % [Locale.t("spin_insufficient"), cost]
			_draw_btn.disabled = true
		else:
			_draw_btn.text = Locale.t("pick_draw_fmt") % cost
			_draw_btn.disabled = false


# ---------------------------------------------------------------- draw / pick
func _on_draw() -> void:
	if _busy or _selectable:
		return
	var cost := _draw_cost()
	# 골드가 부족하면 뽑을 수 없다.
	if not Events.spend_gold(cost):
		_refresh()
		return
	_draws_done += 1
	_deal = _deal_indices()
	_selectable = true

	# 카드를 활성 뒷면으로 세팅하고 "선택" 유도 연출 시작.
	for card: Dictionary in _cards:
		var btn: Button = card["btn"]
		btn.disabled = false
		btn.scale = Vector2.ONE
		btn.modulate = Color.WHITE
		card["q"].visible = true
		card["face"].visible = false
	_result_label.text = Locale.t("pick_hint")
	_continue_btn.disabled = true
	_start_card_hint()
	_refresh()


func _on_card_pressed(i: int) -> void:
	if not _selectable or _busy:
		return
	_selectable = false
	_busy = true
	_stop_card_hint()

	var picked: int = _deal[i]
	_grant_upgrade(UPGRADES[picked]["id"])
	_result_label.text = Locale.t("spin_result_fmt") % _upg_name(UPGRADES[picked])

	# 모든 카드를 까되, 고른 카드만 강조.
	for c in CARD_COUNT:
		_cards[c]["btn"].disabled = true
		_flip_reveal(_cards[c], _deal[c], c == i)

	await get_tree().create_timer(0.55).timeout
	if not is_instance_valid(self):
		return
	_busy = false
	_continue_btn.disabled = false
	_refresh()


## 카드 뒤집기(까기) 연출: 가로로 납작해졌다가 앞면으로 펴진다.
func _flip_reveal(card: Dictionary, upg_index: int, picked: bool) -> void:
	var btn: Button = card["btn"]
	btn.pivot_offset = btn.size * 0.5
	if not picked:
		btn.modulate = Color(1, 1, 1, 0.5)   # 안 고른 카드는 흐리게
	var tw := create_tween()
	tw.tween_property(btn, "scale:x", 0.06, 0.13).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_set_card_face.bind(card, upg_index))
	tw.tween_property(btn, "scale:x", 1.0, 0.13).set_trans(Tween.TRANS_SINE)
	if picked:
		tw.tween_property(btn, "scale", Vector2(1.12, 1.12), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.12)


## 카드 앞면을 해당 업그레이드 내용으로 채운다(? → 아이콘+이름).
func _set_card_face(card: Dictionary, upg_index: int) -> void:
	var upg: Dictionary = UPGRADES[upg_index]
	var col: Color = SECTION_COLORS.get(upg["section"], Color.WHITE)
	var ic: UIIcon = card["icon"]
	ic.kind = SECTION_ICON.get(upg["section"], "star")
	ic.color = col
	ic.queue_redraw()
	card["name"].text = _upg_name(upg)
	card["name"].add_theme_color_override("font_color", col.lightened(0.2))
	card["q"].visible = false
	card["face"].visible = true


## 고를 수 있는 동안 카드 줄을 은은하게 점멸시켜 선택을 유도한다.
func _start_card_hint() -> void:
	_stop_card_hint()
	_cards_row.modulate.a = 1.0
	_hint_tween = create_tween().set_loops()
	_hint_tween.tween_property(_cards_row, "modulate:a", 0.72, 0.55)
	_hint_tween.tween_property(_cards_row, "modulate:a", 1.0, 0.55)


func _stop_card_hint() -> void:
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = null
	if _cards_row:
		_cards_row.modulate.a = 1.0


## 비용 없이(뽑기 비용으로 이미 지불) 업그레이드 1단계를 적용한다.
func _grant_upgrade(id: String) -> void:
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
			var ph := get_tree().get_first_node_in_group("player")
			if ph and ph.has_method("heal_full"):
				ph.heal_full()

	if id != "heal":
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("apply_upgrades"):
			player.apply_upgrades()


func _on_continue() -> void:
	if _busy or _selectable:
		return
	visible = false
	Events.shop_closed.emit()
