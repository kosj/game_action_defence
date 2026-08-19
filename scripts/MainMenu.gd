extends CanvasLayer
## 메인 메뉴: 새로하기 / 이어하기 / 언어 선택. 이어하기는 로컬 저장 데이터가 있을 때만 활성화.
## 표시 문구는 Locale 에서 가져오며, 언어 변경 시 즉시 다시 번역된다.

const _UIPopup := preload("res://scripts/UIPopup.gd")
const _UIStyle := preload("res://scripts/UIStyle.gd")
const _IntroStory := preload("res://scripts/IntroStory.gd")

## 난이도 인덱스 → Locale 키
const _DIFF_KEYS: Array = ["diff_easy", "diff_normal", "diff_hard"]

var _diff_title: Label
var _new_game_btn: Button
var _continue_btn: Button
var _lang_title: Label
var _sound_title: Label
var _sound_btn: Button
var _options_btn: Button
var _options_dim: ColorRect
var _options_panel: PanelContainer
var _options_title: Label
var _close_btn: Button
var _log_btn: Button = null
var _log_hint: Label = null
var _diff_buttons: Array = []
var _lang_buttons: Array = []   # [{ "btn": Button, "lang": String }]

# ── 랭킹 오버레이 ──
var _rank_btn: Button
var _rank_dim: ColorRect
var _rank_panel: PanelContainer
var _rank_title: Label
var _rank_note: Label
var _rank_rows: Array = []       # [{ "name": Label, "score": Label, "mode": String }]
var _rank_online_btn: Button
var _rank_close_btn: Button

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
	glow.position = Vector2(360.0 - 350.0, 330.0 - 260.0)
	add_child(glow)

	var p := CPUParticles2D.new()
	p.amount = 42
	p.lifetime = 7.0
	p.preprocess = 4.0
	p.lifetime_randomness = 0.6
	p.position = Vector2(360.0, 1300.0)
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
	# 타이틀 화면과 같은 분위기를 메뉴 배경으로 — 핏빛 그라데이션 + 붉은 글로우 + 잔불.
	add_child(UITheme.make_gradient_bg(Color(0.12, 0.03, 0.04), Color(0.02, 0.02, 0.03)))
	_build_backdrop()
	# (가장자리 비네트 제거 — 화면 외곽 어둡게 처리하지 않음)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	# 게임 타이틀(브랜드) — 전용 로고 이미지("ZOMBIE BUSTER"). 번역하지 않는다.
	var title := TextureRect.new()
	title.texture = preload("res://assets/ui/logo_title.png")
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.custom_minimum_size = Vector2(400, 222)   # 로고 비율 1.8:1
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	# 최고점(스코어) 표시 제거 — 요청.
	# 난이도 모드 제거 — 단일 통합 모드(선택 UI 없음).

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)

	# ── 1차 CTA — 로고의 핏빛을 그대로 받아 "여기를 눌러라"를 색으로도 말한다 ──
	_new_game_btn = Button.new()
	_new_game_btn.custom_minimum_size = Vector2(320, 78)
	_new_game_btn.add_theme_font_size_override("font_size", 27)
	# 1차 CTA — 색을 구워 넣은 핏빛 판(P2-2). 틴트 방식은 리벳·하이라이트까지 붉히지만
	# 이 판은 리벳이 강철, 하이라이트가 크림으로 남아 "빨간 금속"으로 읽힌다.
	_UIStyle.apply_button_style(_new_game_btn, UITheme.BTN_BG, UITheme.MENU_PRIMARY, 16, "blood")
	_new_game_btn.add_theme_color_override("font_color", UITheme.LOGO_CREAM)
	_new_game_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_new_game_btn.pressed.connect(_on_new_game_pressed)
	box.add_child(_new_game_btn)

	# ── 2차 — 밝은 건메탈. 크기·명도로만 1차와 구분한다 ──
	_continue_btn = Button.new()
	_continue_btn.custom_minimum_size = Vector2(320, 66)
	_continue_btn.add_theme_font_size_override("font_size", 24)
	_UIStyle.apply_button_style(_continue_btn, UITheme.BTN_BG, UITheme.MENU_SECONDARY)
	_continue_btn.disabled = not SaveManager.has_save()
	_continue_btn.pressed.connect(_on_continue_pressed)
	box.add_child(_continue_btn)

	# ── 3차 — 플레이트는 6개 모두 동일한 어두운 금속. 구분은 좌측 아이콘이 담당한다 ──
	var opt_spacer := Control.new()
	opt_spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(opt_spacer)

	_ach_btn = _make_menu_btn("trophy", UITheme.MENU_ICON_REWARD)
	_ach_btn.pressed.connect(_on_achievements_pressed)
	box.add_child(_ach_btn)

	_quest_btn = _make_menu_btn("flag", UITheme.MENU_ICON_QUEST)
	_quest_btn.pressed.connect(_on_quests_pressed)
	box.add_child(_quest_btn)

	_rewards_btn = _make_menu_btn("coin", UITheme.MENU_ICON_REWARD)
	_rewards_btn.pressed.connect(_on_rewards_pressed)
	box.add_child(_rewards_btn)
	_build_rewards_badge()
	RewardInbox.changed.connect(_refresh_rewards_badge)
	_refresh_rewards_badge()

	_rank_btn = _make_menu_btn("star", UITheme.MENU_ICON_REWARD)
	_rank_btn.pressed.connect(_on_ranking_pressed)
	box.add_child(_rank_btn)

	_power_btn = _make_menu_btn("bolt", UITheme.MENU_ICON_POWER)
	_power_btn.pressed.connect(_on_power_pressed)
	box.add_child(_power_btn)

	_options_btn = _make_menu_btn("gear", UITheme.MENU_ICON_PLAIN)
	_options_btn.pressed.connect(_on_options_pressed)
	box.add_child(_options_btn)

	# 버전 표시(하단) — 배포 빌드 식별용 SHA·시각 포함(어떤 빌드가 라이브인지 확인)
	var ver := Label.new()
	ver.text = Events.build_label()
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 14)
	ver.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65, 0.8))
	box.add_child(ver)

	_build_options_panel()
	_build_ranking_panel()
	_build_power_panel()
	_build_character_panel()
	_build_achievement_panel()
	_build_quest_panel()
	_build_rewards_panel()
	_build_theme_panel()
	call_deferred("_prewarm_panels")


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
func _build_options_panel() -> void:
	var p := _UIPopup.make(self, "menu_options", UITheme.SEC_NEUTRAL, UITheme.TEXT,
		_on_close_options, {"separation": 16, "center_body": true})
	_options_dim = p["dim"]
	_options_panel = p["panel"]
	_options_title = p["title"]
	_close_btn = p["close"]
	var vb: VBoxContainer = p["body"]

	# 언어 설정
	_lang_title = Label.new()
	_lang_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lang_title.add_theme_font_size_override("font_size", 18)
	_lang_title.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	vb.add_child(_lang_title)

	var lang_row := HBoxContainer.new()
	lang_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lang_row.add_theme_constant_override("separation", 8)
	vb.add_child(lang_row)
	_lang_buttons.clear()
	for lang in Locale.SUPPORTED:
		var lb := Button.new()
		lb.text = Locale.native_name(lang)
		lb.custom_minimum_size = Vector2(92, 46)
		lb.add_theme_font_size_override("font_size", 17)
		lb.pressed.connect(_on_language_pressed.bind(lang))
		lang_row.add_child(lb)
		_lang_buttons.append({"btn": lb, "lang": lang})

	# 사운드 On/Off
	_sound_title = Label.new()
	_sound_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sound_title.add_theme_font_size_override("font_size", 18)
	_sound_title.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	vb.add_child(_sound_title)

	var snd_row := HBoxContainer.new()
	snd_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(snd_row)
	_sound_btn = Button.new()
	_sound_btn.custom_minimum_size = Vector2(180, 50)
	_sound_btn.add_theme_font_size_override("font_size", 19)
	_sound_btn.pressed.connect(_on_sound_pressed)
	snd_row.add_child(_sound_btn)

	vb.add_child(HSeparator.new())

	# 플레이 기록 내보내기 — 출시 전 밸런스 검증용. 릴리스 빌드에서도 보인다(치트와 무관).
	# 웹은 user:// 가 IndexedDB 라 파일로 뺄 방법이 없어 클립보드가 유일한 경로다.
	# 기록은 이 기기에만 있고 전송되지 않는다 — 힌트 문구로 그 사실을 명시한다.
	_log_btn = Button.new()
	_log_btn.custom_minimum_size = Vector2(0, 50)
	_log_btn.add_theme_font_size_override("font_size", 18)
	_UIStyle.apply_button_style(_log_btn, Color(0.16, 0.18, 0.26), Color(0.5, 0.6, 0.8))
	_log_btn.pressed.connect(_on_copy_log_pressed)
	vb.add_child(_log_btn)

	_log_hint = Label.new()
	_log_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_hint.add_theme_font_size_override("font_size", 13)
	_log_hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	vb.add_child(_log_hint)


