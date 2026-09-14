extends CanvasLayer
## 메인 메뉴: 새로하기 / 이어하기 / 언어 선택. 이어하기는 로컬 저장 데이터가 있을 때만 활성화.
## 표시 문구는 Locale 에서 가져오며, 언어 변경 시 즉시 다시 번역된다.

const _UIPopup := preload("res://scripts/UIPopup.gd")
const _UIStyle := preload("res://scripts/UIStyle.gd")
const _CodexPanel := preload("res://scripts/CodexPanel.gd")
const _ThreatPanel := preload("res://scripts/ThreatPanel.gd")
const _IntroStory := preload("res://scripts/IntroStory.gd")

var _diff_title: Label
var _new_game_btn: Button
var _continue_btn: Button
## 계정 상태 줄(P2-32) — 로고 아래 한 줄: 메타 골드 · 위협 등급 · 최고 생존 시간.
var _status_gold: Label = null
var _status_threat: Label = null
var _status_best: Label = null
var _status_best_chip: Control = null
var _status_threat_chip: Control = null
var _status_row: Control = null
var _lang_title: Label
var _sound_title: Label
var _sound_btn: Button
var _music_title: Label
var _music_btn: Button
var _options_btn: Button
var _codex_btn: Button
## 도감은 **처음 열 때 만든다.** 좀비·보스 아이콘이 게임플레이 아틀라스(767KB)에 있어
## 메뉴 진입 시점에 조립하면 도감을 열지 않는 사람까지 그 페이지를 올리게 된다.
var _codex: RefCounted = null
## 위협 등급 선택도 처음 열 때 만든다(도감과 같은 이유 — 안 여는 사람의 비용을 늘리지 않는다).
var _threat: RefCounted = null
var _options_dim: ColorRect
var _options_panel: PanelContainer
var _options_title: Label
var _close_btn: Button
var _records_btn: Button
var _records_dim: ColorRect
var _records_panel: PanelContainer
var _hero_art: TextureRect
var _hero_name: Label
var _hero_desc: Label
var _arena_label: Label
var _ranking_label: Label
var _records_title: Label
var _records_close: Button

var _diff_buttons: Array = []
var _lang_buttons: Array = []   # [{ "btn": Button, "lang": String }]

# ── 메타 성장(PowerUp) 오버레이 ──
var _power_btn: Button
var _power_dim: ColorRect
var _power_panel: PanelContainer
var _power_gold_label: Label
var _power_rows: Array = []      # [{ "btn": Button, "id": String }]

# ── 캐릭터 선택 오버레이 ──
var _char_dim: ColorRect
var _char_panel: PanelContainer
var _char_rows: Array = []       # [{ "btn": Button, "c": CharacterData }]
var _char_gold_label: Label

# ── 도전과제 오버레이 ──
var _ach_btn: Button
var _ach_dim: ColorRect
var _ach_panel: PanelContainer
var _ach_list: VBoxContainer     # 도전과제 행을 담는 컨테이너(갱신 시 다시 채운다)

var _quest_btn: Button
var _quest_dim: ColorRect
var _quest_panel: PanelContainer
var _quest_list: VBoxContainer

# 보상 보관함(REWARDS) — 퀘스트/도전과제 보상을 유저가 직접 수령하는 패널.
var _rewards_btn: Button
var _rewards_badge: Label        # 미수령 개수 배지(0이면 숨김)
var _rewards_dim: ColorRect
var _rewards_panel: PanelContainer
var _rewards_list: VBoxContainer
var _rewards_total: Label

# ── 테마(아레나) 선택 오버레이 ──
var _theme_dim: ColorRect
var _theme_panel: PanelContainer
var _theme_rows: Array = []      # [{ "btn": Button, "t": ThemeData }]
var _theme_gold_label: Label


func _ready() -> void:
	Events.pause_release_all()   # 게임오버/레벨업에서 정지된 채 메뉴로 돌아와도 메뉴가 멈추지 않도록
	Engine.time_scale = 1.0     # 히트스톱 등으로 배속이 낮게 남아 "멈춘 듯" 보이는 것 방지(복귀 시 정상화)
	# 타이틀에서 오면 같은 트랙이라 이어 재생, 게임에서 돌아오면 크로스페이드로 전환된다.
	SoundManager.play_music("title")
	_build_ui()
	_apply_language()
	Locale.language_changed.connect(_on_language_changed)


## 타이틀 화면과 같은 핏빛 방사 글로우 + 떠오르는 잔불 — 메뉴 뒤 배경 분위기.
func _build_backdrop() -> void:
	var glow := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.72, 0.10, 0.10, 0.42))
	grad.set_color(1, Color(0.72, 0.10, 0.10, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 256
	glow.texture = gtex
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.size = Vector2(700, 520)
	glow.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 - 350.0, 330.0 - 260.0)
	add_child(glow)

	var p := CPUParticles2D.new()
	p.amount = 42
	p.lifetime = 7.0
	p.preprocess = 4.0
	p.lifetime_randomness = 0.6
	p.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5, 1300.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(380.0, 8.0)
	p.direction = Vector2(0, -1)
	p.spread = 16.0
	p.gravity = Vector2(0, -7.0)
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 32.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.4
	p.color = Color(1.0, 0.45, 0.18, 0.5)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.5, 0.2, 0.0))
	ramp.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.5, 0.2, 0.55))
	p.color_ramp = ramp
	p.emitting = true
	add_child(p)


func _build_ui() -> void:
	add_child(UITheme.make_gradient_bg(Color("202629"), Color("0e1316")))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.name = "TacticalLobby"
	box.custom_minimum_size.x = 656
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	box.add_child(header)
	var title := TextureRect.new()
	title.texture = preload("res://assets/ui/logo_title.png")
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.custom_minimum_size = Vector2(280, 144)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)
	_options_btn = Button.new()
	_options_btn.custom_minimum_size = Vector2(144, 88)
	_options_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_UIStyle.tactical_button(_options_btn)
	_options_btn.pressed.connect(_on_options_pressed)
	header.add_child(_options_btn)
	_build_status_strip(box)

	var hero := PanelContainer.new()
	hero.name = "HeroCard"
	var hero_frame := _UIStyle.tactical_panel()
	hero_frame.set_content_margin_all(40)
	hero.add_theme_stylebox_override("panel", hero_frame)
	box.add_child(hero)
	var hero_box := VBoxContainer.new()
	hero_box.add_theme_constant_override("separation", 8)
	hero.add_child(hero_box)
	var stage := Control.new()
	stage.custom_minimum_size.y = 256
	stage.clip_contents = true
	hero_box.add_child(stage)
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/ui/bg_title.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.7, 0.85, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg)
	_hero_art = TextureRect.new()
	_hero_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_hero_art)
	_hero_name = _UIStyle.tactical_label("", 32)
	_hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_box.add_child(_hero_name)
	_hero_desc = _UIStyle.tactical_label("", 24, UITheme.TACTICAL_MUTED)
	_hero_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_desc.custom_minimum_size.x = 560
	_hero_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_box.add_child(_hero_desc)
	_arena_label = _UIStyle.tactical_label("", 24, UITheme.TACTICAL_TEAL)
	_arena_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_arena_label)

	_continue_btn = Button.new()
	_continue_btn.custom_minimum_size.y = 88
	_continue_btn.visible = SaveManager.has_save()
	_UIStyle.tactical_button(_continue_btn, true)
	_continue_btn.pressed.connect(_on_continue_pressed)
	box.add_child(_continue_btn)
	_new_game_btn = Button.new()
	_new_game_btn.custom_minimum_size.y = 88
	_UIStyle.tactical_button(_new_game_btn, not SaveManager.has_save())
	_new_game_btn.pressed.connect(_on_new_game_pressed)
	box.add_child(_new_game_btn)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	box.add_child(grid)
	_power_btn = _make_menu_btn("bolt", UITheme.SEC_POWER_TXT)
	_power_btn.pressed.connect(_on_power_pressed)
	grid.add_child(_power_btn)
	_quest_btn = _make_menu_btn("flag", UITheme.SEC_QUEST_TXT)
	_quest_btn.pressed.connect(_on_quests_pressed)
	grid.add_child(_quest_btn)
	_rewards_btn = _make_menu_btn("coin", UITheme.TACTICAL_YELLOW)
	_rewards_btn.pressed.connect(_on_rewards_pressed)
	grid.add_child(_rewards_btn)
	_records_btn = _make_menu_btn("book", UITheme.TACTICAL_MUTED)
	_records_btn.pressed.connect(_on_records_pressed)
	grid.add_child(_records_btn)
	_build_rewards_badge()
	RewardInbox.changed.connect(_refresh_rewards_badge)

	var record := _UIPopup.make(self, "menu_records", UITheme.TACTICAL_TEAL, UITheme.TACTICAL_TEXT,
		func(): _UIPopup.close(_records_dim, _records_panel))
	_records_dim = record["dim"]
	_records_panel = record["panel"]
	_records_title = record["title"]
	_records_close = record["close"]
	_records_close.custom_minimum_size.y = 88
	_UIStyle.tactical_button(_records_close)
	_records_panel.add_theme_stylebox_override("panel", _UIStyle.tactical_panel())
	var body: VBoxContainer = record["body"]
	_ach_btn = _make_menu_btn("trophy", UITheme.TACTICAL_YELLOW)
	_ach_btn.pressed.connect(func():
		_UIPopup.close(_records_dim, _records_panel, true)
		_on_achievements_pressed())
	body.add_child(_ach_btn)
	_codex_btn = _make_menu_btn("book", UITheme.TACTICAL_TEAL)
	_codex_btn.pressed.connect(func():
		_UIPopup.close(_records_dim, _records_panel, true)
		_on_codex_pressed())
	body.add_child(_codex_btn)
	_ranking_label = _UIStyle.tactical_label("", 24)
	_ranking_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_ranking_label)

	_build_options_panel()
	_build_power_panel()
	_build_character_panel()
	_build_achievement_panel()
	_build_quest_panel()
	_build_rewards_panel()
	_build_theme_panel()
	call_deferred("_prewarm_panels")
	_stagger_menu_entrance(title, box)
	_refresh_lobby()


