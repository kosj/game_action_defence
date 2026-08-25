extends SceneTree
## 필드 픽업 2종(보물상자·무기)의 수집 회귀 테스트 (P1-23).
##
##   godot --headless --path . --script res://tools/verify_pickups.gd
##
## 왜 있나 — 두 픽업은 **물리 노드가 아니다.** 수집 판정이 Area2D 신호가 아니라 `_process`
## 안의 `collect_radius` 거리 계산이라, 타입을 바꾸거나 판정 코드를 건드려도 **컴파일은 되고
## 화면도 멀쩡한데 못 먹는** 상태가 만들어질 수 있다. 그건 눈으로 보기 전에는 안 잡힌다.
## `verify_hotpath.gd` 는 "루트가 물리 노드가 아니다"만 보므로, 실제로 먹히는지는 여기서 본다.
##
## 검사 항목
##   T1 루트가 Node2D 이고 CollisionObject2D 가 아니다
##   T2 멀리 있으면 수집되지 않는다(항상 먹히는 버그를 잡는다)
##   T3 겹쳐 놓으면 수집된다(영영 못 먹는 버그를 잡는다)

var _ok := 0
var _total := 0


func _check(label: String, cond: bool) -> void:
	_total += 1
	if cond:
		_ok += 1
	print("%s %s" % ["PASS" if cond else "FAIL", label])


func _init() -> void:
	await process_frame
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	var pl := get_first_node_in_group("player") as Node2D
	_check("플레이어가 있다", pl != null)
	if pl == null:
		quit(1)
		return

	var pool := root.get_node("Pool")
	for spec in [["res://scenes/ItemPickup.tscn", "item_pickups"],
				 ["res://scenes/WeaponPickup.tscn", "weapon_pickups"]]:
		var scene := load(spec[0]) as PackedScene
		var grp: String = spec[1]
		var n0 := get_nodes_in_group(grp).size()
		var it: Node2D = pool.acquire(scene, main)
		_check("%s 루트가 Node2D 이고 물리 노드가 아니다" % spec[0].get_file(),
			it is Node2D and not (it is CollisionObject2D))
		if it.has_method("setup"):
			# 스포너와 **똑같은 방법**으로 무기 데이터를 만든다(WeaponPickupSpawner:47).
			# 임의로 조립한 dict 를 넘기면 기대 키가 빠져 실제와 다른 개체가 된다.
			# ⚠️ 전역 클래스명은 `--script` 툴에서 오토로드 등록 전에 해석돼 실패한다 —
			#    런타임 load() 로 끊는다(§5-L 결함 ①과 같은 뿌리).
			var wdb: GDScript = load("res://scripts/WeaponDB.gd")
			it.setup(wdb.roll_pickup())
		it.global_position = pl.global_position + Vector2(500.0, 0.0)   # 멀리 — 아직 안 먹혀야 한다
		await physics_frame
		await process_frame
		_check("%s 멀리 있으면 안 먹힌다" % spec[0].get_file(),
			get_nodes_in_group(grp).size() == n0 + 1)
		it.global_position = pl.global_position                         # 겹쳐 놓으면 먹혀야 한다
		for i in 12:
			await process_frame
		_check("%s 겹치면 수집된다" % spec[0].get_file(),
			get_nodes_in_group(grp).size() == n0)

	print("")
	print("픽업 동작 %d/%d" % [_ok, _total])
	quit(0 if _ok == _total else 1)
