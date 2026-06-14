extends Node
## 전역 이벤트 버스 / 재화 관리 (Autoload 싱글톤: "Events")
## UI와 게임 로직을 직접 연결하지 않고 시그널로 느슨하게 묶는다.

signal gold_changed(total: int)

var total_gold: int = 0


func add_gold(amount: int = 1) -> void:
	total_gold += amount
	gold_changed.emit(total_gold)


func reset() -> void:
	total_gold = 0
	gold_changed.emit(total_gold)
