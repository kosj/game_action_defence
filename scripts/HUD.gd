extends CanvasLayer
## HUD: 골드·체력·웨이브·경과시간을 Events 시그널로 받아 실시간 갱신. 게임오버 패널 제어.

const HEART_FULL := preload("res://assets/ui/ui_heart_full.png")
const HEART_EMPTY := preload("res://assets/ui/ui_heart_empty.png")
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
@onready var wave_clear_bg: Panel = $WaveClearBg
@onready var wave_clear_label: Label = $WaveClearLabel
@onready var game_over_panel: Panel = $GameOverPanel
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


func _ready() -> void:
	top_bg.add_theme_stylebox_override("panel", _UIStyle.bottom_bar(Color(0.05, 0.06, 0.09, 0.62)))
	wave_clear_bg.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.08, 0.30, 0.14, 0.92), Color(1.0, 0.85, 0.2), 26, 3))
	game_over_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.08, 0.05, 0.06, 0.96), Color(0.85, 0.25, 0.22), 22, 3))
	_UIStyle.apply_button_style(restart_button, Color(0.55, 0.16, 0.16), Color(0.95, 0.35, 0.3))
	_UIStyle.apply_button_style(main_menu_button, Color(0.18, 0.20, 0.26), Color(0.5, 0.55, 0.65))
	restart_button.text = Locale.t("go_retry")
	main_menu_button.text = Locale.t("go_menu")
	_build_revive_button()
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
	for child in heart_row.get_children():
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


## 체력이 1일 때 화면 가장자리를 붉게 점멸시켜 위험을 경고.
func _update_low_hp_warning(health: int) -> void:
	var should_pulse := health == 1
	if should_pulse and _low_hp_tween == null:
		low_hp_overlay.color.a = 0.0
		_low_hp_tween = create_tween()
		_low_hp_tween.set_loops()
		_low_hp_tween.tween_property(low_hp_overlay, "color:a", 0.30, 0.5)
		_low_hp_tween.tween_property(low_hp_overlay, "color:a", 0.0, 0.5)
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
	# 부활 시 사라진 게임오버 패널을 닫고 그대로 진행 재개.
	game_over_panel.visible = false
	player.revive()


func _on_player_died() -> void:
	SaveManager.delete_save()   # 사망 시 진행 실패 — 체크포인트 무효화
	# 부활 버튼은 아직 안 썼고 광고가 준비됐을 때만 노출.
	_revive_btn.visible = not _revive_used and AdManager.is_rewarded_ready()
	boss_bar.visible = false
	var m := int(Events.elapsed_time) / 60
	var s := int(Events.elapsed_time) % 60
	var best_text := (Locale.t("go_new_best_fmt") % Events.high_score) if Events.is_new_record() \
		else (Locale.t("go_best_fmt") % Events.high_score)
	stats_label.text = "%s\n%s\n%s\n%02d:%02d" % [
		Locale.t("go_score_fmt") % Events.score,
		best_text,
		Locale.t("go_wave_kills_fmt") % [Events.current_wave, Events.total_kills],
		m, s]

	game_over_panel.visible = true
	game_over_panel.modulate.a = 0.0
	game_over_panel.scale = Vector2(0.8, 0.8)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(game_over_panel, "modulate:a", 1.0, 0.3)
	tw.tween_property(game_over_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_restart_pressed() -> void:
	SaveManager.save_high_score()
	Events.reset()
	Pool.clear()
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	SaveManager.save_high_score()
	Events.reset()
	Pool.clear()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
