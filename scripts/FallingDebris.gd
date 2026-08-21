extends Node2D
## 도심 기믹: 낙석. 예고 표식(그림자)이 커진 뒤 착탄해 범위 내 좀비와 플레이어 모두에게 피해.
## 회피 요소 — 예고를 보고 피하면 안전. 착탄 지점은 플레이어 주변에 잡힌다.

const _FXBurst := preload("res://scripts/FXBurst.gd")

const TELEGRAPH := 1.1     # 예고 시간(초)
const IMPACT_R := 74.0
const ZOMBIE_DMG := 22
const PLAYER_DMG := 1

var _player: Node2D = null
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	z_index = -1
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t >= TELEGRAPH:
		_impact()
		return
	queue_redraw()


func _impact() -> void:
	_done = true
	var r_sq := IMPACT_R * IMPACT_R
	for z in Events.live_zombies():
		if is_instance_valid(z) and z.is_in_group("zombies") \
				and global_position.distance_squared_to(z.global_position) < r_sq:
			z.take_damage(ZOMBIE_DMG)
	if is_instance_valid(_player) and _player.global_position.distance_to(global_position) < IMPACT_R \
			and _player.has_method("take_hit"):
		_player.take_hit(PLAYER_DMG)
	_FXBurst.spawn(get_tree().current_scene, global_position, Color(0.55, 0.55, 0.60), IMPACT_R, 0.35)
	Events.shake(7.0)
	SoundManager.play("boom", 0.05, 1.0)
	queue_free()


func _draw() -> void:
	var p := clampf(_t / TELEGRAPH, 0.0, 1.0)
	# 착탄 예고 원(점점 진해지고 안쪽이 차오른다).
	QuadDraw.ring(self, Vector2.ZERO, IMPACT_R, Color(0.9, 0.3, 0.2, 0.35 + 0.5 * p), 2.5, 32)
	QuadDraw.disc(self, Vector2.ZERO, IMPACT_R * p, Color(0.8, 0.25, 0.15, 0.18))
	# 떨어지는 돌(위에서 내려온다).
	var fall_y := -260.0 * (1.0 - p)
	var rock := Vector2(0.0, fall_y)
	QuadDraw.disc(self, rock, 13.0, Color(0.32, 0.30, 0.33, 1.0))
	QuadDraw.disc(self, rock + Vector2(-4, -4), 5.0, Color(0.45, 0.43, 0.47, 1.0))
