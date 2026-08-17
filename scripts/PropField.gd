extends Node2D
## 미장센 프롭 필드 — 선택 테마의 장식/장애물 프롭을 필드에 흩뿌린다.
## 월드좌표 해시로 배치해 플레이어가 움직여도 위치가 고정되고, 보이는 범위만 draw 로 그려
## WebGL 성능을 지킨다. z_index -1 로 유닛 뒤.
##
## Phase C:
##  - 프롭마다 메타데이터(표시 크기 / 장애물 여부 / 충돌 반경 비율)를 카탈로그로 관리.
##  - 텍스처는 preload 대신 load()+ResourceLoader.exists 로 불러와, 아트가 아직 없는 프롭은
##    자동으로 건너뛴다 → 나중에 지정 경로에 PNG 만 넣으면 그 프롭이 곧바로 나타난다.
##  - solid=true 프롭은 플레이어의 이동을 막는다(원형 디펜트레이션). 좀비는 통과(성능 — 220마리
##    상대 충돌은 비용이 크므로 제외). 플레이어를 "방해하는" 지형 요소로 기능한다.

const CELL := 260.0                       # 배치 격자(셀당 최대 1개)
const DENSITY := 30                       # 셀당 프롭 확률(해시 %100 < 이 값)
## 바닥(TILE_DARKEN 0.55)과 톤을 맞추기 위한 감광. 프롭 아트 자체에도 채도 -20% + 웜 틴트를
## 베이크해 두었고, 여기서 한 번 더 어둡게 깔아 3D 렌더 프롭이 페인팅 배경 위로 과하게 튀지 않게 한다.
const DARKEN := Color(0.70, 0.68, 0.66)
## 접지 그림자 — 프롭이 지면에 붙어 보이게 해 투시(3/4 렌더 vs 측면 뷰) 불일치를 크게 완화한다.
const _SHADOW_TEX := preload("res://assets/atlas/shadow.tres")
const SHADOW_W := 0.80     # 프롭 폭 대비 그림자 폭
const SHADOW_H := 0.26     # 그림자 폭 대비 높이(납작한 타원)
const SHADOW_COL := Color(0.0, 0.0, 0.0, 0.38)
const PLAYER_R := 16.0                     # 플레이어 충돌 반경(스프라이트 대략)
const SNAP := 128.0                        # 재드로우 격자(_draw 의 margin=CELL 안에 들어와야 한다)
## 프롭은 **테마별 아틀라스**에 따로 묶여 있다(assets/atlas/props/<테마>/).
## 한 판에서 뜨는 테마는 하나뿐이라, 한 장에 합치면 안 쓰는 두 테마의 프롭까지 늘 VRAM 에
## 올라간다. 폴더를 나눠 선택 테마의 시트 한 장만 열리게 한다 — 아래 theme 값이 곧 폴더명이고
## tools/build_atlas.py 의 ATLASES("props_<테마>")·assets/sprites/props/<테마>/ 와 짝을 이룬다.
const PROP_DIR := "res://assets/atlas/props/"

