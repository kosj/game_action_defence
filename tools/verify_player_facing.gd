extends SceneTree
## 플레이어 4방향 그림 전환 회귀 검사 (P1-33).
##
## 무엇을 지키는가
## --------------
## 1. **아트가 없으면 예전과 똑같이 돈다.** 상/하 그림(run_<id>_up 등)이 저장소에 없는 동안은
##    위/아래로 움직여도 방향이 `side` 로 남고 `_facing`(마지막 좌/우)이 보존되어야 한다.
##    이게 깨지면 아트가 들어오기 전에 화면이 먼저 이상해진다 — 이 검사의 핵심이다.
## 2. **아트가 들어오면 그때 살아난다.** 방향 텍스처가 있으면 위/아래로 움직일 때 그쪽으로
##    바뀌고, 조준(`aim_vector`)도 같이 따라간다. 그림은 위를 보는데 총알이 옆으로 나가면
##    4방향을 넣은 의미가 없다.
## 3. **대각선에서 방향이 떨리지 않는다.** 45° 부근에서 매 프레임 방향이 뒤집히면 그림이
##    깜빡인다. 지금 축에 관성(`_DIR_KEEP`)을 줘서 막고 있고, 그 관성이 실제로 도는지 본다.
##
## ⚠️ 최상위 `preload` 를 쓰면 안 된다 — 이 스크립트는 **오토로드 등록 전에** 컴파일되므로
## Player.gd 안의 `Events`/`CharacterManager` 참조가 미해결로 죽는다(`CLAUDE.md` §3 의 함정).
## 씬은 실행 시점에 `load()` 로 늦게 가져온다.
##
## 실행:
##   godot --headless --path . --script res://tools/verify_player_facing.gd
##
## 종료 코드 0 = 통과.

var _fail := 0
var _player: Node = null
var _started := false


func _initialize() -> void:
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host

	var scene: PackedScene = load("res://scenes/Player.tscn")
	if scene == null:
		_err("Player.tscn 을 열 수 없다")
		_finish()
		return
	_player = scene.instantiate()
	host.add_child(_player)
	# 물리 처리를 끈다 — 이 검사는 방향 판정만 격리해 본다. 켜 두면 조이스틱 입력이 없어
	# velocity 가 매 프레임 0 으로 덮여, 아래에서 넣는 시험용 속도가 살아남지 못한다.
	_player.set_physics_process(false)


## ⚠️ 검사를 `_initialize()` 에서 돌리면 안 된다 — 그 시점에는 `_ready()` 가 아직 불리지
## 않아 `@onready var body` 가 null 이고, `body` 를 만지는 단언이 **조용히 건너뛰어진다**
## (GDScript 는 그 에러로 스크립트를 멈추지 않아 검사가 초록으로 끝난다). 첫 프레임까지
## 기다린 뒤에 돌리고, 그 전에 `body` 가 실제로 잡혔는지부터 확인한다.
func _process(_d: float) -> bool:
	if _started:
		return false
	_started = true
	if _player == null or _player.body == null:
		_err("Player 가 준비되지 않았다(_ready 미실행 — body 가 null)")
		_finish()
		return false
	_test_fallback_without_art()
	_test_with_art()
	_test_hysteresis()
	_test_min_speed()
	_finish()
	return false


## 1. 상/하 그림이 없을 때 — 예전 동작(좌우 플립 한 장)과 같아야 한다.
func _test_fallback_without_art() -> void:
	_clear_art()
	_face(Vector2(200.0, 0.0))
	_expect(_player._dir == "side", "아트 없음: 우로 이동 → side")
	_expect(_player._facing > 0.0, "아트 없음: 우로 이동 → _facing=+1")

	# 위로만 움직여도 방향은 side 로 남고, 마지막 좌/우 값이 보존되어야 한다.
	_face(Vector2(0.0, -200.0))
	_expect(_player._dir == "side", "아트 없음: 위로 이동해도 side 유지")
	_expect(_player._facing > 0.0, "아트 없음: 위로 이동해도 _facing 보존")
	_expect(_player.aim_vector() == Vector2(1.0, 0.0), "아트 없음: 조준은 좌/우로만")

	_face(Vector2(-200.0, 0.0))
	_face(Vector2(0.0, 200.0))
	_expect(_player._dir == "side", "아트 없음: 아래로 이동해도 side 유지")
	_expect(_player._facing < 0.0, "아트 없음: 좌 향한 뒤 아래로 가도 _facing 보존")


