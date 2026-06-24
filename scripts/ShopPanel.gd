extends CanvasLayer
## 룰렛 패널: 웨이브 클리어 후 자동 등장. 골드를 내고 룰렛을 돌려
## 랜덤하게 업그레이드 1개를 획득한다. 골드가 부족하면 돌릴 수 없다.

const _UIStyle := preload("res://scripts/UIStyle.gd")
const _RouletteWheel := preload("res://scripts/RouletteWheel.gd")
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

## 스핀 비용 = 기본 + 웨이브 보정 + 이번 등장에서 돌린 횟수 * 증가분.
## 돌릴수록 비싸져 무한 스핀을 막고, 후반 웨이브일수록 기본가가 오른다.
const SPIN_BASE := 12
const SPIN_WAVE_MULT := 4
const SPIN_STEP := 12

const WHEEL_SIZE := 320.0

var _panel: PanelContainer
var _wave_label: Label
var _gold_label: Label
var _result_label: Label
var _spin_btn: Button
var _continue_btn: Button
var _ad_gold_btn: Button
var _wheel: Control
var _ad_gold_claimed: bool = false   # 등장당 보상형 골드 1회만
var _spins_done: int = 0             # 이번 등장에서 돌린 횟수
var _wave: int = 1
var _spinning: bool = false


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
	_spins_done = 0
	_spinning = false
	_result_label.text = Locale.t("spin_hint")
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
	_panel.offset_top  = -440.0
	_panel.offset_right = 320.0
	_panel.offset_bottom = 440.0
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

	# 룰렛 휠 + 상단 포인터
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(WHEEL_SIZE, WHEEL_SIZE)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.add_child(holder)

	_wheel = _RouletteWheel.new()
	_wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 휠은 holder(고정 크기) 를 꽉 채우므로 회전 중심을 직접 지정.
	_wheel.pivot_offset = Vector2(WHEEL_SIZE, WHEEL_SIZE) * 0.5
	holder.add_child(_wheel)

	var pointer := Label.new()
	pointer.text = "▼"
	pointer.add_theme_font_size_override("font_size", 42)
	pointer.add_theme_color_override("font_color", Color(1.0, 0.92, 0.32))
	pointer.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	pointer.add_theme_constant_override("outline_size", 5)
	pointer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pointer.anchor_left = 0.5
	pointer.anchor_right = 0.5
	pointer.offset_left = -22.0
	pointer.offset_right = 22.0
	pointer.offset_top = -8.0
	pointer.offset_bottom = 48.0
	holder.add_child(pointer)

	# 결과 / 안내 텍스트
	_result_label = _make_label(Locale.t("spin_hint"), 22, true)
	_result_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
	_result_label.custom_minimum_size = Vector2(0, 32)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_result_label)

	# 스핀 버튼
	_spin_btn = Button.new()
	_spin_btn.custom_minimum_size = Vector2(0, 66)
	_apply_font(_spin_btn, 24)
	_spin_btn.icon = _COIN_ICON
	_spin_btn.add_theme_constant_override("icon_max_width", 26)
	_spin_btn.add_theme_constant_override("h_separation", 10)
	_UIStyle.apply_button_style(_spin_btn, Color(0.44, 0.20, 0.46), Color(0.85, 0.45, 0.95))
	_spin_btn.pressed.connect(_on_spin)
	outer.add_child(_spin_btn)

	outer.add_child(HSeparator.new())

	# 계속 버튼
	_continue_btn = Button.new()
	_continue_btn.text = Locale.t("shop_continue")
	_continue_btn.custom_minimum_size = Vector2(0, 60)
	_apply_font(_continue_btn, 24)
	_UIStyle.apply_button_style(_continue_btn, Color(0.14, 0.40, 0.20), Color(0.4, 0.85, 0.45))
	_continue_btn.pressed.connect(_on_continue)
	outer.add_child(_continue_btn)

	_rebuild_wheel()


func _init_pivot() -> void:
	_panel.pivot_offset = _panel.size * 0.5
	_wheel.pivot_offset = _wheel.size * 0.5


