extends CanvasLayer
## 레벨업 카드 선택(뱀서식 인게임 성장). 코인 수집으로 레벨업하면 게임을 잠시 멈추고
## 무기/패시브 아이템 3장 중 하나를 고른다(새 아이템 획득 또는 보유 아이템 레벨업).
## 카탈로그·슬롯 규칙은 ItemDB, 인벤토리는 Events.weapons/passives.

const _UIStyle := preload("res://scripts/UIStyle.gd")
const _CelebrationFX := preload("res://scripts/LevelUpCelebrationFX.gd")

const _CARD_HEIGHT := 184.0

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
var _celebration: Control = null
## 카드를 고른 뒤 확정 연출이 도는 동안 참. 이 사이에는 다른 카드를 누를 수도,
## 자동플레이가 또 고를 수도, "선택지 없는 패널" 안전망이 끼어들 수도 없어야 한다.
var _confirming: bool = false


## 자동플레이 치트: 패널이 떠 있으면 잠시 보여준 뒤 카드를 무작위로 골라준다(진화 선택 포함).
func _process(delta: float) -> void:
	# 안전망 — 카드가 하나도 없는 패널이 떠 있으면 아무도 진행시킬 수 없어 게임이 영구히 멈춘다.
	# (정지 소유권은 Events 워치독이 별도로 지키지만, 여기서 먼저 정상 경로로 빠져나간다.)
	if _confirming:
		return   # 확정 연출 중 — 안전망도 자동플레이도 기다린다
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
	var btn := Cheats.auto_pick(cards)   # 페르소나(무작위/탐욕)에 따라 고른다
	if btn != null:
		btn.pressed.emit()


func _ready() -> void:
	layer = 11   # HUD(10)보다 위 — 카드 선택 중에는 이 패널이 화면을 덮는다.
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS   # 트리를 멈춰도 이 UI 는 동작해야 한다
	Events.level_up.connect(_on_level_up)
	Events.evolution_offer.connect(_on_evolution_offer)
	Events.boss_reward_sequence_changed.connect(_on_boss_reward_sequence_changed)
	_build_ui()


## 레벨업 중에는 플레이 이동용 WASD를 카드 포커스 이동으로 전환한다. InputMap의
## move_* 액션을 그대로 써서 키 설정과 동기화하며, 키 반복은 한 번 누른 입력만 처리한다.
## 방향키·게임패드는 Button의 기본 ui_* 포커스 이동이 먼저 처리하므로 이 경로와 중복되지 않는다.
func _unhandled_input(event: InputEvent) -> void:
	if not _showing or _confirming or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var step := 0
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
		step = -1
	elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
		step = 1
	if step == 0:
		return
	_move_keyboard_focus(step)
	get_viewport().set_input_as_handled()


func _move_keyboard_focus(step: int) -> void:
	var cards: Array[Button] = []
	for child in _card_box.get_children():
		if child is Button and not child.disabled:
			cards.append(child as Button)
	if cards.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var index := cards.find(focused)
	if index < 0:
		cards[0].grab_focus()
	else:
		cards[posmod(index + step, cards.size())].grab_focus()


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.62)
	add_child(_dim)

	_celebration = _CelebrationFX.new()
	add_child(_celebration)

	# 축하 폭죽 홀더 — 패널 뒤(어둠 위)에 깔려 카드 UI 를 가리지 않는다.
	_fw_holder = Control.new()
	_fw_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fw_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fw_holder)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _UIStyle.tactical_panel())
	center.add_child(_panel)

	# 계층: panel → margin → vb(제목 + 카드 목록)
	var margin := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, 16)
	_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.custom_minimum_size = Vector2(560, 0)
	margin.add_child(vb)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 영어 제목("LEVEL 99  ·  CHOOSE AN UPGRADE")은 34px 에서 544px 라 패널 폭(440)을 넘겨
	# 패널 자체를 밀어 넓히고 있었다 — 프레임에 글자가 닿아 여백이 사라진다(실렌더 확인, P2-3).
	# 크기를 줄이는 대신 줄바꿈을 켠다. 한국어·일본어는 짧아 한 줄로 유지된다.
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(560, 82)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", UITheme.TACTICAL_TEXT)
	vb.add_child(_title)

	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 16)
	vb.add_child(_card_box)


