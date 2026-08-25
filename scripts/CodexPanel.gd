extends RefCounted
## 도감 화면 (HANDOFF P1-13). 발견한 것은 아이콘 + 이름, 못 본 것은 실루엣 + `???`.
##
## 왜 이름을 숨기는가: 채워진 칸이 아니라 **비어 있는 칸**이 다음 판의 이유가 된다.
## 이름까지 보이면 "아직 안 뽑았을 뿐"이지만, 실루엣만 보이면 "저게 뭔지 봐야겠다"가 된다.
##
## MainMenu.gd 밖에 두는 이유: 그 파일은 이미 1,100줄이고 여러 세션이 동시에 건드리는
## 충돌 1순위다(CLAUDE.md §1). 팝업 하나가 200줄이면 그 위에 더 쌓지 않는 편이 낫다.
##
## 아트 비용 0 — 무기·패시브 아이콘은 UI 아틀라스, 좀비·보스는 게임플레이 아틀라스,
## 초상·아레나 썸네일은 메뉴 아틀라스에 **이미 있는 것을 그대로 쓴다.**
## 다만 게임플레이 아틀라스(767KB)는 메뉴에 상주하지 않으므로 이 패널은 **처음 열 때
## 만든다** — 도감을 열지 않는 사람의 메뉴 진입 비용을 늘리지 않기 위해서다(MainMenu 참고).

const _UIPopup := preload("res://scripts/UIPopup.gd")
const _Spawner := preload("res://scripts/ZombieSpawner.gd")   # THEME_BOSSES(보스 이름/아트)

const COLS := 4
const TILE_W := 148.0
const TILE_H := 96.0
const ICON_PX := 52.0
const NAME_SIZE := 12
## 미발견 실루엣 색. 셰이더가 알파만 남기고 RGB 를 이 색으로 갈아끼운다 —
## 곱셈(modulate)으로는 색이 새거나 배경에 묻힌다(codex_silhouette.gdshader 주석 참고).
## 팝업 배경(0.11~0.17)보다 확실히 밝아야 형태가 읽힌다.
const SILHOUETTE := Color(0.34, 0.37, 0.46, 1.0)
const _SILHOUETTE_SHADER := preload("res://assets/shaders/codex_silhouette.gdshader")
const UNKNOWN_TEXT := "???"

var dim: ColorRect = null
var panel: PanelContainer = null

var _progress: Label = null
var _sections: Array = []   # [{kind, label, title_key, tiles:[{id, name, icon, thumb, name_lbl}]}]
var _sil_mat: ShaderMaterial = null


## 팝업을 만든다. 내용 갱신은 refresh() — 열 때마다 부른다.
func build(parent: Node, on_close: Callable) -> void:
	var p := _UIPopup.make(parent, "menu_codex", UITheme.SEC_CODEX, UITheme.SEC_CODEX_TXT,
		on_close, {"scroll": true, "hint_key": "codex_hint", "separation": 10})
	dim = p["dim"]
	panel = p["panel"]

	# 진행도는 제목 바로 아래(구분선 위) — 목록을 보기 전에 "얼마나 채웠는지"를 먼저 읽게 한다.
	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress.add_theme_font_size_override("font_size", 20)
	_progress.add_theme_color_override("font_color", UITheme.SEC_CODEX_TXT)
	var vb: VBoxContainer = p["vbox"]
	vb.add_child(_progress)
	vb.move_child(_progress, 1)

	var body: VBoxContainer = p["body"]
	body.add_theme_constant_override("separation", 14)

	_add_section(body, "weapon", "codex_sec_weapon", _weapon_entries(false))
	_add_section(body, "evolution", "codex_sec_evolution", _weapon_entries(true))
	_add_section(body, "passive", "codex_sec_passive", _passive_entries())
	_add_section(body, "zombie", "codex_sec_zombie", _zombie_entries())
	_add_section(body, "boss", "codex_sec_boss", _boss_entries())
	_add_section(body, "character", "codex_sec_survivor", _character_entries())
	_add_section(body, "arena", "codex_sec_arena", _arena_entries())


## 발견 상태를 다시 칠한다. 노드는 만들지 않는다 — 열 때마다 목록을 재조립하면
## 게임플레이 아틀라스가 매번 다시 올라간다.
func refresh() -> void:
	var found := 0
	var total := 0
	for sec in _sections:
		var kind: String = sec["kind"]
		var n := 0
		for tile in sec["tiles"]:
			var got := _is_found(kind, String(tile["id"]))
			if got:
				n += 1
			tile["thumb"].material = null if got else _silhouette_mat()
			tile["name_lbl"].text = String(tile["name"]) if got else UNKNOWN_TEXT
			tile["name_lbl"].add_theme_color_override("font_color",
				UITheme.TEXT if got else UITheme.TEXT_DIM)
		var count: int = sec["tiles"].size()
		sec["label"].text = "%s   %d/%d" % [Locale.t(String(sec["title_key"])), n, count]
		found += n
		total += count
	if _progress:
		_progress.text = Locale.t("codex_progress") % [found, total]


## 언어 전환 대응 — 절 제목/진행도 문구는 refresh 가 다시 넣는다. 항목 이름은 카탈로그의
## display 라서 번역하지 않는다(무기·캐릭터·아레나 이름은 전 언어 공통이다).
func apply_language() -> void:
	refresh()