func _on_options_pressed() -> void:
	_refresh_log_button()   # 판 수가 늘었을 수 있으니 열 때마다 갱신
	_options_dim.visible = true
	_options_panel.visible = true


func _refresh_log_button() -> void:
	if is_instance_valid(_log_btn):
		_log_btn.text = Locale.t("opt_copy_log") % Telemetry.record_count()
		_log_btn.disabled = Telemetry.record_count() == 0


func _on_copy_log_pressed() -> void:
	DisplayServer.clipboard_set(Telemetry.export_text())
	_log_btn.text = Locale.t("opt_copy_log_done")


func _on_close_options() -> void:
	_options_dim.visible = false
	_options_panel.visible = false


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
		_power_rows.append({"btn": btn, "u": u})


func _on_power_pressed() -> void:
	_refresh_power()
	_power_dim.visible = true
	_power_panel.visible = true


func _on_power_close() -> void:
	_power_dim.visible = false
	_power_panel.visible = false




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
		_char_rows.append({"btn": btn, "c": c, "thumb": thumb, "lock": lock})



## 오버레이 카드 갱신 — 선택/잠금/구매 상태를 반영.
func _refresh_character() -> void:
	if _char_gold_label:
		_char_gold_label.text = Locale.t("gold_fmt") % MetaManager.meta_gold
	var sel := CharacterManager.selected_id()
	for row in _char_rows:
		var c: CharacterData = row["c"]
		var btn: Button = row["btn"]
		var thumb: TextureRect = row.get("thumb")
		if CharacterManager.is_unlocked(c):
			btn.text = "%s%s\n%s\n%s" % ["> " if c.id == sel else "", c.display, c.desc, _char_stat_line(c)]
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
		CharacterManager.select(id)
		SoundManager.play_ui("gold", 0.03, 1.2)
		picked = true
	elif c.unlock_cost > 0 and CharacterManager.try_buy(id):
		CharacterManager.select(id)   # 구매 성공 → 즉시 선택
		SoundManager.play_ui("gold", 0.02, 1.0)
		picked = true
	else:
		SoundManager.play_ui("player_hurt", 0.2, 1.0)   # 해금 불가(골드 부족/도전과제 미달)
	_refresh_character()
	if picked and _newgame_flow:
		# 다음 단계: 아레나(테마) 선택
		_char_dim.visible = false
		_char_panel.visible = false
		_on_theme_pressed()