func _on_level_up(_level: int) -> void:
	# 고를 카드가 하나도 없으면(보유 아이템 전부 만렙 + 슬롯 만석) 패널을 아예 띄우지 않는다.
	# 띄워봐야 정지·징글·폭죽만 깜빡이고 아무 보상 없이 닫힌다 — 후반에는 이게 초당 몇 번씩
	# 반복된다. 대신 골드로 보상한다.
	if not _showing and _draw_choices(1).is_empty():
		Events.grant_maxed_level_gold()
		return
	_pending += 1
	if not _showing and not Events.boss_reward_sequence_active:
		_present()


## 보석 분수의 마지막 보석이 착지한 뒤, 그동안 모인 레벨업을 순서대로 보여 준다.
func _on_boss_reward_sequence_changed(active: bool) -> void:
	if not active and _pending > 0 and not _showing:
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
	# 전체 화면 폭죽과 저채도 방사광. 둘 다 패널 뒤라 카드의 글자와 입력을 가리지 않는다.
	_stop_fireworks()   # 직전 레벨업의 잔여 폭죽을 먼저 비운다
	_celebration.play(_evo_mode)
	var screen := get_viewport().get_visible_rect().size
	var fireworks_region := Rect2(Vector2(18, 42), Vector2(maxf(1.0, screen.x - 36), maxf(1.0, screen.y - 84)))
	_fw_tw = FireworksFX.celebrate(_fw_holder, fireworks_region,
		[Color(1.0, 0.85, 0.35), Color(0.5, 0.8, 1.0), Color(1.0, 1.0, 0.9)], 56)
	_refresh()
	_panel.scale = Vector2(0.96, 0.96)
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
		_title.text = Locale.t("evo_title").replace("  ·  ", "\n")
		if _evo_rules.is_empty():
			_close_evo()
			return
		for rule in _evo_rules:
			_card_box.add_child(_make_evolve_card(rule))
		_stagger_cards()
		_prepare_keyboard_focus.call_deferred()
		return
	# 올릴 아이템이 없으면(전부 만렙·슬롯 꽉참) 그 레벨업은 넘긴다. 재귀 대신 루프로 소진해
	# 대기 레벨업이 많이 쌓여도 스택이 깊어지지 않게 한다.
	var choices: Array = []
	while _pending > 0:
		_title.text = (Locale.t("levelup_title_fmt") % Events.level).replace("  ·  ", "\n")
		choices = _draw_choices(3)
		if not choices.is_empty():
			break
		Events.grant_maxed_level_gold()   # 고를 게 없는 레벨업은 골드로 보상하고 넘긴다
		_pending -= 1
	if choices.is_empty():
		_advance_or_close()
		return
	for ch in choices:
		_card_box.add_child(_make_card(ch))
	_stagger_cards()
	_prepare_keyboard_focus.call_deferred()


## 키보드/게임패드 선택: 첫 카드를 즉시 포커스하고 방향 입력이 목록 끝에서 순환하도록 연결한다.
## Button의 엔진 기본 ui_accept 처리를 쓰므로 Enter/Space/패드 확인 버튼이 클릭과 같은 pressed 경로를 탄다.
func _prepare_keyboard_focus() -> void:
	if not _showing or _confirming or _card_box == null:
		return
	var cards: Array[Button] = []
	for child in _card_box.get_children():
		if child is Button:
			cards.append(child as Button)
	if cards.is_empty():
		return
	for i in cards.size():
		var btn := cards[i]
		var prev := cards[(i - 1 + cards.size()) % cards.size()]
		var next := cards[(i + 1) % cards.size()]
		btn.focus_neighbor_top = btn.get_path_to(prev)
		btn.focus_neighbor_left = btn.get_path_to(prev)
		btn.focus_neighbor_bottom = btn.get_path_to(next)
		btn.focus_neighbor_right = btn.get_path_to(next)
		btn.focus_previous = btn.get_path_to(prev)
		btn.focus_next = btn.get_path_to(next)
	cards[0].grab_focus()


