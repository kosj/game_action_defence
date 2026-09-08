extends RankingBackend
class_name LocalRankingBackend
## 로컬 디스크(user://ranking.json)에 모드별 최고점을 저장하는 기본 백엔드.
##
## 웹·PC·에디터의 기본 구현이며, 온라인 백엔드(PlayGamesRankingBackend 등)가 이 클래스를
## 상속해 "오프라인 최고점 캐시"로도 재사용한다. 즉 온라인이 안 될 때도 기기 최고점은 유지된다.

const PATH := "user://ranking.json"

var _bests: Dictionary = {}   # mode_id -> int


func _init() -> void:
	_load()


func backend_name() -> String:
	return "local"


func is_available() -> bool:
	return true   # 로컬 최고점은 항상 사용 가능(오프라인 포함)


func is_signed_in() -> bool:
	return true


func best_for_mode(mode_id: String) -> int:
	return int(_bests.get(mode_id, 0))


func all_bests() -> Dictionary:
	return _bests.duplicate()


func submit_score(mode_id: String, score: int) -> int:
	var prev := best_for_mode(mode_id)
	if score > prev:
		_bests[mode_id] = score
		_save()
		best_changed.emit(mode_id, score)
		return score
	return prev


func set_best(mode_id: String, value: int) -> void:
	if value > best_for_mode(mode_id):
		_bests[mode_id] = value
		_save()
		best_changed.emit(mode_id, value)


func _load() -> void:
	var r := SaveGuard.read_json(PATH)   # 서명 검증(P2-29) — 불일치 파일은 없는 것으로 본다
	var parsed = r["data"]
	if typeof(parsed) == TYPE_DICTIONARY:
		for k in parsed:
			_bests[k] = int(parsed[k])
		if r["status"] == SaveGuard.Status.UNSIGNED:
			_save()   # 구버전 평문 파일 → 첫 실행에 서명본으로 이관


func _save() -> void:
	SaveGuard.write_json(PATH, _bests)   # 서명본(P2-29)
