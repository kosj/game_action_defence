extends CanvasLayer
## HUD: 골드 수치를 Events 시그널로 받아 실시간 갱신.

@onready var gold_label: Label = $GoldLabel


func _ready() -> void:
	Events.gold_changed.connect(_on_gold_changed)
	_on_gold_changed(Events.total_gold)


func _on_gold_changed(total: int) -> void:
	gold_label.text = "Gold: %d" % total