func _on_character_pressed() -> void:
	_refresh_character()
	_char_dim.visible = true
	_char_panel.visible = true


func _on_character_close() -> void:
	_newgame_flow = false   # 선택 중 닫으면 새 게임 흐름 취소
	_char_dim.visible = false
	_char_panel.visible = false




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
	_ach_dim.visible = true
	_ach_panel.visible = true


func _on_achievements_close() -> void:
	_ach_dim.visible = false
	_ach_panel.visible = false


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
	b.custom_minimum_size = Vector2(284, 52)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 19)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT   # 아이콘 오른쪽에서 좌측 정렬
	# 3차 보조 6개 — 어두운 판으로 한 덩어리로 가라앉힌다. 구분은 좌측 아이콘이 담당한다.
	_UIStyle.apply_button_style(b, UITheme.BTN_BG, UITheme.MENU_TERTIARY, 16, "dark")
	_UIStyle.set_button_content_margin_left(b, 56)   # 아이콘 자리 확보
	var ic := UIIcon.make(icon_kind, 24, icon_col)
	ic.anchor_top = 0.5
	ic.anchor_bottom = 0.5
	ic.offset_left = 22.0
	ic.offset_right = 46.0
	ic.offset_top = -12.0
	ic.offset_bottom = 12.0
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


func _on_claim_pressed(index: int) -> void:
	var got: int = RewardInbox.claim(index)
	if got > 0:
		SoundManager.play_ui("gold", 0.03, 1.25)
	_refresh_rewards()
	_refresh_meta_gold_labels()


