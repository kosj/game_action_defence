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

const CELL := 260.0                       # 배치 격자
## 셀 추첨: 먼저 모티프(연출 군집), 빗나가면 단독 프롭. 균일 단독 배치(구 DENSITY 30%)는
## 프롭끼리 아무 상관관계가 없어 "뿌려진" 것으로 읽혔다 — 정렬된 군집이 "배치된" 것으로 읽힌다.
## 군집 셀은 프롭 3~4개를 그리므로 셀 점유율은 낮춰도 화면의 체감 밀도는 이전과 비슷하다.
const MOTIF_DENSITY := 8                  # 셀당 모티프 확률(%) — 군집 하나가 셀 하나를 쓴다
const SCATTER_DENSITY := 14               # 모티프가 빗나간 셀의 단독 프롭 확률(%)
## 단독 프롭 중 장애물(solid)이 차지하는 비율(%). 카탈로그를 균등 추첨하면 테마마다 장애물
## 밀도가 제각각이 된다 — 연구소는 4종 중 3종이 solid 라 75%, 교외는 5종 중 2종이라 40%다.
## 장애물이 많으면 물량 게임의 도주로가 막혀 난이도가 테마 구성에 따라 멋대로 튄다. 장애물과
## 장식을 따로 뽑아 이 상수 하나로 비율을 고정한다. 모티프의 장애물 수는 테이블에 박혀 있어
## 테마 간 편차가 없고, 전체 장애물 밀도는 검증 스크립트가 실측한다.
const SOLID_SHARE := 30
## 시작 지점 주변(이 셀 반경 안)은 장애물 금지 — 스폰 직후 장애물에 밀려나며 시작하지 않게.
const SAFE_CELLS := 1
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
##
## **높이 기준**: 표시 높이는 플레이어(유닛 규약 120px)의 대략 2/3 을 넘지 않고, 넘는다면
## 세로로 솟은 부피가 아니어야 한다. 이 게임은 탑다운 필드 위에 사이드뷰 스프라이트를 세우는
## 투영이라, 키 큰 원통·캡슐은 플레이어가 겹치는 순간 "허공에 떠 있는" 것으로 읽힌다.
## 실제로 배양 탱크(118px = 플레이어의 98%)·격리 포드(세로 캡슐)·서버랙을 이 이유로 뺐다.
##
## **판독성 기준**: 한 개만 놓였을 때 "그것이 무엇인지" 알아볼 수 있어야 한다. 울타리를 이
## 이유로 뺐다 — 단독으로 놓이면 잔디밭 위의 나무 판때기로만 읽혔고, 일렬 모티프에서도 판이
## 서로 떨어져(간격 84px, 판 폭 31px) 울타리가 아니라 판자 3개로 보였다. 붙여서 연속된
## 울타리로 만들면 이번에는 통행 간격 규칙(solid 간 >= r1+r2+2*PLAYER_R+8)을 어겨 벽이 된다.
## 아직 아트가 없는 키(파일 부재)는 로드 단계에서 자동 제외된다.
## 어느 테마에서 쓸지는 ThemeData.prop_keys 가 정한다 — 여기 있어도 그 목록에 없으면 안 나온다.
const _CATALOG := {
	# 교외
	"mailbox":   {"file": "prop_mailbox.png",   "theme": "suburb", "w": 40.0,  "solid": false, "rfrac": 0.40},
	"bush":      {"file": "prop_bush.png",      "theme": "suburb", "w": 62.0,  "solid": false, "rfrac": 0.40},
	"forsale":   {"file": "prop_forsale.png",   "theme": "suburb", "w": 54.0,  "solid": false, "rfrac": 0.40, "noflip": true},   # 글자가 있는 팻말 — 반전하면 거울 글씨가 된다
	"hydrant":   {"file": "prop_hydrant.png",   "theme": "suburb", "w": 34.0,  "solid": true,  "rfrac": 0.42},
	# 도심 — wreck_car 는 BurningCar 기믹(도심 전용)도 같은 시트를 쓴다.
	"wreck_car": {"file": "prop_wreck_car.png", "theme": "city",   "w": 120.0, "solid": true,  "rfrac": 0.42},
	"barrier":   {"file": "prop_barrier.png",   "theme": "city",   "w": 100.0, "solid": true,  "rfrac": 0.40},
	"dumpster":  {"file": "prop_dumpster.png",  "theme": "city",   "w": 82.0,  "solid": true,  "rfrac": 0.42},
	"rubble":    {"file": "prop_rubble.png",    "theme": "city",   "w": 92.0,  "solid": false, "rfrac": 0.40},
	"barrel":    {"file": "prop_barrel.png",    "theme": "city",   "w": 44.0,  "solid": false, "rfrac": 0.42},
	# 연구소
	"drum":      {"file": "prop_drum.png",      "theme": "lab",    "w": 42.0,  "solid": true,  "rfrac": 0.44},
	"console":   {"file": "prop_console.png",   "theme": "lab",    "w": 70.0,  "solid": false, "rfrac": 0.40},
}

