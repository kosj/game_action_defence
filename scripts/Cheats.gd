extends Node
## 치트/디버그 오토로드. 일시정지 메뉴의 CHEATS 하위 메뉴가 조작한다.
## autoplay: 플레이어 이동을 간단한 조종 AI 가 대신한다 — 좀비/보스로부터 반발(가까울수록 강함),
## 위협이 약할 때는 근처 경험치 젬을 주우러 간다. 레벨업 카드도 자동 선택된다(LevelUpPanel).

signal changed                     # 토글 상태 변경 — UI 라벨/표시 갱신용
signal time_skip(seconds: float)   # 경과 시간 점프 — ZombieSpawner 가 받아 난이도 시계를 당긴다
signal spawn_fill                  # 좀비를 현재 동시 출현 상한까지 즉시 채운다 — ZombieSpawner 가 처리
## 보스를 즉시 등장시킨다 — ZombieSpawner 가 처리. 보스전(격리 구역·페이즈·회복 스킬)을
## 10분씩 기다리지 않고 확인하기 위한 것. 누를 때마다 회차가 올라가 강화 곡선도 같이 볼 수 있다.
signal spawn_boss

## ── 릴리스 차단 게이트 ────────────────────────────────────────────────────
## 치트는 점수·랭킹(RankingManager)·도전과제(레벨 20/40·생존 시간)·퀘스트 티어·메타 골드
## 경제를 전부 오염시킨다. 특히 autoplay 는 방치 파밍을 허용해 리더보드를 무의미하게 만든다.
## 그래서 배포 빌드에서는 존재 자체를 없앤다.
##
## 판정: 에디터·디버그 빌드는 항상 켜짐. 릴리스 export 는 프리셋의 custom_features 에
## "cheats" 를 넣은 빌드에서만 켜진다 — export_presets.cfg 의 Web 프리셋은 빈 값이라 기본 차단.
##
## 왜 UI 를 감추는 것으로 끝내지 않는가: 버튼만 없애면 신호를 직접 쏘는 경로가 남는다.
## 상태(autoplay_active)·발신(request_*)·수신(ZombieSpawner 핸들러) 세 곳에 같은 게이트를 건다.
##
## 값을 변수로 들고 있는 이유는 **회귀 테스트 때문**이다 — 헤드리스는 항상 디버그 빌드라
## "치트가 꺼진 릴리스 빌드"를 달리 재현할 방법이 없다. tools/verify_cheat_gate.gd 가
## 이 값을 내려 잠긴 쪽 동작을 확인한다. 실제 빌드에서는 _ready 의 판정이 그대로 유지된다.
var enabled: bool = true

var autoplay: bool = false

## 오토플레이의 레벨업 카드 선택 방식(빌드 페르소나).
##  · "random" — 무작위. 빌드 운을 배제한 **하한선** 측정용(기본값, 기존 동작).
##  · "greedy" — 진화 완성을 향해 고르는 **상한 근사**. 사람이 빌드를 짜는 방식에 가깝다.
## 밸런스 측정은 두 값을 모두 재야 의미가 있다 — 하한만 보면 "너무 어렵다"로,
## 상한만 보면 "너무 쉽다"로 결론이 기운다. `tools/sim_balance.py --persona` 로 고른다.
var autoplay_persona: String = "random"
## 성능 디버그 오버레이(HUD 좌상단) 표시 여부. HUD 의 PerfOverlay 노드가 이 값을 따른다.
## 실기기에서 프레임 시간·드로우 콜·FX 상한을 눈으로 확인하기 위한 것 — 헤드리스 측정으로는
## 렌더 경로 비용이 드러나지 않아 실측 수단이 필요하다.
var perf_overlay: bool = false
## 낮/밤 시간 처리. false 면 DayNightCycle 이 시간 틴트를 한낮(무보정)으로 고정하고
## 달빛 헤일로·반딧불 앰비언트도 끈다 — 날씨 연출은 그대로 남는다(끄는 건 "시간"뿐).
## 밤 구간의 화면 색 때문에 스크린샷·아트 확인이 어려울 때 쓴다.
var daynight: bool = true
## 날씨 연출. false 면 WeatherSystem 이 입자·뿌연 판·날씨 틴트·번개를 전부 끈다(=상시 맑음).
## 스케줄 자체는 계속 돌아 결정론과 이어하기가 그대로 유지된다 — 켜면 그 시점의 날씨가 이어진다.
var weather: bool = true

