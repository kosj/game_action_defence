extends SceneTree
## 사운드 키 정합성 게이트 (P2-12).
##
## 왜 필요한가
## -----------
## 효과음 호출은 **틀려도 아무 일이 일어나지 않는다.** `SoundManager.play()` 는 모르는 키를
## 받으면 조용히 돌아간다 — 예외도, 경고도, 로그도 없다. 그래서 이 계통의 오류는 전부
## "소리가 안 난다" 라는 하나의 증상으로만 나타나고, 그건 아무도 CI 에서 못 본다.
##
## 실제로 두 방향 모두 일어났다.
##   · 키는 남았는데 쓰는 데가 없어짐 — 무기가 삭제됐는데 `swing` 이 남아 파일까지 배포에
##     실려 다녔다(P2-11 에서 정리).
##   · 쓰는 데는 있는데 키가 없음 — 오타 한 글자면 그 소리는 영영 안 난다.
##
## 그래서 여기서 네 가지를 본다.
##   1. 호출부가 쓰는 키가 전부 `_SOUNDS` 에 있는가         (오타 · 삭제된 키 참조)
##   2. `_SOUNDS` 의 키가 전부 어딘가에서 쓰이는가          (고아 — 배포에 실리는 죽은 자산)
##   3. `_VOLUMES`·`_MIN_INTERVAL` 의 키가 `_SOUNDS` 에 있는가 (설정만 남은 유령)
##   4. 파일이 아직 없는 키는 무엇인가                      (실패 아님 — 선택 사운드 규약)
##
## 4번을 실패로 잡지 않는 이유: 이 프로젝트는 "파일이 없으면 조용히 생략되고, 넣는 순간
## 자동으로 붙는다"를 의도적으로 쓴다. 다만 **의도한 공백인지 사고인지 구분되어야** 하므로
## 목록을 항상 찍는다.
##
##   godot --headless --path . --script res://tools/verify_sound_keys.gd

## 코드가 아니라 데이터에서 키를 고르는 곳 — 여기 값도 `_SOUNDS` 에 있어야 한다.
## (`Player._shoot_dir` 이 `current_weapon["sfx"]` 를 그대로 재생한다)
const WEAPON_DB := preload("res://scripts/WeaponDB.gd")
## 같은 이유로 하나 더 — `HUDAlert.flash` 가 위험도로 골라 재생한다(`SOUND[lv]`).
## 아래 `_scan_call_sites()` 는 리터럴만 훑으므로, 이런 표는 여기에 적어 둬야 고아로 잡히지 않는다.
const HUD_ALERT := preload("res://scripts/HUDAlert.gd")

var _fail := 0


func _init() -> void:
	await process_frame
	var sm := root.get_node("SoundManager")
	var consts: Dictionary = sm.get_script().get_script_constant_map()
	var sounds: Dictionary = consts["_SOUNDS"]

	var used := _scan_call_sites()
	for w in WEAPON_DB.WEAPONS:
		used[String(w.get("sfx", ""))] = "scripts/WeaponDB.gd"
	for key in HUD_ALERT.SOUND:
		used[String(key)] = "scripts/HUDAlert.gd"

	# 1) 호출부 → 키
	var unknown: Array = []
	for key in used:
		if key != "" and not sounds.has(key):
			unknown.append("%s (%s)" % [key, used[key]])
	if unknown.is_empty():
		print("  ok   호출부가 쓰는 키 %d종 전부 _SOUNDS 에 있다" % used.size())
	else:
		_fail += 1
		unknown.sort()
		print("  FAIL _SOUNDS 에 없는 키를 재생한다 → %s" % ", ".join(unknown))
		print("       play() 는 모르는 키를 조용히 무시한다 — 이건 '소리가 안 남'으로만 보인다.")

	# 2) 키 → 호출부
	var orphan: Array = []
	for key in sounds:
		if not used.has(key):
			orphan.append(String(key))
	if orphan.is_empty():
		print("  ok   _SOUNDS 의 키 %d종 전부 쓰이는 곳이 있다" % sounds.size())
	else:
		_fail += 1
		orphan.sort()
		print("  FAIL 아무 데서도 쓰지 않는 키 → %s" % ", ".join(orphan))
		print("       자산이 삭제된 뒤 남은 흔적일 수 있다(P2-11). 키·볼륨·파일을 함께 정리할 것.")

	# 3) 설정 딕셔너리 → 키
	for name in ["_VOLUMES", "_MIN_INTERVAL"]:
		var ghost: Array = []
		for key in (consts[name] as Dictionary):
			if not sounds.has(key):
				ghost.append(String(key))
		if ghost.is_empty():
			print("  ok   %s 의 키가 전부 _SOUNDS 에 있다" % name)
		else:
			_fail += 1
			ghost.sort()
			print("  FAIL %s 에 _SOUNDS 없는 키가 남아 있다 → %s" % [name, ", ".join(ghost)])

	# 4) 파일이 아직 없는 키(실패 아님 — 선택 사운드 규약)
	var pending: Array = []
	for key in sounds:
		if not ResourceLoader.exists(String(sounds[key])):
			pending.append(String(key))
	if pending.is_empty():
		print("  ok   %d종 전부 파일이 있다" % sounds.size())
	else:
		pending.sort()
		print("  --   파일 대기 중인 키 %d종 → %s" % [pending.size(), ", ".join(pending)])
		print("       (선택 사운드 — 파일이 들어오면 자동으로 붙는다. 호출부에 폴백이 있는지 확인할 것)")

	if _fail == 0:
		print("\n사운드 키 정합성 OK")
		quit(0)
	else:
		print("\n사운드 키 정합성 실패 %d건" % _fail)
		quit(1)


## scripts/ 전체에서 `play("x")` · `play_ui("x")` · `has_stream("x")` 의 리터럴 키를 모은다.
## 리터럴이 아닌 호출(`play(current_weapon["sfx"])`)은 여기서 안 잡히므로 WEAPON_DB 를 따로 훑는다.
func _scan_call_sites() -> Dictionary:
	var re := RegEx.new()
	# `SoundManager.` 를 반드시 붙여 찾는다 — 그냥 `play("...")` 로 두면 나중에 누가
	# `anim.play("idle")` 을 쓰는 순간 "idle" 이 사운드 키로 잡혀 엉뚱하게 실패한다.
	re.compile('SoundManager\\.(?:play|play_ui|has_stream)\\(\\s*"([a-z_]+)"')
	var used := {}
	var stack: Array[String] = ["res://scripts"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			var p := dir_path.path_join(f)
			if d.current_is_dir():
				stack.append(p)
			elif f.ends_with(".gd") and f != "SoundManager.gd":
				var text := FileAccess.get_file_as_string(p)
				for m in re.search_all(text):
					used[m.get_string(1)] = p.replace("res://", "")
			f = d.get_next()
		d.list_dir_end()
	return used
