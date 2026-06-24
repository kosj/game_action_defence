extends Node
## 다국어(i18n) 로컬라이제이션 (Autoload "Locale").
##
## 코드 기반 사전 — 에디터의 CSV/PO import 과정 없이 동작하고, 언어 추가가 쉽다.
## 새 언어는 SUPPORTED 에 코드를 넣고 STRINGS 각 항목에 해당 코드를 채우기만 하면 된다.
##
## 사용:
##   Locale.t("intro_title")              # 현재 언어 문자열
##   Locale.set_language("ko")            # 언어 전환(+ language_changed 시그널)
##   Locale.language_changed.connect(...) # 동적 UI 재번역용

signal language_changed(lang: String)

const DEFAULT_LANG := "en"
## 지원 언어 코드. 우선 영어로 노출하고 한국어 번역을 함께 준비해 둔다(전환만 하면 적용).
const SUPPORTED: Array = ["en", "ko"]

const SETTING_PATH := "user://language.save"

var current: String = DEFAULT_LANG

## 키 → { 언어코드: 문자열 }. 번역이 없는 언어는 영어(DEFAULT_LANG)로 폴백된다.
const STRINGS: Dictionary = {
	# ── 인트로: "The Last Beacon" (마지막 송신탑) ──────────────────────────
	"intro_title":  {"en": "THE LAST BEACON",                              "ko": "마지막 송신탑"},
	"intro_l1":     {"en": "Day 47 since the outbreak.",                   "ko": "감염 발생 +47일."},
	"intro_l2":     {"en": "The cities fell silent.\nThe dead now hunt the living.",
					 "ko": "도시는 침묵했고,\n죽은 자가 산 자를 사냥한다."},
	"intro_l3":     {"en": "You are the last signal tech\nof a broken unit.",
					 "ko": "당신은 무너진 부대의\n마지막 통신 기술병."},
	"intro_l4":     {"en": "One automated beacon still calls for rescue.",
					 "ko": "자동 송신탑 하나가\n아직 구조를 외치고 있다."},
	"intro_l5":     {"en": "Hold the line.\nKeep the signal alive.",
					 "ko": "전선을 사수하라.\n신호를 살려두어라."},
	"intro_skip":   {"en": "Skip",   "ko": "건너뛰기"},
	"intro_begin":  {"en": "BEGIN",  "ko": "시작"},
}


func _ready() -> void:
	current = _load_language()


## 현재 언어의 문자열. 없으면 영어 폴백, 그래도 없으면 키 자체를 반환(개발 중 누락 식별).
func t(key: String) -> String:
	var entry: Dictionary = STRINGS.get(key, {})
	if entry.is_empty():
		return key
	return entry.get(current, entry.get(DEFAULT_LANG, key))


func set_language(lang: String) -> void:
	if not SUPPORTED.has(lang):
		lang = DEFAULT_LANG
	if lang == current:
		return
	current = lang
	_save_language(lang)
	language_changed.emit(current)


## 기기 언어를 지원 목록과 대조해 추천 코드를 반환(언어 선택 UI 기본값 등에 활용).
func device_language() -> String:
	var sys := OS.get_locale_language()   # 예: "en", "ko"
	return sys if SUPPORTED.has(sys) else DEFAULT_LANG


# ── 저장/복원: 선택 언어를 세션 간 보존. 저장값이 없으면 우선 영어로 시작한다 ──
func _load_language() -> String:
	if not FileAccess.file_exists(SETTING_PATH):
		return DEFAULT_LANG
	var f := FileAccess.open(SETTING_PATH, FileAccess.READ)
	if f == null:
		return DEFAULT_LANG
	var lang := f.get_as_text().strip_edges()
	return lang if SUPPORTED.has(lang) else DEFAULT_LANG


func _save_language(lang: String) -> void:
	var f := FileAccess.open(SETTING_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(lang)