## 캐릭터만 저장하지 않는다 — 해금 상태를 CharacterManager 가 이미 영속으로 들고 있다.
## 같은 사실을 두 곳에 적으면 언젠가 어긋난다(CodexManager 주석 참고).
func _is_found(kind: String, id: String) -> bool:
	if kind == "character":
		var c: CharacterData = GameData.character(id)
		return c != null and CharacterManager.is_unlocked(c)
	return CodexManager.has(kind, id)


## 셰이더 머티리얼은 **한 장을 공유한다** — 칸마다 만들면 60개가 생기고 그만큼
## 드로우콜이 갈린다(같은 머티리얼이면 배칭이 유지된다).
func _silhouette_mat() -> ShaderMaterial:
	if _sil_mat == null:
		_sil_mat = ShaderMaterial.new()
		_sil_mat.shader = _SILHOUETTE_SHADER
		_sil_mat.set_shader_parameter("tint", SILHOUETTE)
	return _sil_mat


func _add_section(body: VBoxContainer, kind: String, title_key: String, entries: Array) -> void:
	var head := Label.new()
	head.add_theme_font_size_override("font_size", 17)
	head.add_theme_color_override("font_color", UITheme.SEC_CODEX_TXT)
	UITheme.heading(head)
	body.add_child(head)

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)

	var tiles: Array = []
	for e in entries:
		tiles.append(_make_tile(grid, e))
	_sections.append({"kind": kind, "label": head, "title_key": title_key, "tiles": tiles})


## 칸 하나 = [아이콘] 위, [이름] 아래. 이름은 autowrap 을 켜지 않는다 —
## 켜면 Label 의 최소 폭이 "가장 긴 단어"로 잡혀 4열이 화면 밖으로 밀린다(테마 카드와 같은 함정).
func _make_tile(grid: GridContainer, e: Dictionary) -> Dictionary:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(TILE_W, TILE_H)
	cell.add_theme_constant_override("separation", 4)
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_child(cell)

	var thumb: Control
	var tex: Texture2D = e.get("icon", null)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
		tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		thumb = tr
	else:
		# 아이콘이 없는 항목은 카탈로그 색 사각형으로 자리를 지킨다(빈 칸으로 보이지 않게).
		var cr := ColorRect.new()
		cr.color = e.get("color", UITheme.TEXT_DIM)
		cr.custom_minimum_size = Vector2(ICON_PX * 0.7, ICON_PX * 0.7)
		cr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		thumb = cr
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(thumb)

	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", NAME_SIZE)
	name_lbl.clip_text = true
	name_lbl.custom_minimum_size = Vector2(TILE_W, 0)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(name_lbl)

	return {"id": e["id"], "name": e["name"], "thumb": thumb, "name_lbl": name_lbl}


# ── 카탈로그 → 항목 목록 ────────────────────────────────────────────────────

## 진화 결과 무기 id 집합. 무기/진화 절을 가르는 기준이며, 캐릭터 궁극기 3종은
## evolved=true 지만 진화 규칙에 없으므로 무기 절에 남는다(레벨업 카드로 해금되는 무기다).
func _evolution_ids() -> Dictionary:
	var out: Dictionary = {}
	for e in GameData.evolution_defs:
		out[e.into_id] = true
	return out


func _weapon_entries(evolved: bool) -> Array:
	var evo := _evolution_ids()
	var out: Array = []
	for w in ItemDB.weapons():
		if evo.has(String(w["id"])) == evolved:
			out.append({"id": w["id"], "name": w["name"], "icon": w["icon"], "color": w["color"]})
	return out


func _passive_entries() -> Array:
	var out: Array = []
	for p in ItemDB.passives():
		out.append({"id": p["id"], "name": p["name"], "icon": p["icon"], "color": p["color"]})
	return out


## 좀비는 표시 이름이 데이터에 없다(ZombieData 는 id 만 가진다). id 를 그대로 쓰되
## capitalize() 로 다듬는다 — "longneck" → "Longneck", 언더바가 있으면 낱말로 갈린다.
func _zombie_entries() -> Array:
	var out: Array = []
	for z in GameData.zombie_list:
		out.append({"id": z.id, "name": String(z.id).capitalize(), "icon": z.texture,
			"color": z.modulate})
	return out


func _boss_entries() -> Array:
	var out: Array = []
	for key in _Spawner.THEME_BOSSES:
		var b: Dictionary = _Spawner.THEME_BOSSES[key]
		out.append({"id": key, "name": b["name"], "icon": _load_tex(String(b.get("sprite", ""))),
			"color": b["tint"]})
	return out


func _character_entries() -> Array:
	var out: Array = []
	for c in GameData.characters:
		out.append({"id": c.id, "name": c.display, "color": c.color,
			"icon": _load_tex("res://assets/atlas/menu/portrait_%s.tres" % c.id)})
	return out


func _arena_entries() -> Array:
	var out: Array = []
	for t in GameData.themes:
		out.append({"id": t.id, "name": t.display, "color": t.mark,
			"icon": _load_tex("res://assets/atlas/menu/theme_%s.tres" % t.id)})
	return out


func _load_tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var t = load(path)
	return t if t is Texture2D else null