func _refresh_lobby() -> void:
	if _hero_art == null: return
	var c := CharacterManager.selected()
	if c != null:
		var path := "res://assets/atlas/menu/portrait_%s.tres" % c.id
		if ResourceLoader.exists(path): _hero_art.texture = load(path)
		_hero_name.text = c.display
		_hero_desc.text = c.desc
	var arena := ThemeManager.selected()
	if arena != null: _arena_label.text = arena.display
	_records_btn.text = Locale.t("menu_records")
	_records_title.text = Locale.t("menu_records")
	_records_close.text = Locale.t("menu_close")


func _on_records_pressed() -> void:
	_ranking_label.text = _records_text()
	_UIPopup.open(_records_dim, _records_panel)


func _records_text() -> String:
	var text := Locale.t("records_header")
	for rank in range(1, ThreatManager.max_rank() + 1):
		var seconds := int(ThreatManager.best_seconds(rank))
		var survival := "%02d:%02d" % [seconds / 60, seconds % 60] if seconds > 0 else "--:--"
		text += "\n" + Locale.t("records_threat_row") % [rank, RankingManager.best_for_threat(rank), survival]
	return text


## 3차 버튼 묶음 사이의 간격. VBox 의 기본 간격(18)에 이만큼을 더해 "여기서 묶음이
## 바뀐다"가 읽히게 한다 — 선을 긋는 것보다 조용하고, 진입 stagger 에도 영향이 없다.
const _GROUP_GAP := 8.0

func _group_gap() -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, _GROUP_GAP)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


## 계정 상태 줄 — [코인 골드] · [검 위협 N] · [시계 최고 mm:ss].
## 값은 전부 이미 있던 것이다(MetaManager·ThreatManager). 보여 주지 않았을 뿐이다.
const _STATUS_FONT := 24
const _STATUS_ICON := 28

func _build_status_strip(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	box.add_child(row)

	_status_gold = _status_chip(row, "coin", UITheme.MENU_ICON_REWARD, Color(0.95, 0.87, 0.60))
	_status_threat = _status_chip(row, "sword", UITheme.SEC_THREAT, UITheme.SEC_THREAT_TXT)
	_status_best = _status_chip(row, "clock", UITheme.MENU_ICON_PLAIN, UITheme.TEXT_DIM)
	_status_threat_chip = _status_threat.get_parent()
	_status_best_chip = _status_best.get_parent()
	_status_row = row

	_refresh_status_strip()
	ThreatManager.changed.connect(_refresh_status_strip)


func _status_chip(row: HBoxContainer, icon: String, icon_col: Color, txt_col: Color) -> Label:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 6)
	row.add_child(chip)
	chip.add_child(UIIcon.make(icon, _STATUS_ICON, icon_col))
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", _STATUS_FONT)
	lbl.add_theme_color_override("font_color", txt_col)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(lbl)
	return lbl


## 강화 구매·보상 수령·등급 변경 뒤에 다시 부른다 — 이 줄은 시그널이 아니라 팝업이 닫힐 때
## 갱신된다(MetaManager 에는 변경 시그널이 없고, 골드가 바뀌는 곳은 그 두 팝업뿐이다).
func _refresh_status_strip() -> void:
	_refresh_lobby()
	if _status_gold == null:
		return
	var gold := MetaManager.meta_gold
	var rank := ThreatManager.selected_rank()
	var best := ThreatManager.best_seconds(rank)
	_status_gold.text = "%d" % gold
	_status_threat.text = Locale.t("threat_badge_fmt") % rank
	# 등급 1 은 보이지 않는다 — HUD 의 위협 뱃지와 같은 규칙이다(아직 사다리를 오르지 않은
	# 사람에게 "위협 1" 은 아무 정보가 아니다). 기록이 없으면 "최고 00:00" 도 빈칸일 뿐이다.
	_status_threat_chip.visible = rank > 1
	_status_best_chip.visible = best > 0.0
	if best > 0.0:
		var t := int(round(best))
		_status_best.text = Locale.t("threat_best_fmt") % ("%02d:%02d" % [t / 60, t % 60])
	# 새 계정(골드 0 · 등급 1 · 기록 없음)에는 말할 것이 없다 — 줄을 통째로 숨겨 첫 화면을
	# 깨끗하게 둔다. 한 판이라도 끝내면 골드가 생겨 줄이 나타난다.
	_status_row.visible = true


## 메뉴 진입 연출 — 로고가 먼저 뜨고 버튼이 위에서부터 차례로 내려앉는다.
##
## 왜 필요한가: 바로 앞 화면(타이틀)에는 슬램·섬광·부유가 있는데 메뉴는 씬 페이드가 걷히면
## 로고와 버튼 여덟 개가 통째로 그냥 있었다. 낙차가 커서 메뉴가 정지 화면처럼 보였다.
##
## 위치가 아니라 scale 로 움직인다 — 버튼은 VBoxContainer 의 자식이라 컨테이너가 배치할 때마다
## position 을 다시 쓴다(레벨업 카드와 같은 제약).
const _MENU_STAGGER := 0.04
const _MENU_IN_SEC := 0.20

func _stagger_menu_entrance(logo: Control, box: VBoxContainer) -> void:
	logo.modulate.a = 0.0
	var ltw := logo.create_tween()
	ltw.tween_property(logo, "modulate:a", 1.0, 0.30)

	var i := 0
	for c in box.get_children():
		var ctrl := c as Control
		if ctrl == null or ctrl == logo:
			continue
		ctrl.modulate.a = 0.0
		var sz := ctrl.size if ctrl.size.y > 0.0 else ctrl.custom_minimum_size
		ctrl.pivot_offset = Vector2(sz.x * 0.5, sz.y)
		ctrl.scale = Vector2(1.0, 0.9)
		var tw := ctrl.create_tween()
		tw.tween_interval(0.12 + _MENU_STAGGER * float(i))
		tw.tween_property(ctrl, "modulate:a", 1.0, _MENU_IN_SEC)
		tw.parallel().tween_property(ctrl, "scale", Vector2.ONE, _MENU_IN_SEC)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1
	# 이어하기가 가능하면 그 버튼만 한 번 더 튄다 — "지난 판이 남아 있다"를 알린다.
	if _continue_btn != null and not _continue_btn.disabled:
		var ptw := _continue_btn.create_tween()
		ptw.tween_interval(0.12 + _MENU_STAGGER * float(i) + _MENU_IN_SEC)
		ptw.tween_property(_continue_btn, "scale", Vector2(1.04, 1.04), 0.16)\
			.set_trans(Tween.TRANS_SINE)
		ptw.tween_property(_continue_btn, "scale", Vector2.ONE, 0.22)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 첫 오픈 렌더 스톨 방지 — 무거운 패널(초상화·아이콘 텍스처)을 시작 직후 투명하게 1회