## 카드 등장 연출 — 위에서부터 순차적으로(stagger) 깔린다. 알파만 올리면 "그 자리에 있던 것이
## 밝아지는" 느낌이라, 세로로 살짝 눌린 상태에서 아래를 축으로 펴지게 해 솟아오르는 인상을 준다.
##
## **위치를 옮기지 않는 이유**: 카드는 VBoxContainer 의 자식이라 컨테이너가 배치할 때마다
## position 을 다시 써 버린다. 컨테이너가 건드리지 않는 것은 modulate 와 scale 뿐이다.
const _CARD_STAGGER := 0.05
const _CARD_IN_SEC := 0.22

func _stagger_cards() -> void:
	var i := 0
	for c in _card_box.get_children():
		c.modulate.a = 0.0
		var ctrl := c as Control
		if ctrl != null:
			# 방금 추가된 카드는 아직 배치 전이라 size 가 0 일 수 있다 — 그때는 최소 크기로
			# 아래 모서리를 잡는다(세로로만 늘이므로 x 피벗은 결과에 영향이 없다).
			var sz := ctrl.size if ctrl.size.y > 0.0 else ctrl.custom_minimum_size
			ctrl.pivot_offset = Vector2(sz.x * 0.5, sz.y)
			ctrl.scale = Vector2(1.0, 0.97)
		# 트윈은 **카드 자신**에 묶는다. 패널에 묶으면 카드가 먼저 해제됐을 때(다음 레벨업으로
		# 넘어가며 _refresh 가 목록을 비운다) 트윈만 남아 해제된 노드를 계속 건드린다.
		var tw := (ctrl if ctrl != null else self).create_tween()
		tw.tween_interval(_CARD_STAGGER * float(i))
		tw.tween_property(c, "modulate:a", 1.0, _CARD_IN_SEC)
		if ctrl != null:
			tw.parallel().tween_property(ctrl, "scale", Vector2.ONE, _CARD_IN_SEC)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# 진화 카드의 맥동은 **등장이 끝난 뒤** 시작한다. 등장 트윈이 modulate:a 를 쓰는데
		# 맥동은 modulate 전체를 쓰므로, 동시에 돌면 둘이 알파를 놓고 다툰다.
		if ctrl != null and ctrl.has_meta("is_evo"):
			tw.tween_callback(_pulse_evolve_card.bind(ctrl))
		i += 1


## 진화 카드는 일반 카드와 같은 판을 쓴다 — 특별하다는 것을 색이 아니라 움직임으로 말한다.
## 반복 트윈이라 확정 연출이 시작될 때 반드시 죽인다(_confirm_card 참고).
const _EVO_PULSE_SEC := 0.7
const _EVO_PULSE_TINT := Color(1.16, 1.07, 0.86, 1.0)

func _pulse_evolve_card(card: Control) -> void:
	if not is_instance_valid(card):
		return
	var tw := card.create_tween()   # 카드와 함께 사라지도록 카드에 묶는다(반복 트윈이라 더 중요하다)
	tw.set_loops()
	tw.tween_property(card, "modulate", _EVO_PULSE_TINT, _EVO_PULSE_SEC).set_trans(Tween.TRANS_SINE)
	tw.tween_property(card, "modulate", Color.WHITE, _EVO_PULSE_SEC).set_trans(Tween.TRANS_SINE)
	card.set_meta("_evo_pulse", tw)


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
	for a in _weighted_take(avail, n - choices.size()):
		choices.append({"kind": "item", "data": a})
	return choices