## 테마별 모티프 — "누가 배치한" 것으로 읽히는 프롭 군집. 오프셋은 셀 중심 기준 px.
## 규칙(검증 스크립트가 실측 확인):
##  ① 군집 전체가 자기 셀 안(오프셋 ±95 + 지터 ±20)에 들어온다 — 충돌 판정이 3×3 셀 조회로
##     끝나려면 군집이 이웃 셀 너머까지 뻗으면 안 된다.
##  ② solid 끼리는 중심 거리 ≥ r1+r2+2×PLAYER_R+8 — 사이에 플레이어가 지나갈 틈을 보장해
##     군집이 함정이 되지 않는다(solid 는 크기 지터 없이 고정 배율이라 이 간격이 흔들리지 않는다).
##  ③ 일렬 모티프는 군집 단위로 플립을 공유한다 — 정렬이 곧 "사람이 놓은 것"의 신호다.
const _MOTIFS := {
	"suburb": [
		# 길가 우편함 — 우체통 + 소화전 + 덤불. 우체통과 소화전이 나란히 서면 "길가"로 읽힌다.
		[{"k": "mailbox", "o": Vector2(-62, -28)}, {"k": "hydrant", "o": Vector2(30, -46)},
		 {"k": "bush", "o": Vector2(62, 42)}],
		# 매물로 나온 집터 — FOR SALE 팻말 + 우체통 + 덤불
		[{"k": "forsale", "o": Vector2(-18, -40)}, {"k": "mailbox", "o": Vector2(-78, 34)},
		 {"k": "bush", "o": Vector2(62, 30)}],
		# 길모퉁이 정원 — 덤불 3개 + 소화전
		[{"k": "bush", "o": Vector2(-72, -42)}, {"k": "bush", "o": Vector2(-18, 50)},
		 {"k": "bush", "o": Vector2(52, -22)}, {"k": "hydrant", "o": Vector2(86, 54)}],
		# 집 앞 잔디 — 장애물 0(테마 평균 solid 를 모티프당 1.0 으로 묶는 완충재)
		[{"k": "bush", "o": Vector2(-60, -30)}, {"k": "bush", "o": Vector2(40, 45)},
		 {"k": "mailbox", "o": Vector2(78, -55)}, {"k": "forsale", "o": Vector2(-15, 12)}],
		# 산울타리 — 덤불 3개 느슨한 줄
		[{"k": "bush", "o": Vector2(-70, 20)}, {"k": "bush", "o": Vector2(0, -30)},
		 {"k": "bush", "o": Vector2(70, 25)}],
	],
	"city": [
		# 검문소 — 바리케이드 2장 일렬 + 드럼통
		[{"k": "barrier", "o": Vector2(-72, 6)}, {"k": "barrier", "o": Vector2(72, 6)},
		 {"k": "barrel", "o": Vector2(0, -56)}],
		# 사고 현장 — 폐차 + 잔해 + 드럼통
		[{"k": "wreck_car", "o": Vector2(-44, 16)}, {"k": "rubble", "o": Vector2(62, -40)},
		 {"k": "barrel", "o": Vector2(86, 46)}],
		# 무너진 방어선 — 폐차 + 잔해 + 드럼통
		[{"k": "wreck_car", "o": Vector2(0, -12)}, {"k": "rubble", "o": Vector2(-80, 56)},
		 {"k": "barrel", "o": Vector2(84, 52)}],
		# 뒷골목 — 쓰레기통 + 드럼통 + 잔해
		[{"k": "dumpster", "o": Vector2(-58, 8)}, {"k": "barrel", "o": Vector2(12, -48)},
		 {"k": "rubble", "o": Vector2(72, 52)}],
		# 파편 지대 — 장애물 0 완충재
		[{"k": "rubble", "o": Vector2(-65, -35)}, {"k": "rubble", "o": Vector2(55, 30)},
		 {"k": "barrel", "o": Vector2(-20, 55)}, {"k": "barrel", "o": Vector2(80, -50)}],
	],
	# 연구소는 서버랙 삭제 후 콘솔(장식)·드럼(장애물) 2종뿐이다. 종류로 다양성을 낼 수 없으므로
	# **배열**로 낸다 — 일렬 / 마주 보는 두 줄 / 어긋난 적치.
	# solid 는 모티프당 [0, 2, 0, 1] = 평균 0.75 로 다른 테마(1.0)보다 낮게 잡았다. 남은 장애물이
	# 드럼 하나뿐이라 모티프마다 넣으면 장애물 **비율**이 상한(1/3)에 붙는다 — 실측 33.2% 로
	# 여유가 0.2%p 였다. 드럼은 반경 11px 로 서버랙(32px)의 1/3 이라 실제 차단 면적은 오히려 줄었다.
	"lab": [
		# 관제 열 — 콘솔 3대 정렬(장애물 0 완충재)
		[{"k": "console", "o": Vector2(-80, 0)}, {"k": "console", "o": Vector2(0, 0)},
		 {"k": "console", "o": Vector2(80, 0)}],
		# 약품 적치장 — 드럼 2통 + 콘솔. 드럼 간 거리 105px 로 통행 간격(63px)을 넘긴다.
		[{"k": "drum", "o": Vector2(-64, 30)}, {"k": "drum", "o": Vector2(10, -45)},
		 {"k": "console", "o": Vector2(78, 35)}],
		# 관측 구역 — 콘솔 3대가 마주 본다(장애물 0 완충재)
		[{"k": "console", "o": Vector2(-62, -18)}, {"k": "console", "o": Vector2(15, 48)},
		 {"k": "console", "o": Vector2(80, -30)}],
		# 정비 구역 — 콘솔 2대 + 드럼, 어긋난 배치
		[{"k": "console", "o": Vector2(-70, -25)}, {"k": "drum", "o": Vector2(20, 40)},
		 {"k": "console", "o": Vector2(75, -10)}],
	],
}