# ---------------------------------------------------------------- locale helpers
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


## 룰렛이 당첨시킬 수 있는 후보(최대치가 아닌 업그레이드) 인덱스 목록.
func _available_indices() -> Array:
	var arr: Array = []
	for i in UPGRADES.size():
		if not _is_maxed(UPGRADES[i]):
			arr.append(i)
	return arr


func _spin_cost() -> int:
	return SPIN_BASE + _wave * SPIN_WAVE_MULT + _spins_done * SPIN_STEP


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
		_ad_gold_btn.disabled = _spinning


func _on_ad_gold_pressed() -> void:
	if _ad_gold_claimed or _spinning or not AdManager.is_rewarded_ready():
		return
	AdManager.show_rewarded("shop_gold")


func _on_rewarded_granted(placement: String) -> void:
	if placement != "shop_gold" or _ad_gold_claimed:
		return
	_ad_gold_claimed = true
	Events.add_gold(_ad_gold_bonus())
	_refresh()


# ---------------------------------------------------------------- wheel build / refresh
func _rebuild_wheel() -> void:
	var sectors: Array = []
	for upg: Dictionary in UPGRADES:
		sectors.append({
			"color": SECTION_COLORS.get(upg["section"], Color(0.4, 0.4, 0.45)),
			"label": _upg_name(upg),
			"dim": _is_maxed(upg),
		})
	_wheel.setup(sectors)


func _refresh() -> void:
	_gold_label.text = "%d" % Events.total_gold
	_update_ad_gold_btn()
	_rebuild_wheel()

	var cost := _spin_cost()
	if _spinning:
		_spin_btn.text = Locale.t("spin_spinning")
		_spin_btn.disabled = true
	elif Events.total_gold < cost:
		_spin_btn.text = "%s  (-%dG)" % [Locale.t("spin_insufficient"), cost]
		_spin_btn.disabled = true
	else:
		_spin_btn.text = Locale.t("spin_btn_fmt") % cost
		_spin_btn.disabled = false


# ---------------------------------------------------------------- spin
func _on_spin() -> void:
	if _spinning:
		return
	var cost := _spin_cost()
	# 골드가 부족하면 구매(스핀)되지 않는다.
	if not Events.spend_gold(cost):
		_refresh()
		return
	_spins_done += 1
	_spinning = true
	_continue_btn.disabled = true
	_result_label.text = Locale.t("spin_spinning")
	_refresh()

	var avail := _available_indices()
	var winner: int = avail[randi() % avail.size()]
	_animate_to(winner)


func _animate_to(winner: int) -> void:
	var n := UPGRADES.size()
	var step := TAU / n
	var a_mid := (winner + 0.5) * step
	var jitter := randf_range(-step * 0.32, step * 0.32)
	# 당첨 섹터 중심이 상단 포인터(각도 -PI/2) 아래에 오도록.
	var desired := fposmod(-PI * 0.5 - a_mid - jitter, TAU)
	_wheel.rotation = fposmod(_wheel.rotation, TAU)
	var turns := 5
	var target := _wheel.rotation + TAU * turns + fposmod(desired - _wheel.rotation, TAU)

	var tw := create_tween()
	tw.tween_property(_wheel, "rotation", target, 3.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_finish_spin.bind(winner))


func _finish_spin(winner: int) -> void:
	var upg: Dictionary = UPGRADES[winner]
	_grant_upgrade(upg["id"])

	_spinning = false
	_continue_btn.disabled = false
	_result_label.text = Locale.t("spin_result_fmt") % _upg_name(upg)
	# 결과 텍스트 팝 연출
	_result_label.scale = Vector2(1.35, 1.35)
	_result_label.pivot_offset = _result_label.size * 0.5
	create_tween().tween_property(_result_label, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh()


## 비용 없이(스핀 비용으로 이미 지불) 업그레이드 1단계를 적용한다.
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
	if _spinning:
		return
	visible = false
	Events.shop_closed.emit()
