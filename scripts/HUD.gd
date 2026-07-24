extends CanvasLayer
## HUD: 골드·체력·웨이브·경과시간을 Events 시그널로 받아 실시간 갱신. 게임오버 패널 제어.

const HEART_FULL := preload("res://assets/ui/ui_heart_full.png")
const HEART_EMPTY := preload("res://assets/ui/ui_heart_empty.png")
const FOG_TEX := preload("res://assets/ui/fog_vision.png")   # 주변 시야 제한 오버레이(방사형 암전)
const _UIStyle := preload("res://scripts/UIStyle.gd")

@onready var top_bg: Panel = $TopBg
@onready var gold_label: Label = $GoldLabel
@onready var heart_row: HBoxContainer = $HeartRow
@onready var weapon_label: Label = $WeaponLabel
@onready var buff_label: Label = $BuffLabel
@onready var wave_label: Label = $WaveLabel
@onready var time_label: Label = $TimeLabel
@onready var progress_label: Label = $ProgressLabel
@onready var score_label: Label = $ScoreLabel
@onready var high_score_label: Label = $HighScoreLabel
@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var low_hp_overlay: ColorRect = $LowHpOverlay
@onready var boss_bar: Control = $BossBar
@onready var boss_fill: ColorRect = $BossBar/BarFill
@onready var boss_name_label: Label = $BossBar/BossName
@onready var wave_clear_bg: Panel = $WaveClearBg
@onready var wave_clear_label: Label = $WaveClearLabel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/Margin/VBoxContainer/GameOverLabel
@onready var stats_label: Label = $GameOverPanel/Margin/VBoxContainer/StatsLabel
@onready var restart_button: Button = $GameOverPanel/Margin/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $GameOverPanel/Margin/VBoxContainer/MainMenuButton

const BOSS_BAR_W := 400.0

var _prev_health: int = -1
var _prev_gold: int = -1
var _prev_score: int = -1
var _max_health: int = 0
var _low_hp_tween: Tween = null
var _boss_max: int = 1
var _weapon_tween: Tween = null
var _weapon_base_text: String = ""
var _magnet_tween: Tween = null

# 보상형 광고 부활: 한 판에 1회만 허용. 코드로 생성해 게임오버 패널 최상단에 끼운다.
var _revive_btn: Button = null
var _revive_used: bool = false

# 게임오버 패널 뒤 화면 블러(시인성). 패널이 뜰 때만 활성화한다.
var _blur_bbc: BackBufferCopy = null
var _blur_rect: ColorRect = null

# 게임오버 통계 위젯(아이콘 그리드) — 코드로 생성해 텍스트 라벨을 대체.
var _go_medal: UIIcon = null
var _go_record: Label = null
var _go_vals: Dictionary = {}   # "score"/"best"/"wave"/"kills"/"time" -> Label

# 웨이브 진행 바(상단 바 하단의 얇은 채움 바) — 코드로 생성.
var _wave_fill: ColorRect = null

# 스웜 경고 배너 — 코드로 생성. 무리/엘리트 팩 등장 직전 화면 중앙 상단에 붉게 번쩍.
var _swarm_banner: Label = null
var _swarm_tween: Tween = null

# 인게임 레벨 표시 — 코드로 생성. 웨이브 바 아래 얇은 경험치 바 + 좌측 레벨 라벨.
var _xp_fill: ColorRect = null
var _level_label: Label = null

# 장착 로드아웃(무기/패시브) 표시 + 목표 힌트 — 코드로 생성.
var _loadout_box: VBoxContainer = null
var _goal_label: Label = null