var _player: Node2D = null
var _last := Vector2(INF, INF)
var _props: Array = []       # 이 테마에서 쓸 프롭 [{tex, w, solid, rfrac}]
## 추첨은 두 통에서 따로 한다(SOLID_SHARE 참고). _props 는 "쓸 프롭이 있는가" 판정용으로 남긴다.
var _solid_props: Array = []
var _soft_props: Array = []
var _by_key: Dictionary = {}   # 프롭 키 → 로드된 엔트리(모티프 구성용)
var _motifs: Array = []        # 이 테마에서 실제로 쓸 수 있는 모티프
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
		var entry := {"tex": tex, "w": meta["w"], "solid": meta["solid"], "rfrac": meta["rfrac"],
				"noflip": bool(meta.get("noflip", false))}
		_props.append(entry)
		_by_key[k] = entry
		if bool(meta["solid"]):
			_solid_props.append(entry)
			_has_solid = true
		else:
			_soft_props.append(entry)
	# 구성 프롭이 전부 로드된 모티프만 쓴다 — 아트가 빠진 모티프는 통째로 제외(반쪽 군집 방지).
	for m in _MOTIFS.get(t.id, []):
		var complete := true
		for ch in m:
			if not _by_key.has(ch["k"]):
				complete = false
				break
		if complete:
			_motifs.append(m)


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
				for cand in _cell_props(cx, cy):
					if bool(cand["solid"]):
						_sep_solid.append(cand)
	if _sep_solid.is_empty():
		return   # 주변 3×3 셀에 장애물이 없다 — 아래 그룹 조회·순회를 통째로 건너뛴다
	# 보스 격리 구역이 열려 있으면 경계선을 물고 있는 장애물은 이번 프레임 판정에서 뺀다.
	# 프롭은 플레이어를 바깥으로, 경계는 안쪽으로 민다 — 그 사이에 끼면 매 프레임 서로 밀어
	# 제자리에서 떨리며 감전 피해(BossArena._shock)만 계속 받는다. 게다가 BossArena 는 런타임에
	# 씬 끝에 붙어 이 노드보다 늦게 처리되므로 경계가 항상 이겨 빠져나갈 수도 없다.
	# 프롭 배치는 월드 해시로 고정이라 아레나(플레이어 위치에 전개)를 피해 놓을 수 없으니,
	# 겹치는 쪽 프롭이 양보한다. 아레나 안쪽에 온전히 들어온 장애물은 평소대로 막는다.
	var arena_c := Vector2.ZERO
	var arena_r := -1.0
	var arena := get_tree().get_first_node_in_group("boss_arena")
	if is_instance_valid(arena) and arena is Node2D and arena.has_method("current_radius"):
		arena_c = (arena as Node2D).global_position
		arena_r = arena.current_radius()
	for pr in _sep_solid:
		var ppos: Vector2 = pr["pos"]
		var rad: float = pr["radius"]
		if arena_r > 0.0 and arena_c.distance_to(ppos) + rad + PLAYER_R > arena_r:
			continue   # 프롭 바깥면이 경계를 넘는다 — 끼임 방지를 위해 통과시킨다
		var d: Vector2 = pp - ppos
		var mind: float = rad + PLAYER_R
		var dl := d.length()
		if dl < mind and dl > 0.001:
			pp += (d / dl) * (mind - dl)   # 표면 밖으로 밀어냄
	# 밀어낼 것이 없으면 쓰지 않는다 — 무조건 대입하면 플레이어와 그 자식들(스프라이트·그림자·
	# 카메라·무기 모듈)의 변환 전파가 매 물리 프레임 한 번씩 헛돈다.
	if pp != _player.global_position:
		_player.global_position = pp


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))


