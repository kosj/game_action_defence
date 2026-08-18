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
	if _t >= 4.9:
		return _report()
	return false


func _setup() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	# --script 메인 루프는 오토로드 등록 전에 컴파일된다 — 식별자 대신 트리에서 찾는다.
	_bal = root.get_node("GameData").balance
	_player = CharacterBody2D.new()
	# 감전 검증용 대역 — 진짜 Player 의 take_hit 은 무적 시간·사망·부활까지 얽혀 있어서,
	# 여기서는 "구역이 언제 몇 대 때리는가"만 세는 껍데기를 붙인다.
	var stub := GDScript.new()
	stub.source_code = "extends CharacterBody2D\nvar hits := 0\nvar last_amount := 0\n" \
			+ "func take_hit(a: int) -> void:\n\thits += 1\n\tlast_amount = a\n"
	stub.reload()
	_player.set_script(stub)
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

	# 감전 계측 구간을 깨끗하게 시작한다 — 앞선 순간이동 검사들도 "접촉"이라 이미 몇 대 맞았다.
	_at(1.78, "shock_reset", func() -> void:
		_player.hits = 0
		_arena._shock_cd = 0.0)

	# 1.8~3.0s(1.2초) 동안 매 프레임 바깥으로 밀어붙인다 — 새지 않고, 주기적으로 감전된다.
	if _t > 1.8 and _t < 3.0:
		_player.global_position += Vector2(40.0, 0.0)
		_expect_once("leak", _player.global_position.distance_to(CENTER) <= R + 41.0,
				"계속 밀어붙여도 경계를 넘어 새어 나가지 않는다")
	_at(3.02, "leak_ok", func() -> void:
		_expect(not _done.has("leak"), "1.2초 동안 바깥으로 계속 밀어도 갇힌 상태가 유지된다")
		# 간격 SHOCK_INTERVAL(0.6s) 이므로 1.2초 접촉이면 2~3대. 프레임 경계 때문에 3대까지 허용.
		var lo: int = int(1.2 / _arena.shock_interval)
		_expect(_player.hits >= lo and _player.hits <= lo + 1,
				"붙어 있는 동안 %.1f초마다 감전 — 1.2초에 %d대(%d~%d 예상)" % [
					_arena.shock_interval, _player.hits, lo, lo + 1])
		_expect(_player.last_amount == _arena.shock_damage,
				"감전 피해량 %d" % _arena.shock_damage))

	# 떨어지면 더 이상 맞지 않는다.
	_at(3.05, "away", func() -> void:
		_player.global_position = CENTER
		_player.hits = 0)
	_at(3.9, "away_chk", func() -> void:
		_expect(_player.hits == 0, "경계에서 떨어지면 감전이 멈춘다(0.85초 동안 0대)"))

	# 보스 처치 → 해제 연출 뒤 스스로 사라진다.
	_at(4.0, "die", func() -> void:
		root.get_node("Events").boss_died.emit()
		_expect(is_instance_valid(_arena), "처치 즉시 사라지지 않고 해제 연출이 재생된다"))
	_at(4.2, "release", func() -> void:
		_player.global_position = CENTER + Vector2(2000.0, 0.0))
	_at(4.3, "release_chk", func() -> void:
		_expect(_player.global_position.distance_to(CENTER) > 1000.0,
				"해제 중에는 더 이상 가두지 않는다(중심에서 %.0f)" % _player.global_position.distance_to(CENTER))
		_expect(_player.hits == 0, "해제 중에는 감전도 하지 않는다"))


func _report() -> bool:
	_expect(not is_instance_valid(_arena), "해제 연출이 끝나면 노드가 스스로 사라진다")
	_check_boss_sprites()
	if _freed_at > 0.0:
		print("  (소멸 %.2fs — 처치 4.00s + 해제 %.2fs)" % [_freed_at, _freed_at - 4.0])
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


## 보스 스프라이트가 데이터에 전부 채워져 있는가.
##
## 왜 여기서 보는가: 예전에는 Boss.setup() 이 스프라이트를 못 찾으면 아키타입 기본 텍스처
## (_BOSS_TEX)로 폴백했다. P1-1 에서 아키타입 5종 순환 경로와 그 아트 4종을 걷어내면서 그
## 폴백도 사라졌으므로, 이제 sprite 가 비거나 경로가 틀리면 **보스가 투명하게 등장한다** —
## 화면을 봐야만 알 수 있는 종류의 사고다. 런타임 안전망을 없앤 대가로 이 검사를 둔다.
## 아트를 지우거나 이름을 바꾸면 여기서 빌드가 멈춘다.
func _check_boss_sprites() -> void:
	var spawner: GDScript = load("res://scripts/ZombieSpawner.gd")
	var bosses: Dictionary = spawner.get("THEME_BOSSES")
	_expect(not bosses.is_empty(), "THEME_BOSSES 가 비어 있지 않다")

	# 테마가 가리키는 boss_key 가 실제로 정의돼 있는가 — 어긋나면 그 아레나에 보스가 안 뜬다.
	var game_data := root.get_node_or_null("GameData")
	if game_data != null:
		var missing := ""
		for th in game_data.themes:
			if th == null:
				continue
			if not bosses.has(th.boss_key):
				missing += "%s(boss_key='%s') " % [th.id, th.boss_key]
		_expect(missing == "", "모든 테마의 boss_key 가 THEME_BOSSES 에 있다  %s" % missing)

	for key in bosses:
		var bt: Dictionary = bosses[key]
		var path: String = String(bt.get("sprite", ""))
		if path == "":
			_expect(false, "%s: sprite 가 비어 있다(폴백이 없으므로 투명 보스가 된다)" % key)
			continue
		if not ResourceLoader.exists(path):
			_expect(false, "%s: sprite 경로가 없다 — %s" % [key, path])
			continue
		_expect(load(path) is Texture2D, "%s: sprite 가 Texture2D 다 — %s" % [key, path])
		_expect_spawns(key, bt)


## 데이터가 맞는 것과 보스가 실제로 보이는 것은 다르다 — 세 테마 보스를 실제로 세워
## Body 에 텍스처가 붙는지까지 본다. 예전에는 치트 SPAWN BOSS 로 눈으로 확인하던 항목이다.
## (Boss.tscn 은 P1-1 이후 기본 텍스처를 갖지 않는다 — 전부 setup() 이 데이터에서 넣는다)
func _expect_spawns(key: String, bt: Dictionary) -> void:
	var boss = load("res://scenes/Boss.tscn").instantiate()
	current_scene.add_child(boss)
	boss.setup({
		"max_health": 100, "speed": 40.0, "contact_damage": int(bt.get("contact", 1)),
		"score": 0, "gold": 0,
		"archetype": bt.get("archetype", ""), "name": bt.get("name", key),
		"tint": bt.get("tint", Color.WHITE), "proj_color": bt.get("proj", Color.WHITE),
		"sprite": bt.get("sprite", ""),
	})
	_expect(boss.body != null and boss.body.texture != null,
		"%s: 실제로 세우면 Body 에 텍스처가 붙는다(투명 보스 아님)" % key)
	boss.free()