func _on_claim_all_pressed() -> void:
	var got: int = RewardInbox.claim_all()
	if got > 0:
		SoundManager.play_ui("gold", 0.03, 1.1)
		SoundManager.play_ui("gold", 0.03, 1.4)
	_refresh_rewards()
	_refresh_meta_gold_labels()


## 파워업/캐릭터/테마 패널의 메타 골드 라벨을 갱신(열려 있지 않아도 안전).
func _refresh_meta_gold_labels() -> void:
	for lbl in [_power_gold_label, _char_gold_label, _theme_gold_label]:
		if lbl != null and lbl.text != "":
			lbl.text = Locale.t("gold_fmt") % MetaManager.meta_gold


func _on_rewards_pressed() -> void:
	_refresh_rewards()
	_rewards_dim.visible = true
	_rewards_panel.visible = true


func _on_rewards_close() -> void:
	_rewards_dim.visible = false
	_rewards_panel.visible = false


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
	_quest_dim.visible = true
	_quest_panel.visible = true


func _on_quests_close() -> void:
	_quest_dim.visible = false
	_quest_panel.visible = false




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
			"name": name_lbl, "desc": desc_lbl, "lock": lock})



func _refresh_theme() -> void:
	if _theme_gold_label:
		_theme_gold_label.text = Locale.t("gold_fmt") % MetaManager.meta_gold
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
		if ThemeManager.is_unlocked(t):
			var picked: bool = t.id == sel
			name_lbl.text = ("> %s" % t.display) if picked else String(t.display)
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


func _on_theme_pressed() -> void:
	_refresh_theme()
	_theme_dim.visible = true
	_theme_panel.visible = true


func _on_theme_close() -> void:
	_newgame_flow = false   # 선택 중 닫으면 새 게임 흐름 취소
	_theme_dim.visible = false
	_theme_panel.visible = false




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
		ThemeManager.select(id)
		SoundManager.play_ui("gold", 0.03, 1.2)
		picked = true
	elif t.unlock_cost > 0 and ThemeManager.try_buy(id):
		ThemeManager.select(id)
		SoundManager.play_ui("gold", 0.02, 1.0)
		picked = true
	else:
		SoundManager.play_ui("player_hurt", 0.2, 1.0)
	_refresh_theme()
	if picked and _newgame_flow:
		_newgame_flow = false
		_theme_dim.visible = false
		_theme_panel.visible = false
		# 마지막 단계: 서사 인트로를 보여준 뒤(완료/건너뛰기 시) 실제 시작
		_IntroStory.play(self, _start_new_game)


func _refresh_power() -> void:
	_power_gold_label.text = Locale.t("gold_fmt") % MetaManager.meta_gold
	for row in _power_rows:
		var u: Dictionary = row["u"]
		var id: String = String(u["id"])
		var lv := MetaManager.level(id)
		var mx := int(u["max"])
		var btn: Button = row["btn"]
		if lv >= mx:
			btn.text = "%s  (MAX)\n%s" % [u["name"], u["desc"]]
			btn.disabled = true
		else:
			var c := MetaManager.cost(id)
			btn.text = "%s  (%d/%d)\n%s   -%d G" % [u["name"], lv, mx, u["desc"], c]
			btn.disabled = MetaManager.meta_gold < c


