extends Node2D
## 메인: 풀 프리워밍(첫 웨이브 끊김 방지).
## Events 의 새 게임/이어하기 상태는 MainMenu 에서 씬 전환 전에 이미 준비된다.

const ZOMBIE := preload("res://scenes/Zombie.tscn")
const BULLET := preload("res://scenes/Bullet.tscn")
const ENEMY_BULLET := preload("res://scenes/EnemyBullet.tscn")
const GOLD := preload("res://scenes/Gold.tscn")
const WEAPON_PICKUP := preload("res://scenes/WeaponPickup.tscn")
const ITEM_PICKUP := preload("res://scenes/ItemPickup.tscn")


func _ready() -> void:
	get_tree().paused = false   # 게임 씬 진입 시 정지 상태가 남아있지 않도록 보장
	# 첫 프레임을 먼저 렌더한 뒤 풀을 채워 WebGL 초기 프리즈 방지
	call_deferred("_do_prewarm")


func _do_prewarm() -> void:
	Pool.prewarm(ZOMBIE, 60)
	Pool.prewarm(BULLET, 50)
	Pool.prewarm(ENEMY_BULLET, 10)
	Pool.prewarm(GOLD, 60)
	Pool.prewarm(WEAPON_PICKUP, 3)
	Pool.prewarm(ITEM_PICKUP, 2)
