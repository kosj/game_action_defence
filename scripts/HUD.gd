extends CanvasLayer
## HUD: 골드·체력 수치를 Events 시그널로 받아 실시간 갱신. 게임오버 패널 제어.

@onready var gold_label: Label = $GoldLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var game_over_panel: ColorRect = $GameOverPanel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton


func _ready() -> void:
	Events.gold_changed.connect(_on_gold_changed)
	Events.player_health_changed.connect(_on_player_health_changed)
	Events.player_died.connect(_on_player_died)
	restart_button.pressed.connect(_on_restart_pressed)
	_on_gold_changed(Events.total_gold)
	if Events.player_max_health > 0:
		_on_player_health_changed(Events.player_health, Events.player_max_health)


func _on_gold_changed(total: int) -> void:
	gold_label.text = "Gold: %d" % total


func _on_player_health_changed(health: int, max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = health


func _on_player_died() -> void:
	game_over_panel.visible = true


func _on_restart_pressed() -> void:
	Events.reset()
	Pool.clear()
	get_tree().reload_current_scene()
