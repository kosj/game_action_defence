extends Node2D
## 식인 파리떼: 시체에서 피어오른 검은 파리 구름. 플레이어를 느리게 추적하며 범위 안의
## 플레이어·좀비를 물어뜯어 지속 피해를 준다. 플레이어보다 느려 벗어날 수 있다(공정).
## 이동을 강요하는 압박형 위험 — 한자리에 머물면 계속 갉아먹힌다.

const SPEED := 82.0
const BITE_R := 40.0
const TICK := 0.42
const PLAYER_DMG := 1
const ZOMBIE_DMG := 3
const LIFE := 9.0
const FLIES := 16          # 파리 개체 수(밀도 있는 구름감)

var _player: Node2D = null
var _age: float = 0.0
var _life: float = LIFE
var _t: float = 0.0
var _seed: float = 0.0


func _ready() -> void:
	z_index = 1   # 유닛 위를 떠다니는 벌레 구름
	_player = get_tree().get_first_node_in_group("player")
	_seed = randf() * 100.0


func _physics_process(delta: float) -> void:
	_age += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if is_instance_valid(_player):
		var to: Vector2 = _player.global_position - global_position
		if to.length() > 1.0:
			global_position += to.normalized() * SPEED * delta
	_t += delta
	if _t >= TICK:
		_t = 0.0
		var r_sq := BITE_R * BITE_R
		for z in Events.live_zombies():
			if is_instance_valid(z) and z.is_in_group("zombies") \
					and global_position.distance_squared_to(z.global_position) < r_sq:
				z.take_damage(ZOMBIE_DMG)
		if is_instance_valid(_player) and _player.global_position.distance_squared_to(global_position) < r_sq \
				and _player.has_method("take_hit"):
			_player.take_hit(PLAYER_DMG)
	queue_redraw()


func _draw() -> void:
	var fade := clampf(_life / 1.0, 0.0, 1.0)
	# 부패한 기운의 탁한 아우라(옅게) — 범위를 읽을 수 있게.
	draw_circle(Vector2.ZERO, BITE_R, Color(0.18, 0.20, 0.10, 0.13 * fade))
	draw_arc(Vector2.ZERO, BITE_R, 0.0, TAU, 28, Color(0.35, 0.38, 0.20, 0.28 * fade), 1.5, true)
	# 파리들 — 각자 다른 주기로 불규칙하게 흩어졌다 모이며 윙윙댄다(벌보다 빠르고 산만한 궤적).
	for i in FLIES:
		var fi := float(i)
		var a := _age * (5.0 + fmod(fi * 1.7 + _seed, 3.0)) + TAU * fi / float(FLIES)
		var wob := sin(_age * 9.0 + fi * 2.3) * 0.35
		var rr := BITE_R * (0.20 + 0.62 * absf(sin(_age * 2.4 + fi * 1.31 + _seed)))
		var p := Vector2.from_angle(a + wob) * rr
		p += Vector2(sin(_age * 17.0 + fi), cos(_age * 15.0 + fi * 1.7)) * 2.2   # 미세 진동(윙윙)
		draw_circle(p, 2.2, Color(0.06, 0.06, 0.05, fade))                       # 검은 몸통
		draw_circle(p + Vector2(0.8, -0.8), 1.0, Color(0.45, 0.50, 0.30, 0.75 * fade))   # 탁한 날개 반짝