func _ready() -> void:
	# 게임오버로 트리를 일시정지해도 HUD(게임오버 패널·버튼·블러)는 계속 동작해야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_bg.add_theme_stylebox_override("panel", _UIStyle.bottom_bar(Color(0.05, 0.06, 0.09, 0.62)))
	wave_clear_bg.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.08, 0.30, 0.14, 0.92), Color(1.0, 0.85, 0.2), 26, 3))
	game_over_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.08, 0.05, 0.06, 0.96), Color(0.85, 0.25, 0.22), 22, 3))
	_UIStyle.apply_button_style(restart_button, Color(0.55, 0.16, 0.16), Color(0.95, 0.35, 0.3))
	_UIStyle.apply_button_style(main_menu_button, Color(0.18, 0.20, 0.26), Color(0.5, 0.55, 0.65))
	restart_button.text = Locale.t("go_retry")
	main_menu_button.text = Locale.t("go_menu")
	_build_fog()
	_build_revive_button()
	_build_hud_icons()
	_build_wave_bar()
	_build_xp_bar()
	_build_swarm_banner()
	_build_loadout()
	_build_goal_hint()
	_build_gameover_stats()
	_build_blur_overlay()
	UITheme.heading(wave_clear_label)
	UITheme.heading($GameOverPanel/Margin/VBoxContainer/GameOverLabel)
	call_deferred("_init_pivots")

	Events.gold_changed.connect(_on_gold_changed)
	Events.player_health_changed.connect(_on_player_health_changed)
	Events.player_died.connect(_on_player_died)
	Events.wave_changed.connect(_on_wave_changed)
	Events.elapsed_changed.connect(_on_elapsed_changed)
	Events.wave_progress_changed.connect(_on_wave_progress_changed)
	Events.wave_complete.connect(_on_wave_complete)
	Events.weapon_equipped.connect(_on_weapon_equipped)
	Events.weapon_timer_changed.connect(_on_weapon_timer_changed)
	Events.gold_magnet_changed.connect(_on_gold_magnet_changed)
	Events.score_changed.connect(_on_score_changed)
	Events.high_score_changed.connect(_on_high_score_changed)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_health_changed.connect(_on_boss_health_changed)
	Events.boss_died.connect(_on_boss_died)
	Events.swarm_incoming.connect(_on_swarm_incoming)
	Events.xp_changed.connect(_on_xp_changed)
	Events.inventory_changed.connect(_on_inventory_changed)
	Events.game_won.connect(_on_game_won)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	AdManager.rewarded_granted.connect(_on_rewarded_granted)
	_on_gold_changed(Events.total_gold)
	if Events.player_max_health > 0:
		_on_player_health_changed(Events.player_health, Events.player_max_health)
	_on_wave_changed(Events.current_wave)
	_on_elapsed_changed(Events.elapsed_time)
	_on_wave_progress_changed(Events.wave_kill_progress, Events.wave_kill_total)
	_on_score_changed(Events.score)
	_on_high_score_changed(Events.high_score)
	_on_xp_changed(Events.xp, Events.xp_to_next, Events.level)
	_on_inventory_changed()


## 둥근 패널/라벨이 자신의 중심을 기준으로 스케일되도록 pivot 보정 (레이아웃 확정 후 1회).
func _init_pivots() -> void:
	gold_label.pivot_offset = gold_label.size * 0.5
	score_label.pivot_offset = score_label.size * 0.5
	weapon_label.pivot_offset = weapon_label.size * 0.5
	wave_clear_bg.pivot_offset = wave_clear_bg.size * 0.5
	wave_clear_label.pivot_offset = wave_clear_label.size * 0.5
	game_over_panel.pivot_offset = game_over_panel.size * 0.5


func _on_gold_changed(total: int) -> void:
	gold_label.text = "%d" % total
	if _prev_gold >= 0 and total > _prev_gold:
		_pulse_gold()
	_prev_gold = total


