extends CanvasLayer
## HUD: 골드·체력·웨이브·경과시간을 Events 시그널로 받아 실시간 갱신. 게임오버 패널 제어.

const FOG_TEX := preload("res://assets/ui/fog_vision.png")   # 주변 시야 제한 오버레이(방사형 암전)
const _UIStyle := preload("res://scripts/UIStyle.gd")
const _PerfOverlay := preload("res://scripts/PerfOverlay.gd")

@onready var top_bg: Panel = $TopBg
@onready var gold_label: Label = $GoldLabel
@onready var hp_bar: Control = $HpBar
@onready var hp_bg: Panel = $HpBar/BarBg
@onready var hp_fill: Panel = $HpBar/BarFill
@onready var hp_label: Label = $HpBar/HpLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var buff_label: Label = $BuffLabel
@onready var kills_label: Label = $KillsLabel
@onready var time_label: Label = $TimeLabel
@onready var score_label: Label = $ScoreLabel
@onready var high_score_label: Label = $HighScoreLabel
@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var low_hp_overlay: ColorRect = $LowHpOverlay
@onready var boss_bar: Control = $BossBar
@onready var boss_bg: Panel = $BossBar/BarBg
@onready var boss_fill: Panel = $BossBar/BarFill
@onready var boss_name_label: Label = $BossBar/BossName
## 화면 중앙 대형 배너 — 30분 클리어와 보스 처치 마일스톤이 함께 쓴다.
@onready var banner_bg: Panel = $BannerBg
@onready var banner_label: Label = $BannerLabel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/Margin/VBoxContainer/GameOverLabel
@onready var stats_label: Label = $GameOverPanel/Margin/VBoxContainer/StatsLabel
@onready var restart_button: Button = $GameOverPanel/Margin/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $GameOverPanel/Margin/VBoxContainer/MainMenuButton

const BOSS_BAR_W := 400.0
const HP_BAR_W := 296.0   # 체력 게이지 채움부의 최대 폭(씬의 BarFill 0~296)

var _prev_health: int = -1
var _prev_gold: int = -1
var _prev_score: int = -1
var _max_health: int = 0
var _low_hp_tween: Tween = null
var _hp_fill_sb: StyleBox = null       # 체력 게이지 채움부 스타일 — Flat(bg_color) 또는 Texture(modulate)
var _hp_fill_max := HP_BAR_W           # 채움부 최대 폭(텍스처 프레임 모드에선 림만큼 안쪽으로 준다)
var _boss_fill_max := BOSS_BAR_W
var _hp_ghost: Panel = null            # 피해 잔상 바 — 줄어든 체력만큼 밝은 잔량이 늦게 따라온다
var _hp_ghost_tween: Tween = null
var _hp_fill_tween: Tween = null       # 채움부 폭 트윈 — 연속 피격 시 중첩되지 않게 매번 kill 후 재생성
var _flash_tween: Tween = null         # 피격 붉은 섬광 — 종료 시 오버레이를 숨겨 fill-rate 낭비를 없앤다
var _gold_shown: float = 0.0           # 골드 롤링 카운터의 현재 표시값
var _gold_roll_tween: Tween = null
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
var _go_vals: Dictionary = {}   # "score"/"best"/"kills"/"time" -> Label

# 스웜 경고 배너 — 코드로 생성. 무리/엘리트 팩 등장 직전 화면 중앙 상단에 붉게 번쩍.
var _swarm_banner: Label = null
var _swarm_tween: Tween = null

# 인게임 레벨 표시 — 코드로 생성. 화면 최상단 경험치 바 + 상단바 중앙의 레벨 뱃지(알약형).
var _xp_bg: ColorRect = null
var _xp_fill: ColorRect = null
var _level_label: Label = null
var _level_badge: Control = null   # VARCO 원형 뱃지 텍스처 모드일 때만(라벨은 그 위 숫자)
var _prev_level: int = -1   # 레벨업 감지(뱃지 펄스)용

# 장착 로드아웃(무기/패시브) — 아이콘 슬롯 그리드(무기 1줄 + 패시브 1줄) + 목표 힌트.
var _loadout_box: VBoxContainer = null
var _weapon_row: HBoxContainer = null
var _passive_row: HBoxContainer = null
var _prev_inv: Dictionary = {}   # id -> level. 신규 획득/레벨업 슬롯 펄스 감지용
var _goal_label: Label = null

# 일시정지 메뉴(게임 중 메인메뉴 나가기)
var _pause_btn: Button = null
var _pause_dim: ColorRect = null
var _pause_panel: PanelContainer = null
var _pause_time: Label = null             # 일시정지 화면의 생존 시간(HUD 에서 옮겨 온 경과 시간)
var _pause_scroll: ScrollContainer = null # 내용이 화면을 넘으면 여기서 스크롤된다
var _pause_vb: VBoxContainer = null       # 스크롤 내용(높이 계산용)
var _stat_icons: Array = []               # 상단 우측 스탯 아이콘들 — 세이프에어리어 이동 대상
var _cheat_box: VBoxContainer = null      # 일시정지 메뉴의 치트 하위 메뉴(접이식)
var _cheat_auto_btn: Button = null        # 자동플레이 토글 버튼(라벨 ON/OFF 갱신)
var _cheat_perf_btn: Button = null        # 성능 오버레이 토글 버튼(라벨 ON/OFF 갱신)
var _cheat_day_btn: Button = null         # 낮/밤 시간 처리 토글 버튼(라벨 ON/OFF 갱신)
var _cheat_weather_btn: Button = null     # 날씨 연출 토글 버튼(라벨 ON/OFF 갱신)
var _perf_overlay: Control = null         # 성능 디버그 오버레이(좌상단)
var _auto_tag: Label = null               # 자동플레이 중임을 알리는 화면 표시