## 프롭 카탈로그: 키 → { file, theme=소속 테마(폴더), w=표시 최대변(px),
##                       solid=장애물여부, rfrac=충돌반경/최소변 비율 }.
## 아직 아트가 없는 키(파일 부재)는 로드 단계에서 자동 제외된다.
## 어느 테마에서 쓸지는 ThemeData.prop_keys 가 정한다 — 여기 있어도 그 목록에 없으면 안 나온다.
const _CATALOG := {
	# 교외
	"fence":     {"file": "prop_fence.png",     "theme": "suburb", "w": 72.0,  "solid": true,  "rfrac": 0.32},
	"mailbox":   {"file": "prop_mailbox.png",   "theme": "suburb", "w": 40.0,  "solid": false, "rfrac": 0.40},
	"bush":      {"file": "prop_bush.png",      "theme": "suburb", "w": 62.0,  "solid": false, "rfrac": 0.40},
	"forsale":   {"file": "prop_forsale.png",   "theme": "suburb", "w": 54.0,  "solid": false, "rfrac": 0.40},
	"hydrant":   {"file": "prop_hydrant.png",   "theme": "suburb", "w": 34.0,  "solid": true,  "rfrac": 0.42},
	# 도심 — wreck_car 는 BurningCar 기믹(도심 전용)도 같은 시트를 쓴다.
	"wreck_car": {"file": "prop_wreck_car.png", "theme": "city",   "w": 120.0, "solid": true,  "rfrac": 0.42},
	"tank":      {"file": "prop_tank.png",      "theme": "city",   "w": 118.0, "solid": true,  "rfrac": 0.42},
	"barrier":   {"file": "prop_barrier.png",   "theme": "city",   "w": 100.0, "solid": true,  "rfrac": 0.40},
	"dumpster":  {"file": "prop_dumpster.png",  "theme": "city",   "w": 82.0,  "solid": true,  "rfrac": 0.42},
	"rubble":    {"file": "prop_rubble.png",    "theme": "city",   "w": 92.0,  "solid": false, "rfrac": 0.40},
	"barrel":    {"file": "prop_barrel.png",    "theme": "city",   "w": 44.0,  "solid": false, "rfrac": 0.42},
	# 연구소
	"pod":       {"file": "prop_pod.png",       "theme": "lab",    "w": 66.0,  "solid": true,  "rfrac": 0.40},
	"server":    {"file": "prop_server.png",    "theme": "lab",    "w": 78.0,  "solid": true,  "rfrac": 0.42},
	"drum":      {"file": "prop_drum.png",      "theme": "lab",    "w": 42.0,  "solid": true,  "rfrac": 0.44},
	"console":   {"file": "prop_console.png",   "theme": "lab",    "w": 70.0,  "solid": false, "rfrac": 0.40},
}

var _player: Node2D = null
var _last := Vector2(INF, INF)
var _props: Array = []       # 이 테마에서 쓸 프롭 [{tex, w, solid, rfrac}]
var _has_solid: bool = false
## 플레이어 주변 3×3 셀의 장애물 프롭 캐시 — 셀을 넘을 때만 갱신한다.
var _sep_cell := Vector2i(0x7fffffff, 0x7fffffff)
var _sep_solid: Array = []


func _ready() -> void:
	z_index = -1   # 바닥(-2) 위, 유닛(0) 아래
	_player = get_tree().get_first_node_in_group("player")
	var t: ThemeData = ThemeManager.selected()
	if t == null:
		return
	for k in t.prop_keys:
		if not _CATALOG.has(k):
			continue
		var meta: Dictionary = _CATALOG[k]
		# 테마별 폴더에서 찾는다 — 다른 테마의 시트는 열지 않으니 그쪽 프롭은 VRAM 에 안 올라간다.
		var path: String = "%s%s/%s" % [PROP_DIR, meta["theme"],
			String(meta["file"]).replace(".png", ".tres")]
		if not ResourceLoader.exists(path):
			continue   # 아트 미준비 — 조용히 건너뛴다(나중에 파일 넣으면 자동 활성화)
		var tex = load(path)
		if not (tex is Texture2D):
			continue
		_props.append({"tex": tex, "w": meta["w"], "solid": meta["solid"], "rfrac": meta["rfrac"]})
		if bool(meta["solid"]):
			_has_solid = true


func _process(_delta: float) -> void:
	if _props.is_empty():
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	var p := _player.global_position
	# 프롭 배치는 월드 해시로 고정돼 있어 _last 는 "그릴 범위의 중심" 역할만 한다 —
	# 픽셀 단위로 따라갈 필요가 없다. 예전 임계값(4px)이면 이동 중 거의 매 프레임 전체
	# 프롭을 재발행했다. 스냅 칸이 바뀔 때만 다시 그린다(_draw 의 margin=CELL 260 > SNAP 이라
	# 스냅으로 생기는 어긋남은 이미 여유 범위 안에 들어온다).
	var snapped := Vector2(floor(p.x / SNAP) * SNAP, floor(p.y / SNAP) * SNAP)
	if snapped == _last:
		return
	_last = snapped
	queue_redraw()