## 후보에서 n 개를 **레벨 가중 비복원 추출**한다. 가중치 = 1 + 레벨 × balance.levelup_focus_weight.
##
## 균등 셔플이었을 때 슬롯 만석(후보 12) 기준으로 특정 무기가 뜰 확률이 25% 라, 진화 조건인
## 무기 만렙(Lv8)까지 평균 28 레벨업이 걸렸다 — 그 레벨에 도달하는 판이 거의 없어 진화 11종이
## 사실상 잠겨 있었다(BALANCE.md §3-14). 이미 올린 것이 더 자주 뜨게 해서, 집중을 운이 아니라
## 선택으로 만든다. 가중치 0 이면 예전의 균등 추출과 같다.
func _weighted_take(pool: Array, n: int) -> Array:
	var out: Array = []
	if n <= 0 or pool.is_empty():
		return out
	var rest: Array = pool.duplicate()
	var fw: float = maxf(0.0, GameData.balance.levelup_focus_weight)
	while out.size() < n and not rest.is_empty():
		var total := 0.0
		for a in rest:
			total += 1.0 + float(a["lv"]) * fw
		var roll := randf() * total
		var idx := rest.size() - 1        # 부동소수 오차로 루프가 안 걸릴 때의 안전한 기본값
		for i in rest.size():
			roll -= 1.0 + float(rest[i]["lv"]) * fw
			if roll <= 0.0:
				idx = i
				break
		out.append(rest[idx])
		rest.remove_at(idx)
	return out


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
	var tag := Locale.t("item_tag_new") if a["is_new"] else Locale.t("item_tag_upgrade")
	var levels := "Lv.1" if a["is_new"] else "Lv.%d → %d" % [a["lv"], int(a["lv"])+1]
	_card_content(btn, item, tag, levels, false)
	btn.pressed.connect(_on_pick.bind(String(item["id"])))
	btn.set_meta("pick_id", String(item["id"]))
	return btn


func _make_evolve_card(rule: Dictionary) -> Button:
	var into := ItemDB.meta(rule["into"])
	var btn := _new_card_button()
	_card_content(btn, into, Locale.t("item_tag_evolve"), "Lv.1", true)
	btn.pressed.connect(_on_evolve.bind(String(rule["base"]), String(rule["into"])))
	btn.set_meta("pick_id", "evolve:" + String(rule["into"]))
	btn.set_meta("is_evo", true)
	return btn


func _card_content(btn: Button, item: Dictionary, tag: String, levels: String, evolved: bool) -> void:
	_UIStyle.tactical_button(btn)
	btn.focus_mode = Control.FOCUS_ALL
	# 공용 버튼 스타일은 터치 화면을 위해 포커스 테두리를 숨긴다. 선택 카드에서는 청록색 판으로
	# 덮어써 현재 키보드 위치가 마우스 없이도 확실히 보이게 한다.
	btn.add_theme_stylebox_override("focus", _UIStyle.button_box(UITheme.TACTICAL_TEAL, 0.0))
	if evolved:
		btn.add_theme_stylebox_override("normal", _UIStyle.button_box(UITheme.TACTICAL_YELLOW, 0.02))
	# A container owns text height; long translations grow the card rather than overlap.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var slot := _UIStyle.tactical_slot(item.get("icon"), 88)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slot)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)
	var badge := _UIStyle.tactical_label(tag + "   " + levels, 24, UITheme.TACTICAL_YELLOW if evolved else UITheme.TACTICAL_TEAL)
	badge.name = "Badge"
	badge.clip_text = true
	badge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	badge.custom_minimum_size.y = 30
	text.add_child(badge)
	var title := _UIStyle.tactical_label(item.get("name", ""), 28)
	title.name = "Title"
	title.add_theme_font_override("font", UITheme.bold_font())
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.y = 34
	text.add_child(title)
	var desc := _UIStyle.tactical_label(item.get("desc", ""), 24, UITheme.TACTICAL_MUTED)
	desc.name = "Description"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.y = 58
	text.add_child(desc)
	var check := UIIcon.make("check", 28, UITheme.TACTICAL_TEXT)
	check.name = "SelectedCheck"
	check.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	check.position = Vector2(-36,8)
	check.hide()
	btn.add_child(check)
	# Fixed row heights make the three-card stack deterministic on 360x640.  Each label owns
	# enough vertical room for its allowed line count and trims inside that room.


func _new_card_button() -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(560, _CARD_HEIGHT)
	return btn