func _ready() -> void:
	# 게임오버로 트리를 일시정지해도 HUD(게임오버 패널·버튼·블러)는 계속 동작해야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 상단바 — VARCO 텍스처(hud_top_bar.png)가 있으면 사용, 없으면 기존 반투명 플랫 바.
	var bar_box := _UIStyle.hud_top_bar_box()
	if bar_box:
		top_bg.add_theme_stylebox_override("panel", bar_box)
	else:
		top_bg.add_theme_stylebox_override("panel", _UIStyle.bottom_bar(Color(0.05, 0.06, 0.09, 0.62)))
	banner_bg.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.08, 0.30, 0.14, 0.92), Color(1.0, 0.85, 0.2), 26, 3))
	game_over_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.08, 0.05, 0.06, 0.96), Color(0.85, 0.25, 0.22), 22, 3))
	_UIStyle.apply_button_style(restart_button, Color(0.55, 0.16, 0.16), Color(0.95, 0.35, 0.3))
	_UIStyle.apply_button_style(main_menu_button, Color(0.18, 0.20, 0.26), Color(0.5, 0.55, 0.65))
	_style_bars()
	# 전장 위에 뜨는 상단 라벨들에 어두운 외곽선을 넣어 가독성을 확보한다.
	# clip_text: 이들은 앵커로 폭이 고정돼 있어 늘어날 수 없다. 번역이나 수치가 예상보다
	# 길어져도 글자가 전장 위로 새지 않도록 위젯 안에서 잘라낸다(현재는 전부 여유가 있다 —
	# tools/check_text_fit.py 로 검증). 안전장치이지 상시 동작하는 기능이 아니다.
	for lbl in [gold_label, score_label, kills_label, time_label, high_score_label, hp_label,
			weapon_label, buff_label, boss_name_label]:
		UITheme.outline_label(lbl)
		lbl.clip_text = true
	UITheme.outline_label(boss_name_label, 6, Color(0.18, 0.0, 0.0, 0.75))
	restart_button.text = Locale.t("go_retry")
	main_menu_button.text = Locale.t("go_menu")
	# 주변 시야 제한(방사형 암전) 오버레이 제거 — 화면 외곽이 어두워 보이지 않도록.
	_build_revive_button()
	_build_hud_icons()
	_build_xp_bar()
	_build_swarm_banner()
	_build_perf_overlay()
	_build_loadout()
	_build_goal_hint()
	_build_gameover_stats()
	_build_blur_overlay()
	_build_pause_menu()
	_apply_safe_area()
	UITheme.heading(banner_label)
	UITheme.heading($GameOverPanel/Margin/VBoxContainer/GameOverLabel)
	call_deferred("_init_pivots")

	Events.gold_changed.connect(_on_gold_changed)
	Events.player_health_changed.connect(_on_player_health_changed)
	Events.player_died.connect(_on_player_died)
	Events.kills_changed.connect(_on_kills_changed)
	Events.run_progress.connect(_on_run_progress)
	Events.run_cleared.connect(_on_run_cleared)
	Events.milestone_reached.connect(_on_milestone_reached)
	Events.weapon_equipped.connect(_on_weapon_equipped)
	Events.weapon_timer_changed.connect(_on_weapon_timer_changed)
	Events.gold_magnet_changed.connect(_on_gold_magnet_changed)
	Events.score_changed.connect(_on_score_changed)
	Events.high_score_changed.connect(_on_high_score_changed)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_health_changed.connect(_on_boss_health_changed)
	Events.boss_died.connect(_on_boss_died)
	Events.swarm_incoming.connect(_on_swarm_incoming)
	Events.weather_changed.connect(_on_weather_changed)
	Events.xp_changed.connect(_on_xp_changed)
	Events.inventory_changed.connect(_on_inventory_changed)
	Events.game_won.connect(_on_game_won)
	Events.achievement_unlocked.connect(_on_achievement_unlocked)
	Events.quest_completed.connect(_on_quest_completed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	AdManager.rewarded_granted.connect(_on_rewarded_granted)
	_on_gold_changed(Events.total_gold)
	if Events.player_max_health > 0:
		_on_player_health_changed(Events.player_health, Events.player_max_health)
	_on_kills_changed(Events.total_kills)
	_on_run_progress(Events.elapsed_time, GameData.difficulty.clear_seconds)
	_on_score_changed(Events.score)
	_on_high_score_changed(Events.high_score)
	_on_xp_changed(Events.xp, Events.xp_to_next, Events.level)
	_on_inventory_changed()


## 둥근 패널/라벨이 자신의 중심을 기준으로 스케일되도록 pivot 보정 (레이아웃 확정 후 1회).
func _init_pivots() -> void:
	gold_label.pivot_offset = gold_label.size * 0.5
	score_label.pivot_offset = score_label.size * 0.5
	weapon_label.pivot_offset = weapon_label.size * 0.5
	banner_bg.pivot_offset = banner_bg.size * 0.5
	banner_label.pivot_offset = banner_label.size * 0.5
	game_over_panel.pivot_offset = game_over_panel.size * 0.5


## 골드 표시 — 즉시 대입 대신 짧게 촤르륵 굴러가는 롤링 카운터(증감 모두).
func _on_gold_changed(total: int) -> void:
	if _prev_gold < 0:
		# 최초 설정(씬 진입/이어하기)은 연출 없이 그대로.
		_gold_shown = float(total)
		gold_label.text = "%d" % total
	else:
		if total > _prev_gold:
			_pulse_gold()
		if _gold_roll_tween and _gold_roll_tween.is_valid():
			_gold_roll_tween.kill()
		_gold_roll_tween = create_tween()
		_gold_roll_tween.tween_method(_set_gold_shown, _gold_shown, float(total), 0.35)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prev_gold = total


func _set_gold_shown(v: float) -> void:
	_gold_shown = v
	gold_label.text = "%d" % int(round(v))


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
	if SoundManager.has_stream("boss_alarm"):
		SoundManager.play("boss_alarm", 0.03, 1.0)   # 보스 등장 경보(파일 있을 때만)
	_boss_max = maxi(max_health, 1)
	boss_name_label.text = Events.boss_display_name   # 보스 타입 이름 표시(BRUTE/GUNNER…)
	boss_fill.size.x = _boss_fill_max
	boss_bar.visible = true
	boss_bar.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(boss_bar, "modulate:a", 1.0, 0.3)
	_announce_boss(Events.boss_display_name)


## 보스 등장 배너 — 화면 중앙에 이름이 크게 슬라이드 인 했다가 사라진다(등장 연출).
func _announce_boss(boss_name: String) -> void:
	var banner := Label.new()
	banner.text = ">>  %s  <<" % boss_name
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 210.0
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 40)
	banner.add_theme_color_override("font_color", Color(1.0, 0.35, 0.30))
	banner.add_theme_color_override("font_outline_color", Color(0.1, 0, 0, 0.95))
	banner.add_theme_constant_override("outline_size", 6)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.7, 0.7)
	banner.pivot_offset = Vector2(180, 24)
	add_child(banner)
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)
	tw.tween_callback(banner.queue_free)


func _on_boss_health_changed(health: int, max_health: int) -> void:
	_boss_max = maxi(max_health, 1)
	var ratio := clampf(float(health) / float(_boss_max), 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(boss_fill, "size:x", _boss_fill_max * ratio, 0.12)


func _on_boss_died() -> void:
	var tw := create_tween()
	tw.tween_property(boss_bar, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): boss_bar.visible = false)


## 스웜 경고 배너 — 화면 상단 중앙에 코드로 생성(씬 수정 없이).
func _build_swarm_banner() -> void:
	_swarm_banner = Label.new()
	_swarm_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_swarm_banner.offset_top = 260.0   # 무기/버프 라벨(y160~224)·보스 바(y112~152)와 겹치지 않게 아래로
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
	_swarm_banner.text = Locale.t("hud_elite") if elite else Locale.t("hud_swarm")
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


## 날씨 전환 알림 — 상시 위젯을 두지 않고(시간 표시 과밀 방지) 바뀌는 순간만 짧게 띄운다.
## key == "" 는 '맑아짐'.
func _on_weather_changed(key: String) -> void:
	var col := Color(0.72, 0.86, 1.0) if key != "" else Color(0.85, 0.88, 0.92)
	_show_toast(Locale.t("weather_clear" if key == "" else "weather_" + key), col, 215.0)


