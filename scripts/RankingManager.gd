extends Node
## 랭킹/최고점 매니저 (Autoload 싱글톤: "RankingManager").
##
## 플랫폼 독립 파사드. 호출부(메뉴·HUD)는 mode_id(=위협 단계)로 점수를 제출/조회하고,
## 실제 저장과 온라인 랭킹은 백엔드(RankingBackend 구현)가 담당한다.
## 새 플랫폼은 RankingBackend 를 상속한 백엔드를 만들어 _make_backend() 에서 갈아끼우면 되고,
## 게임 코드는 한 줄도 바뀌지 않는다.
##   웹/PC/에디터 → LocalRankingBackend (로컬 최고점)
##   안드로이드 실빌드 → PlayGamesRankingBackend (로컬 + Google Play 리더보드)
##
## 새 기록은 위협 단계별로 분리한다. 예전 Easy/Normal/Hard 키는 기존 파일에 그대로
## 남겨 두되 새 기록 화면과 제출 경로에서는 사용하지 않는다.

## 구버전 저장 키. 기존 사용자 기록을 지우지 않기 위해 유지한다.
const MODES: Array = ["easy", "normal", "hard"]

## 안드로이드 실빌드에서 Google Play Games 사용 여부.
## 웹/PC/에디터는 이 값과 무관하게 항상 로컬 백엔드를 쓴다(SETUP_RANKING.md 절차 후 true).
const USE_PLAY_GAMES := false

## 모드 → PGS 리더보드 ID (Play Console 에서 만들고 실제 값으로 채운다).
const LEADERBOARD_IDS: Dictionary = {
	"easy":   "CgkI_REPLACE_EASY",
	"normal": "CgkI_REPLACE_NORMAL",
	"hard":   "CgkI_REPLACE_HARD",
}

## 백엔드 이벤트를 그대로 중계 — UI 가 RankingManager 하나만 구독하면 된다.
signal best_changed(mode_id: String, best: int)
signal sign_in_changed(signed_in: bool)

var _backend: RankingBackend
var _booting := true


func _ready() -> void:
	_backend = _make_backend()
	_backend.best_changed.connect(func(m: String, b: int) -> void: best_changed.emit(m, b))
	_backend.sign_in_changed.connect(func(s: bool) -> void: sign_in_changed.emit(s))

	_migrate_legacy_high_score()

	# 현재 위협 단계의 최고점을 Events 에 주입 — HUD의 신기록 판정이 같은 단계끼리 비교된다.
	Events.set_high_score(current_best())
	_booting = false

	# 실시간 최고점은 로컬에 즉시 보존(창 닫힘/크래시 대비), 게임오버 시 온라인 리더보드에 제출.
	Events.high_score_changed.connect(_on_high_score_changed)
	Events.player_died.connect(_on_player_died)

	if _backend.is_available():
		_backend.sign_in()


func _make_backend() -> RankingBackend:
	if USE_PLAY_GAMES and OS.get_name() == "Android":
		var pg := PlayGamesRankingBackend.new()
		pg.leaderboard_ids = LEADERBOARD_IDS
		return pg
	return LocalRankingBackend.new()


# ── 모드 조회 ────────────────────────────────────────────────────────
static func mode_id_for_difficulty(diff: int) -> String:
	return MODES[clampi(diff, 0, MODES.size() - 1)]


static func mode_id_for_threat(rank: int) -> String:
	return "threat_%d" % maxi(1, rank)


static func current_mode_id() -> String:
	return mode_id_for_threat(ThreatManager.selected_rank())


func best_for_threat(rank: int) -> int:
	return best_for_mode(mode_id_for_threat(rank))


# ── 최고점 조회/제출 ─────────────────────────────────────────────────
func best_for_mode(mode_id: String) -> int:
	return _backend.best_for_mode(mode_id) if _backend else 0


func current_best() -> int:
	return best_for_mode(current_mode_id())


## 해금된 위협 단계별 최고 점수 — 기록 화면용.
func all_bests() -> Dictionary:
	if _backend == null:
		return {}
	var out := {}
	for rank in range(1, ThreatManager.max_rank() + 1):
		out[mode_id_for_threat(rank)] = best_for_threat(rank)
	return out


## 점수 제출(기본: 현재 모드). 반환값은 갱신 후 최고점.
func submit(score: int, mode_id: String = "") -> int:
	if mode_id.is_empty():
		mode_id = current_mode_id()
	return _backend.submit_score(mode_id, score) if _backend else score


## 네이티브 리더보드 열기(온라인 백엔드에서만 성공). 성공 여부 반환.
func show_leaderboard(mode_id: String = "") -> bool:
	if mode_id.is_empty():
		mode_id = current_mode_id()
	return _backend.show_leaderboard(mode_id) if _backend else false


## 온라인 랭킹을 지원하는 백엔드인지(로컬 전용이면 false).
func is_online() -> bool:
	return _backend != null and _backend.backend_name() != "local"


func is_signed_in() -> bool:
	return _backend != null and _backend.is_signed_in()


# ── 내부 ─────────────────────────────────────────────────────────────
func _on_high_score_changed(high: int) -> void:
	if _booting:
		return
	# 변조가 감지된 판의 점수는 보존하지 않는다(P2-29). 아래 사망 제출과 같은 관문.
	if Events.tamper_detected():
		return
	# 실시간 로컬 보존. 온라인 제출은 게임오버(_on_player_died)에서만.
	if _backend:
		_backend.set_best(current_mode_id(), high)


func _on_player_died() -> void:
	if Events.tamper_detected():
		push_warning("[RankingManager] 변조가 감지된 판 — 점수 %d 제출을 건너뛴다" % Events.score)
		return
	submit(Events.score)


## 구버전 단일 최고점(user://highscore.save)은 위협 1 기록으로 1회 이관한다.
func _migrate_legacy_high_score() -> void:
	var legacy := SaveManager.read_legacy_high_score()
	if legacy > 0 and _backend:
		_backend.set_best(mode_id_for_threat(1), legacy)
	SaveManager.clear_legacy_high_score()