func _pulse_gold() -> void:
	gold_label.scale = Vector2(1.35, 1.35)
	var tw := create_tween()
	tw.tween_property(gold_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_score_changed(total: int) -> void:
	score_label.text = Locale.t("hud_score_fmt") % total
	if _prev_score >= 0 and total > _prev_score:
		_pulse_score()
	_prev_score = total


func _pulse_score() -> void:
	score_label.scale = Vector2(1.25, 1.25)
	var tw := create_tween()
	tw.tween_property(score_label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_high_score_changed(high: int) -> void:
	high_score_label.text = Locale.t("hud_best_fmt") % high


func _on_boss_spawned(max_health: int) -> void:
	_boss_max = maxi(max_health, 1)
	boss_name_label.text = Events.boss_display_name   # 보스 타입 이름 표시(BRUTE/GUNNER…)
	boss_fill.size.x = BOSS_BAR_W
	boss_bar.visible = true
	boss_bar.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(boss_bar, "modulate:a", 1.0, 0.3)


func _on_boss_health_changed(health: int, max_health: int) -> void:
	_boss_max = maxi(max_health, 1)
	var ratio := clampf(float(health) / float(_boss_max), 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(boss_fill, "size:x", BOSS_BAR_W * ratio, 0.12)


func _on_boss_died() -> void:
	var tw := create_tween()
	tw.tween_property(boss_bar, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): boss_bar.visible = false)


## 스웜 경고 배너 — 화면 상단 중앙에 코드로 생성(씬 수정 없이).
func _build_swarm_banner() -> void:
	_swarm_banner = Label.new()
	_swarm_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_swarm_banner.offset_top = 300.0   # 무기/버프 라벨(y188~252)·보스 바와 겹치지 않게 아래로
	_swarm_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_swarm_banner.add_theme_font_size_override("font_size", 30)
	_swarm_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_swarm_banner.add_theme_color_override("font_outline_color", Color(0.4, 0.05, 0.05))
	_swarm_banner.add_theme_constant_override("outline_size", 6)
	_swarm_banner.modulate.a = 0.0
	_swarm_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_swarm_banner)


## 무리/엘리트 팩 경고를 배너로 번쩍인다(등장 직전 대비 시간).
func _on_swarm_incoming(elite: bool) -> void:
	if _swarm_banner == null:
		return
	_swarm_banner.text = "⚠ ELITE PACK" if elite else "⚠ SWARM"
	_swarm_banner.add_theme_color_override("font_color", Color(1.0, 0.55, 0.25) if elite else Color(1.0, 0.85, 0.25))
	if _swarm_tween and _swarm_tween.is_valid():
		_swarm_tween.kill()
	_swarm_banner.modulate.a = 0.0
	_swarm_banner.scale = Vector2(0.7, 0.7)
	_swarm_banner.pivot_offset = _swarm_banner.size * 0.5
	_swarm_tween = create_tween()
	_swarm_tween.tween_property(_swarm_banner, "modulate:a", 1.0, 0.18)
	_swarm_tween.parallel().tween_property(_swarm_banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_swarm_tween.tween_interval(0.7)
	_swarm_tween.tween_property(_swarm_banner, "modulate:a", 0.0, 0.4)


func _on_player_health_changed(health: int, max_health: int) -> void:
	if max_health != _max_health:
		_max_health = max_health
		_rebuild_hearts(max_health)
	_update_hearts(health)
	if _prev_health > 0 and health < _prev_health and health > 0:
		_flash_hurt()
	_update_low_hp_warning(health)
	_prev_health = health


func _rebuild_hearts(max_health: int) -> void:
	# remove_child 로 자식 목록에서 "즉시" 뺀다. queue_free 만 하면 삭제가 프레임 끝까지
	# 지연돼, 직후의 _update_hearts() 가 옛 하트까지 세어 새 하트를 빈 칸으로 칠해버린다
	# (최대 체력 업그레이드 후 "체력은 찼는데 UI는 안 채워짐" 버그의 원인).
	for child in heart_row.get_children():
		heart_row.remove_child(child)
		child.queue_free()
	for i in range(max_health):
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(30, 30)
		tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = HEART_FULL
		heart_row.add_child(tr)


func _update_hearts(health: int) -> void:
	var children := heart_row.get_children()
	for i in range(children.size()):
		children[i].texture = HEART_FULL if i < health else HEART_EMPTY


func _flash_hurt() -> void:
	flash_overlay.color = Color(1, 0, 0, 0.35)
	var tw := create_tween()
	tw.tween_property(flash_overlay, "color", Color(1, 0, 0, 0.0), 0.4)


## 체력이 1일 때 화면 가장자리를 붉게 경고. 껌뻑이는 점멸(1초 주기·0→0.30)은 눈이 피로해서,
## 은은한 저강도 글로우가 사인 곡선으로 천천히 "숨쉬는" 연출로 바꿨다(밝기·빈도 모두 완화).
const _LOW_HP_MIN_A := 0.06   # 완전히 꺼지지 않고 낮게 유지 → 깜박임이 아닌 은은한 상시 경고
const _LOW_HP_MAX_A := 0.22   # 피크도 낮춰 눈부심 완화(이전 0.30)
const _LOW_HP_HALF := 1.3     # 한 방향(밝아짐/어두워짐) 시간 — 느려서 껌뻑임 빈도가 낮다

func _update_low_hp_warning(health: int) -> void:
	var should_pulse := health == 1
	if should_pulse and _low_hp_tween == null:
		low_hp_overlay.color.a = _LOW_HP_MIN_A
		_low_hp_tween = create_tween()
		_low_hp_tween.set_loops()
		_low_hp_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_low_hp_tween.tween_property(low_hp_overlay, "color:a", _LOW_HP_MAX_A, _LOW_HP_HALF)
		_low_hp_tween.tween_property(low_hp_overlay, "color:a", _LOW_HP_MIN_A, _LOW_HP_HALF)
	elif not should_pulse and _low_hp_tween != null:
		_low_hp_tween.kill()
		_low_hp_tween = null
		low_hp_overlay.color.a = 0.0


## 무기 픽업 획득 시 이름/등급을 잠시 표시 후 자동 페이드 아웃.
func _on_weapon_equipped(stats: Dictionary) -> void:
	var tier_id: String = stats.get("tier_id", "common")
	if tier_id == "common":
		_weapon_base_text = stats.get("name", "")
	else:
		_weapon_base_text = "%s %s" % [stats.get("tier_name", ""), stats.get("name", "")]
	weapon_label.add_theme_color_override("font_color", stats.get("tier_color", Color.WHITE))
	weapon_label.modulate.a = 1.0
	weapon_label.scale = Vector2(1.4, 1.4)
	weapon_label.visible = true
	if _weapon_tween and _weapon_tween.is_valid():
		_weapon_tween.kill()
	_weapon_tween = create_tween()
	_weapon_tween.tween_property(weapon_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var dur: float = float(stats.get("duration", 0.0))
	if dur > 0.0:
		# 임시 무기: 남은 사용 시간을 계속 표시(자동 페이드 없음). 카운트다운은 weapon_timer_changed 로 갱신.
		weapon_label.text = "%s  %ds" % [_weapon_base_text, int(ceil(dur))]
	else:
		# 기본/영구 무기: 잠깐 보여주고 사라진다.
		weapon_label.text = _weapon_base_text
		_weapon_tween.tween_interval(1.5)
		_weapon_tween.tween_property(weapon_label, "modulate:a", 0.0, 0.4)
		_weapon_tween.tween_callback(func(): weapon_label.visible = false)


## 임시 무기 남은 시간 갱신(초 단위). 만료(<=0)는 기본 무기 장착 신호가 처리하므로 무시.
func _on_weapon_timer_changed(time_left: float, _total: float) -> void:
	if time_left > 0.0:
		weapon_label.text = "%s  %ds" % [_weapon_base_text, int(ceil(time_left))]
		weapon_label.visible = true
		weapon_label.modulate.a = 1.0


## 골드 자석 버프 표시 — 활성 중 남은 시간 표시, 종료 시 페이드 아웃.
func _on_gold_magnet_changed(active: bool, time_left: float) -> void:
	if _magnet_tween and _magnet_tween.is_valid():
		_magnet_tween.kill()
	if active:
		buff_label.text = Locale.t("hud_magnet_fmt") % int(ceil(time_left))
		buff_label.modulate.a = 1.0
		buff_label.visible = true
	else:
		_magnet_tween = create_tween()
		_magnet_tween.tween_property(buff_label, "modulate:a", 0.0, 0.4)
		_magnet_tween.tween_callback(func(): buff_label.visible = false)


func _on_wave_changed(wave: int) -> void:
	wave_label.text = Locale.t("hud_wave_fmt") % wave


func _on_elapsed_changed(seconds: float) -> void:
	var m := int(seconds) / 60
	var s := int(seconds) % 60
	time_label.text = "%02d:%02d" % [m, s]


func _on_wave_progress_changed(killed: int, total: int) -> void:
	if total > 0:
		progress_label.text = "%d / %d" % [killed, total]
	else:
		progress_label.text = ""
	# 진행 바 — 채워질수록 금색→초록으로 물들어 "곧 클리어"가 한눈에 읽힌다.
	if _wave_fill:
		var ratio := clampf(float(killed) / float(maxi(total, 1)), 0.0, 1.0)
		_wave_fill.anchor_right = ratio
		_wave_fill.color = Color(1.0, 0.72, 0.20, 0.95).lerp(Color(0.45, 0.90, 0.45, 0.95), ratio)


## 상단 바 하단에 얇은 웨이브 진행 바(킬 목표 대비 진행률)를 코드로 생성.
## 숫자 라벨(progress_label)은 유지하고, 시각적 진행감은 바가 담당한다.
func _build_wave_bar() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.45)
	bg.anchor_right = 1.0
	bg.offset_top = 132.0
	bg.offset_bottom = 137.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_wave_fill = ColorRect.new()
	_wave_fill.color = Color(1.0, 0.72, 0.20, 0.95)
	_wave_fill.anchor_right = 0.0
	_wave_fill.anchor_bottom = 1.0
	_wave_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(_wave_fill)


## 주변 시야 제한 오버레이 — 화면 중앙(카메라가 플레이어를 중앙 고정)만 선명하고 바깥은 암전.
## HUD(월드 위 CanvasLayer)의 "가장 아래" 자식으로 깔아, 월드는 가리되 HUD 위젯은 그 위에 보이게 한다.
func _build_fog() -> void:
	var fog := TextureRect.new()
	fog.texture = FOG_TEX
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fog.stretch_mode = TextureRect.STRETCH_SCALE
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fog)
	move_child(fog, 0)   # 최하단으로 — 월드 위, 모든 HUD 위젯 아래


## 경험치 바 — 화면 "최상단 엣지"(전 너비)로 배치해 보스 체력바(y138~)와 겹치지 않게 한다.
## 레벨 라벨은 상단 바의 빈 중앙(골드=좌, 웨이브=우 사이)에 둔다.
func _build_xp_bar() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.5)
	bg.anchor_right = 1.0
	bg.offset_top = 0.0
	bg.offset_bottom = 5.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_xp_fill = ColorRect.new()
	_xp_fill.color = Color(0.45, 0.80, 1.0, 0.95)
	_xp_fill.anchor_right = 0.0
	_xp_fill.anchor_bottom = 1.0
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(_xp_fill)

	_level_label = Label.new()
	_level_label.anchor_left = 0.5
	_level_label.anchor_right = 0.5
	_level_label.offset_left = -70.0
	_level_label.offset_right = 70.0
	_level_label.offset_top = 8.0
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 20)
	_level_label.add_theme_color_override("font_color", Color(0.62, 0.86, 1.0))
	_level_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.09))
	_level_label.add_theme_constant_override("outline_size", 4)
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_level_label)