## 2. 상/하 그림이 있을 때 — 그쪽으로 바뀌고 조준도 따라간다.
func _test_with_art() -> void:
	_clear_art()
	_give_art("up")
	_give_art("down")

	_face(Vector2(0.0, -200.0))
	_expect(_player._dir == "up", "아트 있음: 위로 이동 → up")
	_expect(_player.aim_vector() == Vector2(0.0, -1.0), "아트 있음: up 조준은 위쪽")

	_face(Vector2(0.0, 200.0))
	_expect(_player._dir == "down", "아트 있음: 아래로 이동 → down")
	_expect(_player.aim_vector() == Vector2(0.0, 1.0), "아트 있음: down 조준은 아래쪽")

	_face(Vector2(-200.0, 0.0))
	_expect(_player._dir == "side", "아트 있음: 좌로 이동 → side 복귀")
	_expect(_player.aim_vector() == Vector2(-1.0, 0.0), "아트 있음: side 조준은 바라보는 좌/우")

	# 상/하 그림은 정면·후면이라 뒤집으면 무기가 반대 손으로 간다 — 플립이 걸리면 안 된다.
	_face(Vector2(0.0, -200.0))
	_player._animate_walk(1.0)
	_expect(_player.body.scale.x > 0.0, "up 그림에는 수평 플립이 걸리지 않는다")

	# 위쪽만 그림이 있고 아래쪽이 없으면, 아래로 갈 때만 side 로 되돌아가야 한다.
	_clear_art()
	_give_art("up")
	_face(Vector2(0.0, -200.0))
	_expect(_player._dir == "up", "부분 아트: 위 그림만 있어도 up 은 산다")
	_face(Vector2(0.0, 200.0))
	_expect(_player._dir == "side", "부분 아트: 아래 그림이 없으면 side 로 내려간다")


## 3. 대각선 관성 — 45° 부근에서 방향이 매 프레임 뒤집히지 않아야 한다.
func _test_hysteresis() -> void:
	_clear_art()
	_give_art("up")
	_give_art("down")

	# side 에서 출발해 "수직이 약간 더 큰" 대각선을 준다. 관성(1.35배) 안이므로 side 유지.
	_face(Vector2(200.0, 0.0))
	_face(Vector2(100.0, 110.0))
	_expect(_player._dir == "side", "관성: side 에서 살짝 기운 대각선은 side 유지")

	# 관성을 넘길 만큼 수직이 커지면 넘어간다(넘어가지 않으면 방향 전환 자체가 죽은 것).
	_face(Vector2(100.0, 300.0))
	_expect(_player._dir == "down", "관성: 수직이 확실히 크면 down 으로 전환")

	# 반대로 down 에서 살짝 기운 수평은 down 을 유지해야 한다.
	_face(Vector2(110.0, 100.0))
	_expect(_player._dir == "down", "관성: down 에서 살짝 기운 대각선은 down 유지")

	_face(Vector2(300.0, 100.0))
	_expect(_player._dir == "side", "관성: 수평이 확실히 크면 side 로 전환")


## 4. 정지에 가까우면 방향을 바꾸지 않는다 — 제자리에서 캐릭터가 도는 것을 막는다.
func _test_min_speed() -> void:
	_clear_art()
	_give_art("up")
	_face(Vector2(200.0, 0.0))
	var before: String = _player._dir
	_face(Vector2(0.5, -2.0))   # 임계(5.0 px/s) 미만
	_expect(_player._dir == before, "정지 근처에서는 방향을 바꾸지 않는다")


# ── 도우미 ────────────────────────────────────────────────────────────────

## 속도를 넣고 방향 판정을 한 번 돌린다.
func _face(v: Vector2) -> void:
	_player.velocity = v
	_player._update_facing()


## 방향 그림을 전부 비운다(= 지금 저장소 상태: 측면 한 장만).
func _clear_art() -> void:
	_player._sheet_by_dir.clear()
	_player._idle_by_dir.clear()
	_player._idle_by_dir["side"] = _fake_tex()
	_player._dir = "side"
	_player._facing = 1.0
	_player._tex_dir = ""


## 시험용 방향 그림을 넣는다 — 실제 PNG 가 아직 없으므로 크기만 있는 자리표시 텍스처를 쓴다.
## 이 검사가 보는 것은 "어느 방향을 골랐는가"지 그림의 내용이 아니다.
func _give_art(dir_key: String) -> void:
	_player._idle_by_dir[dir_key] = _fake_tex()


func _fake_tex() -> Texture2D:
	var t := PlaceholderTexture2D.new()
	t.size = Vector2(120.0, 150.0)
	return t


func _expect(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  %s" % label)
	else:
		_err(label)


func _err(label: String) -> void:
	_fail += 1
	print("  FAIL  %s" % label)


func _finish() -> void:
	if _fail == 0:
		print("verify_player_facing: 모두 통과")
	else:
		print("verify_player_facing: %d건 실패" % _fail)
	quit(1 if _fail > 0 else 0)