const _AVOID_R := 200.0    # 이 안의 좀비로부터 도망(너무 크면 겁쟁이가 되어 교전을 못 한다)
const _BOSS_R := 360.0     # 보스는 더 멀리서부터 피한다
const _ENGAGE_R := 300.0   # 최근접 적이 이보다 멀면 접근 — 무기 사거리 안에 적을 유지(카이팅)
const _GEM_R := 480.0      # 젬 수집 감지 반경
## 상자(보물/진화/무기) 감지 반경. 젬보다 멀리서부터, 더 강하게 끌린다 —
## 상자는 드물고 값이 크다(진화 발동·무료 레벨업·골드). 특히 **진화는 상자 개봉으로만** 열리므로
## 이걸 안 주우면 이 게임의 가장 큰 파워 스파이크가 통째로 빠진다.
## 습득 반경이 34px 로 좁아 "지나가다 우연히"로는 거의 안 잡힌다 — 일부러 가야 한다.
const _CHEST_R := 620.0
const _ARENA_MARGIN := 150.0   # 보스 격리 구역 경계에서 이 거리 안이면 안쪽으로 되돌린다

## 무리에 쫓길 때의 도주 루프 방지 — 사이드뷰 자동사격은 "이동 중인 좌우 방향"으로만 나간다
## (Player._update_facing/_handle_attack). 그래서 무리에게서 수평으로 계속 도망치면 총구가
## 무리 반대쪽을 향해 한 발도 맞지 않고, 죽지도 죽이지도 않는 판이 된다 — 밸런스 측정에서
## "10분 생존 · 처치 17 · 좀비 158마리 누적" 같은 판이 반복 관측됐다(측정 판의 20~40%).
##
## 위험이 이 임계를 넘을 때만(=쫓기는 중) 가로를 조준축으로 되돌린다. 위험이 낮을 때는
## 기존 동작(교전 거리 유지 + 젬 수집)이 정상 작동하므로 건드리지 않는다 —
## 저위험 구간에 조준 유지를 걸었더니 무리로 걸어들어가 2~3분에 죽었다(실측).
const _AIM_DANGER := 1.2       # 이 위험도 이상이면 가로를 조준축으로 쓴다(포위 상황)
const _AIM_BAND := 150.0       # 위험이 낮아도 최근접 적이 이 밖~사거리 안이면 조준축으로 쓴다.
                               # 무리가 뒤로 처지면 danger 가 낮아 조준 유지가 안 걸리는데,
                               # 그 상태가 바로 "총구를 등지고 계속 달리는" 도주 루프다.
const _REPEL_X_DAMP := 0.4     # 그때 반발의 가로 성분 감쇠(총구가 돌아가지 않게)
const _AIM_PULL := 0.7         # 최근접 적 쪽으로 유지하는 가로 성분
const _AIM_MIN_D := 70.0       # 이보다 붙으면 조준 유지를 끈다(접촉 피해를 자초하지 않게)

const _Gem := preload("res://scripts/Gold.gd")


func _ready() -> void:
	enabled = OS.is_debug_build() or OS.has_feature("cheats")


## 자동플레이가 실제로 동작해야 하는가. **소비처는 autoplay 대신 반드시 이 함수를 본다** —
## 상태 변수를 직접 읽으면 게이트를 우회하게 된다(Player·LevelUpPanel·HUD 가 호출한다).
func autoplay_active() -> bool:
	return autoplay and enabled


## ── 신호 발신 — 잠긴 빌드에서는 아무 일도 일어나지 않는다 ────────────────────
## HUD 버튼은 이 함수들을 부른다. 시그널을 직접 emit 하지 않는 이유가 곧 게이트다.
func request_time_skip(seconds: float) -> void:
	if not enabled:
		return
	time_skip.emit(seconds)