## 랭킹 오버레이 — 모드(난이도)별 최고 점수. 온라인 백엔드(안드로이드 PGS)면 네이티브 리더보드
## 버튼도 노출한다. 로컬 빌드(웹/PC)에서는 이 기기의 모드별 최고점만 보여준다.
func _build_ranking_panel() -> void:
	var p := _UIPopup.make(self, "rank_title", UITheme.SEC_NEUTRAL, UITheme.SEC_REWARD,
		_on_close_ranking, {"separation": 14, "center_body": true})
	_rank_dim = p["dim"]
	_rank_panel = p["panel"]
	_rank_title = p["title"]
	_rank_close_btn = p["close"]
	var vb: VBoxContainer = p["body"]

	_rank_note = Label.new()
	_rank_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_note.add_theme_font_size_override("font_size", 15)
	_rank_note.add_theme_color_override("font_color", Color(0.70, 0.74, 0.82))
	vb.add_child(_rank_note)

	vb.add_child(HSeparator.new())

	# 모드(난이도)별 최고점 행 — 난이도 강조색으로 모드명을 칠한다.
	var accents := [Color(0.40, 0.85, 0.45), Color(0.40, 0.60, 0.95), Color(0.95, 0.40, 0.35)]
	_rank_rows.clear()
	for i in RankingManager.MODES.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		vb.add_child(row)

		var name_lbl := Label.new()
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", accents[i])
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var score_lbl := Label.new()
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_lbl.add_theme_font_size_override("font_size", 22)
		score_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.99))
		score_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(score_lbl)

		_rank_rows.append({"name": name_lbl, "score": score_lbl, "mode": RankingManager.MODES[i], "key": _DIFF_KEYS[i]})

	vb.add_child(HSeparator.new())

	# 온라인 리더보드 버튼(안드로이드 PGS 로그인 시에만 노출).
	_rank_online_btn = Button.new()
	_rank_online_btn.custom_minimum_size = Vector2(0, 52)
	_rank_online_btn.add_theme_font_size_override("font_size", 18)
	_UIStyle.apply_button_style(_rank_online_btn, Color(0.14, 0.28, 0.42), Color(0.4, 0.7, 0.95))
	_rank_online_btn.pressed.connect(_on_view_online_pressed)
	_rank_online_btn.visible = false
	vb.add_child(_rank_online_btn)


func _on_ranking_pressed() -> void:
	_refresh_ranking_rows()
	_rank_dim.visible = true
	_rank_panel.visible = true


func _on_close_ranking() -> void:
	_rank_dim.visible = false
	_rank_panel.visible = false




func _on_view_online_pressed() -> void:
	RankingManager.show_leaderboard()   # 현재 난이도 모드의 네이티브 리더보드


## 각 모드의 최고점을 다시 읽어 행에 반영하고, 온라인 버튼 노출 여부를 갱신.
func _refresh_ranking_rows() -> void:
	var bests := RankingManager.all_bests()
	for r in _rank_rows:
		r["name"].text = Locale.t(r["key"])
		r["score"].text = "%d" % int(bests.get(r["mode"], 0))
	_rank_online_btn.visible = RankingManager.is_online() and RankingManager.is_signed_in()




## 현재 언어로 모든 라벨/버튼 텍스트를 갱신하고 선택 강조를 다시 칠한다.
func _apply_language() -> void:
	_new_game_btn.text = Locale.t("menu_new_game")
	_continue_btn.text = Locale.t("menu_continue")
	_ach_btn.text = Locale.t("menu_achievements")
	_quest_btn.text = Locale.t("menu_quests")
	_power_btn.text = Locale.t("menu_powerup")
	_refresh_rewards_badge()   # 보상 버튼 라벨도 로케일에서 가져온다
	_lang_title.text = Locale.t("menu_language")
	_sound_title.text = Locale.t("menu_sound")
	_options_btn.text = Locale.t("menu_options")
	_options_title.text = Locale.t("menu_options")
	_log_hint.text = Locale.t("opt_log_hint")
	_refresh_log_button()
	_close_btn.text = Locale.t("menu_close")
	_rank_btn.text = Locale.t("menu_ranking")
	_rank_title.text = Locale.t("rank_title")
	_rank_note.text = Locale.t("rank_local_note")
	_rank_online_btn.text = Locale.t("rank_online")
	_rank_close_btn.text = Locale.t("menu_close")
	_refresh_ranking_rows()
	_refresh_language_buttons()
	_refresh_sound_button()


## 사운드 On/Off 토글 — 즉시 적용·저장하고 버튼 표시를 갱신.
func _on_sound_pressed() -> void:
	SoundManager.set_enabled(not SoundManager.is_enabled())
	_refresh_sound_button()


func _refresh_sound_button() -> void:
	var on := SoundManager.is_enabled()
	_sound_btn.text = "%s: %s" % [Locale.t("menu_sound"), Locale.t("sound_on") if on else Locale.t("sound_off")]
	if on:
		_UIStyle.apply_button_style(_sound_btn, Color(0.14, 0.34, 0.20), Color(0.4, 0.85, 0.45))
	else:
		_UIStyle.apply_button_style(_sound_btn, Color(0.30, 0.14, 0.14), Color(0.85, 0.4, 0.4))


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
	_on_character_pressed()   # 1단계: 생존자 선택


func _start_new_game() -> void:
	SaveManager.delete_save()
	SaveManager.pending_continue = false
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
