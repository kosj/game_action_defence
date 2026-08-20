extends SceneTree
## 핫패스 회귀 가드 (P1-21).
##
## 여기 있는 것은 전부 **눈으로는 안 보이고 프레임만 깎이는** 종류다. 화면은 멀쩡하고
## 테스트도 초록인데 후반 프레임만 조용히 나빠지므로, 자동 검사가 유일한 안전망이다.
##
##   godot --headless --path . --script res://tools/verify_hotpath.gd
##
## 근거 수치는 OPTIMIZATION_PLAN.md §7 참고.

## 대량으로 존재하는 개체 씬 — 이들이 물리 노드가 되면 개체 수만큼 물리 서버 등록·변환
## 동기화가 되살아난다. Bullet 은 예전에 Area2D 였고, Gold 는 **충돌 도형도 없는 Area2D** 였다.
const MASS_SCENES := [
	"res://scenes/Bullet.tscn",
	"res://scenes/Gold.tscn",
	"res://scenes/Zombie.tscn",
]

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   %s" % label)
	else:
		_fail += 1
		print("  FAIL %s%s" % [label, ("  — " + detail) if detail != "" else ""])


func _init() -> void:
	await process_frame
	print("── 핫패스 가드 ──────────────────────────────────────")
	_check_mass_scenes()
	_check_scripts_alive()
	_check_all_scripts_compile()
	_check_damage_number_redraw()
	await _check_near_cache()
	await _check_radius_path()
	_check_homing_throttle()
	print("")
	if _fail == 0:
		print("핫패스 가드 통과")
	else:
		print("핫패스 가드 실패 %d 건" % _fail)
	quit(_fail)


## ① 대량 개체 씬의 루트는 물리 노드가 아니어야 한다.
func _check_mass_scenes() -> void:
	for path in MASS_SCENES:
		var ps := load(path) as PackedScene
		if ps == null:
			_check("%s 로드" % path, false, "씬을 열 수 없다")
			continue
		var n := ps.instantiate()
		_check("%s 루트가 물리 노드가 아니다" % path.get_file(),
			not (n is CollisionObject2D),
			"%s 는 CollisionObject2D 다 — 개체 수만큼 물리 서버 등록이 되살아난다" % n.get_class())
		n.free()


## ② 핫패스 스크립트가 실제로 컴파일된다.
##
## 컴파일에 실패한 GDScript 도 노드에는 **붙어 있다.** 그래서 "스크립트가 있는가"로는 못 가른다 —
## 게임은 조용히 죽은 탄을 날리고, 벤치는 그 상태로 "탄은 싸다"는 표를 찍는다(P1-18 이 그랬다).
func _check_scripts_alive() -> void:
	for path in MASS_SCENES:
		var ps := load(path) as PackedScene
		if ps == null:
			continue
		var n := ps.instantiate()
		var sc = n.get_script()
		_check("%s 스크립트가 살아 있다" % path.get_file(),
			sc != null and (sc as GDScript).can_instantiate(),
			"컴파일 실패 — 이 개체는 아무 일도 하지 않는다")
		n.free()


## ②-b `scripts/**` 의 모든 GDScript 가 실제로 컴파일된다.
##
## `tools/check_gdscript.py` 는 스코프를 보지 않고, CI 의 `--import` 는 **파싱 오류가 나도
## 종료 코드 0** 이다. 그래서 "지역 변수 타입 추론 실패" 같은 오류가 조용히 통과할 수 있다 —
## 실제로 이 작업 중에 그렇게 통과한 오류가 하나 있었고, 그 상태로 낸 벤치 수치는 전부 거짓이었다
## (그 스크립트가 죽으면 그 개체는 아무 일도 하지 않으므로 "공짜"로 측정된다).
##
## 컴파일에 실패한 GDScript 는 `can_instantiate()` 가 false 다 — 그것 하나로 전수 검사한다.
func _check_all_scripts_compile() -> void:
	var bad: Array = []
	var n := 0
	for path in _gd_files("res://scripts"):
		var sc = load(path)
		if sc == null:
			bad.append(path)
			continue
		if sc is GDScript and not (sc as GDScript).can_instantiate():
			bad.append(path)
		n += 1
	_check("scripts/** GDScript %d개가 전부 컴파일된다" % n, bad.is_empty(), str(bad))