func _on_xp_changed(xp: int, xp_to_next: int, level: int) -> void:
	if _xp_fill:
		_xp_fill.anchor_right = clampf(float(xp) / float(maxi(xp_to_next, 1)), 0.0, 1.0)
	if _level_label:
		_level_label.text = "Lv.%d" % level


## 장착 로드아웃 — 화면 좌측에 무기/패시브를 아이템 색의 라벨로 세로 나열.
func _build_loadout() -> void:
	_loadout_box = VBoxContainer.new()
	_loadout_box.add_theme_constant_override("separation", 2)
	_loadout_box.offset_left = 8.0
	_loadout_box.offset_top = 158.0
	_loadout_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_loadout_box)


func _on_inventory_changed() -> void:
	if _loadout_box == null:
		return
	for c in _loadout_box.get_children():
		_loadout_box.remove_child(c)
		c.queue_free()
	_add_loadout_lines(Events.weapons)
	_add_loadout_lines(Events.passives)


func _add_loadout_lines(inv: Dictionary) -> void:
	for id in inv.keys():
		var lv: int = int(inv[id])
		if lv <= 0:
			continue
		var m := ItemDB.meta(String(id))
		if m.is_empty():
			continue
		var lbl := Label.new()
		lbl.text = "%s  %d" % [m["name"], lv]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", m["color"])
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_loadout_box.add_child(lbl)


