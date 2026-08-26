@tool
extends SceneTree
## 인게임에서 **실제로 상주하는** 텍스처를 찍는다.
##
## 왜 필요한가
##   `OPTIMIZATION_PLAN.md` 에 "인게임 상주 VRAM 32MB → 8MB" 라고 적혀 있었는데, 그건
##   게임플레이·UI **두 아틀라스의 합**이지 총합이 아니었다. 실측하면 30.4MB 다.
##   총합을 재는 수단이 없어서 그 오해가 문서에 그대로 남아 있었다 — 그래서 만들었다.
##
##   LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
##   xvfb-run -a -s "-screen 0 720x1280x24" godot --path . --fixed-fps 60 \
##       --rendering-driver opengl3 --script res://tools/check_vram.gd
##
## ⚠️ `--headless` 로는 의미가 없다(더미 렌더러라 텍스처 메모리가 0).
##
## ⚠️ **Main 을 직접 띄우므로 타이틀·메뉴를 거치지 않는다.** 즉 이 값은 "인게임 바닥값" 이고,
##   실제 플레이는 타이틀 → 메뉴 → 게임이라 그 경로에서 잡힌 것이 더 남아 있을 수 있다.
##   `preload` 는 **그 스크립트가 로드된 뒤에야** 상수 풀로 텍스처를 붙든다 — 그래서
##   TitleScreen.gd 의 `bg_title` 은 여기선 cached=false 로 나오지만 실제 플레이에서는
##   타이틀을 거치므로 남는다. 두 경로의 차이가 곧 "메뉴가 안 놓아준 것" 이다.
##
## 총합(tex_mem)에는 뷰포트 렌더 타깃도 들어간다(720×1280 RGBA = 3.5MB/장). 그래서
## 아래 목록의 합보다 항상 크다 — 목록은 "어떤 그림이 남아 있나"를 보는 용도다.

const DT := 1.0 / 60.0
const SETTLE := 1.5      # Main 이 한 판을 세팅할 시간

var _t := 0.0
var _started := false


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
		root.add_child(main)
		current_scene = main
		return false
	_t += DT
	if _t < SETTLE:
		return false
	print("[VRAM] tex_mem = %.1f MB (뷰포트 렌더 타깃 포함)" % (
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0))
	var total := 0.0
	for e in _scan():
		total += e[0]
		print("[VRAM] %8.2fMB  %s" % [e[0], e[1]])
	print("[VRAM] 상주 PNG 합계 %.1f MB" % total)
	quit(0)
	return true


## 프로젝트의 모든 PNG 중 지금 리소스 캐시에 살아 있는 것만 크기순으로.
func _scan() -> Array:
	var out: Array = []
	for p in _all_png("res://assets"):
		if not ResourceLoader.has_cached(p):
			continue
		var t = ResourceLoader.load(p)
		if t is Texture2D:
			var sz: Vector2i = (t as Texture2D).get_size()
			out.append([float(sz.x * sz.y * 4) / 1048576.0, p])
	out.sort_custom(func(a, b): return a[0] > b[0])
	return out


func _all_png(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var path := dir.path_join(n)
		if d.current_is_dir():
			out.append_array(_all_png(path))
		elif n.ends_with(".png"):
			out.append(path)
		n = d.get_next()
	d.list_dir_end()
	return out
