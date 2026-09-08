class_name SaveGuard
extends RefCounted
## 세이브 파일 서명(HMAC-SHA256) — 평문 JSON 을 편집기로 고치는 것에 대한 허들(P2-29).
##
## 파일 형식: {"v": 1, "payload": "<원본 JSON 문자열>", "sig": "<hex>"}
## payload 를 **문자열째** 서명한다 — parse → stringify 를 거치면 정수가 실수(5 → 5.0)로 바뀌어
## 같은 데이터도 바이트가 달라지기 때문이다. 문자열을 그대로 싣고 그대로 검증한다.
##
## read_json 의 status:
##   OK        서명 일치.
##   UNSIGNED  구버전 평문 파일(서명 도입 이전 세이브). **첫 실행(스탬프 없음)에서만** 받아들이고
##             호출부가 즉시 서명본으로 다시 쓴다. 스탬프가 생긴 뒤의 평문 파일은 서명을 떼어낸
##             것으로 보고 TAMPERED 로 돌려준다 — 안 그러면 "서명을 지우면 그만"이 된다.
##   TAMPERED  서명 불일치 · 평문 강등. 호출부는 파일이 없는 것처럼 처리한다(그 파일의 진행은 버린다).
##   CORRUPT   JSON 이 아님(쓰다 만 파일 등). 기존과 같이 무시.
##   MISSING   파일 없음.
##
## 스탬프(`user://save_guard.stamp`)는 "이 기기에서 서명본을 한 번이라도 썼다"는 표시다.
## 스탬프 유무는 **세션 시작 시 한 번만** 읽는다 — 첫 실행에서 오토로드들이 차례로 평문 파일을
## 읽어 서명본으로 다시 쓰는 동안, 앞 오토로드가 만든 스탬프가 뒤 오토로드의 평문 파일을
## TAMPERED 로 만들면 안 되기 때문이다. 그래서 첫 실행 한 번에 9개 파일이 전부 이관된다.
##
## ⚠️ 키는 소스에 있다(공개 레포). "숫자만 고치면 된다"를 "소스를 읽고 HMAC 을 계산해야
## 한다"로 올리는 허들이지 방어가 아니다. 서버 검증이 본질이다(`LAUNCH_CHECKLIST.md` C).

enum Status { OK, UNSIGNED, TAMPERED, CORRUPT, MISSING }

const FORMAT_VERSION := 1
const STAMP_PATH := "user://save_guard.stamp"

## 이번 세션에 TAMPERED 파일을 만났는가 — 텔레메트리가 판 기록에 남긴다.
static var tamper_seen: bool = false

## -1 미확정 · 0 불허 · 1 허용. 세션 첫 read/write 때 스탬프 유무로 한 번 정하고 바꾸지 않는다.
static var _legacy_allowed: int = -1


## data 를 JSON 으로 직렬화해 서명본으로 쓴다. 성공 여부 반환.
static func write_json(path: String, data: Variant) -> bool:
	_ensure_init()
	var payload := JSON.stringify(data)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"v": FORMAT_VERSION, "payload": payload, "sig": _sign(payload)}))
	f.close()
	_touch_stamp()
	return true


## 반환: {"status": Status, "data": Variant}. data 는 OK/UNSIGNED 일 때만 의미가 있다.
static func read_json(path: String) -> Dictionary:
	_ensure_init()
	if not FileAccess.file_exists(path):
		return {"status": Status.MISSING, "data": null}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"status": Status.MISSING, "data": null}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		return {"status": Status.CORRUPT, "data": null}
	# 서명본인가 — 세 키가 전부 있고 payload/sig 가 문자열이면 서명본으로 본다.
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("sig") and parsed.has("payload") \
			and typeof(parsed.get("payload")) == TYPE_STRING and typeof(parsed.get("sig")) == TYPE_STRING:
		var payload: String = parsed["payload"]
		if parsed["sig"] != _sign(payload):
			return _tampered(path, "서명 불일치")
		var inner = JSON.parse_string(payload)
		if inner == null:
			return {"status": Status.CORRUPT, "data": null}
		return {"status": Status.OK, "data": inner}
	# 평문(구버전) — 스탬프 이전이면 이관 대상, 이후면 서명을 떼어낸 것이다.
	if _legacy_allowed == 1:
		return {"status": Status.UNSIGNED, "data": parsed}
	return _tampered(path, "서명 없는 평문 파일(스탬프 이후)")


## 구버전 평문 파일을 받아들이는 세션인가(첫 실행 이관용). 테스트가 상태를 확인하는 데도 쓴다.
static func legacy_allowed() -> bool:
	_ensure_init()
	return _legacy_allowed == 1


## 테스트 전용 — 이관 허용 여부를 강제한다. 실제 코드는 부르지 않는다.
static func _override_legacy_for_test(allow: bool) -> void:
	_legacy_allowed = 1 if allow else 0


static func _ensure_init() -> void:
	if _legacy_allowed == -1:
		_legacy_allowed = 0 if FileAccess.file_exists(STAMP_PATH) else 1


static func _touch_stamp() -> void:
	if FileAccess.file_exists(STAMP_PATH):
		return
	var f := FileAccess.open(STAMP_PATH, FileAccess.WRITE)
	if f:
		f.store_string(str(FORMAT_VERSION))
		f.close()


static func _tampered(path: String, why: String) -> Dictionary:
	tamper_seen = true
	push_warning("[SaveGuard] %s — %s. 이 파일의 진행은 무시한다" % [path, why])
	return {"status": Status.TAMPERED, "data": null}


static func _sign(payload: String) -> String:
	var ctx := HMACContext.new()
	if ctx.start(HashingContext.HASH_SHA256, _key()) != OK:
		return ""
	ctx.update(payload.to_utf8_buffer())
	return ctx.finish().hex_encode()


## 키를 조각으로 나눠 두고 실행 시 합친다 — pck 를 문자열 검색해 한 줄로 찾는 것만 막는다.
## (GDScript 는 토큰화된 .gdc 로 내보내져 리터럴이 평문으로 잡히지 않지만, 그래도 한 조각으로
## 두지 않는다.) 키가 소스에 있다는 사실 자체는 바뀌지 않는다 — 위 헤더 참고.
## ⚠️ 프로젝트 이름·버전 같은 **바뀔 수 있는 값을 섞지 않는다.** 키가 바뀌면 모든 플레이어의 기존
## 서명본이 TAMPERED 가 되어 진행이 통째로 무시된다. 바꿔야 한다면 v 를 올리고 재서명 이관을 넣을 것.
static func _key() -> PackedByteArray:
	var parts: PackedStringArray = ["zb", "-", "save", "-", "guard", "-", "2026", "-", "p2", "29"]
	var joined := ""
	for p in parts:
		joined += p
	return joined.to_utf8_buffer()