## 렌더시켜 GPU 업로드를 미리 끝낸다. 이후 실제 오픈은 즉시 표시된다.
func _prewarm_panels() -> void:
	var panels: Array = [_power_panel, _char_panel]
	for p in panels:
		if p != null:
			p.modulate.a = 0.0
			p.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	for p in panels:
		if p != null:
			p.visible = false
			p.modulate.a = 1.0


## 옵션 패널(언어 / 사운드 On/Off) — Option 버튼으로 열고 닫는 오버레이.
## 옵션 팝업(P2-33). 세 줄의 설정 행 카드 + 맨 아래 개발용 기록 복사.
##
## 예전 모습: 언어 제목·칩 세 개·사운드 제목·"Sound: On" 버튼이 **전체 화면 판 한가운데**
## 250px 로 떠 있었다(center_body). 위아래가 텅 비어 설정 화면이 아니라 미완성 화면처럼
## 읽혔고, 제목 "Sound" 아래 버튼이 또 "Sound: On" 이라 같은 말을 두 번 했다.
## 개발용 기록 복사 버튼은 구분선 하나로 설정 사이에 끼어 있었다.
##
## 지금: 행 하나가 [제목 ─ 조작] 한 카드다(다른 팝업의 행 문법과 같다). 위에서부터 차곡차곡
## 쌓이고, 기록 복사는 닫기 버튼 바로 위 — 설정이 아니라 도구라는 자리다.
const _OPT_TITLE_W := 150.0
## 칩 폭 104 인 이유: 플레이트 여백(36)을 빼고 "English"(16px 에서 58px)가 들어가야 한다.
## 예전 92px 은 폭 검사 케이스가 없어서 조용히 넘치고 있었다 — 이번에 케이스를 넣으며 드러났다.
const _OPT_CHIP := Vector2(104, 42)
const _OPT_TOGGLE := Vector2(112, 42)

func _build_options_panel() -> void:
	var p := _UIPopup.make(self, "menu_options", UITheme.SEC_NEUTRAL, UITheme.TEXT,
		_on_close_options, {"separation": 12})
	_options_dim = p["dim"]
	_options_panel = p["panel"]
	_options_title = p["title"]
	_close_btn = p["close"]
	var vb: VBoxContainer = p["body"]

	# ── 언어: 칩 셋 ──
	var lang := _make_option_row(vb)
	_lang_title = lang["title"]
	var chips: HBoxContainer = lang["slot"]
	chips.add_theme_constant_override("separation", 6)
	_lang_buttons.clear()
	for l in Locale.SUPPORTED:
		var lb := Button.new()
		lb.text = Locale.native_name(l)
		lb.custom_minimum_size = _OPT_CHIP
		lb.add_theme_font_size_override("font_size", 16)
		lb.pressed.connect(_on_language_pressed.bind(l))
		chips.add_child(lb)
		_lang_buttons.append({"btn": lb, "lang": l})

	# ── 사운드(효과음)·음악: 각각 On/Off 토글 ──
	# 예전에는 스위치가 하나라 음악을 끄면 효과음도 같이 꺼졌다. 둘로 나눈다.
	var snd := _make_option_row(vb)
	_sound_title = snd["title"]
	_sound_btn = _make_toggle(snd["slot"], _on_sound_pressed)

	var mus := _make_option_row(vb)
	_music_title = mus["title"]
	_music_btn = _make_toggle(mus["slot"], _on_music_pressed)

## 설정 행 카드 — [제목 ────── 조작]. 반환: { "title": Label, "slot": HBoxContainer }.
## 판은 버튼 플레이트를 그대로 쓴다(다른 팝업의 행과 같은 재질). 카드 자체는 눌리지 않고
## 오른쪽 조작만 반응한다.
func _make_option_row(vb: VBoxContainer) -> Dictionary:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _UIStyle.button_box(UITheme.SEC_NEUTRAL))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var title := Label.new()
	title.custom_minimum_size = Vector2(_OPT_TITLE_W, 0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", UITheme.TEXT)
	row.add_child(title)

	var slot := HBoxContainer.new()
	slot.alignment = BoxContainer.ALIGNMENT_END
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slot)
	return {"title": title, "slot": slot}


