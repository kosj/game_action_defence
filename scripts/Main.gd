extends Node2D
## 메인: 골드 초기화 + 풀 프리워밍(첫 웨이브 끊김 방지).

const ZOMBIE := preload("res://scenes/Zombie.tscn")
const BULLET := preload("res://scenes/Bullet.tscn")
const GOLD := preload("res://scenes/Gold.tscn")
const WEAPON_PICKUP := preload("res://scenes/WeaponPickup.tscn")


func _ready() -> void:
	Events.reset()
	# 첫 프레임을 먼저 렌더한 뒤 풀을 채워 WebGL 초기 프리즈 방지
	call_deferred("_do_prewarm")


func _do_prewarm() -> void:
	Pool.prewarm(ZOMBIE, 15)
	Pool.prewarm(BULLET, 20)
	Pool.prewarm(GOLD, 15)
	Pool.prewarm(WEAPON_PICKUP, 3)