func request_spawn_fill() -> void:
	if not enabled:
		return
	spawn_fill.emit()


func request_spawn_boss() -> void:
	if not enabled:
		return
	spawn_boss.emit()


func toggle_autoplay() -> void:
	if not enabled:
		return
	autoplay = not autoplay
	changed.emit()


func toggle_perf_overlay() -> void:
	perf_overlay = not perf_overlay
	changed.emit()


func toggle_daynight() -> void:
	daynight = not daynight
	changed.emit()


func toggle_weather() -> void:
	weather = not weather
	changed.emit()


## 자동플레이 이동 방향(정규화, 없으면 ZERO). Player._handle_move 가 조이스틱 대신 사용한다.
## 카이팅 조종: 가까운 위협은 피하되, 적이 사거리 밖으로 멀어지면 다가가 교전 거리를 유지한다
## — 도망만 다니면 무기가 한 발도 못 쏘므로, "쏘면서 피하는" 뱀서식 무빙을 흉내낸다.
func auto_move_dir(p: Node2D) -> Vector2:
	var pos := p.global_position
	var repel := Vector2.ZERO
	var danger := 0.0
	var nearest: Node2D = null
	var nearest_d := INF
	for z in Events.live_zombies():
		if not is_instance_valid(z):
			continue
		var d: Vector2 = pos - z.global_position
		var dl := d.length()
		if dl < nearest_d:
			nearest_d = dl
			nearest = z
		if dl < 1.0 or dl > _AVOID_R:
			continue
		var w := 1.0 - dl / _AVOID_R
		repel += (d / dl) * w * w
		danger += w * w
	for b in p.get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(b):
			continue
		var d2: Vector2 = pos - (b as Node2D).global_position
		var dl2 := d2.length()
		if dl2 >= 1.0 and dl2 < _BOSS_R:
			var w2 := (1.0 - dl2 / _BOSS_R) * 2.5
			repel += (d2 / dl2) * w2
			danger += w2
	# 쫓기는 중(danger 높음)에만 가로를 조준축으로 쓴다 — 세로로 비키면서 무리를 총구에 둔다.
	var aiming: bool = nearest != null and nearest_d > _AIM_MIN_D \
			and (danger >= _AIM_DANGER or (nearest_d > _AIM_BAND and nearest_d < _ENGAGE_R))
	var out := (Vector2(repel.x * _REPEL_X_DAMP, repel.y) if aiming else repel) * 1.4
	if aiming:
		out.x += signf(nearest.global_position.x - pos.x) * _AIM_PULL
	# 교전 거리 유지: 주변이 안전한데 최근접 적이 멀면 다가간다 — 자동 조준 무기가 계속 사격한다.
	if danger < 0.5 and nearest != null and nearest_d > _ENGAGE_R:
		out += (nearest.global_position - pos).normalized() * 0.8
	# 상자를 최우선으로 주우러 간다(젬보다 앞). 포위 중에는 무리하지 않는다.
	if danger < 1.4:
		var chest: Node2D = null
		var chest_d := _CHEST_R * _CHEST_R
		for c in p.get_tree().get_nodes_in_group("item_pickups"):
			if not is_instance_valid(c):
				continue
			var cd := pos.distance_squared_to((c as Node2D).global_position)
			if cd < chest_d:
				chest_d = cd
				chest = c
		if chest != null:
			out += (chest.global_position - pos).normalized() * (1.5 - danger * 0.5)
	# 위협이 약할 때만 젬을 주우러 간다 — 수집 욕심에 포위당하지 않도록 위협도로 끌림을 줄인다.
	if danger < 0.9:
		var best: Node2D = null
		var best_d := _GEM_R * _GEM_R
		for g in _Gem.live_gems():
			if not is_instance_valid(g):
				continue
			var dd := pos.distance_squared_to(g.global_position)
			if dd < best_d:
				best_d = dd
				best = g
		if best != null:
			out += (best.global_position - pos).normalized() * (0.85 - danger * 0.6)
	# 보스 격리 구역 안쪽으로 되돌리기 — 조종 AI 는 보스에게서 도망치므로, 그대로 두면 경계에
	# 등을 붙인 채 얻어맞는다. 경계에 다가갈수록 강해지는 안쪽 힘을 더해 구역 안에서 돌게 한다.
	var arena: Node2D = p.get_tree().get_first_node_in_group("boss_arena")
	if is_instance_valid(arena):
		var to_c: Vector2 = arena.global_position - pos
		var edge: float = arena.current_radius() - to_c.length()
		if edge < _ARENA_MARGIN:
			var push: float = clampf((_ARENA_MARGIN - edge) / _ARENA_MARGIN, 0.0, 1.0)
			out += to_c.normalized() * (0.6 + 2.2 * push * push)
	if out.length() < 0.06:
		return Vector2.ZERO
	return out.normalized()