## 도전과제 달성 토스트 — 화면 상단 중앙에 잠깐 떴다 사라진다(코드로 즉석 생성).
func _on_achievement_unlocked(title: String) -> void:
	SoundManager.play_ui("gold", 0.0, 1.4)   # 달성 보상 하이톤 차임
	_show_toast("[*]  %s  - reward waiting" % title, Color(1.0, 0.85, 0.35), 150.0)


## 끝없는 과제 완료 — 보상은 자동 지급되지 않고 메뉴의 REWARDS 보관함에서 직접 수령한다.
func _on_quest_completed(title: String, reward: int) -> void:
	SoundManager.play_ui("gold", 0.0, 1.5)
	_show_toast("[+]  Quest: %s   +%d gold waiting" % [title, reward], Color(0.6, 1.0, 0.6), 190.0)


## 화면 상단 중앙에 잠깐 떠오르는 토스트 알림(달성/과제 공용).
func _show_toast(text: String, col: Color, from_y: float) -> void:
	var toast := Label.new()
	toast.text = text
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.offset_top = from_y
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 22)
	toast.add_theme_color_override("font_color", col)
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast.add_theme_constant_override("outline_size", 4)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.modulate.a = 0.0
	add_child(toast)
	var tw := create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(toast, "offset_top", from_y - 30.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.0)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(toast.queue_free)


func _on_player_health_changed(health: int, max_health: int) -> void:
	_max_health = max_health
	_update_hp_bar(health, max_health)
	if _prev_health > 0 and health < _prev_health and health > 0:
		_flash_hurt()
	_update_low_hp_warning(health)
	_prev_health = health


## 체력을 하트 개수 대신 연속 게이지로 표시. 비율에 따라 초록→노랑→빨강으로 색이 바뀌고,
## 폭은 부드럽게 트윈된다. 라벨은 "현재 / 최대" 숫자를 함께 보여준다.
## 피해 시에는 잔상 바가 이전 폭에 0.35초 머물렀다가 따라 줄어든다(깎인 양 강조).
func _update_hp_bar(health: int, max_health: int) -> void:
	var mx := maxi(max_health, 1)
	var cur := clampi(health, 0, mx)
	var ratio := float(cur) / float(mx)
	var target := _hp_fill_max * ratio
	hp_label.text = "HP %d / %d" % [cur, mx]
	# 연속 피격(접촉 데미지)에서 트윈을 새로 만들기만 하면 여러 트윈이 같은 size:x 를 놓고 다퉈
	# 바가 튀고 트윈 객체도 누적된다 — 잔상 바(_hp_ghost_tween)처럼 직전 트윈을 반드시 정리한다.
	if _hp_fill_tween and _hp_fill_tween.is_valid():
		_hp_fill_tween.kill()
	_hp_fill_tween = create_tween()
	_hp_fill_tween.tween_property(hp_fill, "size:x", target, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _hp_fill_sb is StyleBoxFlat:
		_hp_fill_sb.bg_color = _hp_color(ratio)
	elif _hp_fill_sb is StyleBoxTexture:
		_hp_fill_sb.modulate_color = _hp_color(ratio)
	if _hp_ghost:
		if _hp_ghost_tween and _hp_ghost_tween.is_valid():
			_hp_ghost_tween.kill()
		if _prev_health >= 0 and cur < _prev_health:
			# 피해: 잔상은 이전 폭에 잠시 머문 뒤 현재 폭으로 수축.
			_hp_ghost_tween = create_tween()
			_hp_ghost_tween.tween_interval(0.35)
			_hp_ghost_tween.tween_property(_hp_ghost, "size:x", target, 0.30)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			# 회복/초기화: 잔상이 보일 이유가 없다 — 즉시 현재 폭으로.
			_hp_ghost.size.x = target


## 체력/보스 게이지 스타일 — VARCO 텍스처(프레임+필)가 있으면 나인패치, 없으면 플랫 폴백.
func _style_bars() -> void:
	var frame_tex := _UIStyle.hud_tex("hud_gauge_frame.png")
	var fill_tex := _UIStyle.hud_tex("hud_gauge_fill.png")
	if frame_tex and fill_tex:
		_style_bars_textured(frame_tex, fill_tex)
	else:
		_style_bars_flat()
	_build_hp_ghost(fill_tex)


## 텍스처 게이지 — 프레임은 나인패치, 필은 무채색 스트립에 modulate 로 의미 색을 입힌다.
## 필/잔상은 프레임 림 안쪽으로 인셋(±4px)해 채널 안에 앉힌다.
func _style_bars_textured(frame_tex: Texture2D, fill_tex: Texture2D) -> void:
	# 마진/인셋은 tools/gen_hud_assets.py 의 나인패치 계약(프레임 7, 필 4, 채널 시작 4px)과 일치.
	hp_bg.add_theme_stylebox_override("panel", _UIStyle.tex_box(frame_tex, 7))
	_hp_fill_sb = _UIStyle.tex_box(fill_tex, 4, Color(0.3, 0.85, 0.35))
	hp_fill.add_theme_stylebox_override("panel", _hp_fill_sb)
	hp_fill.offset_left = 4.0
	hp_fill.offset_top = 4.0
	hp_fill.offset_bottom = 22.0
	_hp_fill_max = HP_BAR_W - 8.0
	hp_fill.size.x = _hp_fill_max

	boss_bg.add_theme_stylebox_override("panel", _UIStyle.tex_box(frame_tex, 7))
	boss_fill.add_theme_stylebox_override("panel", _UIStyle.tex_box(fill_tex, 4, Color(0.92, 0.22, 0.22)))
	boss_fill.offset_left = 4.0
	boss_fill.offset_top = 28.0
	boss_fill.offset_bottom = 36.0
	_boss_fill_max = BOSS_BAR_W - 8.0


## 플랫 게이지(폴백) — 둥근 모서리·테두리의 StyleBoxFlat.
func _style_bars_flat() -> void:
	var hp_bg_sb := StyleBoxFlat.new()
	hp_bg_sb.bg_color = Color(0.09, 0.03, 0.05, 0.9)
	hp_bg_sb.set_corner_radius_all(7)
	hp_bg_sb.corner_detail = 6
	hp_bg_sb.anti_aliasing = true
	hp_bg_sb.set_border_width_all(2)
	hp_bg_sb.border_color = Color(0, 0, 0, 0.55)
	hp_bg.add_theme_stylebox_override("panel", hp_bg_sb)

	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.3, 0.85, 0.35)
	fill_sb.set_corner_radius_all(6)
	fill_sb.corner_detail = 6
	fill_sb.anti_aliasing = true
	_hp_fill_sb = fill_sb
	hp_fill.add_theme_stylebox_override("panel", _hp_fill_sb)

	var boss_bg_sb := StyleBoxFlat.new()
	boss_bg_sb.bg_color = Color(0.11, 0.02, 0.03, 0.9)
	boss_bg_sb.set_corner_radius_all(6)
	boss_bg_sb.corner_detail = 6
	boss_bg_sb.anti_aliasing = true
	boss_bg_sb.set_border_width_all(2)
	boss_bg_sb.border_color = Color(0, 0, 0, 0.5)
	boss_bg.add_theme_stylebox_override("panel", boss_bg_sb)

	var boss_fill_sb := StyleBoxFlat.new()
	boss_fill_sb.bg_color = Color(0.92, 0.22, 0.22)
	boss_fill_sb.set_corner_radius_all(5)
	boss_fill_sb.corner_detail = 6
	boss_fill_sb.anti_aliasing = true
	boss_fill.add_theme_stylebox_override("panel", boss_fill_sb)