## On/Off 토글 버튼. 문구는 _refresh_*_button 이 상태에 맞춰 넣는다.
func _make_toggle(slot: HBoxContainer, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = _OPT_TOGGLE
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(on_pressed)
	slot.add_child(b)
	return b


func _on_options_pressed() -> void:
	_UIPopup.open(_options_dim, _options_panel)


func _on_close_options() -> void:
	_UIPopup.close(_options_dim, _options_panel)


## 메타 성장(PowerUp) 오버레이 — 은행 골드로 영구 강화를 구매한다.
## 영구 강화 종류(effect_kind) → 아이콘 썸네일 경로.
const _POWER_ICONS := {
	"bullet_damage": "res://assets/atlas/ui/passive_gunpowder.tres",
	"max_health": "res://assets/atlas/ui/passive_armor.tres",
	"move_speed": "res://assets/atlas/ui/passive_swift.tres",
	"atk_speed": "res://assets/atlas/ui/passive_haste.tres",
	"crit": "res://assets/atlas/ui/passive_crit.tres",
	"regen": "res://assets/atlas/ui/passive_regen.tres",
	"area": "res://assets/atlas/ui/passive_magnet.tres",
	"gold_mult": "res://assets/atlas/ui/reward_gold.tres",
	"xp_mult": "res://assets/atlas/ui/hud_xp.tres",
	"revive": "res://assets/atlas/ui/reward_revive.tres",
}


func _build_power_panel() -> void:
	var p := _UIPopup.make(self, "popup_power", UITheme.SEC_POWER, UITheme.SEC_POWER_TXT,
		_on_power_close, {"scroll": true})
	_power_dim = p["dim"]
	_power_panel = p["panel"]
	var list: VBoxContainer = p["body"]
	list.add_theme_constant_override("separation", 10)

	# 보유 골드는 제목 바로 아래(구분선 위)에 둔다 — 가격을 보기 전에 잔액을 읽게 한다.
	_power_gold_label = Label.new()
	_power_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_gold_label.add_theme_font_size_override("font_size", 20)
	_power_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	var vb: VBoxContainer = p["vbox"]
	vb.add_child(_power_gold_label)
	vb.move_child(_power_gold_label, 1)   # 제목(0) 바로 뒤

	_power_rows.clear()
	for u in MetaManager.upgrades():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 86)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 18)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_UIStyle.apply_button_style(btn, Color(0.22, 0.16, 0.28), Color(0.6, 0.45, 0.9))
		btn.pressed.connect(_on_power_buy.bind(String(u["id"])))
		list.add_child(btn)
		# 강화 종류별 아이콘 썸네일 — 버튼 좌측에 고정.
		var icon_path: String = _POWER_ICONS.get(String(u.get("kind", "")), "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var tr := TextureRect.new()
			tr.texture = load(icon_path)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.anchor_top = 0.0
			tr.anchor_bottom = 1.0
			tr.offset_left = 14.0
			tr.offset_right = 72.0
			tr.offset_top = 14.0
			tr.offset_bottom = -14.0
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(tr)
			_UIStyle.set_button_content_margin_left(btn, 86)
		_power_rows.append(_add_power_side(btn, u))


## 위협 등급 선택 열기. 첫 호출에서만 패널을 만든다.
## forward — 새 게임 흐름의 3단계로 들어올 때(아레나 다음). UIPopup.open 주석 참고.
## silent — 앞 단계의 확정음이 이 전환을 이미 말하고 있을 때(UIPopup.open 주석).
func _open_threat(forward: bool = false, silent: bool = false) -> void:
	if _threat == null:
		_threat = _ThreatPanel.new()
		_threat.build(self, _on_threat_close, _on_threat_picked)
	_threat.refresh()
	_UIPopup.open(_threat.dim, _threat.panel, forward, silent)


func _on_threat_close() -> void:
	if _threat == null:
		return
	_UIPopup.close(_threat.dim, _threat.panel)
	# 새 게임 흐름 중이었다면 닫기도 "고른 등급으로 진행"이다(현재 선택은 항상 유효하다).
	if _newgame_flow:
		_finish_newgame_flow()


func _on_threat_picked() -> void:
	_UIPopup.close(_threat.dim, _threat.panel, true)   # 확정음이 이 전환을 말한다
	_finish_newgame_flow()


## 새 게임 흐름의 끝 — 서사 인트로를 보여준 뒤(완료/건너뛰기 시) 실제 시작.
func _finish_newgame_flow() -> void:
	if not _newgame_flow:
		return
	_newgame_flow = false
	_IntroStory.play(self, _start_new_game)


## 도감 열기. 첫 호출에서만 패널을 만든다(위 _codex 주석 참고).
func _on_codex_pressed() -> void:
	if _codex == null:
		_codex = _CodexPanel.new()
		_codex.build(self, _on_codex_close)
	_codex.refresh()
	_UIPopup.open(_codex.dim, _codex.panel)


func _on_codex_close() -> void:
	if _codex == null:
		return
	# **닫을 때** 지금 발견된 것을 전부 "봤다"로 표시한다. 여는 순간에 지우면 무엇이
	# 새것이었는지 볼 시간이 없다(CodexManager.mark_all_seen 주석 참고).
	CodexManager.mark_all_seen()
	_UIPopup.close(_codex.dim, _codex.panel)


func _on_power_pressed() -> void:
	_refresh_power()
	_UIPopup.open(_power_dim, _power_panel)


func _on_power_close() -> void:
	_UIPopup.close(_power_dim, _power_panel)
	_refresh_status_strip()   # 구매로 골드가 줄었을 수 있다




func _on_power_buy(id: String) -> void:
	if MetaManager.buy(id):
		SoundManager.play_ui("gold", 0.03, 1.25)
	_refresh_power()


# ── 캐릭터 선택 오버레이 ─────────────────────────────────────────────
func _build_character_panel() -> void:
	var p := _UIPopup.make(self, "popup_character", UITheme.SEC_CHAR, UITheme.SEC_CHAR_TXT,
		_on_character_close, {"scroll": true, "separation": 14})
	_char_dim = p["dim"]
	_char_panel = p["panel"]
	var rows_box: VBoxContainer = p["body"]
	rows_box.add_theme_constant_override("separation", 16)

	# 보유 골드는 제목 바로 아래(구분선 위) — 가격을 보기 전에 잔액을 읽게 한다.
	_char_gold_label = Label.new()
	_char_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_gold_label.add_theme_font_size_override("font_size", 20)
	_char_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	var vb: VBoxContainer = p["vbox"]
	vb.add_child(_char_gold_label)
	vb.move_child(_char_gold_label, 1)

	_char_rows.clear()
	for c in GameData.characters:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 168)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 19)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT   # 썸네일 오른쪽에서 좌측 정렬(겹침 방지)
		btn.pressed.connect(_on_char_pick.bind(String(c.id)))
		rows_box.add_child(btn)
		# 캐릭터 썸네일 — 전용 초상화(assets/ui/portraits/portrait_<id>.png)가 있으면 우선 사용,
		# 없으면 인게임 스프라이트. 잠금 상태는 _refresh_character 가 실루엣처럼 어둡게 한다.
		var thumb: TextureRect = null
		var tex_path := "res://assets/atlas/menu/portrait_%s.tres" % c.id   # 메뉴 아틀라스(인게임 미상주)
		if not ResourceLoader.exists(tex_path):
			tex_path = c.sprite_path
		if tex_path != "" and ResourceLoader.exists(tex_path):
			thumb = TextureRect.new()
			thumb.texture = load(tex_path)
			thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumb.anchor_top = 0.0
			thumb.anchor_bottom = 1.0
			thumb.offset_left = 14.0
			thumb.offset_right = 158.0
			thumb.offset_top = 10.0
			thumb.offset_bottom = -10.0
			thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(thumb)
			_UIStyle.set_button_content_margin_left(btn, 172)
		# 잠금 자물쇠 — 썸네일 위에 얹는다. thumb 의 자식으로 넣으면 잠금 시 걸리는
		# modulate(0.35)에 같이 어두워져 안 보인다 — 버튼에 직접 붙여 썸네일 영역에 맞춘다.
		# 갱신마다 만들지 않고 한 번 만들어 visible 만 토글한다.
		var lock := UIIcon.make("lock", 44, Color(0.95, 0.86, 0.55))
		lock.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		lock.offset_left = 64.0
		lock.offset_right = 108.0
		lock.offset_top = -22.0
		lock.offset_bottom = 22.0
		lock.visible = false
		btn.add_child(lock)

		# 선택 표시 — 예전에는 이름 앞에 `"> "` 를 붙였다. 잠금 표시를 아이콘으로 바꾼 것과
		# 같은 이유로(P2-4) 여기도 아이콘으로 한다: 글자는 언어·폰트에 매이고 화살표는
		# "다음"으로도 읽힌다. 자물쇠와 같은 방식으로 한 번 만들고 visible 만 토글한다.
		var pick := UIIcon.make("check", 30, Color(0.55, 1.0, 0.6))
		pick.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		pick.offset_left = -46.0
		pick.offset_right = -16.0
		pick.offset_top = 12.0
		pick.offset_bottom = 42.0
		pick.visible = false
		btn.add_child(pick)
		_char_rows.append({"btn": btn, "c": c, "thumb": thumb, "lock": lock, "pick": pick})



## 오버레이 카드 갱신 — 선택/잠금/구매 상태를 반영.
func _refresh_character() -> void:
	_refresh_lobby()
	_roll_meta_gold(MetaManager.meta_gold)
	var sel := CharacterManager.selected_id()
	for row in _char_rows:
		var c: CharacterData = row["c"]
		var btn: Button = row["btn"]
		var thumb: TextureRect = row.get("thumb")
		if row.get("pick"):
			row["pick"].visible = CharacterManager.is_unlocked(c) and c.id == sel
		if CharacterManager.is_unlocked(c):
			btn.text = "%s\n%s\n%s" % [c.display, c.desc, _char_stat_line(c)]
			if c.id == sel:
				_UIStyle.apply_button_style(btn, Color(c.color.r * 0.30, c.color.g * 0.30, c.color.b * 0.30, 1.0), c.color)
			else:
				_UIStyle.apply_button_style(btn, Color(0.14, 0.16, 0.20), Color(0.35, 0.40, 0.48))
			if thumb:
				thumb.modulate = Color.WHITE
			if row.get("lock"):
				row["lock"].visible = false
		else:
			btn.text = "%s\n%s\n%s" % [c.display, _char_stat_line(c), _unlock_hint(c)]
			_UIStyle.apply_button_style(btn, Color(0.10, 0.10, 0.12), Color(0.30, 0.30, 0.34))
			if thumb:
				thumb.modulate = Color(0.35, 0.35, 0.4)   # 잠금 — 실루엣처럼 어둡게
			if row.get("lock"):
				row["lock"].visible = true
		# apply_button_style 이 스타일박스를 새로 깔아 썸네일용 좌측 컨텐츠 마진이 사라진다 — 재적용.
		if thumb:
			_UIStyle.set_button_content_margin_left(btn, 172)


