extends SceneTree
## 치트 릴리스 차단 게이트 검증 (P0-1).
##   godot --headless --path . --script res://tools/verify_cheat_gate.gd
## 종료 코드 = 실패 개수.
##
## 왜 필요한가: 치트는 점수·랭킹·도전과제·퀘스트·메타 골드를 전부 오염시킨다. 특히 AUTO-PLAY 는
## 방치 파밍을 허용해 리더보드를 무의미하게 만든다. 게이트가 조용히 풀리면 **화면으로는 알 수
## 없고** 랭킹이 오염된 뒤에야 드러나므로, 잠긴 쪽 동작을 코드로 못박아 둔다.
##
## 헤드리스는 항상 디버그 빌드라 릴리스를 그대로 재현할 수 없다. Cheats.enabled 를 내려
## "잠긴 빌드"를 흉내 내고, 원래 값으로 되돌린 뒤 열린 쪽도 함께 확인한다
## (게이트를 걸다가 개발 빌드의 치트까지 죽이는 것도 회귀다).
##
## ⚠️ 산출물에서 "AUTO-PLAY" 문자열을 찾는 방식은 쓰지 않는다 — **수정 전 빌드에서도 0건**이라
## 아무것도 판별하지 못한다(실측함). Godot 은 .gd 를 .gdc 로 토큰화해 내보내므로 스크립트 안의
## 문자열 리터럴은 pck 에서 평문으로 검색되지 않는다. 같은 이유로 MUTANT HOUND 같은 다른
## 리터럴도 잡히지 않는다. 그래서 대신 **실제 스위치인 export 프리셋**을 여기서 검사한다.

var _fails := 0
var _done := false


func _ok(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("  FAIL %s%s" % [label, ("  — " + detail) if detail != "" else ""])


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var cheats := root.get_node("Cheats")

	print("── 게이트 판정 ──────────────────────────────────")
	# 헤드리스/에디터는 디버그 빌드라 열려 있어야 한다 — 개발 중 치트가 죽으면 그것도 회귀다.
	_ok("디버그 빌드에서는 게이트가 열려 있다", cheats.enabled,
		"OS.is_debug_build()=%s" % OS.is_debug_build())

	print("── 잠긴 빌드(릴리스) ────────────────────────────")
	cheats.enabled = false
	cheats.autoplay = true   # 어떤 경로로든 상태가 켜져 있었다고 가정한다

	_ok("게이트가 닫히면 autoplay_active() 는 거짓", not cheats.autoplay_active(),
		"상태가 true 여도 잠겨 있으면 동작하지 않아야 한다")

	cheats.autoplay = false
	cheats.toggle_autoplay()
	_ok("잠긴 빌드에서는 autoplay 를 켤 수 없다", not cheats.autoplay)

	# 발신 게이트 — request_* 는 아무 신호도 내보내지 않아야 한다.
	var hits := {"time": 0, "fill": 0, "boss": 0}
	var f_time := func(_s: float) -> void: hits["time"] += 1
	var f_fill := func() -> void: hits["fill"] += 1
	var f_boss := func() -> void: hits["boss"] += 1
	cheats.time_skip.connect(f_time)
	cheats.spawn_fill.connect(f_fill)
	cheats.spawn_boss.connect(f_boss)

	cheats.request_time_skip(300.0)
	cheats.request_spawn_fill()
	cheats.request_spawn_boss()
	_ok("잠긴 빌드에서는 request_time_skip 이 신호를 내지 않는다", hits["time"] == 0)
	_ok("잠긴 빌드에서는 request_spawn_fill 이 신호를 내지 않는다", hits["fill"] == 0)
	_ok("잠긴 빌드에서는 request_spawn_boss 가 신호를 내지 않는다", hits["boss"] == 0)

	print("── 열린 빌드(개발) ──────────────────────────────")
	cheats.enabled = true
	cheats.request_time_skip(300.0)
	cheats.request_spawn_fill()
	cheats.request_spawn_boss()
	_ok("열린 빌드에서는 세 신호가 그대로 나간다",
		hits["time"] == 1 and hits["fill"] == 1 and hits["boss"] == 1,
		"time=%d fill=%d boss=%d" % [hits["time"], hits["fill"], hits["boss"]])

	cheats.toggle_autoplay()
	_ok("열린 빌드에서는 autoplay 가 켜진다", cheats.autoplay and cheats.autoplay_active())
	cheats.toggle_autoplay()   # 원복 — 이어지는 검사에 영향을 주지 않게

	cheats.time_skip.disconnect(f_time)
	cheats.spawn_fill.disconnect(f_fill)
	cheats.spawn_boss.disconnect(f_boss)

	print("── 소비처가 게이트를 우회하지 않는가 ─────────────")
	# Player·LevelUpPanel 은 Cheats.autoplay 를 직접 읽으면 안 된다(잠금이 무의미해진다).
	# 소스를 직접 훑는다 — 실행 경로로는 "안 읽는다"를 증명할 수 없다.
	for path in ["res://scripts/Player.gd", "res://scripts/LevelUpPanel.gd", "res://scripts/HUD.gd"]:
		var src := FileAccess.get_file_as_string(path)
		var bad := 0
		for line in src.split("\\n"):
			var t := String(line).strip_edges()
			if t.begins_with("#"):
				continue
			if t.contains("Cheats.autoplay") and not t.contains("Cheats.autoplay_active"):
				bad += 1
		_ok("%s 가 Cheats.autoplay 를 직접 읽지 않는다" % path.get_file(), bad == 0,
			"%d 곳" % bad)

	print("── export 프리셋 ────────────────────────────────")
	# 배포 빌드가 잠기는 실제 근거는 프리셋의 custom_features 다. 여기에 "cheats" 가 들어가면
	# OS.has_feature("cheats") 가 참이 되어 위 게이트가 통째로 열린다 — 한 글자로 P0 가 되살아난다.
	# (개발용 치트 빌드를 따로 두게 되면 그 프리셋 이름을 이 검사에 알려줘야 한다)
	var cfg := ConfigFile.new()
	var err := cfg.load("res://export_presets.cfg")
	_ok("export_presets.cfg 를 읽을 수 있다", err == OK, "err=%d" % err)
	if err == OK:
		var leaked := ""
		for section in cfg.get_sections():
			if not cfg.has_section_key(section, "custom_features"):
				continue
			var feats := String(cfg.get_value(section, "custom_features", ""))
			if feats.to_lower().contains("cheats"):
				leaked += "%s(%s) " % [String(cfg.get_value(section, "name", section)), feats]
		_ok("어떤 프리셋도 custom_features 에 cheats 를 켜지 않는다", leaked == "", leaked)

	print("──────────────────────────────────────────────────")
	print("실패 %d건" % _fails)
	quit(_fails)
	return true