## 피해 잔상 바 — 채움부 "뒤"에 깔리는 밝은 바. 피해 순간 이전 폭에 머물렀다가
## 잠시 뒤 현재 폭으로 따라 줄어들어, 방금 깎인 양이 시각적으로 남는다.
func _build_hp_ghost(fill_tex: Texture2D) -> void:
	_hp_ghost = Panel.new()
	_hp_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fill_tex:
		_hp_ghost.add_theme_stylebox_override("panel", _UIStyle.tex_box(fill_tex, 4, Color(1.0, 0.55, 0.45, 0.85)))
		_hp_ghost.offset_left = 4.0
		_hp_ghost.offset_top = 4.0
		_hp_ghost.offset_bottom = 22.0
	else:
		var ghost_sb := StyleBoxFlat.new()
		ghost_sb.bg_color = Color(1.0, 0.55, 0.45, 0.85)
		ghost_sb.set_corner_radius_all(6)
		ghost_sb.corner_detail = 6
		ghost_sb.anti_aliasing = true
		_hp_ghost.add_theme_stylebox_override("panel", ghost_sb)
		_hp_ghost.offset_bottom = 26.0
	_hp_ghost.size.x = _hp_fill_max
	hp_bar.add_child(_hp_ghost)
	hp_bar.move_child(_hp_ghost, hp_fill.get_index())   # 채움부 바로 아래(뒤)로


## 체력 비율에 따른 게이지 색: 높음=초록, 중간=노랑, 낮음=빨강(선형 보간).
func _hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.85, 0.75, 0.2).lerp(Color(0.3, 0.85, 0.35), (ratio - 0.5) * 2.0)
	return Color(0.9, 0.25, 0.2).lerp(Color(0.85, 0.75, 0.2), ratio * 2.0)


## 피격 섬광. 전체 화면 ColorRect 는 alpha 0 이어도 visible 이면 매 프레임 풀스크린 블렌딩을
## 하므로(720x1280 ≈ 92만 픽셀), 연출이 끝나면 visible=false 로 렌더에서 완전히 빼낸다.
func _flash_hurt() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	flash_overlay.color = Color(1, 0, 0, 0.35)
	flash_overlay.visible = true
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash_overlay, "color", Color(1, 0, 0, 0.0), 0.4)
	_flash_tween.tween_callback(func() -> void: flash_overlay.visible = false)


## 체력이 1일 때 화면 가장자리를 붉게 경고. 껌뻑이는 점멸(1초 주기·0→0.30)은 눈이 피로해서,
## 은은한 저강도 글로우가 사인 곡선으로 천천히 "숨쉬는" 연출로 바꿨다(밝기·빈도 모두 완화).
const _LOW_HP_MIN_A := 0.06   # 완전히 꺼지지 않고 낮게 유지 → 깜박임이 아닌 은은한 상시 경고
const _LOW_HP_MAX_A := 0.22   # 피크도 낮춰 눈부심 완화(이전 0.30)
const _LOW_HP_HALF := 1.3     # 한 방향(밝아짐/어두워짐) 시간 — 느려서 껌뻑임 빈도가 낮다

func _update_low_hp_warning(health: int) -> void:
	# 최대 체력이 커질 수 있으므로 절대값(==1)이 아닌 비율로 위급 판정(≤20%, 최소 1 이상).
	var should_pulse := health > 0 and float(health) / float(maxi(_max_health, 1)) <= 0.2
	if should_pulse and _low_hp_tween == null:
		low_hp_overlay.color.a = _LOW_HP_MIN_A
		low_hp_overlay.visible = true
		_low_hp_tween = create_tween()
		_low_hp_tween.set_loops()
		_low_hp_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_low_hp_tween.tween_property(low_hp_overlay, "color:a", _LOW_HP_MAX_A, _LOW_HP_HALF)
		_low_hp_tween.tween_property(low_hp_overlay, "color:a", _LOW_HP_MIN_A, _LOW_HP_HALF)
	elif not should_pulse and _low_hp_tween != null:
		_low_hp_tween.kill()
		_low_hp_tween = null
		low_hp_overlay.color.a = 0.0
		low_hp_overlay.visible = false   # 투명한 풀스크린 레이어를 렌더에 남겨두지 않는다


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


## 엔들리스 — 상단 우측에 누적 처치 수를 표시한다(웨이브 개념은 없다).
func _on_kills_changed(kills: int) -> void:
	kills_label.text = Locale.t("hud_kills_fmt") % kills


## 메인 타이머 — 클리어(30분)까지의 "남은 시간" 카운트다운 하나만 보여준다(경과·진행률 라벨 통합).
## 카운트다운 자체가 목표를 전달하고, 경과 시간은 일시정지 패널/게임오버 통계에서 확인한다.
## 클리어 후엔 금색 "연장전 +MM:SS" 카운트업으로 전환, 막판 1분은 붉게 강조.
func _on_run_progress(elapsed: float, clear: float) -> void:
	if elapsed >= clear:
		var over := int(elapsed - clear)
		time_label.text = "%s +%02d:%02d" % [Locale.t("hud_overtime"), over / 60, over % 60]
		time_label.add_theme_font_size_override("font_size", 19)
		time_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	else:
		var remain := int(ceil(clear - elapsed))
		time_label.text = "%02d:%02d" % [remain / 60, remain % 60]
		if remain <= 60:
			time_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))