## 장애물 프롭이 있으면, 플레이어 주변 셀만 훑어 겹친 프롭 밖으로 밀어낸다(값싼 원형 디펜트레이션).
func _physics_process(_delta: float) -> void:
	if not _has_solid or not is_instance_valid(_player):
		return
	var pp: Vector2 = _player.global_position
	var pc := _cell_of(pp)
	# _cell_prop() 은 호출마다 7키 Dictionary 를 새로 만든다 — 주변 3×3 을 매 물리 프레임
	# 훑으면 프레임당 9개가 버려진다. 배치는 셀 해시로 고정이므로 플레이어가 셀을 넘을 때만
	# 갱신하고, 그 사이에는 장애물 목록을 재사용한다(판정 대상은 이전과 동일).
	if pc != _sep_cell:
		_sep_cell = pc
		_sep_solid.clear()
		for cx in range(pc.x - 1, pc.x + 2):
			for cy in range(pc.y - 1, pc.y + 2):
				var cand := _cell_prop(cx, cy)
				if not cand.is_empty() and bool(cand["solid"]):
					_sep_solid.append(cand)
	for pr in _sep_solid:
		var d: Vector2 = pp - pr["pos"]
		var mind: float = pr["radius"] + PLAYER_R
		var dl := d.length()
		if dl < mind and dl > 0.001:
			pp += (d / dl) * (mind - dl)   # 표면 밖으로 밀어냄
	_player.global_position = pp


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))


## 정수 셀 좌표 → 안정적 해시(음수 없이).
func _hash(cx: int, cy: int) -> int:
	return ((cx * 73856093) ^ (cy * 19349663)) & 0x7fffffff


## 셀에 프롭이 있으면 그 배치 정보를 반환({} 이면 없음). _draw 와 충돌이 공유(동일 배치 보장).
func _cell_prop(cx: int, cy: int) -> Dictionary:
	var h := _hash(cx, cy)
	if h % 100 >= DENSITY:
		return {}
	var meta: Dictionary = _props[(h / 100) % _props.size()]
	var tex: Texture2D = meta["tex"]
	var ts := tex.get_size()
	var sc: float = (float(meta["w"]) / maxf(ts.x, ts.y)) * (0.8 + 0.5 * float((h / 7) % 100) / 100.0)
	var w := ts.x * sc
	var hgt := ts.y * sc
	var cell_i := int(CELL)
	var px := float(cx) * CELL + float((h / 11) % cell_i)
	var py := float(cy) * CELL + float((h / 17) % cell_i)
	return {
		"pos": Vector2(px, py), "tex": tex, "w": w, "h": hgt,
		"flip": ((h / 3) & 1) == 1, "solid": bool(meta["solid"]),
		"radius": float(meta["rfrac"]) * minf(w, hgt),
	}


func _draw() -> void:
	if _props.is_empty():
		return
	var vp := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.zoom.x > 0.0 and cam.zoom.y > 0.0:
		vp = Vector2(vp.x / cam.zoom.x, vp.y / cam.zoom.y)
	var c := _last
	var margin := CELL
	var x0 := int(floor((c.x - vp.x * 0.5 - margin) / CELL))
	var x1 := int(ceil((c.x + vp.x * 0.5 + margin) / CELL))
	var y0 := int(floor((c.y - vp.y * 0.5 - margin) / CELL))
	var y1 := int(ceil((c.y + vp.y * 0.5 + margin) / CELL))
	for cx in range(x0, x1):
		for cy in range(y0, y1):
			var pr := _cell_prop(cx, cy)
			if pr.is_empty():
				continue
			var tex: Texture2D = pr["tex"]
			var w: float = pr["w"]
			var hgt: float = pr["h"]
			var pos: Vector2 = pr["pos"]
			# 발밑 접지 그림자를 먼저(아래에) 깐다.
			var sw := w * SHADOW_W
			var sh := sw * SHADOW_H
			draw_texture_rect(_SHADOW_TEX,
				Rect2(pos.x - sw * 0.5, pos.y + hgt * 0.42 - sh * 0.5, sw, sh), false, SHADOW_COL)
			if pr["flip"]:
				draw_set_transform(pos, 0.0, Vector2(-1.0, 1.0))
				draw_texture_rect(tex, Rect2(-w * 0.5, -hgt * 0.5, w, hgt), false, DARKEN)
			else:
				draw_texture_rect(tex, Rect2(pos.x - w * 0.5, pos.y - hgt * 0.5, w, hgt), false, DARKEN)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