func _gd_files(dir_path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."):
				out.append_array(_gd_files(dir_path.path_join(f)))
		elif f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
		f = d.get_next()
	d.list_dir_end()
	return out


## ③ 데미지 숫자는 매 프레임 다시 그리지 않는다.
##
## 문자열 드로우(특히 외곽선)는 GL Compatibility 에서 가장 비싼 2D 연산이다. 동시 36개를
## 매 프레임 다시 그리면 초당 2,160회다. 페이드·팝·흔들림은 전부 CanvasItem 속성으로 낼 수 있다.
func _check_damage_number_redraw() -> void:
	var f := FileAccess.open("res://scripts/DamageNumber.gd", FileAccess.READ)
	if f == null:
		_check("DamageNumber.gd 읽기", false)
		return
	var src := f.get_as_text()
	f.close()
	var body := src.substr(src.find("func _process("))
	var end := body.find("\nfunc ", 1)
	if end > 0:
		body = body.substr(0, end)
	_check("DamageNumber._process 가 queue_redraw 를 부르지 않는다",
		not body.contains("queue_redraw"),
		"수명 내내 매 프레임 문자열을 다시 그리게 된다")


## ④ 같은 셀을 다시 물으면 3×3 순회를 건너뛴다 + 그래도 결과는 같다.
##
## 건너뛰기가 사라져도 게임은 정상 동작하므로(느려질 뿐) 눈으로는 못 잡는다.
## 반대로 캐시가 너무 오래 살아 있으면 **좀비가 죽어도 계속 맞는** 버그가 되므로 둘 다 본다.
func _check_near_cache() -> void:
	var ev := root.get_node_or_null("Events")
	if ev == null:
		_check("Events 오토로드", false)
		return
	var host := Node2D.new()
	root.add_child(host)
	var zs: Array = []
	for i in 3:
		var z := Node2D.new()
		z.global_position = Vector2(100.0 + float(i), 100.0)   # 전부 같은 셀(64px 격자)
		host.add_child(z)
		z.add_to_group("zombies")
		zs.append(z)
	await physics_frame

	var q0: int = int(ev.zg_queries)
	var b0: int = int(ev.zg_builds)
	var a: Array = ev.zombies_near(Vector2(100.0, 100.0)).duplicate()
	var built_first := int(ev.zg_builds) - b0
	var b: Array = ev.zombies_near(Vector2(120.0, 110.0)).duplicate()   # 같은 셀의 다른 지점
	var built_second := int(ev.zg_builds) - b0 - built_first
	var far: Array = ev.zombies_near(Vector2(5000.0, 5000.0)).duplicate()
	var built_far := int(ev.zg_builds) - b0 - built_first - built_second

	_check("첫 질의는 3×3 을 돈다", built_first == 1)
	_check("같은 셀 재질의는 순회를 건너뛴다", built_second == 0,
		"건너뛰기가 사라졌다 — 탄 1발당 약 2.4µs 가 되돌아온다")
	_check("다른 셀은 다시 돈다", built_far == 1)
	_check("질의 수가 세어진다", int(ev.zg_queries) - q0 == 3)
	_check("같은 셀 두 질의의 결과가 같다", a.size() == b.size() and a.size() == 3,
		"a=%d b=%d (좀비 3마리를 모두 담아야 한다)" % [a.size(), b.size()])
	_check("먼 셀은 비어 있다", far.is_empty())

	# 프레임이 넘어가면 캐시가 풀려야 한다 — 안 그러면 죽은 좀비를 계속 맞힌다.
	for z in zs:
		z.remove_from_group("zombies")
	await physics_frame
	var after: Array = ev.zombies_near(Vector2(100.0, 100.0))
	_check("프레임이 바뀌면 캐시가 무효화된다", after.is_empty(),
		"그룹에서 빠진 좀비가 아직 후보로 나온다")

	for z in zs:
		z.free()
	host.free()


## ⑤ 광역 반경 질의가 **싼 쪽 경로**를 고른다 + 두 경로의 결과가 같다.
##
## 유도탄의 조준 반경(420px)은 셀 15×15 = 225칸이다. 후반 좀비가 25~40마리뿐일 때 그 225칸을
## 도는 것은 전수 스캔보다 10배 비싸다 — 실측에서 이것 하나가 물리 틱의 약 4.5ms 였다.
## 임계를 고정값으로 되돌리면 그 비용이 조용히 돌아오므로 경로 선택 자체를 잠근다.
func _check_radius_path() -> void:
	var ev := root.get_node_or_null("Events")
	if ev == null:
		return
	var host := Node2D.new()
	root.add_child(host)
	var zs: Array = []
	for i in 10:
		var z := Node2D.new()
		z.global_position = Vector2(float(i) * 37.0, float(i) * 23.0)
		host.add_child(z)
		z.add_to_group("zombies")
		zs.append(z)
	await physics_frame

	# 좀비 10마리 · 반경 420(=15×15 칸) → 전수 스캔이 싸다.
	var wide: Array = ev.zombies_in_radius(Vector2.ZERO, 420.0).duplicate()
	_check("넓은 반경 + 적은 좀비 → 전수 스캔", bool(ev.zg_radius_scanned),
		"225칸을 도는 경로로 돌아갔다 — 유도탄 1발당 약 60µs 가 되살아난다")

	# 같은 질의를 좁은 반경으로 — 이번에는 셀 경로가 싸다(칸 수 9 < 마리 수 10).
	var near_r: Array = ev.zombies_in_radius(Vector2.ZERO, 60.0).duplicate()
	_check("좁은 반경 → 셀 경로", not bool(ev.zg_radius_scanned))

	# 어느 경로로 오든 "반경 안"이라는 계약은 같아야 한다 — 직접 세어 대조한다.
	var expect_wide := 0
	var expect_near := 0
	for z in zs:
		var d := (z as Node2D).global_position.length()
		if d <= 420.0:
			expect_wide += 1
		if d <= 60.0:
			expect_near += 1
	_check("전수 스캔 경로 결과가 맞다", wide.size() == expect_wide,
		"%d != %d" % [wide.size(), expect_wide])
	_check("셀 경로 결과가 맞다", near_r.size() == expect_near,
		"%d != %d" % [near_r.size(), expect_near])

	for z in zs:
		z.free()
	host.free()


## ⑥ 유도탄 조준이 매 프레임 돌지 않는다.
##
## 조준 질의(`zombies_in_radius(pos, 420)`)의 비용은 **탄 × 좀비의 곱**이다 — 통제 실험에서
## 유도탄 200발 기준 좀비 0 → 150 만으로 1.85ms → 12.19ms 였다. 60Hz 로 되돌리면 최대 부하에서
## 따라잡기 틱(렌더 1프레임당 물리 4회)이 되살아난다. 상수를 되돌리는 것을 여기서 막는다.
func _check_homing_throttle() -> void:
	var sc := load("res://scripts/Bullet.gd") as GDScript
	var every: int = int(sc.get("STEER_EVERY")) if sc != null else 1
	_check("유도탄 조준이 매 프레임이 아니다 (STEER_EVERY=%d)" % every, every >= 2,
		"매 프레임 조준하면 최대 부하에서 물리 틱이 약 1.6배가 된다")
