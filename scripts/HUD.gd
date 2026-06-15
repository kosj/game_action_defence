extends CanvasLayer
## HUD: 골드·체력·웨이브·경과시간을 Events 시그널로 받아 실시간 갱신. 게임오버 패널 제어.

const HEART_FULL := preload("res://assets/ui/ui_heart_full.png")
const HEART_EMPTY := preload("res://assets/ui/ui_heart_empty.png")
const KR_FONT := preload("res://assets/fonts/NotoSansKR-Regular.ttf")

@onready var gold_label: Label = $GoldLabel
@onready var heart_row: HBoxContainer = $HeartRow
@onready var wave_label: Label = $WaveLabel
@onready var time_label: Label = $TimeLabel
@onready var progress_label: Label = $ProgressLabel
@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var wave_clear_label: Label = $WaveClearLabel
@onready var game_over_panel: ColorRect = $GameOverPanel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton

var _prev_health: int = -1
var _max_health: int = 0


func _ready() -> void:
	_apply_font()
	Events.gold_changed.connect(_on_gold_changed)
	Events.player_health_changed.connect(_on_player_health_changed)
	Events.player_died.connect(_on_player_died)
	Events.wave_changed.connect(_on_wave_changed)
	Events.elapsed_changed.connect(_on_elapsed_changed)
	Events.wave_progress_changed.connect(_on_wave_progress_changed)
	Events.wave_complete.connect(_on_wave_complete)
	restart_button.pressed.connect(_on_restart_pressed)
	_on_gold_changed(Events.total_gold)
	if Events.player_max_health > 0:
		_on_player_health_changed(Events.player_health, Events.player_max_health)
	_on_wave_changed(Events.current_wave)
	_on_elapsed_changed(Events.elapsed_time)
	_on_wave_progress_changed(Events.wave_kill_progress, Events.wave_kill_total)


func _apply_font() -> void:
	var nodes: Array = [
		gold_label, wave_label, time_label, progress_label, wave_clear_label,
		$GameOverPanel/VBoxContainer/GameOverLabel,
		restart_button,
	]
	for n in nodes:
		n.add_theme_font_override("font", KR_FONT)


func _on_gold_changed(total: int) -> void:
	gold_label.text = "%d" % total


func _on_player_health_changed(health: int, max_health: int) -> void:
	if max_health != _max_health:
		_max_health = max_health
		_rebuild_hearts(max_health)
	_update_hearts(health)
	if _prev_health > 0 and health < _prev_health and health > 0:
		_flash_hurt()
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
	wave_clear_label.text = "Wave %d 클리어!" % wave
	wave_clear_label.modulate.a = 1.0
	wave_clear_label.visible = true
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(wave_clear_label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): wave_clear_label.visible = false)


func _on_player_died() -> void:
	game_over_panel.visible = true


func _on_restart_pressed() -> void:
	Events.reset()
	Pool.clear()
	get_tree().reload_current_scene()
