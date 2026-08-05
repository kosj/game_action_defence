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
const DARKEN := Color(0.82, 0.82, 0.86)   # 바닥과 어우러지게 살짝 어둡게
const PLAYER_R := 16.0                     # 플레이어 충돌 반경(스프라이트 대략)
const PROP_DIR := "res://assets/sprites/props/"

## 프롭 카탈로그: 키 → { path, w=표시 최대변(px), solid=장애물여부, rfrac=충돌반경/최소변 비율 }.
## 아직 아트가 없는 키(파일 부재)는 로드 단계에서 자동 제외된다.
const _CATALOG := {
	# 교외
	"fence":     {"file": "prop_fence.png",     "w": 72.0,  "solid": true,  "rfrac": 0.32},
	"wreck_car": {"file": "prop_wreck_car.png", "w": 120.0, "solid": true,  "rfrac": 0.42},
	"mailbox":   {"file": "prop_mailbox.png",   "w": 40.0,  "solid": false, "rfrac": 0.40},
	"bush":      {"file": "prop_bush.png",       "w": 62.0,  "solid": false, "rfrac": 0.40},
	"forsale":   {"file": "prop_forsale.png",    "w": 54.0,  "solid": false, "rfrac": 0.40},
	"hydrant":   {"file": "prop_hydrant.png",    "w": 34.0,  "solid": true,  "rfrac": 0.42},
	# 도심
	"tank":      {"file": "prop_tank.png",       "w": 118.0, "solid": true,  "rfrac": 0.42},
	"barrier":   {"file": "prop_barrier.png",    "w": 100.0, "solid": true,  "rfrac": 0.40},
	"dumpster":  {"file": "prop_dumpster.png",   "w": 82.0,  "solid": true,  "rfrac": 0.42},
	"rubble":    {"file": "prop_rubble.png",     "w": 92.0,  "solid": false, "rfrac": 0.40},
	"barrel":    {"file": "prop_barrel.png",     "w": 44.0,  "solid": false, "rfrac": 0.42},
	# 연구소
	"pod":       {"file": "prop_pod.png",        "w": 66.0,  "solid": true,  "rfrac": 0.40},
	"server":    {"file": "prop_server.png",     "w": 78.0,  "solid": true,  "rfrac": 0.42},
	"drum":      {"file": "prop_drum.png",       "w": 42.0,  "solid": true,  "rfrac": 0.44},
	"console":   {"file": "prop_console.png",    "w": 70.0,  "solid": false, "rfrac": 0.40},
}

var _player: Node2D = null
var _last := Vector2(INF, INF)
var _props: Array = []       # 이 테마에서 쓸 프롭 [{tex, w, solid, rfrac}]
var _has_solid: bool = false


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
		var path: String = PROP_DIR + String(meta["file"])
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
	if p.distance_squared_to(_last) > 16.0:
		_last = p
		queue_redraw()


## 장애물 프롭이 있으면, 플레이어 주변 셀만 훑어 겹친 프롭 밖으로 밀어낸다(값싼 원형 디펜트레이션).
func _physics_process(_delta: float) -> void:
	if not _has_solid or not is_instance_valid(_player):
		return
	var pp: Vector2 = _player.global_position
	var pc := _cell_of(pp)
	for cx in range(pc.x - 1, pc.x + 2):
		for cy in range(pc.y - 1, pc.y + 2):
			var pr := _cell_prop(cx, cy)
			if pr.is_empty() or not pr["solid"]:
				continue
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
			if pr["flip"]:
				draw_set_transform(pos, 0.0, Vector2(-1.0, 1.0))
				draw_texture_rect(tex, Rect2(-w * 0.5, -hgt * 0.5, w, hgt), false, DARKEN)
			else:
				draw_texture_rect(tex, Rect2(pos.x - w * 0.5, pos.y - hgt * 0.5, w, hgt), false, DARKEN)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