## 30분 생존 클리어 — 웨이브 클리어 배너를 재사용해 크게 알린다(승리 아님, 이후 무한 하드모드).
func _on_run_cleared() -> void:
	if SoundManager.has_stream("victory"):
		SoundManager.play_ui("victory", 0.02, 1.0)   # 30분 클리어 징글(파일 있을 때만)
	banner_label.text = Locale.t("run_cleared")
	banner_label.visible = true
	banner_bg.visible = true
	banner_label.modulate.a = 1.0
	banner_bg.modulate.a = 1.0
	banner_label.scale = Vector2(0.7, 0.7)
	banner_bg.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(banner_label, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner_bg, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(2.2)
	tw.set_parallel(true)
	tw.tween_property(banner_label, "modulate:a", 0.0, 0.6)
	tw.tween_property(banner_bg, "modulate:a", 0.0, 0.6)
	tw.set_parallel(false)
	tw.tween_callback(func():
		banner_label.visible = false
		banner_bg.visible = false)
	Events.shake(8.0)


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


## 경험치 바 — 화면 최상단 엣지(전 너비) + 상단바 중앙의 알약형 레벨 뱃지.
## 뱃지가 XP 바와 같은 시안 톤을 공유해 "레벨 ↔ 경험치"가 한 덩어리로 읽히게 한다.
func _build_xp_bar() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.anchor_right = 1.0
	bg.offset_top = 0.0
	bg.offset_bottom = 8.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_xp_bg = bg
	_xp_fill = ColorRect.new()
	_xp_fill.color = Color(0.50, 0.84, 1.0, 1.0)
	_xp_fill.anchor_right = 0.0
	_xp_fill.anchor_bottom = 1.0
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(_xp_fill)

	# 레벨 표시 — VARCO 원형 뱃지 텍스처가 있으면 뱃지+숫자, 없으면 알약형 라벨.
	var badge_tex := _UIStyle.hud_tex("hud_badge_level.png")
	_level_label = Label.new()
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if badge_tex:
		# 레벨은 성장 게임의 핵심 정보 — 뱃지를 크게(64px), XP 바와 붙여 강조한다.
		var badge := TextureRect.new()
		badge.texture = badge_tex
		badge.anchor_left = 0.5
		badge.anchor_right = 0.5
		badge.offset_left = -32.0
		badge.offset_right = 32.0
		badge.offset_top = 6.0
		badge.offset_bottom = 70.0
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(badge)
		_level_badge = badge
		# 숫자만으로는 레벨인지 알기 어려워 뱃지 상단에 "Lv" 캡션을 함께 표시한다.
		var cap := Label.new()
		cap.text = "Lv"
		cap.set_anchors_preset(Control.PRESET_TOP_WIDE)
		cap.offset_top = 12.0
		cap.offset_bottom = 26.0
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_font_size_override("font_size", 11)
		cap.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
		cap.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		cap.add_theme_constant_override("outline_size", 2)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(cap)
		# 숫자는 캡션 아래로 살짝 내려 중앙 하단에 배치.
		_level_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_level_label.offset_top = 18.0
		_level_label.offset_bottom = -4.0
		_level_label.add_theme_font_size_override("font_size", 20)
		_level_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75))
		_level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_level_label.add_theme_constant_override("outline_size", 3)
		badge.add_child(_level_label)
	else:
		_level_label.anchor_left = 0.5
		_level_label.anchor_right = 0.5
		_level_label.offset_left = -56.0
		_level_label.offset_right = 56.0
		_level_label.offset_top = 12.0
		_level_label.offset_bottom = 40.0
		_level_label.add_theme_font_size_override("font_size", 19)
		_level_label.add_theme_color_override("font_color", Color(0.72, 0.90, 1.0))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.08, 0.13, 0.85)
		sb.set_corner_radius_all(14)
		sb.corner_detail = 6
		sb.anti_aliasing = true
		sb.set_border_width_all(1)
		sb.border_color = Color(0.45, 0.80, 1.0, 0.55)
		sb.content_margin_left = 12.0
		sb.content_margin_right = 12.0
		_level_label.add_theme_stylebox_override("normal", sb)
		add_child(_level_label)


func _on_xp_changed(xp: int, xp_to_next: int, level: int) -> void:
	if _xp_fill:
		_xp_fill.anchor_right = clampf(float(xp) / float(maxi(xp_to_next, 1)), 0.0, 1.0)
	if _level_label:
		_level_label.text = str(level) if _level_badge else "Lv %d" % level
		# 레벨업 순간 뱃지 펄스(초기 -1 → 첫 설정은 제외).
		if _prev_level >= 0 and level > _prev_level:
			var target: Control = _level_badge if _level_badge else _level_label
			target.pivot_offset = target.size * 0.5
			target.scale = Vector2(1.3, 1.3)
			var tw := create_tween()
			tw.tween_property(target, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_prev_level = level


## 장착 로드아웃 — 좌하단 아이콘 슬롯 그리드(무기 1줄 + 패시브 1줄, 각 최대 6칸).
## 텍스트 리스트(후반 16줄+)가 화면 좌측을 덮던 것을 슬롯 두 줄로 압축한다.
## 레벨은 슬롯 우하단 뱃지 숫자로, 신규 획득/레벨업 슬롯은 잠깐 펄스로 알린다.
const _LOADOUT_SLOT_PX := 44

func _build_loadout() -> void:
	# 밝은 필드 위에서도 잘 읽히도록 반투명 어두운 패널을 배경에 깔고(내용에 맞춰 자동 크기).
	var panel := PanelContainer.new()
	# 좌측 "하단" 정렬 — 바닥 목표 힌트(하단 44px) 바로 위에 붙인다.
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 8.0
	panel.offset_top = -54.0
	panel.offset_bottom = -54.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.40)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 7.0
	sb.content_margin_right = 7.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	_loadout_box = VBoxContainer.new()
	_loadout_box.add_theme_constant_override("separation", 5)
	_loadout_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_loadout_box)

	_weapon_row = HBoxContainer.new()
	_passive_row = HBoxContainer.new()
	for row in [_weapon_row, _passive_row]:
		row.add_theme_constant_override("separation", 5)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_loadout_box.add_child(row)


func _on_inventory_changed() -> void:
	if _weapon_row == null:
		return
	for row in [_weapon_row, _passive_row]:
		for c in row.get_children():
			row.remove_child(c)
			c.queue_free()
	_fill_loadout_row(_weapon_row, Events.weapons)
	_fill_loadout_row(_passive_row, Events.passives)
	_passive_row.visible = _passive_row.get_child_count() > 0
	# 이번 변경으로 늘어난 항목 레벨을 스냅샷 — 다음 변경에서 펄스 대상 판별.
	_prev_inv = {}
	for inv in [Events.weapons, Events.passives]:
		for id in inv.keys():
			_prev_inv[id] = int(inv[id])


func _fill_loadout_row(row: HBoxContainer, inv: Dictionary) -> void:
	for id in inv.keys():
		var lv: int = int(inv[id])
		if lv <= 0:
			continue
		var m := ItemDB.meta(String(id))
		if m.is_empty():
			continue
		var slot := _make_loadout_slot(m, lv)
		row.add_child(slot)
		# 신규 획득 또는 레벨 상승 슬롯은 펄스로 시선 유도(첫 빌드는 _prev_inv 가 비어 전체 제외).
		if not _prev_inv.is_empty() and lv > int(_prev_inv.get(id, 0)):
			_pulse_slot(slot)


## 슬롯 위젯: 어두운 함몰 사각 + 아이콘 + 우하단 레벨 뱃지. (Phase 2 에서 나인패치 프레임으로 교체)
## PanelContainer 는 자식 rect 를 강제 배치해 뱃지 앵커가 무시되므로 일반 Control 로 직접 쌓는다.
func _make_loadout_slot(meta: Dictionary, lv: int) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(_LOADOUT_SLOT_PX, _LOADOUT_SLOT_PX)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot_tex := _UIStyle.hud_tex("hud_slot_small.png")
	if slot_tex:
		frame.add_theme_stylebox_override("panel", _UIStyle.tex_box(slot_tex, 12))
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.05, 0.08, 0.75)
		sb.set_corner_radius_all(8)
		sb.corner_detail = 5
		sb.anti_aliasing = true
		sb.set_border_width_all(1)
		var tint: Color = meta.get("color", Color.WHITE)
		sb.border_color = Color(tint.r, tint.g, tint.b, 0.55)   # 아이템 색은 테두리 힌트로만
		frame.add_theme_stylebox_override("panel", sb)
	slot.add_child(frame)

	var icon = meta.get("icon")
	if icon != null and icon is Texture2D:
		var tex := TextureRect.new()
		tex.texture = icon
		# 슬롯 함몰부를 꽉 채우는 여백 — 프레임 림(슬롯의 12.3%)이 끝나는 지점에 맞춘다.
		# 아이콘 원본에는 투명 여백이 없으므로 이 값이 곧 보이는 크기가 된다.
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.offset_left = 3.0
		tex.offset_top = 3.0
		tex.offset_right = -3.0
		tex.offset_bottom = -3.0
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tex)

	var badge := Label.new()
	badge.text = str(lv)
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	badge.add_theme_constant_override("outline_size", 4)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	badge.offset_right = -3.0
	badge.offset_bottom = -1.0
	slot.add_child(badge)
	return slot