## 정수 셀 좌표 → 안정적 해시(음수 없이).
func _hash(cx: int, cy: int) -> int:
	return ((cx * 73856093) ^ (cy * 19349663)) & 0x7fffffff


## 이 셀에 놓을 프롭 한 종을 고른다 — 장애물/장식을 SOLID_SHARE 비율로 나눠 뽑는다.
func _pick(h: int) -> Dictionary:
	var i := h / 100
	if _solid_props.is_empty():
		return _soft_props[i % _soft_props.size()]
	if _soft_props.is_empty():
		return _solid_props[i % _solid_props.size()]
	# h 의 다른 자릿수를 그대로 쓰면 종류 추첨(h/100)과 상관이 생겨 특정 종만 장애물로 몰린다.
	# 곱셈 해시로 한 번 더 섞어 독립적인 비트를 얻는다.
	var r := ((h * 2654435761) >> 7) & 0x7fffffff
	if r % 100 < SOLID_SHARE:
		return _solid_props[i % _solid_props.size()]
	return _soft_props[i % _soft_props.size()]


## 셀의 프롭 배치 목록(빈 배열이면 없음). _draw 와 충돌이 공유한다(동일 배치 보장).
## 모티프 셀은 군집(3~4개), 단독 셀은 1개를 돌려준다. 순수 함수 — 셀 좌표 해시로만 결정된다.
func _cell_props(cx: int, cy: int) -> Array:
	var h := _hash(cx, cy)
	var roll := h % 100
	var out: Array = []
	# 시작 지점 주변 셀은 장애물 금지(스폰 보호) — 모티프는 건너뛰고 단독도 장식만 놓는다.
	var safe: bool = absi(cx) <= SAFE_CELLS and absi(cy) <= SAFE_CELLS
	if roll < MOTIF_DENSITY:
		if safe or _motifs.is_empty():
			return out
		var m: Array = _motifs[(h / 100) % _motifs.size()]
		var flip := ((h / 3) & 1) == 1
		# 군집 전체를 셀 중심 근처에 두고 통째로 지터 — 개별 지터를 주면 정렬이 무너진다.
		var base := Vector2((float(cx) + 0.5) * CELL + float((h / 11) % 41) - 20.0,
				(float(cy) + 0.5) * CELL + float((h / 17) % 41) - 20.0)
		for i in m.size():
			var ch: Dictionary = m[i]
			var meta: Dictionary = _by_key[ch["k"]]
			var off: Vector2 = ch["o"]
			if flip:
				off.x = -off.x
			# solid 는 배율 고정 — 모티프의 solid 간 통행 간격이 지터로 흔들리면 안 된다.
			var jitter := 1.0 if bool(meta["solid"]) else 0.9 + 0.25 * float((h / (23 + i * 7)) % 100) / 100.0
			out.append(_make(meta, base + off, flip and not bool(meta["noflip"]), jitter))
		return out
	if roll < MOTIF_DENSITY + SCATTER_DENSITY:
		if safe and _soft_props.is_empty():
			return out
		var meta2: Dictionary = _soft_props[(h / 100) % _soft_props.size()] if safe else _pick(h)
		var cell_i := int(CELL)
		var pos := Vector2(float(cx) * CELL + float((h / 11) % cell_i),
				float(cy) * CELL + float((h / 17) % cell_i))
		out.append(_make(meta2, pos, ((h / 3) & 1) == 1 and not bool(meta2["noflip"]),
				0.8 + 0.5 * float((h / 7) % 100) / 100.0))
	return out


