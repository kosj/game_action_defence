extends CanvasLayer
## HUD: 골드·체력·웨이브·경과시간을 Events 시그널로 받아 실시간 갱신. 게임오버 패널 제어.

@onready var gold_label: Label = $GoldLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var wave_label: Label = $WaveLabel
@onready var time_label: Label = $TimeLabel
@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var game_over_panel: ColorRect = $GameOverPanel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton

var _prev_health: int = -1


func _ready() -> void:
	Events.gold_changed.connect(_on_gold_changed)
	Events.player_health_changed.connect(_on_player_health_changed)
	Events.player_died.connect(_on_player_died)
	Events.wave_changed.connect(_on_wave_changed)
	Events.elapsed_changed.connect(_on_elapsed_changed)
	restart_button.pressed.connect(_on_restart_pressed)
	_on_gold_changed(Events.total_gold)
	if Events.player_max_health > 0:
		_on_player_health_changed(Events.player_health, Events.player_max_health)
	_on_wave_changed(Events.current_wave)
	_on_elapsed_changed(Events.elapsed_time)


func _on_gold_changed(total: int) -> void:
	gold_label.text = "Gold: %d" % total


func _on_player_health_changed(health: int, max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = health
	if _prev_health > 0 and health < _prev_health and health > 0:
		_flash_hurt()
	_prev_health = health


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


func _on_player_died() -> void:
	game_over_panel.visible = true


func _on_restart_pressed() -> void:
	Events.reset()
	Pool.clear()
	get_tree().reload_current_scene()