func _pulse_slot(slot: Control) -> void:
	# 레이아웃 직후에는 size 가 0 일 수 있어 한 프레임 뒤 중심 피벗으로 펄스.
	# (Callable.call_deferred 는 4.2+ 라 4.1 호환을 위해 Node.call_deferred 사용)
	call_deferred("_pulse_slot_now", slot)


func _pulse_slot_now(slot: Control) -> void:
	if not is_instance_valid(slot):
		return
	slot.pivot_offset = slot.size * 0.5
	slot.scale = Vector2(1.35, 1.35)
	var tw := create_tween()
	tw.tween_property(slot, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 목표 힌트 — 게임 시작 직후 잠깐만 보여주고 페이드 아웃(카운트다운 타이머가 이후 목표를 전달).
func _build_goal_hint() -> void:
	_goal_label = Label.new()
	_goal_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_goal_label.offset_top = -44.0
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var clear := int(GameData.difficulty.clear_seconds)
	_goal_label.text = Locale.t("hud_goal_fmt") % ("%02d:%02d" % [clear / 60, clear % 60])
	_goal_label.add_theme_font_size_override("font_size", 15)
	_goal_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.75, 0.7))
	_goal_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_goal_label.add_theme_constant_override("outline_size", 3)
	_goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_goal_label)
	# 이어하기(경과 진행 중)로 들어온 판은 즉시, 새 판은 8초 후 사라진다.
	var hold := 8.0 if Events.elapsed_time < 5.0 else 2.0
	var tw := create_tween()
	tw.tween_interval(hold)
	tw.tween_property(_goal_label, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func(): _goal_label.visible = false)


## 마일스톤(보스 처치) 배너 — 예전 웨이브 클리어 연출을 그대로 재활용한다.
## 발신자가 없어 72줄 연출과 스팅어가 통째로 도달 불가였다(P0-2).
func _on_milestone_reached(index: int) -> void:
	if SoundManager.has_stream("wave_clear"):
		SoundManager.play_ui("wave_clear", 0.02, 1.0)   # 마일스톤 스팅어(파일 있을 때만)
	banner_label.text = Locale.t("boss_cleared") % index
	banner_label.visible = true
	banner_bg.visible = true
	banner_label.modulate.a = 1.0
	banner_bg.modulate.a = 1.0
	banner_label.scale = Vector2(0.7, 0.7)
	banner_bg.scale = Vector2(0.7, 0.7)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(banner_label, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner_bg, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(1.3)
	tw.set_parallel(true)
	tw.tween_property(banner_label, "modulate:a", 0.0, 0.5)
	tw.tween_property(banner_bg, "modulate:a", 0.0, 0.5)
	tw.set_parallel(false)
	tw.tween_callback(func():
		banner_label.visible = false
		banner_bg.visible = false)


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


## 보상형 시청 완료 콜백. 지금 쓰는 placement 는 부활 하나뿐이다
## (인게임 상점은 2026-08 폐기 — P0-3).
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
	Events.pause_pop(game_over_panel)
	if _pause_btn:
		_pause_btn.visible = true   # 부활 → 일시정지 버튼 복귀
	if _loadout_box:
		_loadout_box.visible = true   # 로드아웃 표시 복귀
	player.revive()


# 상단 바 작은 아이콘들(웨이브·시간 아이콘) — 텍스트 위주 HUD 보강.
# 점수(★)와 랭킹(최고 🏆)은 HUD 에서 숨긴다(요청) — 처치 수/시간만 노출해 상단을 간결하게.
func _build_hud_icons() -> void:
	score_label.visible = false
	high_score_label.visible = false
	_right_stat_icon("skull",  kills_label,       Color(0.95, 0.6, 0.6))
	_right_stat_icon("clock",  time_label,       Color(0.82, 0.86, 0.95))


## 우측 정렬 라벨의 오른쪽 끝에 작은 아이콘을 붙이고, 값 텍스트 자리를 그만큼 확보.
## 아이콘을 화면 오른쪽 끝(EDGE_MARGIN)에 정확히 맞추고, 라벨 텍스트는 그 왼쪽으로 물려준다.
func _right_stat_icon(kind: String, label: Label, col: Color) -> void:
	const SZ := 18.0
	const EDGE_MARGIN := 70.0   # 오른쪽 끝의 일시정지 버튼(44px + 여백)을 비켜 간다
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
	_stat_icons.append(ic)
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
	# 스코어(★)·랭킹(🏆)은 표시하지 않는다(요청) — 처치·시간만 남긴다.
	for row in [["skull", "kills", Color(0.95, 0.55, 0.55)], ["clock", "time", Color(0.82, 0.86, 0.95)]]:
		grid.add_child(UIIcon.make(row[0], 22, row[2]))
		var val := Label.new()
		val.add_theme_font_size_override("font_size", 24)
		val.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
		grid.add_child(val)
		_go_vals[row[1]] = val

	# 정보(제목·통계)와 버튼 사이 고정 간격 — 통계가 2줄뿐이라 확장 스페이서를 쓰면
	# 패널 중앙이 텅 비어 보인다. 고정 간격 + VBox 중앙 정렬로 짜임새 있게 모은다.
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 22)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(gap)
	vbox.move_child(gap, holder.get_index() + 1)


func _on_player_died() -> void:
	if SoundManager.has_stream("defeat"):
		SoundManager.play_ui("defeat", 0.02, 1.0)   # 게임오버 스팅어(파일 있을 때만)
	SaveManager.delete_save()   # 사망 시 진행 실패 — 체크포인트 무효화
	if _pause_btn:
		_pause_btn.visible = false   # 게임오버 패널과 겹치지 않도록 일시정지 버튼 숨김
	if _loadout_box:
		_loadout_box.visible = false   # 좌하단 로드아웃이 게임오버 버튼을 가리지 않게
	# 부활 버튼은 아직 안 썼고 광고가 준비됐을 때만 노출.
	_revive_btn.visible = not _revive_used and AdManager.is_rewarded_ready()
	_show_end_panel(false)


