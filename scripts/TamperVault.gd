class_name TamperVault
extends RefCounted
## 런타임 정수 금고 — 메모리 스캐너(Cheat Engine · GameGuardian · WASM 메모리 뷰어)에 대한 허들(P2-29).
##
## 골드·점수·체력을 평문 int 로 두면 "화면의 숫자를 검색 → 덮어쓰기"가 그대로 통한다.
## 여기서는 값을 난수 키로 XOR 해 보관하므로 평문이 메모리에 없고, **쓸 때마다 키를 갈아
## 모든 칸의 저장 바이트가 함께 바뀐다**(변함/안 변함 스캔으로도 좁히기 어렵다).
## 각 값에는 별도 솔트로 만든 섀도(해시)를 같이 두어, 인코딩된 칸을 찾아 직접 고치면
## 다음 읽기에서 불일치로 드러난다 — `tampered` 가 서고 `tamper_detected` 가 난다.
##
## ⚠️ 이것은 허들이지 방어가 아니다. 클라이언트 메모리는 결국 열리고, 소스가 공개라 방식도
## 공개다. 온라인 랭킹·클라우드 세이브·IAP 를 붙이면 **서버 검증이 본질**이다
## (`LAUNCH_CHECKLIST.md` C). 탐지 시 조치는 호출부 몫이다 — Events 는 그 판을 변조 판으로
## 표시하고, 랭킹 제출(RankingManager)·메타 골드 적립(MetaManager.bank)이 그 표시를 보고
## 건너뛴다. 정상 코드 경로는 전부 set_int 를 거치므로 **오탐은 구조적으로 없다**.
##
## 사용: 값을 직접 필드로 두지 말고 프로퍼티 접근자 뒤에 숨긴다.
##   var _vault := TamperVault.new()
##   var gold: int:
##       get: return _vault.get_int(&"gold")
##       set(value): _vault.set_int(&"gold", value)

signal tamper_detected(name: StringName)

## 섀도 해시용 64비트 홀수 승수(PCG/LCG 계열). 곱셈 오버플로는 GDScript 에서 조용히 감긴다 —
## 그것이 의도다(랩어라운드 해시).
const _MUL: int = 6364136223846793005

var tampered: bool = false   # 불일치를 한 번이라도 봤는가. clear_tamper_flag() 전까지 유지.

var _rng := RandomNumberGenerator.new()
var _key: int = 0
var _salt: int = 0
var _enc: Dictionary = {}      # name -> value ^ _key
var _shadow: Dictionary = {}   # name -> _hash(value)


func _init() -> void:
	_key = _random_key()
	_salt = _random_key()


## 값을 넣는다. 쓰기마다 키를 갈아 모든 칸이 함께 바뀐다(다른 칸의 무결성도 이때 검증한다).
func set_int(name: StringName, value: int) -> void:
	var values := _decode_all()
	values[name] = value
	_key = _random_key()
	_salt = _random_key()
	_enc.clear()
	_shadow.clear()
	for n in values:
		_enc[n] = int(values[n]) ^ _key
		_shadow[n] = _hash(int(values[n]))


## 값을 읽는다(없으면 0). 읽을 때 섀도와 대조하고, 어긋나면 tampered 를 세운다.
func get_int(name: StringName) -> int:
	if not _enc.has(name):
		return 0
	return _verified(name)


func has(name: StringName) -> bool:
	return _enc.has(name)


## 모든 칸을 검증한다. 결정 시점(랭킹 제출·적립)에서 "아직 안 읽은 칸"까지 잡기 위해 쓴다.
func verify_all() -> bool:
	for n in _enc:
		_verified(n)
	return not tampered


## 키만 갈아 끼운다(값 유지). 판 시작 등 "메모리 배치를 바꾸고 싶은" 시점용.
func rekey() -> void:
	var values := _decode_all()
	_key = _random_key()
	_salt = _random_key()
	_enc.clear()
	_shadow.clear()
	for n in values:
		_enc[n] = int(values[n]) ^ _key
		_shadow[n] = _hash(int(values[n]))


## 판 단위 표시라 새 판이 시작될 때 호출부(Events.reset)가 내린다.
func clear_tamper_flag() -> void:
	tampered = false


## 전부 비운다 — 칸·섀도·표시를 버리고 키를 새로 뽑는다. 새 판 시작(Events.reset)용.
## clear_tamper_flag 만 내리고 값을 덮어쓰면 안 된다: 첫 set_int 가 남아 있던 변조 칸을
## 재검증하면서 표시를 다시 세운다(테스트 T4 가 실제로 그렇게 실패했다).
func reset_all() -> void:
	_enc.clear()
	_shadow.clear()
	tampered = false
	_key = _random_key()
	_salt = _random_key()


## 모든 칸을 검증하며 평문으로 풀어 낸다(재인코딩 전용). 검증을 빼먹으면 변조된 칸이
## 재인코딩되면서 섀도까지 새로 계산돼 흔적이 지워진다 — 그래서 반드시 _verified 를 거친다.
func _decode_all() -> Dictionary:
	var out := {}
	for n in _enc:
		out[n] = _verified(n)
	return out


func _verified(name: StringName) -> int:
	var value: int = int(_enc[name]) ^ _key
	if int(_shadow.get(name, 0)) != _hash(value):
		if not tampered:
			tampered = true
			tamper_detected.emit(name)
	return value


func _hash(value: int) -> int:
	return ((value * _MUL) + _salt) ^ (_salt >> 7)


## 64비트 난수 키. 0 이면 XOR 이 항등이 되어 평문이 드러나므로 피한다.
func _random_key() -> int:
	var k: int = (int(_rng.randi()) << 32) | int(_rng.randi())
	return k if k != 0 else 1
