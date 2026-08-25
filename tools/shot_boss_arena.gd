@tool
extends SceneTree
## 보스전 실제 렌더 화면 덤프 — 창 모드로 Main 을 띄우고 치트로 보스를 소환한 뒤,
## 뷰포트 텍스처를 그대로 PNG 로 저장한다. 보스 등장 직후 한 장, 플레이어를 경계에 밀어붙여 한 장.
##
## **헤드리스(--headless)로는 잡을 수 없는 것을 잡기 위한 도구다.** 헤드리스에서도 _draw 는
## 호출되고 오류도 안 나지만, 그려진 것이 다른 레이어에 덮였는지는 알 수 없다 — 격리 구역을
## z=-5 로 두는 바람에 배경 ColorRect(z=-3)에 통째로 가려져 화면에서 안 보인 적이 있다.
## 보스 관련 비주얼을 손댔으면 이걸로 실제 픽셀을 확인한다.
##
##   godot --path . --fixed-fps 60 --script res://tools/shot_boss_arena.gd
##
## 저장 위치는 user:// (실행 시 절대경로를 출력한다).

const DT := 1.0 / 60.0
const OUT := "user://arena_shot_"

var _t := 0.0
var _started := false
var _spawned := false
var _shots := 0


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
		root.add_child(main)
		current_scene = main
		return false
	_t += DT
	if not _spawned and _t > 0.8:
		_spawned = true
		# 시그널을 직접 쏘지 않는다 — 게이트를 지나는 진입점을 쓴다(P0-1, Cheats.gd 참고).
		root.get_node("Cheats").request_spawn_boss()
	if not _spawned:
		return false

	# 전개가 끝난 뒤 한 장, 그다음 플레이어를 경계로 밀어붙여 한 장.
	if _shots == 0 and _t > 2.0:
		_grab("center")
		return false
	# 매 프레임 바깥으로 밀어 경계에 붙인 상태를 유지한다(스파크가 터지는 상황).
	if _t > 2.2:
		var pl: Node2D = get_first_node_in_group("player")
		var ar: Node2D = get_first_node_in_group("boss_arena")
		if pl != null and ar != null:
			pl.global_position = ar.global_position + Vector2(0, ar.radius + 120.0)
	if _shots == 1 and _t > 2.5:
		_grab("edge")
		quit(0)
		return true
	return false


func _grab(tag: String) -> void:
	var img := root.get_texture().get_image()
	var path := OUT + tag + ".png"
	img.save_png(path)
	print("저장: %s  (%dx%d)  실제경로=%s" % [path, img.get_width(), img.get_height(),
			ProjectSettings.globalize_path(path)])
	_shots += 1
