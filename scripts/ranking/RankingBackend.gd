extends RefCounted
class_name RankingBackend
## 랭킹/최고점 백엔드의 공통 인터페이스.
##
## 플랫폼별 구현(로컬 · Google Play Games · Apple Game Center · Firebase …)이 이 클래스를
## 상속해 아래 메서드를 채운다. 게임 코드는 항상 RankingManager 를 통해서만 백엔드에 접근하므로,
## 새 플랫폼을 붙일 때 호출부(메뉴·HUD)는 한 줄도 바뀌지 않는다.
##
## 계약(모든 백엔드 공통):
##   · mode_id 는 게임 모드 식별자(현재는 난이도: "easy"/"normal"/"hard").
##   · 최고점은 "더 높을 때만" 갱신된다(점수는 클수록 좋다).
##   · 갱신이 일어나면 best_changed(mode_id, best) 를 emit 한다.

## 백엔드가 최고점을 갱신했을 때(로컬 저장/온라인 동기화 후).
signal best_changed(mode_id: String, best: int)
## 온라인 로그인 상태가 바뀌었을 때(로컬 전용 백엔드에서는 발생하지 않음).
signal sign_in_changed(signed_in: bool)


## 사람이 읽을 수 있는 백엔드 식별자("local", "play_games", …).
func backend_name() -> String:
	return "none"


## 이 플랫폼/빌드에서 온라인 랭킹을 지원하는지. 로컬 전용이면 false.
func is_available() -> bool:
	return false


## 필요 시 로그인 시도. 로컬 백엔드는 아무 것도 하지 않는다.
func sign_in() -> void:
	pass


func is_signed_in() -> bool:
	return false


## 점수 제출 — 로컬 최고점을 갱신하고(더 높을 때만) 지원 시 온라인 리더보드에도 보낸다.
## 반환값: 제출 후의 해당 모드 최고점.
func submit_score(mode_id: String, score: int) -> int:
	return score


## 외부(마이그레이션/보정)에서 최고점을 주입. 기존 값보다 높을 때만 반영.
func set_best(mode_id: String, value: int) -> void:
	pass


func best_for_mode(mode_id: String) -> int:
	return 0


## 모든 모드의 최고점 { mode_id: int }.
func all_bests() -> Dictionary:
	return {}


## 네이티브 리더보드 UI 열기. 성공 시 true(로컬 전용 백엔드는 지원하지 않으므로 false).
func show_leaderboard(mode_id: String) -> bool:
	return false
