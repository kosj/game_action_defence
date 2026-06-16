extends CanvasLayer
## HUD: 골드·체력·웨이브·경과시간을 Events 시그널로 받아 실시간 갱신. 게임오버 패널 제어.

const HEART_FULL := preload("res://assets/ui/ui_heart_full.png")
const HEART_EMPTY := preload("res://assets/ui/ui_heart_empty.png")
const _UIStyle := preload("res://scripts/UIStyle.gd")

@onready var top_bg: Panel = $TopBg
@onready var gold_label: Label = $GoldLabel
@onready var heart_row: HBoxContainer = $HeartRow
@onready var weapon_label: Label = $WeaponLabel
@onready var wave_label: Label = $WaveLabel
@onready var time_label: Label = $TimeLabel
@onready var progress_label: Label = $ProgressLabel
@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var low_hp_overlay: ColorRect = $LowHpOverlay
@onready var wave_clear_bg: Panel = $WaveClearBg
@onready var wave_clear_label: Label = $WaveClearLabel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var stats_label: Label = $GameOverPanel/Margin/VBoxContainer/StatsLabel
@onready var restart_button: Button = $GameOverPanel/Margin/VBoxContainer/RestartButton

var _prev_health: int = -1
var _prev_gold: int = -1
var _max_health: int = 0
var _low_hp_tween: Tween = null


func _ready() -> void:
	top_bg.add_theme_stylebox_override("panel", _UIStyle.bottom_bar(Color(0.05, 0.06, 0.09, 0.62)))
	wave_clear_bg.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.08, 0.30, 0.14, 0.92), Color(1.0, 0.85, 0.2), 26, 3))
	game_over_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.08, 0.05, 0.06, 0.96), Color(0.85, 0.25, 0.22), 22, 3))
	_UIStyle.apply_button_style(restart_button, Color(0.55, 0.16, 0.16), Color(0.95, 0.35, 0.3))
	call_deferred("_init_pivots")

	Events.gold_changed.connect(_on_gold_changed)
	Events.player_health_changed.connect(_on_player_health_changed)
	Events.player_died.connect(_on_player_died)
	Events.wave_changed.connect(_on_wave_changed)
	Events.elapsed_changed.connect(_on_elapsed_changed)
	Events.wave_progress_changed.connect(_on_wave_progress_changed)
	Events.wave_complete.connect(_on_wave_complete)
	Events.weapon_equipped.connect(_on_weapon_equipped)
	restart_button.pressed.connect(_on_restart_pressed)
	_on_gold_changed(Events.total_gold)
	if Events.player_max_health > 0:
		_on_player_health_changed(Events.player_health, Events.player_max_health)
	_on_wave_changed(Events.current_wave)
	_on_elapsed_changed(Events.elapsed_time)
	_on_wave_progress_changed(Events.wave_kill_progress, Events.wave_kill_total)


## 둥근 패널/라벨이 자신의 중심을 기준으로 스케일되도록 pivot 보정 (레이아웃 확정 후 1회).
func _init_pivots() -> void:
	gold_label.pivot_offset = gold_label.size * 0.5
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
		tr.custom_minimum_size = Vector2(44, 44)
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


## 무기 픽업 획득 시 이름/등급을 표시하고 등급 색으로 강조 펄스.
func _on_weapon_equipped(stats: Dictionary) -> void:
	var tier_id: String = stats.get("tier_id", "common")
	if tier_id == "common":
		weapon_label.text = stats.get("name", "")
	else:
		weapon_label.text = "%s %s" % [stats.get("tier_name", ""), stats.get("name", "")]
	weapon_label.add_theme_color_override("font_color", stats.get("tier_color", Color.WHITE))
	weapon_label.scale = Vector2(1.4, 1.4)
	var tw := create_tween()
	tw.tween_property(weapon_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_wave_changed(wave: int) -> void:
	wave_label.text = "Wave %d" % wave


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
	wave_clear_label.text = "Wave %d Clear!" % wave
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


func _on_player_died() -> void:
	var m := int(Events.elapsed_time) / 60
	var s := int(Events.elapsed_time) % 60
	stats_label.text = "Reached Wave %d   Time %02d:%02d" % [Events.current_wave, m, s]

	game_over_panel.visible = true
	game_over_panel.modulate.a = 0.0
	game_over_panel.scale = Vector2(0.8, 0.8)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(game_over_panel, "modulate:a", 1.0, 0.3)
	tw.tween_property(game_over_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_restart_pressed() -> void:
	Events.reset()
	Pool.clear()
	get_tree().reload_current_scene()
