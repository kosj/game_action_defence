@tool
extends SceneTree
## HUD 겹침 순서 실렌더 확인 (P1-28).
##
## **헤드리스로는 잡을 수 없는 것을 잡기 위한 도구다.** 로드아웃 슬롯을 종류별(프레임·아이콘·
## 뱃지)로 z 를 갈라 배칭을 살렸는데, z 를 건드리면 "무엇이 무엇을 덮는가"가 바뀔 수 있다.
## 헤드리스는 그것을 알려주지 않는다 — 그려진 것이 다른 레이어에 덮였는지는 픽셀로만 안다.
##
##   xvfb-run -a godot --path . --fixed-fps 60 --script res://tools/shot_hud_layers.gd
##
## 세 장면을 잡는다. 각각이 지키는 것:
##   loadout   — 슬롯 프레임 < 아이콘 < 뱃지 순서가 슬롯마다 유지되는가
##   pause     — 일시정지 딤이 로드아웃 **위**를 덮는가(z 를 안 올리면 아이콘이 새어 나온다)
##   lowhp     — 저체력 오버레이가 로드아웃 위에 깔리는가

const DT := 1.0 / 60.0
const OUT := "user://hud_layers_"

var _t := 0.0
var _started := false
var _shots := 0
var _setup := false


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
		root.add_child(main)
		current_scene = main
		return false
	_t += DT

	# 로드아웃에 슬롯이 여러 개 있어야 의미가 있다 — 무기·패시브를 채운다.
	if not _setup and _t > 0.5:
		_setup = true
		var ev := root.get_node("Events")
		ev.weapons = {"pistol": 5, "gatling": 4, "shotgun": 3, "boomerang": 2,
			"flamethrower": 3, "railgun": 2}
		ev.passives = {"speed": 3, "damage": 4, "armor": 2, "magnet": 3,
			"crit": 2, "regen": 1}
		ev.inventory_changed.emit()
		return false

	if _shots == 0 and _t > 1.2:
		_grab("loadout")
		return false

	# ② 일시정지 — 딤이 로드아웃을 덮어야 한다.
	if _shots == 1 and _t > 1.4:
		var hud := _find(root, "HUD")
		if hud != null and hud.has_method("_on_pause_pressed"):
			hud.call("_on_pause_pressed")
		_shots = 2
		return false
	if _shots == 2 and _t > 2.2:
		_grab("pause")
		var hud2 := _find(root, "HUD")
		if hud2 != null and hud2.has_method("_on_resume_pressed"):
			hud2.call("_on_resume_pressed")
		_shots = 3
		return false

	# ③ 저체력 오버레이 — 로드아웃 위에 붉은 틴트가 깔려야 한다.
	#
	# ⚠️ `player.take_hit()` 로는 안 된다. 피격 쿨다운(_hurt_timer)에 걸리면 조용히 무시되고,
	# 큰 값을 주면 저체력이 아니라 사망이 된다 — 처음에 그렇게 짜서 HP 5/5 인 화면을 찍어 놓고
	# "저체력 확인"이라고 부를 뻔했다. 오버레이를 실제로 켜는 것은 이 이벤트다.
	if _shots == 3 and _t > 2.6:
		root.get_node("Events").update_player_health(1, 5)
		_shots = 4
		return false
	if _shots == 4 and _t > 3.4:
		_grab("lowhp")
		quit(0)
		return true
	return false


func _find(n: Node, nm: String) -> Node:
	if n.name == nm:
		return n
	for c in n.get_children():
		var r := _find(c, nm)
		if r != null:
			return r
	return null


func _grab(tag: String) -> void:
	var img := root.get_texture().get_image()
	var path := OUT + tag + ".png"
	img.save_png(path)
	print("저장: %s  (%dx%d)  실제경로=%s" % [path, img.get_width(), img.get_height(),
			ProjectSettings.globalize_path(path)])
	_shots += 1