## 캐릭터 시작 스탯 보정 요약 한 줄(비싼 캐릭터일수록 좋은 수치가 한눈에 비교되게).
func _char_stat_line(c: CharacterData) -> String:
	var parts: Array = []
	if c.bonus_max_health > 0: parts.append("HP+%d" % c.bonus_max_health)
	if c.bonus_bullet_damage > 0: parts.append("DMG+%d" % c.bonus_bullet_damage)
	if c.bonus_move_speed > 0: parts.append("SPD+%d" % c.bonus_move_speed)
	if c.bonus_atk_speed > 0: parts.append("ATK+%d" % c.bonus_atk_speed)
	if c.bonus_area > 0: parts.append("AREA+%d" % c.bonus_area)
	if c.bonus_crit > 0: parts.append("CRIT+%d" % c.bonus_crit)
	if c.bonus_greed > 0: parts.append("LOOT+%d" % c.bonus_greed)
	var ult: WeaponData = GameData.weapon_def(c.ultimate_weapon)
	if ult != null:
		parts.append("ULT: %s" % ult.display)
	return "  ".join(parts)


## 잠긴 캐릭터의 해금 조건 안내 문구.
func _unlock_hint(c: CharacterData) -> String:
	if c.unlock_cost > 0:
		return Locale.t("unlock_cost_fmt") % c.unlock_cost
	if c.unlock_achievement != "":
		var a: AchievementData = GameData.achievement(c.unlock_achievement)
		return Locale.t("locked_by_fmt") % (a.desc if a != null else Locale.t("locked_by_ach"))
	return Locale.t("locked")


func _on_char_pick(id: String) -> void:
	var c: CharacterData = GameData.character(id)
	if c == null:
		return
	var picked := false
	if CharacterManager.is_unlocked(c):
		# 이미 가진 것을 고르는 것과 사는 것은 다른 사건이다 — 선택은 확정음, 구매는
		# 동전음. 예전에는 둘 다 gold 를 피치만 바꿔 썼다.
		SoundManager.play_ui("ui_select", 0.03)
		CharacterManager.select(id)
		picked = true
	elif c.unlock_cost > 0 and CharacterManager.try_buy(id):
		CharacterManager.select(id)   # 구매 성공 → 즉시 선택
		SoundManager.play_ui("gold", 0.02, 1.0)
		picked = true
	else:
		# 해금 불가(골드 부족/도전과제 미달). 예전에는 player_hurt(피격음)를 냈다 —
		# 살 돈이 없을 때 맞는 소리가 나는 셈이었다.
		SoundManager.play_ui("ui_deny", 0.04)
	_refresh_character()
	if picked and _newgame_flow:
		# 다음 단계: 아레나(테마) 선택. 이 전환의 소리는 위의 확정음 하나뿐이다 —
		# 닫힘·열림음까지 내면 한 번의 탭에 네 소리가 겹친다(UIPopup.open 주석).
		_UIPopup.close(_char_dim, _char_panel, true)
		_on_theme_pressed(true, true)


## forward — 새 게임 흐름의 1단계로 열릴 때. 버튼 시그널은 인자 없이 호출한다(기본값 false).
func _on_character_pressed(forward: bool = false) -> void:
	_refresh_character()
	_UIPopup.open(_char_dim, _char_panel, forward)


func _on_character_close() -> void:
	_newgame_flow = false   # 선택 중 닫으면 새 게임 흐름 취소
	_UIPopup.close(_char_dim, _char_panel)




# ── 도전과제 오버레이 ─────────────────────────────────────────────────
func _build_achievement_panel() -> void:
	var p := _UIPopup.make(self, "popup_achievements", UITheme.SEC_ACHIEVE, UITheme.SEC_ACHIEVE_TXT,
		_on_achievements_close, {"scroll": true, "separation": 10})
	_ach_dim = p["dim"]
	_ach_panel = p["panel"]
	_ach_list = p["body"]   # 행은 _refresh_achievements() 가 카드로 다시 만든다
	_ach_list.add_theme_constant_override("separation", 6)


func _refresh_achievements() -> void:
	if _ach_list == null:
		return
	for c in _ach_list.get_children():
		_ach_list.remove_child(c)
		c.queue_free()
	for a in GameData.achievements:
		var done := AchievementManager.is_unlocked(a.id)
		var prog := mini(AchievementManager.progress(a.metric), a.threshold)
		_ach_list.add_child(UIListRow.make({
			"icon": _ach_icon(a.metric),
			"icon_color": Color(1.0, 0.82, 0.35),
			"title": a.display,
			"reward": int(a.reward_gold),
			"desc": "%s   (%d / %d)" % [a.desc, prog, a.threshold],
			"cur": prog,
			"goal": a.threshold,
			"state": UIListRow.STATE_DONE if done else UIListRow.STATE_ACTIVE,
		}))


## 도전과제 지표별 아이콘 — 누적 처치/보스/생존 시간/최고 레벨.
func _ach_icon(metric: String) -> String:
	match metric:
		"boss_kills": return "sword"
		"best_time":  return "clock"
		"best_level": return "star"
		_:            return "skull"


func _on_achievements_pressed() -> void:
	_refresh_achievements()
	_UIPopup.open(_ach_dim, _ach_panel)


func _on_achievements_close() -> void:
	_UIPopup.close(_ach_dim, _ach_panel)


# ── 끝없는 과제(Quests) 패널 — 현재 활성 과제 + 진행 + 다음 보상 표시 ──────────
func _build_quest_panel() -> void:
	# 카드형 행은 텍스트 행보다 높아 항목이 늘면 넘친다 — 셸의 스크롤로 수용한다.
	var p := _UIPopup.make(self, "popup_quests", UITheme.SEC_QUEST, UITheme.SEC_QUEST_TXT,
		_on_quests_close, {"hint_key": "quest_hint", "scroll": true})
	_quest_dim = p["dim"]
	_quest_panel = p["panel"]
	_quest_list = p["body"]
	_quest_list.add_theme_constant_override("separation", 14)


## ── 보상 보관함(REWARDS) — 유저가 직접 "CLAIM"을 눌러 수령 ─────────────────
func _build_rewards_panel() -> void:
	var p := _UIPopup.make(self, "popup_rewards", UITheme.SEC_REWARD, UITheme.SEC_REWARD_TXT,
		_on_rewards_close, {"hint_key": "rewards_hint", "scroll": true})
	_rewards_dim = p["dim"]
	_rewards_panel = p["panel"]
	_rewards_list = p["body"]
	_rewards_list.add_theme_constant_override("separation", 10)

	_rewards_total = Label.new()
	_rewards_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rewards_total.add_theme_font_size_override("font_size", 16)
	_rewards_total.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_UIPopup.add_above_close(p, _rewards_total)

	var claim_all := Button.new()
	claim_all.text = Locale.t("rewards_claim_all")
	claim_all.custom_minimum_size = Vector2(0, 54)
	claim_all.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(claim_all, Color(0.45, 0.32, 0.06), Color(1.0, 0.88, 0.4))
	claim_all.pressed.connect(_on_claim_all_pressed)
	_UIPopup.add_above_close(p, claim_all)