## REAPER 처치 → 승리. 게임오버 패널을 승리용으로 재사용(부활 없음).
func _on_game_won() -> void:
	SaveManager.delete_save()   # 런 종료 — 체크포인트 무효화
	if _pause_btn:
		_pause_btn.visible = false
	_revive_btn.visible = false
	if _loadout_box:
		_loadout_box.visible = false
	game_over_label.text = Locale.t("go_victory")
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

	_go_record.visible = false   # 신기록 배너(스코어 기반) 미표시

	_go_vals["kills"].text = "%d" % Events.total_kills
	_go_vals["time"].text = "%02d:%02d" % [m, s]

	_set_blur(true)
	game_over_panel.visible = true
	game_over_panel.modulate.a = 0.0
	game_over_panel.scale = Vector2(0.8, 0.8)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(game_over_panel, "modulate:a", 1.0, 0.3)
	tw.tween_property(game_over_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 게임 전체 정지 — 좀비·총알·플레이어 이동까지 모두 멈춘다(HUD/광고는 PROCESS_MODE_ALWAYS 라 계속 동작).
	Events.pause_push(game_over_panel, "gameover")


func _on_restart_pressed() -> void:
	Events.pause_release_all()   # 새 판 시작 전 정지 소유권 전부 해제
	MetaManager.bank(Events.total_gold)   # 이번 판 골드를 영구 은행에 적립
	Events.reset()
	Pool.clear()
	get_tree().reload_current_scene()


## 게임 중 일시정지 버튼 + 오버레이(재개 / 메인메뉴). HUD 는 PROCESS_MODE_ALWAYS 라 정지 중에도 동작한다.
func _build_pause_menu() -> void:
	_pause_btn = Button.new()
	_pause_btn.text = ""   # "❚❚" 글리프는 서브셋 폰트에 없어 깨지므로 텍스트 대신 막대 2개를 직접 그린다.
	# 상단바(96px) 우측 끝에 정착 — 두 줄(처치/시간) 높이에 걸쳐 세로 중앙.
	_pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_btn.offset_left = -58.0
	_pause_btn.offset_right = -14.0
	_pause_btn.offset_top = 26.0
	_pause_btn.offset_bottom = 70.0
	_UIStyle.apply_button_style(_pause_btn, Color(0.12, 0.13, 0.18, 0.9), Color(0.5, 0.55, 0.68))
	_pause_btn.pressed.connect(_on_pause_pressed)
	add_child(_pause_btn)
	# VARCO 원형 버튼 텍스처(⏸ 아이콘 포함)가 있으면 플레이트 대신 사용 —
	# 스타일박스는 비우고 텍스처를 얼굴로 깐다(눌림 팝은 UITheme 전역 스케일이 담당).
	var round_tex := _UIStyle.hud_tex("hud_btn_round.png")
	if round_tex:
		for state in ["normal", "hover", "pressed", "disabled"]:
			_pause_btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var face := TextureRect.new()
		face.texture = round_tex
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pause_btn.add_child(face)
	else:
		# 일시정지 아이콘 — 폰트 글리프 대신 흰 막대 2개(어떤 폰트/빌드에서도 안 깨짐).
		var pico := CenterContainer.new()
		pico.set_anchors_preset(Control.PRESET_FULL_RECT)
		pico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pause_btn.add_child(pico)
		var bars := HBoxContainer.new()
		bars.add_theme_constant_override("separation", 5)
		bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pico.add_child(bars)
		for i in 2:
			var bar := ColorRect.new()
			bar.color = Color(0.85, 0.88, 0.95)
			bar.custom_minimum_size = Vector2(5, 18)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bars.add_child(bar)

	_pause_dim = ColorRect.new()
	_pause_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_dim.color = Color(0, 0, 0, 0.7)
	_pause_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_dim.visible = false
	add_child(_pause_dim)

	_pause_panel = PanelContainer.new()
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	# 내용이 늘어도 중앙을 기준으로 위아래 양쪽으로 자라게 한다(한쪽으로만 자라면 화면 밖으로 밀린다).
	_pause_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pause_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.08, 0.09, 0.13, 0.97), Color(0.5, 0.6, 0.8), 22, 3))
	_pause_panel.visible = false
	add_child(_pause_panel)

	var margin := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, 26)
	_pause_panel.add_child(margin)

	# CHEATS 를 펼치면 버튼이 8개 더 붙어 패널이 화면 높이에 육박한다. 스크롤이 없으면
	# 그 순간 아래쪽이 잘려 손댈 수가 없으므로, 내용을 스크롤 영역에 담는다.
	# (높이는 _fit_pause_scroll() 이 "내용 높이 vs 화면 여유" 중 작은 쪽으로 맞춘다)
	_pause_scroll = ScrollContainer.new()
	_pause_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pause_scroll.scroll_deadzone = 24   # 터치 드래그가 버튼 클릭에 먹히지 않게
	margin.add_child(_pause_scroll)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(300, 0)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_scroll.add_child(vb)
	_pause_vb = vb

	var title := Label.new()
	title.text = Locale.t("pause_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	vb.add_child(title)
	UITheme.heading(title)

	# 경과(생존) 시간 — 상단 HUD 에서 뺀 정보를 여기서 확인한다.
	_pause_time = Label.new()
	_pause_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_time.add_theme_font_size_override("font_size", 18)
	_pause_time.add_theme_color_override("font_color", Color(0.66, 0.70, 0.78))
	vb.add_child(_pause_time)

	var resume := Button.new()
	resume.text = Locale.t("pause_resume")
	resume.custom_minimum_size = Vector2(0, 60)
	resume.add_theme_font_size_override("font_size", 24)
	_UIStyle.apply_button_style(resume, Color(0.14, 0.40, 0.20), Color(0.4, 0.85, 0.45))
	resume.pressed.connect(_on_resume_pressed)
	vb.add_child(resume)

	var menu := Button.new()
	menu.text = Locale.t("go_menu")
	menu.custom_minimum_size = Vector2(0, 56)
	menu.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(menu, Color(0.18, 0.20, 0.26), Color(0.5, 0.55, 0.65))
	menu.pressed.connect(_on_main_menu_pressed)
	vb.add_child(menu)

	# ── 치트 하위 메뉴(접이식) — 자동플레이/시간 점프/골드/레벨업 ─────────────
	# 배포 빌드에는 만들지 않는다. 여기 있는 것들이 점수·랭킹·도전과제·퀘스트·메타 골드를
	# 전부 오염시키기 때문이다(P0-1). 판정은 Cheats.enabled 한 곳에 모여 있다 —
	# 에디터·디버그 빌드는 그대로, 릴리스 export 는 custom_features 에 "cheats" 가 있을 때만.
	# 노드를 아예 만들지 않으므로 아래 _cheat_* 참조는 전부 null 로 남는다(_refresh_cheat_ui 가
	# 필드마다 null 을 확인하고 넘어간다 — 잠긴 빌드에서 그 경로가 실제로 도는 자리다).
	if Cheats.enabled:
		var cheats := Button.new()
		cheats.text = "CHEATS"
		cheats.custom_minimum_size = Vector2(0, 48)
		cheats.add_theme_font_size_override("font_size", 19)
		_UIStyle.apply_button_style(cheats, Color(0.26, 0.16, 0.30), Color(0.7, 0.5, 0.85))
		vb.add_child(cheats)

		_cheat_box = VBoxContainer.new()
		_cheat_box.add_theme_constant_override("separation", 8)
		_cheat_box.visible = false
		vb.add_child(_cheat_box)
		cheats.pressed.connect(func():
			_cheat_box.visible = not _cheat_box.visible
			call_deferred("_fit_pause_scroll"))   # 펼침/접힘 후 바뀐 높이로 다시 맞춘다

		_cheat_auto_btn = _make_cheat_button("AUTO-PLAY: OFF", _on_cheat_autoplay)
		_make_cheat_button("TIME +5 MIN", func(): Cheats.request_time_skip(300.0))
		_make_cheat_button("SPAWN TO CAP", func(): Cheats.request_spawn_fill())
		# 보스전을 10분씩 기다리지 않고 확인 — 누를 때마다 회차가 올라 강화 곡선도 같이 볼 수 있다.
		_make_cheat_button("SPAWN BOSS", func(): Cheats.request_spawn_boss())
		_make_cheat_button("GOLD +500", func(): Events.add_gold(500))
		_make_cheat_button("LEVEL UP +1", func(): Events.bonus_level())
		_cheat_perf_btn = _make_cheat_button("PERF HUD: OFF", func(): Cheats.toggle_perf_overlay())
		# 낮/밤 시간 틴트를 통째로 끈다(날씨는 유지) — 밤 구간에서 화면이 어두워 확인이 어려울 때.
		_cheat_day_btn = _make_cheat_button("DAY/NIGHT: ON", func(): Cheats.toggle_daynight())
		# 비·눈·모래바람과 번개를 통째로 끈다(=상시 맑음). 스케줄은 계속 돌아 다시 켜면 이어진다.
		_cheat_weather_btn = _make_cheat_button("WEATHER: ON", func(): Cheats.toggle_weather())
		Cheats.changed.connect(_refresh_cheat_ui)
		_refresh_cheat_ui()   # 씬 재진입 시 이미 켜져 있던 토글이 라벨에 반영되도록 초기 1회 갱신

	# 자동플레이 동작 중 표시 — 일시정지 버튼 아래 작은 태그.
	_auto_tag = Label.new()
	_auto_tag.text = "AUTO"
	_auto_tag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_auto_tag.offset_left = -60.0
	_auto_tag.offset_right = -12.0
	_auto_tag.offset_top = 100.0
	_auto_tag.offset_bottom = 122.0
	_auto_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_auto_tag.add_theme_font_size_override("font_size", 15)
	_auto_tag.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
	_auto_tag.visible = false
	add_child(_auto_tag)

	call_deferred("_fit_pause_scroll")   # 레이아웃이 확정된 다음 프레임에 1회


## 일시정지 패널 높이 맞추기 — 내용이 다 들어가면 그 높이로 딱 맞추고(스크롤 불필요),
## 화면 여유를 넘으면 거기서 잘라 스크롤로 넘긴다. 세로가 짧은 화면이나 CHEATS 를 펼친
## 상태에서 아래쪽 버튼이 화면 밖으로 나가 손댈 수 없던 문제를 막는다.
func _fit_pause_scroll() -> void:
	if _pause_scroll == null or _pause_vb == null:
		return
	var want := _pause_vb.get_combined_minimum_size().y
	# 패널 여백(마진 26x2 + 프레임 콘텐츠 18x2)과 화면 위아래 숨통을 뺀 값이 실제 여유.
	var room := get_viewport().get_visible_rect().size.y - 88.0 - 80.0
	_pause_scroll.custom_minimum_size.y = minf(want, maxf(room, 200.0))


## 성능 디버그 오버레이(좌상단). 기본은 숨김이며 CHEATS > PERF HUD 로 켠다.
## 씬을 다시 들어와도 Cheats 의 토글 상태를 그대로 따른다.
func _build_perf_overlay() -> void:
	_perf_overlay = _PerfOverlay.new()
	add_child(_perf_overlay)
	_perf_overlay.visible = Cheats.perf_overlay


func _make_cheat_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 17)
	_UIStyle.apply_button_style(b, Color(0.14, 0.15, 0.22), Color(0.55, 0.45, 0.7))
	b.pressed.connect(on_pressed)
	_cheat_box.add_child(b)
	return b