# ── 오토플레이 빌드 선택 ────────────────────────────────────────────────
## 레벨업 카드 중 하나를 고른다(LevelUpPanel 이 호출). 카드에는 `pick_id` 메타가 실려 있다.
## 진화 카드는 `pick_id` 가 "evolve:<into>" 형태다.
func auto_pick(cards: Array) -> Button:
	if cards.is_empty():
		return null
	if autoplay_persona != "greedy":
		return cards[randi() % cards.size()] as Button
	var best: Button = null
	var best_s := -INF
	for c in cards:
		var btn := c as Button
		if btn == null:
			continue
		var sc := _pick_score(String(btn.get_meta("pick_id", "")))
		if sc > best_s:
			best_s = sc
			best = btn
	return best if best != null else cards[0] as Button


## 탐욕형 점수. 뱀서식 빌드의 통념을 그대로 옮겼다 —
## ① 진화가 가장 큰 파워 스파이크다 ② 폭보다 집중(적은 무기를 높은 레벨로)
## ③ 궁극기는 놓치지 않는다. 정교한 최적해가 아니라 "사람이 대충 이렇게 고른다"의 근사다.
func _pick_score(id: String) -> float:
	if id == "":
		return 0.0
	if id.begins_with("evolve:"):
		return 10000.0            # 진화가 떴으면 무조건 집는다
	# 궁극기는 **획득 1회**만 최우선이다. 이미 가진 뒤에도 같은 점수를 주면 레벨을 전부
	# 여기에 쏟아붓는다(실측에서 ult_quake:6 이 나왔다) — 보유 후엔 일반 무기처럼 다룬다.
	if id.begins_with("ult_") and not Events.weapons.has(id):
		return 5000.0
	var m := ItemDB.meta(id)
	if m.is_empty():
		return 0.0
	var is_w := ItemDB.is_weapon(id)
	var lv: int = int((Events.weapons if is_w else Events.passives).get(id, 0))
	var score := 0.0
	# ① 진화 조건에 직접 기여하는가 — 짝이 이미 갖춰진 쪽을 먼저 채운다.
	for e in ItemDB.evolutions():
		if Events.weapons.has(e["into"]):
			continue              # 이미 진화함
		if String(e["base"]) == id and int(Events.passives.get(e["passive"], 0)) >= 1:
			score += 900.0 + lv * 60.0        # 만렙에 가까울수록 급하다
		elif String(e["passive"]) == id and int(Events.weapons.get(e["base"], 0)) >= 1:
			score += 700.0
	# ② 집중 — 이미 가진 것을 올리는 쪽이 새 슬롯을 여는 것보다 낫다. 진화 조건이 만렙이라
	# 레벨이 오를수록 더 급해진다(가속 가중). 슬롯을 넓게 벌리면 아무것도 만렙이 안 된다.
	if lv > 0:
		score += 300.0 + lv * lv * 18.0
	else:
		score += 60.0
	# ③ 무기가 먼저다(피해가 없으면 아무것도 안 된다). 무기를 3개 모은 뒤엔 패시브를 올린다.
	score += (60.0 if is_w else 0.0) if Events.weapons.size() < 3 else (0.0 if is_w else 60.0)
	return score