## 3차(보조) 메뉴 버튼 — 6개가 모두 같은 어두운 금속 플레이트를 쓰고, 구분은 좌측
## 아이콘의 모양·색만으로 한다. 1·2차보다 좁게(SHRINK_CENTER) 두어 폭으로도 위계를 만든다.
func _make_menu_btn(icon_kind: String, icon_col: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(320, 88)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_UIStyle.tactical_button(b, false, false, icon_col)
	_UIStyle.set_button_content_margin_left(b, 68)
	var ic := UIIcon.make(icon_kind, 32, icon_col)
	ic.anchor_top = 0.5
	ic.anchor_bottom = 0.5
	ic.offset_left = 24
	ic.offset_right = 56
	ic.offset_top = -16
	ic.offset_bottom = 16
	b.add_child(ic)
	return b


## 미수령 보상 배지 — 버튼 우상단의 작은 붉은 원. 라벨에 "(3)" 을 붙이는 것보다
## 눈에 띄고, 번역된 라벨 길이에 영향을 주지 않는다.
func _build_rewards_badge() -> void:
	_rewards_badge = Label.new()
	_rewards_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rewards_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rewards_badge.add_theme_font_size_override("font_size", 14)
	_rewards_badge.add_theme_color_override("font_color", UITheme.LOGO_CREAM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.80, 0.14, 0.14)
	sb.set_corner_radius_all(13)
	sb.corner_detail = 6
	sb.anti_aliasing = true
	sb.set_border_width_all(2)
	sb.border_color = Color(0.06, 0.04, 0.05, 0.9)
	_rewards_badge.add_theme_stylebox_override("normal", sb)
	_rewards_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_rewards_badge.offset_left = -36.0
	_rewards_badge.offset_right = -10.0
	_rewards_badge.offset_top = 3.0
	_rewards_badge.offset_bottom = 29.0
	_rewards_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rewards_badge.visible = false
	_rewards_btn.add_child(_rewards_badge)


## 대기 보상 개수 갱신 — 0이면 배지를 숨긴다.
func _refresh_rewards_badge() -> void:
	if _rewards_btn == null:
		return
	_rewards_btn.text = Locale.t("menu_rewards")
	if _rewards_badge:
		var n: int = RewardInbox.count()
		_rewards_badge.visible = n > 0
		_rewards_badge.text = "%d" % mini(n, 99)


func _refresh_rewards() -> void:
	for c in _rewards_list.get_children():
		c.queue_free()
	var entries: Array = RewardInbox.entries
	if entries.is_empty():
		var empty := Label.new()
		empty.text = Locale.t("rewards_empty")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Color(0.6, 0.58, 0.5))
		_rewards_list.add_child(empty)
		_rewards_total.text = ""
		return
	var total := 0
	for i in entries.size():
		var e: Dictionary = entries[i]
		total += int(e["gold"])
		var from_quest: bool = e["src"] == "quest"
		_rewards_list.add_child(UIListRow.make({
			"icon": "flag" if from_quest else "trophy",
			"icon_color": Color(0.60, 1.0, 0.60) if from_quest else Color(1.0, 0.82, 0.35),
			"title": String(e["title"]),
			"reward": int(e["gold"]),
			"desc": Locale.t("rewards_src_quest" if from_quest else "rewards_src_ach"),
			"state": UIListRow.STATE_READY,
			"action": {"text": Locale.t("rewards_claim"), "on_pressed": _on_claim_pressed.bind(i),
				"accent": Color(0.5, 0.95, 0.5)},
		}))
	_rewards_total.text = Locale.t("rewards_total_fmt") % total


## 수령 — 그 행이 물러나는 것을 보여준 뒤 목록을 다시 만든다. 예전에는 누르는 즉시
## _refresh_rewards() 가 목록을 통째로 새로 그려, 무엇이 없어졌는지 알 수 없었다.
##
## 가로로 밀어내지 않고 스케일로 접는 이유는 카드가 VBoxContainer 의 자식이기 때문이다
## (컨테이너가 배치할 때마다 position 을 다시 쓴다 — 레벨업 카드와 같은 제약).
## 접히는 0.18초 동안은 다른 수령을 막는다. 그 사이 RewardInbox 는 이미 한 칸 줄었는데
## 화면의 행은 아직 그대로라, 다음 탭이 **다른 보상을 수령**하게 된다.
const _CLAIM_OUT_SEC := 0.18
var _claiming: bool = false

func _on_claim_pressed(index: int) -> void:
	if _claiming:
		return
	_claiming = true
	var got: int = RewardInbox.claim(index)
	if got > 0:
		SoundManager.play_ui("gold", 0.03, 1.25)
	await _fold_reward_row(index)
	_claiming = false
	if not is_inside_tree():
		return
	_refresh_rewards()
	_refresh_meta_gold_labels()


## 수령한 행을 오른쪽 끝을 축으로 접으며 사라지게 한다.
func _fold_reward_row(index: int) -> void:
	var row: Control = null
	if _rewards_list != null and index >= 0 and index < _rewards_list.get_child_count():
		row = _rewards_list.get_child(index) as Control
	if row == null:
		return
	var sz := row.size if row.size.x > 0.0 else row.custom_minimum_size
	row.pivot_offset = Vector2(sz.x, sz.y * 0.5)
	var tw := row.create_tween()
	tw.set_parallel(true)
	tw.tween_property(row, "modulate:a", 0.0, _CLAIM_OUT_SEC)
	tw.tween_property(row, "scale", Vector2(0.88, 0.88), _CLAIM_OUT_SEC).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(_CLAIM_OUT_SEC, true, false, true).timeout


func _on_claim_all_pressed() -> void:
	if _claiming:
		return
	var got: int = RewardInbox.claim_all()
	if got > 0:
		SoundManager.play_ui("gold", 0.03, 1.1)
		SoundManager.play_ui("gold", 0.03, 1.4)
	_refresh_rewards()
	_refresh_meta_gold_labels()


## 메타 골드 라벨은 세 패널(강화·캐릭터·아레나)이 같은 값을 보여준다. 수령 직후에는 그 값이
## 뛰므로 HUD 골드와 같은 롤링 카운터로 굴려 올린다 — 숫자가 바뀐 것을 눈이 따라가게 한다.
var _meta_gold_shown: float = -1.0
var _meta_gold_tween: Tween = null