## 고른 카드가 확정되는 순간 — 그 카드만 잠깐 커지며 밝아지고 나머지는 물러난다.
## 예전에는 누르는 즉시 _refresh() 가 카드를 전부 지워, 무엇을 골랐는지 확인할 틈이 없었다.
##
## 정지 중에도 흐르는 타이머를 쓴다(레벨업 패널이 트리를 멈춰 둔 상태다).
const _CONFIRM_SEC := 0.26
const _CONFIRM_TINT := Color(1.08, 1.08, 1.02, 1.0)

func _confirm_card(picked: Control) -> void:
	_confirming = true
	if _celebration != null:
		_celebration.confirm()
	# 확정음 — 그림(카드가 커지며 밝아짐)과 같은 순간에 소리도 있어야 "정해졌다"가 된다.
	# 진화는 뒤이어 전용 팡파르가 나므로 여기서는 내지 않는다(둘이 겹쳐 뭉갠다).
	if not _evo_mode:
		SoundManager.play_ui("ui_select", 0.03)
	for c in _card_box.get_children():
		var ctrl := c as Control
		if ctrl == null:
			continue
		# 진화 카드의 반복 맥동을 먼저 끈다 — 그대로 두면 확정 트윈과 modulate 를 놓고 다툰다.
		if ctrl.has_meta("_evo_pulse"):
			var pulse = ctrl.get_meta("_evo_pulse")
			if pulse is Tween and pulse.is_valid():
				pulse.kill()
			ctrl.remove_meta("_evo_pulse")
		if ctrl == picked:
			ctrl.add_theme_stylebox_override("normal", _UIStyle.button_box(UITheme.TACTICAL_TEAL, 0.0))
			ctrl.get_node("SelectedCheck").show()
			ctrl.pivot_offset = ctrl.size * 0.5
			var tw := ctrl.create_tween()
			tw.set_parallel(true)
			tw.tween_property(ctrl, "scale", Vector2(1.025, 1.025), _CONFIRM_SEC * 0.55)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(ctrl, "modulate", _CONFIRM_TINT, _CONFIRM_SEC * 0.4)
		else:
			# 고르지 않은 카드는 물러난다 — 선택이 하나였음을 화면이 말해 준다.
			var otw := ctrl.create_tween()
			otw.tween_property(ctrl, "modulate:a", 0.0, _CONFIRM_SEC * 0.7)
	await get_tree().create_timer(_CONFIRM_SEC, true, false, true).timeout
	_confirming = false


func _on_pick(id: String) -> void:
	if _confirming:
		return
	await _confirm_card(_card_with_pick_id(id))
	if not is_inside_tree():
		return
	Events.grant_item(id)   # 인벤토리 레벨 +1 후 upgrade_* 재계산
	_apply_and_advance()


## pick_id 메타로 카드를 되찾는다. 시그널이 id 만 넘겨주기 때문인데, 버튼 자체를 바인딩하면
## 카드가 지워진 뒤에도 참조가 남아 해제된 인스턴스를 만질 위험이 있다.
func _card_with_pick_id(id: String) -> Control:
	for c in _card_box.get_children():
		if c.has_meta("pick_id") and String(c.get_meta("pick_id")) == id:
			return c as Control
	return null


func _on_evolve(base_id: String, into_id: String) -> void:
	if _confirming:
		return
	await _confirm_card(_card_with_pick_id("evolve:" + into_id))
	if not is_inside_tree():
		return
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
	# 전장으로 돌아가는 순간의 줌 펀치. **정지를 푼 뒤에** 부른다 — Player 는
	# PROCESS_MODE_ALWAYS 가 아니라, 정지 중에 걸면 줌이 당겨진 채 굳는다.
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("camera_zoom_punch"):
		player.camera_zoom_punch(0.94, 0.28)


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
	if _celebration != null:
		_celebration.clear()


## 씬 전환 등으로 패널이 뜬 채 사라질 때 — 정지가 영구히 남지 않게 소유권을 반납한다.
func _exit_tree() -> void:
	_stop_fireworks()
	Events.pause_pop(self)
