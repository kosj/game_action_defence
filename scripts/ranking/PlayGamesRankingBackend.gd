extends LocalRankingBackend
class_name PlayGamesRankingBackend
## Google Play Games Services(안드로이드) 백엔드.
##
## 로컬(부모 클래스)에 최고점을 미러링해 오프라인에서도 기록을 유지하면서, 온라인 리더보드
## 로그인/제출/조회는 _pgs_* 어댑터 메서드에 위임한다.
##
## 플러그인 클래스를 "직접 참조하지 않으므로" addon 미설치 상태에서도 스크립트가 정상 파싱된다
## (웹·에디터·PC 빌드 안전). 안드로이드 실빌드에서 플러그인을 설치한 뒤 SETUP_RANKING.md 의
## 스니펫으로 _pgs_* 3개 메서드 본문을 채우면 온라인 랭킹이 켜진다.

## 모드 → PGS 리더보드 ID (Play Console 발급). RankingManager 가 주입한다.
var leaderboard_ids: Dictionary = {}

var _signed_in := false


func backend_name() -> String:
	return "play_games"


func is_available() -> bool:
	return true


func sign_in() -> void:
	_pgs_sign_in()


func is_signed_in() -> bool:
	return _signed_in


func submit_score(mode_id: String, score: int) -> int:
	# 로컬 최고점을 먼저 갱신(오프라인 기록 보존) 후, 로그인 상태면 온라인 리더보드에도 제출.
	var best := super.submit_score(mode_id, score)
	if _signed_in and leaderboard_ids.has(mode_id):
		_pgs_submit_score(str(leaderboard_ids[mode_id]), score)
	return best


func show_leaderboard(mode_id: String) -> bool:
	if _signed_in and leaderboard_ids.has(mode_id):
		return _pgs_show_leaderboard(str(leaderboard_ids[mode_id]))
	return false


## 로그인 콜백에서 호출해 상태 변화를 알린다(어댑터 구현이 사용).
func _set_signed_in(v: bool) -> void:
	if v == _signed_in:
		return
	_signed_in = v
	sign_in_changed.emit(v)


# ───────────── PGS 어댑터 (SETUP_RANKING.md 의 스니펫으로 채운다) ─────────────
# 계약: 로그인 성공/실패 시 반드시 _set_signed_in(true/false) 호출.
# 아래는 미연동 골격이라 항상 오프라인(로컬만)으로 동작한다.

func _pgs_sign_in() -> void:
	# TODO(SETUP_ADS 유사): PlayGamesSDK.initialize() + 자동 로그인 요청.
	# 로그인 완료 콜백에서 _set_signed_in(true), 실패 시 _set_signed_in(false).
	pass


func _pgs_submit_score(leaderboard_id: String, score: int) -> void:
	# TODO: LeaderboardsClient.submit_score(leaderboard_id, score)
	pass


func _pgs_show_leaderboard(leaderboard_id: String) -> bool:
	# TODO: LeaderboardsClient.show_leaderboard(leaderboard_id) 후 true 반환.
	return false