func _roll_meta_gold(to: int) -> void:
	if _meta_gold_shown < 0.0:
		_meta_gold_shown = float(to)   # 첫 표시는 연출 없이
		_set_meta_gold_text(_meta_gold_shown)
		return
	if _meta_gold_tween != null and _meta_gold_tween.is_valid():
		_meta_gold_tween.kill()
	_meta_gold_tween = create_tween()
	_meta_gold_tween.tween_method(_set_meta_gold_text, _meta_gold_shown, float(to), 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_meta_gold_text(v: float) -> void:
	_meta_gold_shown = v
	var txt := Locale.t("gold_fmt") % int(round(v))
	for lbl in [_power_gold_label, _char_gold_label, _theme_gold_label]:
		if lbl != null:
			lbl.text = txt


## 파워업/캐릭터/테마 패널의 메타 골드 라벨을 갱신(열려 있지 않아도 안전).
func _refresh_meta_gold_labels() -> void:
	_roll_meta_gold(MetaManager.meta_gold)


func _on_rewards_pressed() -> void:
	_refresh_rewards()
	_UIPopup.open(_rewards_dim, _rewards_panel)


func _on_rewards_close() -> void:
	_UIPopup.close(_rewards_dim, _rewards_panel)
	_refresh_status_strip()   # 수령으로 골드가 늘었을 수 있다


## 활성 과제를 매번 새로 그린다(티어가 바뀌므로 재생성이 간단·정확).
func _refresh_quests() -> void:
	for c in _quest_list.get_children():
		c.queue_free()
	for q in QuestManager.active_quests():
		var cur := int(q["current"])
		var goal := int(q["goal"])
		_quest_list.add_child(UIListRow.make({
			"icon": _quest_icon(String(q.get("id", ""))),
			"icon_color": Color(0.95, 0.72, 0.45),
			"title": String(q["title"]),
			"reward": int(q["reward"]),
			"desc": "%s   (%d / %d)" % [q["desc"], cur, goal],
			"cur": cur,
			"goal": goal,
			"state": UIListRow.STATE_READY if cur >= goal else UIListRow.STATE_ACTIVE,
		}))


## 과제 종류별 아이콘 — 좀비 처치/보스 격파/생존 시간.
func _quest_icon(id: String) -> String:
	match id:
		"bosses":  return "sword"
		"survive": return "clock"
		_:         return "skull"


func _on_quests_pressed() -> void:
	_refresh_quests()
	_UIPopup.open(_quest_dim, _quest_panel)


func _on_quests_close() -> void:
	_UIPopup.close(_quest_dim, _quest_panel)




# ── 테마(아레나) 선택 오버레이 ────────────────────────────────────────
func _build_theme_panel() -> void:
	var p := _UIPopup.make(self, "popup_arena", UITheme.SEC_ARENA, UITheme.SEC_ARENA_TXT,
		_on_theme_close, {"scroll": true, "separation": 14})
	_theme_dim = p["dim"]
	_theme_panel = p["panel"]
	var rows_box: VBoxContainer = p["body"]
	rows_box.add_theme_constant_override("separation", 16)

	# 보유 골드는 제목 바로 아래(구분선 위) — 가격을 보기 전에 잔액을 읽게 한다.
	_theme_gold_label = Label.new()
	_theme_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_theme_gold_label.add_theme_font_size_override("font_size", 20)
	_theme_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	var vb: VBoxContainer = p["vbox"]
	vb.add_child(_theme_gold_label)
	vb.move_child(_theme_gold_label, 1)

	# 테마 카드 = [이름 / 설명] 위, [가로를 꽉 채우는 와이드 썸네일] 아래.
	# 카드 높이(썸네일이 남는 세로를 모두 차지). 3개 기준으로 한 화면에 들어온다.
	var card_h := 240.0

	_theme_rows.clear()
	for t in GameData.themes:
		# 내용을 Button 의 text 가 아니라 "앵커로 얹은 자식"으로 구성하는 이유:
		# autowrap 이 켜진 Button/Label 은 최소 크기를 "가장 좁은 폭으로 줄바꿈했을 때의
		# 높이"로 보고한다. 그 값이 컨테이너에 전파되면 카드 하나가 스크롤 영역 전체를
		# 차지할 만큼 부풀어 오른다(이전 레이아웃에서 실제로 발생). Button 은 컨테이너가
		# 아니므로 앵커 자식의 최소 크기는 카드 높이에 영향을 주지 않는다.
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, card_h)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN   # 남는 세로를 먹지 않게 고정
		btn.clip_contents = true
		btn.pressed.connect(_on_theme_pick.bind(String(t.id)))
		rows_box.add_child(btn)

		var pad := MarginContainer.new()
		pad.set_anchors_preset(Control.PRESET_FULL_RECT)
		pad.add_theme_constant_override("margin_left", 16)
		pad.add_theme_constant_override("margin_right", 16)
		pad.add_theme_constant_override("margin_top", 12)
		pad.add_theme_constant_override("margin_bottom", 14)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(pad)

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(col)

		# 이름 줄 = [자물쇠] + 이름. 예전에는 이름 앞에 `"[-] "` 를 붙였다(P2-4).
		# 자물쇠는 한 번 만들어 visible 만 토글한다 — 갱신마다 노드를 만들지 않는다.
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(name_row)

		var lock := UIIcon.make("lock", 22, Color(0.95, 0.86, 0.55))
		lock.visible = false
		name_row.add_child(lock)

		# 선택 표시 — 캐릭터 카드와 같은 이유로 `"> "` 대신 체크 아이콘을 쓴다.
		var pick := UIIcon.make("check", 22, Color(0.55, 1.0, 0.6))
		pick.visible = false
		name_row.add_child(pick)

		# 이름/설명은 autowrap 을 끄고 넘치면 잘라낸다(위 주석의 최소 크기 폭주 방지).
		var name_lbl := Label.new()
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.clip_text = true
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UITheme.heading(name_lbl)
		name_row.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.add_theme_font_size_override("font_size", 15)
		desc_lbl.clip_text = true
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(desc_lbl)

		# 와이드 썸네일 — 카드 가로를 꽉 채우고 남는 세로를 모두 차지. 원본(4:3)은
		# 가운데를 잘라 배너처럼 보여준다(COVERED).
		var thumb: TextureRect = null
		var tex_path := "res://assets/atlas/menu/theme_%s.tres" % t.id   # 메뉴 아틀라스(인게임 미상주)
		if ResourceLoader.exists(tex_path):
			thumb = TextureRect.new()
			thumb.texture = load(tex_path)
			thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
			thumb.clip_contents = true
			thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(thumb)
		_theme_rows.append({"btn": btn, "t": t, "thumb": thumb,
			"name": name_lbl, "desc": desc_lbl, "lock": lock, "pick": pick})



func _refresh_theme() -> void:
	_refresh_lobby()
	_roll_meta_gold(MetaManager.meta_gold)
	var sel := ThemeManager.selected_id()
	for row in _theme_rows:
		var t: ThemeData = row["t"]
		var btn: Button = row["btn"]
		var thumb: TextureRect = row.get("thumb")
		var name_lbl: Label = row["name"]
		var desc_lbl: Label = row["desc"]
		var lock: Control = row.get("lock")
		if lock:
			lock.visible = not ThemeManager.is_unlocked(t)
		if row.get("pick"):
			row["pick"].visible = ThemeManager.is_unlocked(t) and t.id == sel
		if ThemeManager.is_unlocked(t):
			var picked: bool = t.id == sel
			name_lbl.text = String(t.display)
			name_lbl.add_theme_color_override("font_color",
				UITheme.SEC_ARENA_TXT if picked else UITheme.TEXT)
			desc_lbl.text = t.desc
			desc_lbl.add_theme_color_override("font_color", UITheme.TEXT_DIM)
			if picked:
				_UIStyle.apply_button_style(btn, Color(t.tile_b.r, t.tile_b.g, t.tile_b.b, 1.0), t.mark)
			else:
				_UIStyle.apply_button_style(btn, Color(0.14, 0.16, 0.20), Color(0.35, 0.40, 0.48))
			if thumb:
				thumb.modulate = Color.WHITE
		else:
			name_lbl.text = t.display
			name_lbl.add_theme_color_override("font_color", Color(0.62, 0.64, 0.70))
			desc_lbl.text = _theme_unlock_hint(t)
			desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.74, 0.42))
			_UIStyle.apply_button_style(btn, Color(0.10, 0.10, 0.12), Color(0.30, 0.30, 0.34))
			if thumb:
				thumb.modulate = Color(0.35, 0.35, 0.4)


func _theme_unlock_hint(t: ThemeData) -> String:
	if t.unlock_cost > 0:
		return Locale.t("unlock_cost_fmt") % t.unlock_cost
	if t.unlock_achievement != "":
		var a: AchievementData = GameData.achievement(t.unlock_achievement)
		return Locale.t("locked_by_fmt") % (a.desc if a != null else Locale.t("locked_by_ach"))
	return Locale.t("locked")


## forward — 새 게임 흐름의 2단계(생존자 다음)로 열릴 때.
## silent — 앞 단계의 확정음이 이 전환을 이미 말하고 있을 때(UIPopup.open 주석).
func _on_theme_pressed(forward: bool = false, silent: bool = false) -> void:
	_refresh_theme()
	_UIPopup.open(_theme_dim, _theme_panel, forward, silent)


func _on_theme_close() -> void:
	_newgame_flow = false   # 선택 중 닫으면 새 게임 흐름 취소
	_UIPopup.close(_theme_dim, _theme_panel)




func _on_theme_pick(id: String) -> void:
	var t: ThemeData = null
	for row in _theme_rows:
		if row["t"].id == id:
			t = row["t"]
			break
	if t == null:
		return
	var picked := false
	if ThemeManager.is_unlocked(t):
		SoundManager.play_ui("ui_select", 0.03)   # 캐릭터 선택과 같은 문법
		ThemeManager.select(id)
		picked = true
	elif t.unlock_cost > 0 and ThemeManager.try_buy(id):
		ThemeManager.select(id)
		SoundManager.play_ui("gold", 0.02, 1.0)
		picked = true
	else:
		SoundManager.play_ui("ui_deny", 0.04)
	_refresh_theme()
	if picked and _newgame_flow:
		_UIPopup.close(_theme_dim, _theme_panel, true)   # 확정음이 이 전환을 말한다
		# 다음 단계: 위협 등급. 해금된 등급이 하나뿐이면 고를 것이 없으므로 건너뛴다 —
		# 새 플레이어에게 선택지 없는 화면을 세우지 않는다(P1-12).
		if ThreatManager.max_rank() > 1:
			_open_threat(true, true)
		else:
			_finish_newgame_flow()