func _on_cheat_autoplay() -> void:
	Cheats.toggle_autoplay()


func _refresh_cheat_ui() -> void:
	if _cheat_auto_btn:
		_cheat_auto_btn.text = "AUTO-PLAY: ON" if Cheats.autoplay_active() else "AUTO-PLAY: OFF"
	if _auto_tag:
		_auto_tag.visible = Cheats.autoplay_active()
	if _cheat_perf_btn:
		_cheat_perf_btn.text = "PERF HUD: ON" if Cheats.perf_overlay else "PERF HUD: OFF"
	if _perf_overlay:
		_perf_overlay.visible = Cheats.perf_overlay
	if _cheat_day_btn:
		_cheat_day_btn.text = "DAY/NIGHT: ON" if Cheats.daynight else "DAY/NIGHT: OFF"
	if _cheat_weather_btn:
		_cheat_weather_btn.text = "WEATHER: ON" if Cheats.weather else "WEATHER: OFF"


func _on_pause_pressed() -> void:
	if get_tree().paused:   # 레벨업/보물상자 등 다른 정지 중이면 무시
		return
	if _pause_time:
		var m := int(Events.elapsed_time) / 60
		var s := int(Events.elapsed_time) % 60
		_pause_time.text = Locale.t("pause_time_fmt") % ("%02d:%02d" % [m, s])
	_pause_dim.visible = true
	_pause_panel.visible = true
	Events.pause_push(_pause_panel, "pausemenu")
	call_deferred("_fit_pause_scroll")   # 열 때마다 현재 화면 크기에 맞춰 재계산
	if _pause_btn:
		_pause_btn.visible = false


func _on_resume_pressed() -> void:
	_pause_dim.visible = false
	_pause_panel.visible = false
	if _pause_btn:
		_pause_btn.visible = true
	Events.pause_pop(_pause_panel)


## 노치/펀치홀 세이프에어리어 — 상단 인셋만큼 상단 고정 위젯들을 아래로 내린다.
## 데스크톱/웹은 인셋 0 이라 무동작. canvas_items 스트레치(keep)라 창→캔버스 스케일로 환산한다.
func _apply_safe_area() -> void:
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return
	var inset_px := float(DisplayServer.get_display_safe_area().position.y)
	if inset_px <= 0.0:
		return
	var inset := inset_px * get_viewport().get_visible_rect().size.y / float(win.y)
	top_bg.offset_bottom += inset   # 바 배경은 노치 뒤까지 채우고, 내용만 아래로 민다
	# 뱃지 모드에선 라벨이 뱃지의 풀렉트 자식이라 뱃지 쪽을 옮긴다.
	var lv_node: Control = _level_badge if _level_badge else _level_label
	for c in [get_node("CoinIcon"), gold_label, hp_bar, kills_label, time_label,
			lv_node, _xp_bg, _pause_btn, _auto_tag, boss_bar, weapon_label, buff_label] + _stat_icons:
		if c is Control:
			c.offset_top += inset
			c.offset_bottom += inset


func _on_main_menu_pressed() -> void:
	Events.pause_release_all()   # 씬 전환 전 정지 소유권 전부 해제
	MetaManager.bank(Events.total_gold)   # 이번 판 골드를 영구 은행에 적립
	Events.reset()
	Pool.clear()
	SceneFade.transition_to("res://scenes/MainMenu.tscn")
