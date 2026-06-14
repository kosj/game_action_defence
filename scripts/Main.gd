extends Node2D
## 메인: 골드 초기화 + 풀 프리워밍(첫 웨이브 끊김 방지).

const ZOMBIE := preload("res://scenes/Zombie.tscn")
const BULLET := preload("res://scenes/Bullet.tscn")
const GOLD := preload("res://scenes/Gold.tscn")


func _ready() -> void:
	Events.reset()
	# 자주 쓰는 오브젝트를 미리 풀에 채워둔다
	Pool.prewarm(ZOMBIE, 60)
	Pool.prewarm(BULLET, 40)
	Pool.prewarm(GOLD, 40)
