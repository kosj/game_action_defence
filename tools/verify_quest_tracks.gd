extends SceneTree
## 퀘스트 트랙 · 마일스톤 저장 · 웨이브 시대 잔재 검증 (P0-2 · P0-3 · P2-6).
## C 레인이 걷어낸 것들이 조용히 돌아오지 않는지 한자리에서 지킨다.
##   godot --headless --path . --script res://tools/verify_quest_tracks.gd
## 종료 코드 = 실패 개수.
##
## 무엇을 막는가: 이 시스템은 **조용히 죽는다**. 예전에는 waves 트랙이 발신자 없는 시그널에
## 물려 있어 메뉴에 영구 0/8 로 떠 있었고, 같은 시그널에 물린 주기 저장도 함께 멈춰 있었다.
## 화면에는 아무 오류도 나지 않는다 — 유저가 탭을 닫은 뒤에야 진행이 사라진 걸 안다.
## 그래서 "세 트랙이 각자의 신호로 실제로 오르는가"와 "마일스톤에서 디스크로 내려가는가"를
## 코드로 못박는다.

var _fails := 0
var _done := false


func _ok(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("  FAIL %s%s" % [label, ("  — " + detail) if detail != "" else ""])


func _cur(qm, id: String) -> int:
	for q in qm.active_quests():
		if q["id"] == id:
			return int(q["current"])
	return -1


## 트랙 카운터만 0 으로 되돌린다(티어는 건드리지 않는다 — 목표치가 바뀌면 비교가 흔들린다).
func _reset(qm) -> void:
	for t in qm.TRACKS:
		qm._count[t["id"]] = 0
	qm._survive_frac = 0.0
	qm._last_elapsed = -1.0


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var qm := root.get_node("QuestManager")
	var events := root.get_node("Events")

	print("── 트랙 구성 ────────────────────────────────────")
	var ids: Array = []
	for t in qm.TRACKS:
		ids.append(String(t["id"]))
	_ok("트랙이 3종이다", qm.TRACKS.size() == 3, str(ids))
	_ok("죽어 있던 waves 트랙이 없다", not ids.has("waves"), str(ids))
	_ok("생존 트랙이 있다", ids.has("survive"), str(ids))

	print("── 세 트랙이 각자의 신호로 오른다 ────────────────")
	_reset(qm)
	var k0 := _cur(qm, "kills")
	for i in range(5):
		events.zombie_killed.emit()
	_ok("kills: zombie_killed 로 오른다", _cur(qm, "kills") == k0 + 5,
		"%d -> %d" % [k0, _cur(qm, "kills")])

	var b0 := _cur(qm, "bosses")
	events.boss_died.emit()
	_ok("bosses: boss_died 로 오른다", _cur(qm, "bosses") == b0 + 1,
		"%d -> %d" % [b0, _cur(qm, "bosses")])

	# 생존은 elapsed_changed 의 **증가분**을 적산한다 — 절댓값을 더하면 판마다 폭증한다.
	var s0 := _cur(qm, "survive")
	events.elapsed_changed.emit(0.0)
	events.elapsed_changed.emit(120.0)
	_ok("survive: 경과 2분이면 +2 분", _cur(qm, "survive") == s0 + 2,
		"%d -> %d" % [s0, _cur(qm, "survive")])

	events.elapsed_changed.emit(150.0)
	_ok("survive: 30초는 아직 안 오른다(잔여로 남는다)", _cur(qm, "survive") == s0 + 2)
	events.elapsed_changed.emit(180.0)
	_ok("survive: 잔여가 합쳐져 1분이 되면 오른다", _cur(qm, "survive") == s0 + 3,
		"%d" % _cur(qm, "survive"))

	# 새 판(또는 이어하기 복원)에서 경과 시간이 뒤로 감 — 그 시각을 새로 세면 안 된다.
	var before := _cur(qm, "survive")
	events.elapsed_changed.emit(20.0)
	_ok("survive: 판이 바뀌어 시간이 되감겨도 새로 세지 않는다", _cur(qm, "survive") == before,
		"%d -> %d" % [before, _cur(qm, "survive")])
	events.elapsed_changed.emit(80.0)
	_ok("survive: 되감긴 뒤에도 증가분은 정상 적산", _cur(qm, "survive") == before + 1,
		"%d" % _cur(qm, "survive"))

	print("── 마일스톤 주기 저장 ───────────────────────────")
	# 이 항목의 본질. 저장 시점이 player_died 하나뿐이면 웹에서 탭을 닫는 순간 통째로 날아간다.
	var path: String = qm.SAVE_PATH
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	qm._dirty = true
	events.milestone_reached.emit(1)
	_ok("milestone_reached 가 퀘스트 진행을 디스크로 내린다", FileAccess.file_exists(path),
		path)

	var am := root.get_node("AchievementManager")
	var apath: String = am.SAVE_PATH
	if FileAccess.file_exists(apath):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(apath))
	am._dirty = true
	events.milestone_reached.emit(2)
	_ok("milestone_reached 가 도전과제 진행도 내린다", FileAccess.file_exists(apath), apath)

	print("── 보스 처치 → 마일스톤 배선 ────────────────────")
	# 시그널을 직접 쏘는 위 검사만으로는 "실제로 누가 쏘는가"를 증명하지 못한다 —
	# P0-2 의 원인이 바로 **선언만 있고 발신자가 없는 시그널**이었다. 발신자를 직접 부른다.
	# (_on_boss_died 는 _boss_alive/_boss_count 와 emit 만 건드려 트리 없이도 부를 수 있다)
	var got := {"n": 0, "idx": -1}
	var on_ms := func(i: int) -> void:
		got["n"] += 1
		got["idx"] = i
	events.milestone_reached.connect(on_ms)
	var zs = (load("res://scripts/ZombieSpawner.gd") as GDScript).new()
	zs._boss_count = 3
	zs._boss_alive = true
	zs._on_boss_died()
	_ok("ZombieSpawner 가 보스 처치에서 마일스톤을 쏜다", got["n"] == 1, "%d회" % got["n"])
	_ok("마일스톤 index 가 보스 회차다", got["idx"] == 3, "idx=%d" % got["idx"])
	_ok("보스 처치 후 _boss_alive 가 내려간다", not zs._boss_alive)
	events.milestone_reached.disconnect(on_ms)
	zs.free()

	print("── 구 세이브 호환 ───────────────────────────────")
	# 트랙 id 가 바뀌었으므로 구 waves 키가 남은 세이브를 읽어도 조용히 무시되어야 한다.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"tier": {"kills": 2, "waves": 7}, "count": {"kills": 33, "waves": 5}, "frac": 0.25,
	}))
	f.close()
	qm._load()
	_ok("구 waves 키가 남아 있어도 로드가 깨지지 않는다", not qm._tier.has("waves"),
		str(qm._tier.keys()))
	_ok("같은 세이브의 살아 있는 트랙은 그대로 복원된다", int(qm._tier["kills"]) == 2,
		"kills tier=%s" % str(qm._tier.get("kills")))
	_ok("생존 잔여 분(frac)도 복원된다", absf(qm._survive_frac - 0.25) < 0.001,
		"%f" % qm._survive_frac)

	print("── 죽은 시그널·사문이 되살아나지 않았는가 ────────")
	_ok("Events 에 wave_complete 가 없다", not events.has_signal("wave_complete"))
	_ok("Events 에 milestone_reached 가 있다", events.has_signal("milestone_reached"))
	# 인게임 상점 폐기(P0-3). 되살리려면 폐기 결정부터 뒤집어야 한다 — 조용히 돌아오지 않게 못박는다.
	_ok("Events 에 shop_closed 가 없다", not events.has_signal("shop_closed"))
	_ok("ShopPanel.gd 가 없다", not ResourceLoader.exists("res://scripts/ShopPanel.gd"))
	_ok("ShopPanel.tscn 이 없다", not ResourceLoader.exists("res://scenes/ShopPanel.tscn"))
	# 상점 전용이던 로케일 블록(sec_* · upg_*)도 함께 사라졌다. 남으면 안 쓰는 CJK 글리프가
	# 폰트 서브셋에 계속 실려 웹 초기 로딩에 그대로 얹힌다.
	var locale := root.get_node("Locale")
	var stale := ""
	for k in locale.STRINGS:
		var key := String(k)
		if key.begins_with("shop_") or key.begins_with("upg_") or key.begins_with("sec_"):
			stale += key + " "
	_ok("상점 전용 로케일 키가 남아 있지 않다", stale == "", stale)

	print("── 웨이브 시대 데드 API (P2-6) ──────────────────")
	# 이것들이 남아 있으면 다음 작업자가 "무한 스케일링이 있다"고 오인한다 —
	# 실제 난이도 곡선은 ZombieSpawner._hp_mult() 의 2차 곡선과 difficulty.tres 다.
	for sig in ["wave_changed", "wave_progress_changed"]:
		_ok("Events 에 %s 가 없다" % sig, not events.has_signal(sig))
	_ok("Events 에 kills_changed 가 있다", events.has_signal("kills_changed"))

	for m in ["wave_pressure_mult", "wave_speed_pressure", "diff_spawn_mult",
			"diff_total_mult", "difficulty_name"]:
		_ok("Events 에 %s() 가 없다" % m, not events.has_method(m))

	var props := {}
	for pd in events.get_property_list():
		props[String(pd["name"])] = true
	for prop in ["current_wave", "wave_kill_progress", "wave_kill_total"]:
		_ok("Events 에 %s 상태가 없다" % prop, not props.has(prop))

	# 세이브에서도 빠졌는가 — 남으면 항상 1 인 값을 계속 쓰고 읽는다.
	var sm_src := FileAccess.get_file_as_string("res://scripts/SaveManager.gd")
	_ok("SaveManager 가 current_wave 를 저장/복원하지 않는다",
		not sm_src.contains("current_wave"))

	print("── HUD 노드 개명이 실제로 붙는가 (P2-6) ─────────")
	# 씬 노드를 개명하면 @onready 경로가 조용히 어긋난다 — 화면을 띄우기 전엔 모른다.
	# 실제로 인스턴스화해서 세 참조가 전부 잡히는지 본다.
	var hud = load("res://scenes/HUD.tscn").instantiate()
	root.add_child(hud)
	_ok("HUD.KillsLabel 이 잡힌다", hud.kills_label != null)
	_ok("HUD.BannerBg 가 잡힌다", hud.banner_bg != null)
	_ok("HUD.BannerLabel 이 잡힌다", hud.banner_label != null)
	hud.free()

	print("──────────────────────────────────────────────────")
	print("실패 %d건" % _fails)
	quit(_fails)
	return true
