extends SceneTree
## 폰트 커버리지 검사 (CI 스텝). 표시되는 모든 글자가 서브셋 폰트에 실제로 들어 있는지 확인한다.
##
## 왜 필요한가: assets/fonts 의 CJK 폰트는 `tools/subset_fonts.py` 로 "쓰는 글자만" 남겨
## 2.4MB → 0.32MB 로 줄여 놓았다. 그래서 나중에 새 문자가 들어간 문자열을 추가하면
## 화면에 두부(□)가 뜬다 — 눈으로 보기 전까지 모른다. 이 검사가 그걸 빌드에서 막는다.
##
## 새 문자를 추가해 이 검사가 실패하면 tools/subset_fonts.py 의 docstring 을 따라
## 원본 폰트를 받아 다시 서브셋해야 한다.
##
##   실행: godot --headless --script res://tools/check_font_coverage.gd

const FONTS := [
	"res://assets/fonts/NotoSansCJK-Subset.otf",
	"res://assets/fonts/NotoSansCJK-Subset-Bold.otf",
]
## 서브셋 이전 **원본에도** 없던 글자 목록. 이 검사는 이 목록을 **면제가 아니라 분류에만** 쓴다 —
## 여기 있는 글자를 문자열에 쓰면 그것도 실패다. 되살릴 수 없는 것과 써도 되는 것은 다르기 때문이다.
##
## 예전에는 이 목록의 글자를 검사에서 건너뛰었다. 그래서 일본어 문자열 10개가 이 글자들을 쓰는데도
## CI 는 초록이었고 화면에는 두부(□)가 떴다(HANDOFF P1-17 — 23자). "고칠 수 없으니 묻지 않는다"가
## "써도 된다"로 읽힌 것이다. 지금은 묻는다. 대신 실패 메시지에서 둘을 갈라 준다:
##   · 재서브셋으로 살릴 수 있는 글자 → tools/subset_fonts.py 를 다시 돌린다
##   · 원본에도 없는 글자          → 되살릴 방법이 없다. 그 글자를 피해 문구를 바꾼다
const KNOWN_ABSENT := "res://tools/font_known_absent.txt"
## 표시 문자열이 들어 있는 데이터 폴더(아이템/캐릭터 이름·설명 등).
const DATA_DIR := "res://data"

var _fails: Array = []


func _read_absent() -> Dictionary:
	var out := {}
	var f := FileAccess.open(KNOWN_ABSENT, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("#"):
			continue
		for i in line.length():
			out[line[i]] = true
	return out


## Locale 사전의 모든 언어 문자열 — 오토로드가 없는 --script 컨텍스트라 상수를 직접 읽는다.
func _collect_locale(used: Dictionary) -> void:
	var sc: GDScript = load("res://scripts/Locale.gd")
	if sc == null:
		_fails.append("Locale.gd 로드 실패")
		return
	var strings: Dictionary = sc.get_script_constant_map().get("STRINGS", {})
	if strings.is_empty():
		_fails.append("Locale.STRINGS 를 읽을 수 없음")
		return
	for key in strings.keys():
		var entry: Dictionary = strings[key]
		for lang in entry.keys():
			var s: String = str(entry[lang])
			for i in s.length():
				used[s[i]] = true


## data/*.tres 의 텍스트를 그대로 훑는다(이름·설명 필드가 UI 에 노출된다).
func _collect_data(used: Dictionary) -> void:
	var d := DirAccess.open(DATA_DIR)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if not d.current_is_dir() and name.ends_with(".tres"):
			var f := FileAccess.open(DATA_DIR.path_join(name), FileAccess.READ)
			if f != null:
				var t := f.get_as_text()
				for i in t.length():
					var c := t[i]
					if c.unicode_at(0) > 0x7F:
						used[c] = true
		name = d.get_next()
	d.list_dir_end()


func _initialize() -> void:
	var absent := _read_absent()
	var used := {}
	_collect_locale(used)
	_collect_data(used)
	print("[FONT] 표시 문자 %d자 수집 (원본에도 없는 글자 %d자 — 쓰면 실패한다)"
		% [used.size(), absent.size()])

	for p in FONTS:
		var font: Font = load(p)
		if font == null:
			_fails.append("%s 로드 실패" % p)
			continue
		# 글리프가 없으면 폭이 0 이 되므로, 대표 문자열로 기본 동작을 먼저 확인한다.
		for sample in ["Zombie Buster", "감염에서 살아남아라", "アウトブレイク"]:
			if font.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x <= 0.0:
				_fails.append("%s: \"%s\" 폭이 0" % [p.get_file(), sample])
		# 없는 글리프를 둘로 나눈다 — 고치는 방법이 다르기 때문이다(위 KNOWN_ABSENT 주석 참고).
		var resubset: Array = []   # 원본에는 있다 → 다시 서브셋하면 살아난다
		var hopeless: Array = []   # 원본에도 없다 → 문구를 바꾸는 수밖에 없다
		for ch in used.keys():
			var c: String = ch
			if c.strip_edges() == "":
				continue
			if font.has_char(c.unicode_at(0)):
				continue
			if absent.has(c):
				hopeless.append(c)
			else:
				resubset.append(c)
		if resubset.is_empty() and hopeless.is_empty():
			print("[FONT] %s: OK" % p.get_file())
		if not resubset.is_empty():
			_fails.append("%s: 글리프 %d자 누락(재서브셋으로 복구 가능) → %s"
				% [p.get_file(), resubset.size(), "".join(resubset)])
		if not hopeless.is_empty():
			_fails.append("%s: 글리프 %d자 누락(원본에도 없음 — 문구를 바꿔야 한다) → %s"
				% [p.get_file(), hopeless.size(), "".join(hopeless)])

	if _fails.is_empty():
		print("[FONT] 커버리지 검사 통과")
		quit(0)
		return
	for x in _fails:
		print("[FONT] 실패: " + x)
	print("[FONT] '재서브셋으로 복구 가능' 은 tools/subset_fonts.py 를 다시 돌리면 된다.")
	print("[FONT] '원본에도 없음' 은 되살릴 방법이 없다 — 그 글자를 피해 문구를 바꿔라")
	print("[FONT]   (일본어는 가나 표기로 우회한다. scripts/Locale.gd 의 선례 참고).")
	quit(1)