## 목표 힌트 — 화면 하단에 "최종 웨이브까지 생존" 안내(목표 명확화).
func _build_goal_hint() -> void:
	_goal_label = Label.new()
	_goal_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_goal_label.offset_top = -44.0
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.text = "SURVIVE TO WAVE 20 → REAPER"
	_goal_label.add_theme_font_size_override("font_size", 15)
	_goal_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.75, 0.7))
	_goal_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_goal_label.add_theme_constant_override("outline_size", 3)
	_goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_goal_label)


func _on_wave_complete(wave: int) -> void:
	wave_clear_label.text = Locale.t("wave_clear_fmt") % wave
	wave_clear_label.visible = true
	wave_clear_bg.visible = true
	wave_clear_label.modulate.a = 1.0
	wave_clear_bg.modulate.a = 1.0
	wave_clear_label.scale = Vector2(0.7, 0.7)
	wave_clear_bg.scale = Vector2(0.7, 0.7)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(wave_clear_label, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(wave_clear_bg, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(1.3)
	tw.set_parallel(true)
	tw.tween_property(wave_clear_label, "modulate:a", 0.0, 0.5)
	tw.tween_property(wave_clear_bg, "modulate:a", 0.0, 0.5)
	tw.set_parallel(false)
	tw.tween_callback(func():
		wave_clear_label.visible = false
		wave_clear_bg.visible = false)


## 게임오버 패널 최상단에 "광고 보고 부활" 버튼을 코드로 생성(보상형 광고 유도).
func _build_revive_button() -> void:
	_revive_btn = Button.new()
	_revive_btn.text = Locale.t("hud_revive")
	_revive_btn.custom_minimum_size = Vector2(0, 56)
	_revive_btn.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(_revive_btn, Color(0.14, 0.40, 0.20), Color(0.4, 0.9, 0.45))
	_revive_btn.pressed.connect(_on_revive_pressed)
	var box := restart_button.get_parent()
	box.add_child(_revive_btn)
	box.move_child(_revive_btn, restart_button.get_index())   # 다시하기 버튼 바로 위로


## 게임오버 패널 뒤 화면을 흐리게 — BackBufferCopy 로 화면을 떠 두고 블러 셰이더 ColorRect 로 덮는다.
## 그리기 순서를 패널 바로 앞(아래)으로 옮겨, 화면 전체를 블러한 위에 패널만 선명히 표시한다.
func _build_blur_overlay() -> void:
	_blur_bbc = BackBufferCopy.new()
	_blur_bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_blur_bbc.visible = false
	add_child(_blur_bbc)

	_blur_rect = ColorRect.new()
	_blur_rect.anchor_right = 1.0
	_blur_rect.anchor_bottom = 1.0
	_blur_rect.mouse_filter = Control.MOUSE_FILTER_STOP   # 패널 밖 영역의 터치가 뒤 게임으로 새지 않게 차단
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/gameover_blur.gdshader")
	_blur_rect.material = mat
	_blur_rect.visible = false
	add_child(_blur_rect)

	var idx := game_over_panel.get_index()
	move_child(_blur_bbc, idx)
	move_child(_blur_rect, game_over_panel.get_index())


func _set_blur(active: bool) -> void:
	if _blur_bbc:
		_blur_bbc.visible = active
	if _blur_rect:
		_blur_rect.visible = active


func _on_revive_pressed() -> void:
	if _revive_used or not AdManager.is_rewarded_ready():
		return
	AdManager.show_rewarded("revive")


## 보상형 시청 완료 콜백. 부활 placement 만 처리(상점 보상은 ShopPanel 이 처리).
func _on_rewarded_granted(placement: String) -> void:
	if placement != "revive" or _revive_used:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("revive"):
		return
	_revive_used = true
	# 부활 시 사라진 게임오버 패널을 닫고 정지를 해제해 그대로 진행 재개.
	game_over_panel.visible = false
	_set_blur(false)
	get_tree().paused = false
	player.revive()


# 상단 바 작은 아이콘들(점수 별 / 웨이브·시간·최고 아이콘) — 텍스트 위주 HUD 보강.
func _build_hud_icons() -> void:
	var star := UIIcon.make("star", 20, Color(1.0, 0.85, 0.2))
	star.position = Vector2(score_label.offset_left, score_label.offset_top + 5)
	add_child(star)
	score_label.offset_left += 24   # 별 자리 확보를 위해 점수 텍스트를 오른쪽으로
	_right_stat_icon("flag",   wave_label,       Color(0.70, 0.85, 1.0))
	_right_stat_icon("clock",  time_label,       Color(0.82, 0.86, 0.95))
	_right_stat_icon("trophy", high_score_label, Color(1.0, 0.82, 0.3))


## 우측 정렬 라벨의 오른쪽 끝에 작은 아이콘을 붙이고, 값 텍스트 자리를 그만큼 확보.
## 아이콘을 화면 오른쪽 끝(EDGE_MARGIN)에 정확히 맞추고, 라벨 텍스트는 그 왼쪽으로 물려준다.
func _right_stat_icon(kind: String, label: Label, col: Color) -> void:
	const SZ := 18.0
	const EDGE_MARGIN := 10.0   # 화면 오른쪽 끝 여백
	const GAP := 6.0            # 아이콘과 텍스트 사이 간격
	var ic := UIIcon.make(kind, SZ, col)
	# 모든 앵커/오프셋을 명시해 아이콘 사각형을 화면 안에 가두고(이전엔 offset_right
	# 가 18 로 남아 오른쪽으로 18px 삐져나가 잘렸음), 라벨 세로 중앙에 맞춘다.
	ic.anchor_left = 1.0
	ic.anchor_right = 1.0
	ic.anchor_top = 0.0
	ic.anchor_bottom = 0.0
	ic.offset_right = -EDGE_MARGIN
	ic.offset_left = -EDGE_MARGIN - SZ
	var cy := (label.offset_top + label.offset_bottom) * 0.5
	ic.offset_top = cy - SZ * 0.5
	ic.offset_bottom = cy + SZ * 0.5
	add_child(ic)
	# 라벨 오른쪽 끝을 아이콘 왼쪽까지 당겨 텍스트와 아이콘이 겹치지 않게 한다.
	label.offset_right = -EDGE_MARGIN - SZ - GAP


# 게임오버 패널: 메달 + 아이콘 통계 그리드를 코드로 구성(기존 텍스트 라벨 대체).
func _build_gameover_stats() -> void:
	stats_label.visible = false
	var vbox := stats_label.get_parent()

	var holder := VBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 10)
	vbox.add_child(holder)
	vbox.move_child(holder, stats_label.get_index() + 1)

	# 메달 + 신기록 표시
	_go_medal = UIIcon.make("trophy", 56, Color(1.0, 0.82, 0.25))
	_go_medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(_go_medal)

	_go_record = Label.new()
	_go_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_record.add_theme_font_size_override("font_size", 20)
	_go_record.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	UITheme.heading(_go_record)
	_go_record.visible = false
	holder.add_child(_go_record)

	# 통계 그리드 [아이콘][값]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	holder.add_child(grid)
	for row in [["star", "score", Color(1.0, 0.85, 0.2)], ["flag", "wave", Color(0.7, 0.85, 1.0)],
			["skull", "kills", Color(0.95, 0.55, 0.55)], ["clock", "time", Color(0.82, 0.86, 0.95)],
			["trophy", "best", Color(0.8, 0.82, 0.9)]]:
		grid.add_child(UIIcon.make(row[0], 22, row[2]))
		var val := Label.new()
		val.add_theme_font_size_override("font_size", 24)
		val.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
		grid.add_child(val)
		_go_vals[row[1]] = val


func _on_player_died() -> void:
	SaveManager.delete_save()   # 사망 시 진행 실패 — 체크포인트 무효화
	# 부활 버튼은 아직 안 썼고 광고가 준비됐을 때만 노출.
	_revive_btn.visible = not _revive_used and AdManager.is_rewarded_ready()
	_show_end_panel(false)


## REAPER 처치 → 승리. 게임오버 패널을 승리용으로 재사용(부활 없음).
func _on_game_won() -> void:
	SaveManager.delete_save()   # 런 종료 — 체크포인트 무효화
	_revive_btn.visible = false
	game_over_label.text = "VICTORY!"
	game_over_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_show_end_panel(true)


func _show_end_panel(victory: bool) -> void:
	boss_bar.visible = false
	var m := int(Events.elapsed_time) / 60
	var s := int(Events.elapsed_time) % 60

	# 점수 등급별 메달 색 (승리는 무조건 금)
	var medal := Color(0.80, 0.52, 0.32)   # bronze
	if victory or Events.score >= 2500: medal = Color(1.0, 0.82, 0.25)   # gold
	elif Events.score >= 800: medal = Color(0.78, 0.80, 0.88)            # silver
	_go_medal.color = medal
	_go_medal.queue_redraw()

	_go_record.visible = Events.is_new_record()
	if Events.is_new_record():
		_go_record.text = Locale.t("go_new_best_fmt") % Events.high_score

	_go_vals["wave"].text = "%d" % Events.current_wave
	_go_vals["kills"].text = "%d" % Events.total_kills
	_go_vals["time"].text = "%02d:%02d" % [m, s]
	_go_vals["best"].text = "%d" % Events.high_score
	# 점수 카운트업 연출
	_go_vals["score"].text = "0"
	var ct := create_tween()
	ct.tween_method(func(v: float): _go_vals["score"].text = "%d" % int(v), 0.0, float(Events.score), 0.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_set_blur(true)
	game_over_panel.visible = true
	game_over_panel.modulate.a = 0.0
	game_over_panel.scale = Vector2(0.8, 0.8)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(game_over_panel, "modulate:a", 1.0, 0.3)
	tw.tween_property(game_over_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 게임 전체 정지 — 좀비·총알·플레이어 이동까지 모두 멈춘다(HUD/광고는 PROCESS_MODE_ALWAYS 라 계속 동작).
	get_tree().paused = true


func _on_restart_pressed() -> void:
	get_tree().paused = false   # 새 판 시작 전 정지 해제
	MetaManager.bank(Events.total_gold)   # 이번 판 골드를 영구 은행에 적립
	Events.reset()
	Pool.clear()
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false   # 씬 전환 전 정지 해제
	MetaManager.bank(Events.total_gold)   # 이번 판 골드를 영구 은행에 적립
	Events.reset()
	Pool.clear()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