## 배치 정보 한 건을 만든다(그리기 + 충돌 공용).
func _make(meta: Dictionary, pos: Vector2, flip: bool, scale_mult: float) -> Dictionary:
	var tex: Texture2D = meta["tex"]
	var ts := tex.get_size()
	var sc: float = (float(meta["w"]) / maxf(ts.x, ts.y)) * scale_mult
	var w := ts.x * sc
	var hgt := ts.y * sc
	return {
		"pos": pos, "tex": tex, "w": w, "h": hgt,
		"flip": flip, "solid": bool(meta["solid"]),
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
			for pr in _cell_props(cx, cy):
				_draw_prop(pr)


func _draw_prop(pr: Dictionary) -> void:
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
		# 반전 변환을 즉시 되돌린다. 걸어둔 채 다음 프롭으로 넘어가면 이후의 그림자와
		# 비반전 프롭이 전부 이 프롭 기준 거울 좌표로 그려져 화면 밖으로 사라진다 —
		# 스크롤로 그리기 범위가 바뀔 때마다 "반전 뒤에 오는" 프롭 집합이 바뀌므로,
		# 프롭이 위치에 따라 나타났다 사라졌다 하는 깜박임으로 보였다.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(tex, Rect2(pos.x - w * 0.5, pos.y - hgt * 0.5, w, hgt), false, DARKEN)
