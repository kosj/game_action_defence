extends SceneTree
## 아틀라스 파이프라인 검사 (CI 스텝).
##
## 배경: 좀비·보스·그림자·젬·총알 스프라이트는 `tools/build_atlas.py` 로 아틀라스 한 장에
## 묶여 있다. Main 이 y_sort 라 이 스프라이트들이 Y 순서로 뒤섞여 그려지는데, 텍스처가
## 서로 다르면 배칭이 매 아이템마다 끊긴다(좀비 300마리 = 약 600 드로우 콜).
##
## 이 검사가 막는 것:
##  1. 아틀라스에 있는 스프라이트를 **PNG 경로로 직접 참조**하는 코드/씬/데이터
##     → 그 스프라이트만 아틀라스 밖 텍스처가 되어 배칭이 다시 끊긴다
##  2. AtlasTexture 의 region 크기가 원본과 달라지는 것
##     → get_size() 로 스케일·그림자 크기를 잡는 코드가 조용히 틀어진다
##
## 새 스프라이트 추가 절차는 tools/build_atlas.py 의 docstring 참고.
##   실행: godot --headless --script res://tools/check_atlas.gd

const ATLAS_DIRS := [
	"res://assets/atlas",
	"res://assets/atlas/ui",
	"res://assets/atlas/ui/frames",
	"res://assets/atlas/ui/hud",
	# 초상화·테마 썸네일은 메인메뉴에서만 쓴다 — 갈라 둬야 인게임 VRAM 에 안 남는다.
	"res://assets/atlas/menu",
	# 프롭은 테마별로 나뉘어 있다 — 한 판에 한 테마만 로드된다(ASSET_PIPELINE.md 1절).
	"res://assets/atlas/props/suburb",
	"res://assets/atlas/props/city",
	"res://assets/atlas/props/lab",
]
const SRC_DIR := "res://assets/sprites"
## 참조를 훑을 폴더(아틀라스 자신은 제외).
const SCAN_DIRS := ["res://scripts", "res://scenes", "res://data", "res://tools"]

var _fails: Array = []


## 스템 -> 그 스템의 .tres 경로. 같은 이름이 게임플레이/UI 양쪽에 있을 수 있으므로
## (예: weapon_boomerang) 경로까지 들고 있어야 크기 비교를 올바른 쪽과 할 수 있다.
func _atlas_stems() -> Dictionary:
	var out := {}
	for dir_path in ATLAS_DIRS:
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if not d.current_is_dir() and f.ends_with(".tres"):
				out[f.get_basename()] = dir_path.path_join(f)
			f = d.get_next()
		d.list_dir_end()
	return out


## region 크기가 원본 PNG 와 같은지 — 다르면 스케일 계산이 어긋난다.
func _check_sizes(stems: Dictionary) -> void:
	for stem in stems.keys():
		var tex: Texture2D = load(stems[stem])
		if tex == null:
			_fails.append("%s.tres 로드 실패" % stem)
			continue
		if not (tex is AtlasTexture):
			_fails.append("%s.tres 가 AtlasTexture 가 아님" % stem)
			continue
		var src_path := "%s/%s.png" % [SRC_DIR, stem]
		if not ResourceLoader.exists(src_path) or str(stems[stem]).contains("/atlas/ui/"):
			continue   # 원본이 다른 하위 폴더(ui/icons 등)에 있으면 크기 비교는 생략
		var src: Texture2D = load(src_path)
		if src != null and src.get_size() != tex.get_size():
			_fails.append("%s: 아틀라스 %s vs 원본 %s (크기 불일치)"
				% [stem, str(tex.get_size()), str(src.get_size())])


## 아틀라스 대상 스프라이트를 PNG 경로로 직접 참조하는 곳이 있으면 실패.
func _scan(dir_path: String, stems: Dictionary) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir_path.path_join(f)
		if d.current_is_dir():
			if not f.begins_with("."):
				_scan(p, stems)
		elif f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres"):
			var fa := FileAccess.open(p, FileAccess.READ)
			if fa != null:
				var text := fa.get_as_text()
				for stem in stems.keys():
					# 하위 폴더(props/ 등)까지 포함해 어떤 경로로든 그 PNG 를 가리키면 잡는다.
					if text.contains("/%s.png" % stem) and (text.contains("assets/sprites") or text.contains("assets/ui/")):
						_fails.append("%s: '%s.png' 를 직접 참조 (%s 를 쓰세요)"
							% [p, stem, stems[stem]])
		f = d.get_next()
	d.list_dir_end()


## 생성된 AtlasTexture 가 실제 런타임 경로에서 참조되는지 검사한다. 소스 PNG가 글롭에 걸리기만
## 하면 아틀라스에 들어가므로, 이 검사가 없으면 이미 교체된 그림도 시트 면적과 VRAM을 차지한다.
## 메뉴 초상화·테마 프롭·HUD는 문자열로 경로를 조립하므로 해당 전용 폴더만 동적 참조로 허용한다.
func _check_runtime_references() -> void:
	var text := ""
	for dir_path in SCAN_DIRS:
		text += _read_tree(dir_path)
	for dir_path in ATLAS_DIRS:
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if not d.current_is_dir() and f.ends_with(".tres"):
				var path: String = dir_path.path_join(f)
				var dynamic: bool = path.contains("/atlas/menu/") or path.contains("/atlas/props/") \
					or path.contains("/atlas/ui/hud/")
				if not dynamic and not text.contains(path):
					_fails.append("미사용 아틀라스 항목: %s (원본 PNG도 정리하세요)" % path)
			f = d.get_next()
		d.list_dir_end()


func _read_tree(dir_path: String) -> String:
	var out := ""
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir_path.path_join(f)
		if d.current_is_dir():
			if not f.begins_with("."):
				out += _read_tree(p)
		elif f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres"):
			var fa := FileAccess.open(p, FileAccess.READ)
			if fa != null:
				out += fa.get_as_text()
		f = d.get_next()
	return out


func _initialize() -> void:
	var stems := _atlas_stems()
	if stems.is_empty():
		print("[ATLAS] assets/atlas 에 AtlasTexture 가 없습니다 — build_atlas.py 를 실행하세요")
		quit(1)
		return
	print("[ATLAS] 아틀라스 항목 %d개" % stems.size())
	_check_sizes(stems)
	for dir_path in SCAN_DIRS:
		_scan(dir_path, stems)
	_check_runtime_references()

	if _fails.is_empty():
		print("[ATLAS] 검사 통과 (크기 일치 + 직접 참조 없음 + 미사용 항목 없음)")
		quit(0)
		return
	for x in _fails:
		print("[ATLAS] 실패: " + x)
	print("[ATLAS] tools/build_atlas.py 의 안내를 따르세요.")
	quit(1)
