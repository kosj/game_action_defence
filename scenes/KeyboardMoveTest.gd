extends Node
## 키보드 이동 회귀 테스트 (P2-28).
##
## 실행:
##   godot --headless --path . res://scenes/KeyboardMoveTest.tscn
##
## 배경: 이동 입력이 화면 조이스틱(터치/마우스) 하나뿐이라 데스크톱·웹 브라우저에서는
## 키보드로 움직일 수 없었다. 이제 WASD·방향키를 함께 받는다.
##
## 검사 항목
##   T1 이동 액션 4종이 InputMap 에 등록돼 있다
##   T2 각 액션에 WASD 와 방향키가 둘 다 바인딩돼 있다
##   T3 키를 누르면 그 방향으로 이동한다(4방향)
##   T4 대각 이동이 정규화된다 — 대각으로 더 빨라지지 않는다
##   T5 키를 떼면 멈춘다
##   T6 키보드 입력이 없으면 화면 조이스틱이 그대로 동작한다(회귀 방지)
##   T7 자동플레이 중에는 키보드가 개입하지 않는다(치트 우선순위 유지)

const MAIN := preload("res://scenes/Main.tscn")

## 액션 -> [WASD 물리 키코드, 방향키 물리 키코드]
const BINDINGS := {
	"move_left":  [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up":    [KEY_W, KEY_UP],
	"move_down":  [KEY_S, KEY_DOWN],
}

var _ok: int = 0
var _total: int = 0
var _pl: Node2D = null


func _ready() -> void:
	add_child(MAIN.instantiate())
	_run()


func _check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		_ok += 1
	print("%s %s" % ["PASS" if cond else "FAIL", name])


func _release_all() -> void:
	for a in BINDINGS:
		Input.action_release(a)


## 지정 액션들을 누른 채 frames 물리 프레임을 돌리고, 그동안의 이동 벡터를 돌려준다.
func _move_with(actions: Array, frames: int) -> Vector2:
	_release_all()
	for a in actions:
		Input.action_press(a)
	await get_tree().physics_frame          # 누른 상태가 반영된 첫 프레임은 버린다
	var from: Vector2 = _pl.global_position
	for i in frames:
		await get_tree().physics_frame
	var moved: Vector2 = _pl.global_position - from
	_release_all()
	await get_tree().physics_frame
	return moved


func _run() -> void:
	Events.reset()
	await get_tree().process_frame
	await get_tree().process_frame
	_pl = get_tree().get_first_node_in_group("player")
	var sp: Node = get_tree().current_scene.get_node_or_null("ZombieSpawner")
	if sp != null:
		sp.set_process(false)
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()
	if Cheats.autoplay_active():
		Cheats.toggle_autoplay()            # 게이트를 존중하는 경로로만 끈다
	await get_tree().physics_frame

	# --- T1/T2: 입력 맵 ---
	var missing := PackedStringArray()
	var half_bound := PackedStringArray()
	for a in BINDINGS:
		if not InputMap.has_action(a):
			missing.append(a)
			continue
		var codes := {}
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				codes[(ev as InputEventKey).physical_keycode] = true
		for want in BINDINGS[a]:
			if not codes.has(want):
				half_bound.append("%s:%s" % [a, OS.get_keycode_string(want)])
	_check("T1 이동 액션 4종이 등록돼 있다 (%s)"
		% ("없음: " + ", ".join(missing) if missing.size() > 0 else "전부 있음"), missing.is_empty())
	_check("T2 WASD·방향키가 둘 다 바인딩돼 있다 (%s)"
		% ("누락: " + ", ".join(half_bound) if half_bound.size() > 0 else "전부 있음"),
		half_bound.is_empty())
	if not missing.is_empty():
		print("RESULT ok=%d/%d" % [_ok, _total])
		get_tree().quit(1)
		return

	# --- T3: 네 방향 ---
	var right: Vector2 = await _move_with(["move_right"], 20)
	var left: Vector2 = await _move_with(["move_left"], 20)
	var up: Vector2 = await _move_with(["move_up"], 20)
	var down: Vector2 = await _move_with(["move_down"], 20)
	print("  오른쪽=%s 왼쪽=%s 위=%s 아래=%s" % [str(right.round()), str(left.round()),
		str(up.round()), str(down.round())])
	_check("T3 키를 누르면 그 방향으로 이동한다",
		right.x > 20.0 and left.x < -20.0 and up.y < -20.0 and down.y > 20.0)

	# --- T4: 대각선 정규화 — 같은 프레임 수에서 이동 거리가 같아야 한다 ---
	var diag: Vector2 = await _move_with(["move_right", "move_up"], 20)
	var ratio := diag.length() / maxf(right.length(), 0.001)
	print("  수평 %.1f / 대각 %.1f (비 %.3f)" % [right.length(), diag.length(), ratio])
	_check("T4 대각 이동이 정규화된다(비 1.0±0.05)", absf(ratio - 1.0) < 0.05)

	# --- T5: 떼면 멈춘다 ---
	_release_all()
	await get_tree().physics_frame
	var idle_from: Vector2 = _pl.global_position
	for i in 15:
		await get_tree().physics_frame
	var idle: float = _pl.global_position.distance_to(idle_from)
	print("  키를 뗀 뒤 15프레임 이동 = %.2f" % idle)
	_check("T5 키를 떼면 멈춘다", idle < 1.0)

	# --- T6: 조이스틱은 그대로 동작한다 ---
	var joy: Node = get_tree().get_first_node_in_group("joystick")
	if joy == null:
		_check("T6 조이스틱이 그대로 동작한다 (조이스틱 미발견)", false)
	else:
		_release_all()
		joy._value = Vector2(0.0, 1.0)      # 아래로 최대 입력
		var jfrom: Vector2 = _pl.global_position
		for i in 20:
			await get_tree().physics_frame
		var jmoved: Vector2 = _pl.global_position - jfrom
		joy._value = Vector2.ZERO
		print("  조이스틱만: %s" % str(jmoved.round()))
		_check("T6 키보드 입력이 없으면 조이스틱이 그대로 동작한다", jmoved.y > 20.0)

	# --- T7: 자동플레이가 키보드보다 우선한다 ---
	if not Cheats.enabled:
		_check("T7 자동플레이 우선 (잠긴 빌드라 건너뜀)", true)
	else:
		Cheats.toggle_autoplay()
		_check("사전조건: 자동플레이가 켜졌다", Cheats.autoplay_active())
		# 왼쪽 키를 누른 채로 둔다 — 조종 AI 가 이동을 소유하므로 키 방향과 무관해야 한다.
		var auto_moved: Vector2 = await _move_with(["move_left"], 30)
		print("  자동플레이 중 왼쪽 키: %s" % str(auto_moved.round()))
		_check("T7 자동플레이 중에는 키보드가 조종을 빼앗지 않는다", auto_moved.x >= -1.0)
		Cheats.toggle_autoplay()

	_release_all()
	print("RESULT ok=%d/%d" % [_ok, _total])
	await get_tree().process_frame
	get_tree().quit(0 if _ok == _total else 1)