func _refresh_power() -> void:
	_roll_meta_gold(MetaManager.meta_gold)
	for row in _power_rows:
		var u: Dictionary = row["u"]
		var id: String = String(u["id"])
		var lv := MetaManager.level(id)
		var mx := int(u["max"])
		var btn: Button = row["btn"]
		# 이름·설명만 글자로 남는다 — 레벨과 가격은 우측 열의 위젯이 말한다.
		btn.text = "%s\n%s" % [u["name"], u["desc"]]
		for i in row["pips"].size():
			row["pips"][i].add_theme_stylebox_override("panel", _power_pip_box(i < lv))
		if lv >= mx:
			row["price_box"].visible = false
			row["maxed"].visible = true
			btn.disabled = true
		else:
			var c := MetaManager.cost(id)
			row["price_box"].visible = true
			row["maxed"].visible = false
			row["price"].text = "%d" % c
			btn.disabled = MetaManager.meta_gold < c
		# apply_button_style 이 다시 깔릴 수 있으므로 좌우 여백을 여기서 다시 잡지 않는다 —
		# 이 행들은 스타일을 한 번만 적용한다(_build_power_panel).


## 강화 행의 우측 열 — 레벨 핍과 가격표. 예전에는 둘 다 버튼 글자 안에 있었다
## ("이름 (2/5)\n설명   -300 G"). 숫자를 글로 읽어야 해서 남은 레벨도 가격도 눈에 안 들어왔다.
##
## 핍을 쓰는 이유: 최대 레벨이 3~10 으로 제각각이라 "3/10"과 "3/3"이 글자로는 같은 무게인데,
## 핍은 남은 칸이 그대로 보인다. 최대 10개까지라 폭을 그에 맞춰 잡았다.
const _POWER_PIP := 7          # 핍 지름
const _POWER_PIP_GAP := 3
const _POWER_MAX_PIPS := 10    # data/meta 의 max_level 최댓값
const _POWER_RIGHT_W := _POWER_MAX_PIPS * (_POWER_PIP + _POWER_PIP_GAP)   # 100
const _POWER_RIGHT_PAD := 14

func _add_power_side(btn: Button, u: Dictionary) -> Dictionary:
	# 글자가 이 열을 파고들지 않도록 버튼의 우측 콘텐츠 여백을 그만큼 확보한다.
	_UIStyle.set_button_content_margin_right(btn, _POWER_RIGHT_W + _POWER_RIGHT_PAD * 2)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.offset_left = -(_POWER_RIGHT_W + _POWER_RIGHT_PAD)
	col.offset_right = -_POWER_RIGHT_PAD
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 7)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(col)

	# 가격 — 보상함·퀘스트 카드와 같은 문법(코인 아이콘 + 숫자).
	var price_box := HBoxContainer.new()
	price_box.alignment = BoxContainer.ALIGNMENT_END
	price_box.add_theme_constant_override("separation", 4)
	price_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(price_box)
	price_box.add_child(UIIcon.make("coin", 16, Color(1.0, 0.82, 0.30)))
	var price := Label.new()
	price.add_theme_font_size_override("font_size", 16)
	price.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	price_box.add_child(price)

	# 만렙 표시 — 가격 자리를 대신 차지한다(둘이 동시에 보일 일은 없다).
	var maxed := Label.new()
	maxed.text = Locale.t("power_max_tag")
	maxed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	maxed.add_theme_font_size_override("font_size", 16)
	maxed.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	maxed.visible = false
	col.add_child(maxed)

	# 레벨 핍 — 한 번만 만들고 갱신 때는 색만 바꾼다.
	var pips_box := HBoxContainer.new()
	pips_box.alignment = BoxContainer.ALIGNMENT_END
	pips_box.add_theme_constant_override("separation", _POWER_PIP_GAP)
	pips_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pips_box)
	var pips: Array = []
	for _i in int(u["max"]):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(_POWER_PIP, _POWER_PIP)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips_box.add_child(dot)
		pips.append(dot)

	return {"btn": btn, "u": u, "price": price, "price_box": price_box,
		"maxed": maxed, "pips": pips}


## 핍 하나의 색 — 채운 칸은 강화색, 빈 칸은 어두운 함몰부.
func _power_pip_box(filled: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(_POWER_PIP / 2.0))
	sb.corner_detail = 4
	sb.anti_aliasing = true
	if filled:
		sb.bg_color = Color(0.78, 0.58, 1.00)
	else:
		sb.bg_color = Color(0.10, 0.10, 0.14, 0.9)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.40, 0.35, 0.50, 0.55)
	return sb


## 현재 언어로 모든 라벨/버튼 텍스트를 갱신하고 선택 강조를 다시 칠한다.
func _apply_language() -> void:
	_refresh_lobby()
	_new_game_btn.text = Locale.t("menu_new_game")
	_continue_btn.text = Locale.t("menu_continue")
	_refresh_status_strip()
	_ach_btn.text = Locale.t("menu_achievements")
	_quest_btn.text = Locale.t("menu_quests")
	_power_btn.text = Locale.t("menu_powerup")
	_codex_btn.text = Locale.t("menu_codex")
	if _codex != null:
		_codex.apply_language()
	if _threat != null:
		_threat.apply_language()
	_refresh_rewards_badge()   # 보상 버튼 라벨도 로케일에서 가져온다
	_lang_title.text = Locale.t("menu_language")
	_sound_title.text = Locale.t("menu_sound")
	_music_title.text = Locale.t("menu_music")
	_refresh_music_button()
	_options_btn.text = Locale.t("menu_options")
	_options_title.text = Locale.t("menu_options")
	_close_btn.text = Locale.t("menu_close")
	_refresh_language_buttons()
	_refresh_sound_button()


## 사운드 On/Off 토글 — 즉시 적용·저장하고 버튼 표시를 갱신.
func _on_sound_pressed() -> void:
	SoundManager.set_enabled(not SoundManager.is_enabled())
	_refresh_sound_button()


func _refresh_sound_button() -> void:
	_style_toggle(_sound_btn, SoundManager.is_enabled())


func _on_music_pressed() -> void:
	SoundManager.set_music_enabled(not SoundManager.is_music_enabled())
	_refresh_music_button()


func _refresh_music_button() -> void:
	_style_toggle(_music_btn, SoundManager.is_music_enabled())


## 토글의 문구·색. 제목 칸이 "사운드"/"음악"을 이미 말하므로 버튼은 On/Off 만 말한다 —
## 예전 "Sound: On" 은 제목과 같은 말을 두 번 했다.
func _style_toggle(btn: Button, on: bool) -> void:
	if btn == null:
		return
	btn.text = Locale.t("sound_on") if on else Locale.t("sound_off")
	if on:
		_UIStyle.apply_button_style(btn, Color(0.14, 0.34, 0.20), Color(0.4, 0.85, 0.45))
	else:
		_UIStyle.apply_button_style(btn, Color(0.30, 0.14, 0.14), Color(0.85, 0.4, 0.4))


func _on_language_pressed(lang: String) -> void:
	Locale.set_language(lang)


func _on_language_changed(_lang: String) -> void:
	_apply_language()


## 현재 선택된 언어 버튼만 강조.
func _refresh_language_buttons() -> void:
	for entry in _lang_buttons:
		var b: Button = entry["btn"]
		if entry["lang"] == Locale.current:
			_UIStyle.apply_button_style(b, Color(0.30, 0.26, 0.10), Color(1.0, 0.82, 0.25))
		else:
			_UIStyle.apply_button_style(b, Color(0.14, 0.15, 0.20), Color(0.30, 0.32, 0.40))


## 새 게임 흐름: 생존자 선택 -> 아레나 선택 -> 인트로 -> 시작.
## 캐릭터/테마 선택은 이 흐름에서만 열린다(메인 메뉴 버튼 제거됨).
var _newgame_flow := false

func _on_new_game_pressed() -> void:
	_newgame_flow = true
	_on_character_pressed(true)   # 1단계: 생존자 선택


func _start_new_game() -> void:
	SaveManager.delete_save()
	SaveManager.pending_continue = false
	SaveManager.pending_suburb = {}
	Events.reset()
	Events.set_high_score(RankingManager.current_best())   # 이번 판 신기록 기준점(단일 모드)
	SceneFade.transition_to("res://scenes/Main.tscn")


func _on_continue_pressed() -> void:
	var data := SaveManager.load_save()
	if data.is_empty():
		return
	SaveManager.apply_to_events(data)
	Events.set_high_score(RankingManager.current_best())   # 새 게임과 동일한 신기록 기준점
	SceneFade.transition_to("res://scenes/Main.tscn")
