@tool
extends SceneTree

## 보스 격리 구역 검증 — 헤드리스로 구역을 전개해 두고 실제 프레임을 돌리며
## 전개 → 가둠 → 해제 수명을 확인한다.
##
##   godot --headless --fixed-fps 60 --script res://tools/verify_boss_arena.gd
##
## 이 노드가 하는 일은 "플레이어를 못 나가게 막는 것" 하나뿐이라 그 한 가지를 여러 각도로 본다:
## 전개 애니메이션 뒤의 실제 반경 · 밖으로 나간 플레이어의 복귀 · 안쪽은 건드리지 않음 ·
## 계속 밀어붙여도 새지 않음 · 보스 처치 후 자동 소멸. 종료 코드 0 = 전부 통과.
##
## 노드의 _physics_process 는 이 스크립트의 _process 보다 **먼저** 도는 프레임 구조라,
## 위치를 옮긴 뒤의 확인은 몇 프레임 뒤(+0.05s)에 예약해서 본다.

const DT := 1.0 / 60.0
const R := 500.0
const CENTER := Vector2(1000, 500)   # 원점이 아니어도 되는지 같이 확인

var _arena: Node2D = null
var _player: CharacterBody2D = null
var _t: float = 0.0
var _fail: int = 0
var _done: Dictionary = {}
var _bal: Resource = null
var _freed_at: float = -1.0
## 해제된 노드를 담은 변수는 null 과 같다고 비교된다 — `_arena == null` 을 초기화 조건으로 쓰면
## 구역이 사라진 순간 _setup 이 다시 돌아 버린다(실제로 그랬다). 별도 플래그로 판단한다.
var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_setup()
		return false
	_t += DT
	if _freed_at < 0.0 and not is_instance_valid(_arena):
		_freed_at = _t
	_step()
	if _t >= 3.2:
		return _report()
	return false


func _setup() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	# --script 메인 루프는 오토로드 등록 전에 컴파일된다 — 식별자 대신 트리에서 찾는다.
	_bal = root.get_node("GameData").balance
	_player = CharacterBody2D.new()
	_player.add_to_group("player")
	scene.add_child(_player)
	_player.global_position = CENTER
	_arena = (load("res://scripts/BossArena.gd") as GDScript).spawn(scene, CENTER, R)
	print("─ 보스 격리 구역 검증 ─ 중심 (%.0f, %.0f) · 반경 %.0f" % [CENTER.x, CENTER.y, R])
	print("  실제 회차별 반경: %s" % _radii_by_count())


## 스포너와 같은 식으로 회차별 반경을 계산해 보여준다(수치 감각 확인용).
func _radii_by_count() -> String:
	var out := PackedStringArray()
	for n in range(1, 7):
		var r: float = maxf(_bal.boss_arena_radius_min,
				_bal.boss_arena_radius - _bal.boss_arena_shrink_per_count * float(n - 1))
		out.append("%d차 %.0f" % [n, r])
	return ", ".join(out)


func _step() -> void:
	# 전개 직후 — 아직 넓게 열려 있다(바깥에서 조여 들어온다).
	_at(0.02, "open", func() -> void:
		_expect(_arena.current_radius() > R,
				"전개 중에는 최종 반경보다 넓다(%.0f)" % _arena.current_radius()))

	# 전개 완료 후 실제 반경 = 설정 반경.
	_at(0.7, "settled", func() -> void:
		_expect(is_equal_approx(_arena.current_radius(), R),
				"전개가 끝나면 실제 반경이 설정값과 같다(%.1f)" % _arena.current_radius()))

	# 안쪽에 있는 플레이어는 건드리지 않는다.
	var inside := CENTER + Vector2(120.0, -60.0)
	_at(0.9, "inside", func() -> void: _player.global_position = inside)
	_at(0.95, "inside_chk", func() -> void:
		_expect(_player.global_position.is_equal_approx(inside),
				"구역 안에서는 위치를 건드리지 않는다"))

	# 밖으로 나가면 경계 위로 되돌아온다.
	_at(1.2, "outside", func() -> void:
		_player.global_position = CENTER + Vector2(3000.0, 0.0))
	_at(1.25, "outside_chk", func() -> void:
		var d: float = _player.global_position.distance_to(CENTER)
		_expect(absf(d - R) < 1.0, "멀리 벗어나도 경계 위로 되돌아온다(중심에서 %.1f)" % d))

	# 어느 방향이든 같은 반경에서 막힌다.
	_at(1.5, "diag", func() -> void:
		_player.global_position = CENTER + Vector2(-800.0, 900.0))
	_at(1.55, "diag_chk", func() -> void:
		var d: float = _player.global_position.distance_to(CENTER)
		_expect(absf(d - R) < 1.0, "대각선 방향도 같은 반경에서 막힌다(%.1f)" % d))

	# 매 프레임 바깥으로 밀어붙여도 새어 나가지 않는다.
	if _t > 1.8 and _t < 2.3:
		_player.global_position += Vector2(40.0, 0.0)
		_expect_once("leak", _player.global_position.distance_to(CENTER) <= R + 41.0,
				"계속 밀어붙여도 경계를 넘어 새어 나가지 않는다")
	_at(2.3, "leak_ok", func() -> void:
		_expect(not _done.has("leak"), "0.5초 동안 바깥으로 계속 밀어도 갇힌 상태가 유지된다"))

	# 보스 처치 → 해제 연출 뒤 스스로 사라진다.
	_at(2.4, "die", func() -> void:
		root.get_node("Events").boss_died.emit()
		_expect(is_instance_valid(_arena), "처치 즉시 사라지지 않고 해제 연출이 재생된다"))
	_at(2.6, "release", func() -> void:
		_player.global_position = CENTER + Vector2(2000.0, 0.0))
	_at(2.7, "release_chk", func() -> void:
		_expect(_player.global_position.distance_to(CENTER) > 1000.0,
				"해제 중에는 더 이상 가두지 않는다(중심에서 %.0f)" % _player.global_position.distance_to(CENTER)))


func _report() -> bool:
	_expect(not is_instance_valid(_arena), "해제 연출이 끝나면 노드가 스스로 사라진다")
	if _freed_at > 0.0:
		print("  (소멸 %.2fs — 처치 2.40s + 해제 %.2fs)" % [_freed_at, _freed_at - 2.4])
	print("결과: %s" % ("전부 통과" if _fail == 0 else "%d건 실패" % _fail))
	(load("res://scripts/FXBurst.gd") as GDScript).clear_pool()
	quit(_fail)
	return true


func _at(t: float, key: String, fn: Callable) -> void:
	if _t >= t and not _done.has(key):
		_done[key] = true
		fn.call()


func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   %s" % msg)
	else:
		_fail += 1
		print("  FAIL %s" % msg)


## 매 프레임 확인하는 조건 — 실패했을 때 한 번만 보고한다(로그 폭주 방지).
func _expect_once(key: String, cond: bool, msg: String) -> void:
	if cond or _done.has(key):
		return
	_done[key] = true
	_fail += 1
	print("  FAIL %s" % msg)
