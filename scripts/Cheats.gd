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

var autoplay: bool = false
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
const _ARENA_MARGIN := 150.0   # 보스 격리 구역 경계에서 이 거리 안이면 안쪽으로 되돌린다

const _Gem := preload("res://scripts/Gold.gd")


func toggle_autoplay() -> void:
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
	var out := repel * 1.4
	# 교전 거리 유지: 주변이 안전한데 최근접 적이 멀면 다가간다 — 자동 조준 무기가 계속 사격한다.
	if danger < 0.5 and nearest != null and nearest_d > _ENGAGE_R:
		out += (nearest.global_position - pos).normalized() * 0.8
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
