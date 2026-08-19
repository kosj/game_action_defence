extends Node
## 도감(Codex) — "무엇을 이미 봤는가"의 영속 기록. HANDOFF P1-13 / CONTENT_PLAN §2 Phase B.
##
## 왜 필요한가: 만들어 둔 콘텐츠도 목록이 없으면 플레이어는 그것이 있는지조차 모른다.
## 진화 11종이 특히 그렇다 — 사람 실측에서 19분 런에 하나(napalm)가 나온 것이 전부다
## (BALANCE.md §3-6). 목록과 빈 칸이 있으면 "저기까지 가면 뭔가 더 있다"가 되고,
## 아트를 한 장도 더 그리지 않고 이미 만든 콘텐츠가 목표로 바뀐다.
##
## 저장하는 것은 **발견한 id 집합뿐**이다(user://codex.save, JSON). 스키마가 단순해야
## 카탈로그가 바뀌어도 마이그레이션이 필요 없다 — 모르는 id 는 읽을 때 버리고(_load),
## 새로 생긴 id 는 그냥 미발견 칸으로 뜬다.
##
## 캐릭터는 여기에 저장하지 않는다. 해금 상태를 CharacterManager 가 이미 영속으로 들고 있어
## 같은 사실을 두 곳에 적으면 언젠가 어긋난다 — 화면에서 그때 계산한다(CodexPanel).

const SAVE_PATH := "user://codex.save"

## 저장 분류. UI 의 절 구분과 1:1 이다.
##   weapon    카드로 뜨는 무기 + 캐릭터 궁극기 (획득)
##   evolution 진화 결과 무기 (진화 완료)
##   passive   패시브 (획득)
##   zombie    좀비 종 (처치)
##   boss      테마 보스 (처치)
##   arena     아레나 테마 (플레이)
const KINDS := ["weapon", "evolution", "passive", "zombie", "boss", "arena"]

signal changed

var _found: Dictionary = {}        # kind -> {id: true}
var _evolution_ids: Dictionary = {}   # 진화 결과 무기 id 집합(무기/진화 분류용)


func _ready() -> void:
	for k in KINDS:
		_found[k] = {}
	for e in GameData.evolution_defs:
		_evolution_ids[e.into_id] = true
	_load()
	# 무기·패시브는 시그널에 id 가 실려 오지 않는다(inventory_changed 는 인자가 없고,
	# 연결부 4곳의 시그니처를 바꾸면 전부 깨진다). 바뀐 뒤의 인벤토리를 통째로 훑는다.
	Events.inventory_changed.connect(_scan_inventory)


## 발견 기록. 이미 있으면 아무것도 하지 않고 false 를 돌려준다.
## 저장은 **새로 발견했을 때만** 한다 — 카탈로그 전체가 60여 항목이라 한 계정에서 평생
## 그 횟수만큼만 파일을 쓴다. 전투 중 호출되지만 디바운스가 필요 없는 이유가 이것이다.
func discover(kind: String, id: String) -> bool:
	if id == "" or not _found.has(kind):
		return false
	var set: Dictionary = _found[kind]
	if set.has(id):
		return false
	set[id] = true
	_save()
	changed.emit()
	return true


func has(kind: String, id: String) -> bool:
	return _found.has(kind) and (_found[kind] as Dictionary).has(id)


func found_count(kind: String) -> int:
	return (_found[kind] as Dictionary).size() if _found.has(kind) else 0


## 판 시작 — 이 아레나를 "플레이했다"로 기록한다. 인벤토리는 Events.reset() 이 쏘는
## inventory_changed 로 이미 잡히지만, 이어하기 경로가 그 시그널을 거치는지에 기록이
## 의존하지 않도록 여기서 한 번 더 훑는다.
func on_run_start(arena_id: String) -> void:
	discover("arena", arena_id)
	_scan_inventory()


func _scan_inventory() -> void:
	for id in Events.weapons.keys():
		var sid := String(id)
		discover("evolution" if _evolution_ids.has(sid) else "weapon", sid)
	for id in Events.passives.keys():
		discover("passive", String(id))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for kind in KINDS:
		var ids = parsed.get(kind, [])
		if typeof(ids) != TYPE_ARRAY:
			continue
		for id in ids:
			(_found[kind] as Dictionary)[String(id)] = true


func _save() -> void:
	var out: Dictionary = {}
	for kind in KINDS:
		out[kind] = (_found[kind] as Dictionary).keys()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))
		f.close()


## 테스트 전용 — 기록을 비운다(회귀 테스트가 깨끗한 상태에서 시작하도록).
func clear_all() -> void:
	for k in KINDS:
		_found[k] = {}
	_save()
	changed.emit()
