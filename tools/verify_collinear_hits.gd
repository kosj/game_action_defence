extends SceneTree
## 동일 선상 총알 판정 회귀 검사.
##
## 공간 해시 후보는 거리순이 아니다. 한 틱에 여러 적과 교차할 때 뒤쪽 적이 먼저 반환되면
## 관통 수를 먼저 소비해 앞쪽 적이 멀쩡히 남았다. 도착점 주변만 조회하던 경로는 큰 delta 에서
## 선분 앞부분의 적을 아예 후보에 넣지 않았다. 역순으로 등록한 세 표적을 긴 선분으로 관통시켜
## 실제 이동 순서대로 맞는지 잠근다.

class HitTarget extends Node2D:
	var hits := 0

	func take_damage(_amount: int, _crit: bool = false) -> void:
		hits += 1

	func apply_knockback(_direction: Vector2, _strength: float) -> void:
		pass


var _host: Node2D
var _targets: Array[HitTarget] = []
var _fail := 0
var _started := false


func _initialize() -> void:
	_host = Node2D.new()
	root.add_child(_host)
	current_scene = _host
	# 트리/그룹 등록 순서를 일부러 거리 역순으로 만든다. 옛 코드는 이 순서를 따라 뒤부터 맞혔다.
	for x in [220.0, 40.0, 120.0]:
		var t := HitTarget.new()
		t.position = Vector2(x, 0.0)
		_host.add_child(t)
		t.add_to_group("zombies")
		_targets.append(t)


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	await physics_frame
	# pierce=1 은 두 마리를 맞힌다. 등록순이 아니라 경로순(40 → 120)이어야 한다.
	_fire(1)
	_check("관통탄이 앞쪽 두 마리를 경로순으로 타격", _targets[1].hits == 1 and _targets[2].hits == 1,
		"near=%d mid=%d" % [_targets[1].hits, _targets[2].hits])
	_check("관통 수를 다 쓰면 뒤쪽 적은 남김", _targets[0].hits == 0,
		"far=%d" % _targets[0].hits)

	for t in _targets:
		t.hits = 0
	await physics_frame
	# 비관통탄도 후보 배열의 첫 항목이 아니라 실제로 가장 가까운 적을 맞혀야 한다.
	_fire(0)
	_check("비관통탄이 가장 가까운 적을 타격", _targets[1].hits == 1,
		"near=%d" % _targets[1].hits)
	_check("비관통탄이 뒤쪽 적을 건너뛰지 않음", _targets[0].hits == 0 and _targets[2].hits == 0,
		"mid=%d far=%d" % [_targets[2].hits, _targets[0].hits])

	if _fail == 0:
		print("동일 선상 총알 판정 OK")
		quit(0)
	else:
		print("동일 선상 총알 판정 실패 %d건" % _fail)
		quit(1)


func _fire(pierce: int) -> void:
	var b = (load("res://scenes/Bullet.tscn") as PackedScene).instantiate()
	_host.add_child(b)
	b.on_spawn()
	b.global_position = Vector2.ZERO
	b.direction = Vector2.RIGHT
	b.damage = 1
	b.pierce = pierce
	b.splash_radius = 0.0
	b._hit_r = 5.0
	b._check_swept_hit(Vector2.ZERO, Vector2(260.0, 0.0))


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fail += 1
		print("  FAIL %s%s" % [label, (" — " + detail) if detail != "" else ""])
