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
var _evo_mode: bool = false     # 진화 선택 모드(진화 상자 개봉 시) — 일반 레벨업과 분리
var _evo_rules: Array = []      # 진화 모드에서 제시할 진화 규칙들
var _evo_queued: int = 0        # 패널이 떠 있는 동안 들어온 진화 제안(버리지 않고 이어서 띄운다)
var _auto_t: float = 0.0        # 자동플레이 치트 — 카드가 뜬 뒤 이 시간이 지나면 무작위 선택
var _stuck_t: float = 0.0       # 카드 없는 패널이 떠 있는 시간(안전망 — 강제 진행/닫기)
var _fw_holder: Control = null  # 축하 폭죽 홀더(패널 뒤)
var _fw_tw: Tween = null        # 폭죽 발사 예약 트윈 — 패널을 닫을 때 끊는다


## 자동플레이 치트: 패널이 떠 있으면 잠시 보여준 뒤 카드를 무작위로 골라준다(진화 선택 포함).
func _process(delta: float) -> void:
	# 안전망 — 카드가 하나도 없는 패널이 떠 있으면 아무도 진행시킬 수 없어 게임이 영구히 멈춘다.
	# (정지 소유권은 Events 워치독이 별도로 지키지만, 여기서 먼저 정상 경로로 빠져나간다.)
	if _showing and _card_box != null and _card_box.get_child_count() == 0:
		_stuck_t += delta
		if _stuck_t >= 1.5:
			_stuck_t = 0.0
			push_warning("[LevelUpPanel] 선택지 없는 패널이 떠 있어 강제로 진행한다")
			_pending = 0
			_evo_queued = 0
			_advance_or_close()
		return
	_stuck_t = 0.0
	if not (_showing and Cheats.autoplay_active()):
		_auto_t = 0.0
		return
	_auto_t += delta
	if _auto_t < 0.7:
		return
	_auto_t = 0.0
	var cards := _card_box.get_children()
	if cards.is_empty():
		return
	var btn := cards[randi() % cards.size()] as Button
	if btn != null:
		btn.pressed.emit()


func _ready() -> void:
	layer = 11   # HUD(10)보다 위 — 카드 선택 중에는 이 패널이 화면을 덮는다.
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

	# 축하 폭죽 홀더 — 패널 뒤(어둠 위)에 깔려 카드 UI 를 가리지 않는다.
	_fw_holder = Control.new()
	_fw_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fw_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fw_holder)

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


## 진화 보물상자 개봉 — 진화 선택지를 띄운다. 이미 패널이 떠 있으면 버리지 않고 대기시켰다가
## 현재 선택이 끝난 뒤 이어서 띄운다(예전에는 조용히 사라져 상자 보상이 증발했다).
func _on_evolution_offer() -> void:
	if _showing:
		_evo_queued += 1
		return
	var rules := Events.available_evolutions()
	if rules.is_empty():
		return
	_evo_mode = true
	_evo_rules = rules
	_present()


func _present() -> void:
	_showing = true
	visible = true
	Events.pause_push(self, "levelup")   # 정지 소유권은 Events 가 참조 카운트로 관리한다
	if SoundManager.has_stream("level_up"):
		SoundManager.play_ui("level_up", 0.03, 1.0)   # 레벨업 징글(파일 있을 때만)
	# 레벨업 축하 폭죽 — 패널 주변 화면 전역에 금빛/청색 폭죽을 쏟아붓는다.
	_stop_fireworks()   # 직전 레벨업의 잔여 폭죽을 먼저 비운다
	_fw_tw = FireworksFX.celebrate(_fw_holder, Rect2(70, 190, 580, 760),
		[Color(1.0, 0.85, 0.35), Color(0.5, 0.8, 1.0), Color(1.0, 1.0, 0.9)], 40)
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
	# 올릴 아이템이 없으면(전부 만렙·슬롯 꽉참) 그 레벨업은 넘긴다. 재귀 대신 루프로 소진해
	# 대기 레벨업이 많이 쌓여도 스택이 깊어지지 않게 한다.
	var choices: Array = []
	while _pending > 0:
		_title.text = "LEVEL %d  ·  CHOOSE AN UPGRADE" % Events.level
		choices = _draw_choices(3)
		if not choices.is_empty():
			break
		_pending -= 1
	if choices.is_empty():
		_advance_or_close()
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
const ULT_MIN_LEVEL := 8   # 이 레벨부터 캐릭터 궁극기가 카드로 등장(중후반 해금)


func _draw_choices(n: int) -> Array:
	var choices: Array = []
	# 캐릭터 궁극기 — 중후반(레벨 8+)에 미보유면 반드시 선택지에 포함(슬롯 규칙 무시, 놓칠 수 없게).
	var ult := _ult_choice()
	if not ult.is_empty():
		choices.append({"kind": "item", "data": ult})
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


## 선택 캐릭터의 궁극기 해금 카드(레벨 8+ & 미보유일 때만, 아니면 {}).
func _ult_choice() -> Dictionary:
	if Events.level < ULT_MIN_LEVEL:
		return {}
	var c: CharacterData = CharacterManager.selected()
	if c == null or c.ultimate_weapon == "":
		return {}
	if int(Events.weapons.get(c.ultimate_weapon, 0)) > 0:
		return {}
	var w: WeaponData = GameData.weapon_def(c.ultimate_weapon)
	if w == null:
		return {}
	return {"item": ItemDB._w_dict(w), "lv": 0, "is_new": true}


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
	# 런 최대 파워업 — 레벨업 징글보다 한 단계 웅장한 전용 팡파르(없으면 팡파르/레벨업으로 폴백).
	if SoundManager.has_stream("evolve"):
		SoundManager.play_ui("evolve", 0.02, 1.0)
	elif SoundManager.has_stream("fanfare"):
		SoundManager.play_ui("fanfare", 0.02, 0.9)
	Events.evolve(base_id, into_id)
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("apply_upgrades"):
		player.apply_upgrades()
	if _evo_mode:
		_close_evo()   # 진화 선택은 레벨업 대기열과 무관 — 대기분이 있으면 이어서 처리된다
	else:
		_consume_and_advance()   # (레거시 경로 — 현재는 진화가 카드로 안 뜨므로 사실상 미사용)


## 진화 선택 종료 — 대기 중인 레벨업/진화 제안이 남아 있으면 이어서 띄운다.
func _close_evo() -> void:
	_evo_mode = false
	_evo_rules = []
	_advance_or_close()


func _apply_and_advance() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("apply_upgrades"):
		player.apply_upgrades()   # 강화 카운터 → 실제 스탯 반영(인게임 상점은 2026-08 폐기, P0-3)
	_consume_and_advance()


## 이번 레벨업을 소비하고 다음 단계로.
func _consume_and_advance() -> void:
	_pending = maxi(0, _pending - 1)
	_advance_or_close()


## 남은 레벨업 → 대기 중인 진화 제안 → 그래도 없으면 닫고 정지 소유권 반납.
## 모든 종료 경로가 여기 하나로 모이므로, 대기분이 증발하거나 정지가 남는 일이 없다.
func _advance_or_close() -> void:
	if _pending > 0:
		_evo_mode = false
		_evo_rules = []
		_refresh()
		return
	if _evo_queued > 0:
		_evo_queued -= 1
		var rules := Events.available_evolutions()
		if not rules.is_empty():
			_evo_mode = true
			_evo_rules = rules
			_refresh()
			return
	_evo_queued = 0
	_evo_mode = false
	_evo_rules = []
	_showing = false
	visible = false
	_stop_fireworks()   # 숨겨진 파티클은 스스로 끝나지 못한다 — 닫을 때 확실히 비운다
	Events.pause_pop(self)


## 폭죽 정리 — 남은 발사 예약을 끊고 살아있는 파티클을 즉시 제거한다.
## CPUParticles2D 는 숨겨지면 시뮬레이션이 멈춰 finished 를 영영 emit 하지 않는다.
## 여기서 확실히 지우지 않으면 레벨업마다 수십 개가 홀더에 쌓이고, 다음에 패널이 열리는
## 순간 전부 한꺼번에 되살아나 프레임이 무너진다(고레벨 프리즈의 직접 원인이었다).
func _stop_fireworks() -> void:
	if _fw_tw != null and _fw_tw.is_valid():
		_fw_tw.kill()
	_fw_tw = null
	if _fw_holder != null:
		for c in _fw_holder.get_children():
			c.queue_free()


## 씬 전환 등으로 패널이 뜬 채 사라질 때 — 정지가 영구히 남지 않게 소유권을 반납한다.
func _exit_tree() -> void:
	_stop_fireworks()
	Events.pause_pop(self)
