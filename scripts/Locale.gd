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
##
## 한국어/일본어 글리프는 assets/fonts 의 Noto Sans CJK 서브셋을 전역 기본 폰트로 설치해 표시한다.

signal language_changed(lang: String)

const DEFAULT_LANG := "en"
## 지원 언어 코드. 기본은 영어, 한국어/일본어 지원.
const SUPPORTED: Array = ["en", "ko", "ja"]

## 언어 선택기에 표시할 각 언어의 자기 이름(현재 언어와 무관하게 고정).
const NATIVE_NAMES: Dictionary = {"en": "English", "ko": "한국어", "ja": "日本語"}

const SETTING_PATH := "user://language.save"
const FONT_PATH := "res://assets/fonts/NotoSansCJK-Subset.otf"

var current: String = DEFAULT_LANG

## 키 → { 언어코드: 문자열 }. 번역이 없는 언어는 영어(DEFAULT_LANG)로 폴백된다.
const STRINGS: Dictionary = {
	# ── 인트로: "The Last Beacon" (마지막 송신탑) ──────────────────────────
	"intro_title":  {"en": "THE LAST BEACON",        "ko": "마지막 송신탑",        "ja": "最後のビーコン"},
	"intro_l1":     {"en": "Day 47 since the outbreak.",
					 "ko": "감염 발생 +47일.",
					 "ja": "感染発生から47日。"},
	"intro_l2":     {"en": "The cities fell silent.\nThe dead now hunt the living.",
					 "ko": "도시는 침묵했고,\n죽은 자가 산 자를 사냥한다.",
					 "ja": "都市は沈黙し、\n死者が生者を狩る。"},
	"intro_l3":     {"en": "You are the last signal tech\nof a broken unit.",
					 "ko": "당신은 무너진 부대의\n마지막 통신 기술병.",
					 "ja": "あなたは壊滅した部隊の\n最後の通信兵。"},
	"intro_l4":     {"en": "One automated beacon still calls for rescue.",
					 "ko": "자동 송신탑 하나가\n아직 구조를 외치고 있다.",
					 "ja": "自動ビーコンが今も\n救助を呼び続けている。"},
	"intro_l5":     {"en": "Hold the line.\nKeep the signal alive.",
					 "ko": "전선을 사수하라.\n신호를 살려두어라.",
					 "ja": "戦線を守れ。\n信号を絶やすな。"},
	"intro_skip":   {"en": "Skip",   "ko": "건너뛰기",   "ja": "スキップ"},
	"intro_begin":  {"en": "BEGIN",  "ko": "시작",       "ja": "開始"},

	# ── 메인 메뉴 ─────────────────────────────────────────────────────────
	"menu_best":       {"en": "Best Score", "ko": "최고 점수", "ja": "ハイスコア"},
	"menu_difficulty": {"en": "Difficulty", "ko": "난이도",    "ja": "難易度"},
	"menu_new_game":   {"en": "New Game",   "ko": "새 게임",   "ja": "ニューゲーム"},
	"menu_continue":   {"en": "Continue",   "ko": "이어하기",  "ja": "つづける"},
	"menu_language":   {"en": "Language",   "ko": "언어",      "ja": "言語"},
	"title_tagline":   {"en": "SURVIVE THE OUTBREAK", "ko": "감염에서 살아남아라", "ja": "アウトブレイクを生き延びろ"},
	"title_tap":       {"en": "TAP TO START", "ko": "화면을 터치해 시작", "ja": "タップしてスタート"},
	"menu_sound":      {"en": "Sound",       "ko": "사운드",    "ja": "サウンド"},
	"sound_on":        {"en": "On",          "ko": "켜짐",      "ja": "オン"},
	"sound_off":       {"en": "Off",         "ko": "꺼짐",      "ja": "オフ"},
	"menu_options":    {"en": "Options",     "ko": "옵션",      "ja": "オプション"},
	"menu_close":      {"en": "Close",       "ko": "닫기",      "ja": "閉じる"},
	"menu_ranking":    {"en": "Ranking",     "ko": "랭킹",      "ja": "ランキング"},

	# ── 랭킹 오버레이 ─────────────────────────────────────────────────────
	"rank_title":      {"en": "RANKING",     "ko": "랭킹",      "ja": "ランキング"},
	"rank_local_note": {"en": "Best score per mode (this device)",
						"ko": "모드별 최고 점수 (이 기기)",
						"ja": "モード別ハイスコア（この端末）"},
	"rank_online":     {"en": "View Google Play Leaderboard",
						"ko": "Google Play 랭킹 보기",
						"ja": "Google Play ランキングを見る"},
	"diff_easy":       {"en": "Easy",       "ko": "쉬움",      "ja": "イージー"},
	"diff_normal":     {"en": "Normal",     "ko": "보통",      "ja": "ノーマル"},
	"diff_hard":       {"en": "Hard",       "ko": "어려움",    "ja": "ハード"},

	# ── HUD (포맷 문자열은 %d 자리 유지) ──────────────────────────────────
	"hud_score_fmt":   {"en": "Score %d",   "ko": "점수 %d",   "ja": "スコア %d"},
	"hud_best_fmt":    {"en": "Best %d",    "ko": "최고 %d",   "ja": "ベスト %d"},
	"hud_wave_fmt":    {"en": "Wave %d",    "ko": "웨이브 %d", "ja": "ウェーブ %d"},
	"wave_clear_fmt":  {"en": "Wave %d Clear!", "ko": "웨이브 %d 클리어!", "ja": "ウェーブ %d クリア！"},
	"hud_magnet_fmt":  {"en": "Gold Magnet  %ds", "ko": "골드 자석  %d초", "ja": "ゴールド磁石  %d秒"},
	"hud_revive":      {"en": "REVIVE  (Watch Ad)", "ko": "부활  (광고 시청)", "ja": "復活（広告を視聴）"},

	# ── 게임오버 패널 ─────────────────────────────────────────────────────
	"go_score_fmt":      {"en": "Score  %d", "ko": "점수  %d", "ja": "スコア  %d"},
	"go_new_best_fmt":   {"en": "NEW BEST!  %d", "ko": "신기록!  %d", "ja": "新記録！  %d"},
	"go_best_fmt":       {"en": "Best  %d", "ko": "최고  %d", "ja": "ベスト  %d"},
	"go_wave_kills_fmt": {"en": "Wave %d   Kills %d", "ko": "웨이브 %d   처치 %d", "ja": "ウェーブ %d   撃破 %d"},
	"go_retry":          {"en": "Retry",     "ko": "다시하기",   "ja": "リトライ"},
	"go_menu":           {"en": "Main Menu", "ko": "메인 메뉴",  "ja": "メインメニュー"},

	# ── 상점 ──────────────────────────────────────────────────────────────
	"shop_clear_title":  {"en": "Wave Clear!", "ko": "웨이브 클리어!", "ja": "ウェーブクリア！"},
	"shop_continue":     {"en": "Continue ->", "ko": "계속 ->", "ja": "つづける →"},
	"shop_max":          {"en": "MAX", "ko": "최대", "ja": "最大"},
	"shop_ad_claimed":   {"en": "Bonus claimed", "ko": "보너스 받음", "ja": "ボーナス受取済"},
	"shop_ad_unavail":   {"en": "Free Gold (ad unavailable)", "ko": "무료 골드 (광고 없음)", "ja": "無料ゴールド（広告なし）"},
	"shop_ad_gold_fmt":  {"en": "+%d Gold  (Watch Ad)", "ko": "+%d 골드  (광고 시청)", "ja": "+%d ゴールド（広告視聴）"},
	"sec_weapon":    {"en": "WEAPON",    "ko": "무기",   "ja": "武器"},
	"sec_orb":       {"en": "ORB",       "ko": "오브",   "ja": "オーブ"},
	"sec_lightning": {"en": "LIGHTNING", "ko": "번개",   "ja": "稲妻"},
	"sec_survival":  {"en": "SURVIVAL",  "ko": "생존",   "ja": "生存"},

	# 업그레이드 이름/설명
	"upg_speed_name":            {"en": "Move Speed",     "ko": "이동 속도",    "ja": "移動速度"},
	"upg_speed_desc":            {"en": "+30 move speed", "ko": "+30 이동 속도", "ja": "+30 移動速度"},
	"upg_atk_speed_name":        {"en": "Atk Speed",      "ko": "공격 속도",    "ja": "攻撃速度"},
	"upg_atk_speed_desc":        {"en": "-15% fire delay","ko": "-15% 발사 딜레이", "ja": "-15% 発射ディレイ"},
	"upg_bullet_damage_name":    {"en": "Bullet Dmg",     "ko": "총알 데미지",  "ja": "弾ダメージ"},
	"upg_bullet_damage_desc":    {"en": "+1 bullet damage","ko": "+1 총알 데미지","ja": "+1 弾ダメージ"},
	"upg_multi_bullet_name":     {"en": "Multi-Shot",     "ko": "멀티샷",       "ja": "マルチショット"},
	"upg_multi_bullet_desc":     {"en": "+1 extra bullet","ko": "+1 추가 총알", "ja": "+1 追加弾"},
	"upg_orbs_name":             {"en": "Orb Shield",     "ko": "오브 실드",    "ja": "オーブシールド"},
	"upg_orbs_desc":             {"en": "+1 orbiting orb","ko": "+1 공전 오브", "ja": "+1 周回オーブ"},
	"upg_orb_damage_name":       {"en": "Orb Dmg",        "ko": "오브 데미지",  "ja": "オーブダメージ"},
	"upg_orb_damage_desc":       {"en": "+1 orb damage",  "ko": "+1 오브 데미지","ja": "+1 オーブダメージ"},
	"upg_lightning_name":        {"en": "Lightning Bolt", "ko": "번개",         "ja": "稲妻"},
	"upg_lightning_desc":        {"en": "Faster strikes", "ko": "더 빠른 낙뢰", "ja": "落雷が高速化"},
	"upg_lightning_count_name":  {"en": "Lightning Count","ko": "번개 갯수",     "ja": "稲妻の数"},
	"upg_lightning_count_desc":  {"en": "+1 lightning bolt","ko": "+1 번개 가닥","ja": "+1 稲妻"},
	"upg_lightning_damage_name": {"en": "Lightning Dmg",  "ko": "번개 데미지",  "ja": "稲妻ダメージ"},
	"upg_lightning_damage_desc": {"en": "+1 lightning damage","ko": "+1 번개 데미지","ja": "+1 稲妻ダメージ"},
	"upg_max_health_name":       {"en": "Max HP",         "ko": "최대 체력",    "ja": "最大HP"},
	"upg_max_health_desc":       {"en": "+1 heart (heals)","ko": "+1 하트 (회복)","ja": "+1 ハート（回復）"},
	"upg_heal_name":             {"en": "Heal HP",        "ko": "체력 회복",    "ja": "HP回復"},
	"upg_heal_desc":             {"en": "Full HP restore","ko": "체력 전부 회복","ja": "HP全回復"},

	# ── 보상형 광고 오버레이 ──────────────────────────────────────────────
	"ad_title":      {"en": "REWARDED AD", "ko": "보상형 광고", "ja": "リワード広告"},
	"ad_watch_fmt":  {"en": "Watch  %d",   "ko": "시청  %d",    "ja": "視聴  %d"},
	"ad_finished":   {"en": "Ad finished", "ko": "시청 완료",   "ja": "視聴完了"},
	"ad_claim":      {"en": "CLAIM REWARD","ko": "보상 받기",   "ja": "報酬を受取"},
	"ad_demo_hint":  {"en": "(demo placeholder — real video plays here in a build)",
					  "ko": "(데모 — 실제 빌드에선 영상이 재생됩니다)",
					  "ja": "(デモ — 製品版では動画が再生されます)"},
}


func _ready() -> void:
	current = _load_language()
	_install_font()


## 현재 언어의 문자열. 없으면 영어 폴백, 그래도 없으면 키 자체를 반환(개발 중 누락 식별).
func t(key: String) -> String:
	var entry: Dictionary = STRINGS.get(key, {})
	if entry.is_empty():
		return key
	return entry.get(current, entry.get(DEFAULT_LANG, key))


## 언어별 자기 이름(선택기 라벨용). 예: native_name("ja") == "日本語"
func native_name(lang: String) -> String:
	return NATIVE_NAMES.get(lang, lang)


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
	var sys := OS.get_locale_language()   # 예: "en", "ko", "ja"
	return sys if SUPPORTED.has(sys) else DEFAULT_LANG


# ── 전역 기본 폰트: 한/일 글리프를 위해 Noto Sans CJK 서브셋을 설치 ──
# 번들 폰트가 (에디터 import 후) 있으면 그것을, 없으면 기기 시스템 CJK 폰트로 폴백.
func _install_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		var fnt = load(FONT_PATH)
		if fnt is Font:
			ThemeDB.fallback_font = fnt
			return
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([
		"Noto Sans CJK KR", "Noto Sans KR", "Malgun Gothic", "Apple SD Gothic Neo",
		"Noto Sans CJK JP", "Hiragino Sans", "Yu Gothic", "sans-serif"])
	sf.allow_system_fallback = true
	ThemeDB.fallback_font = sf


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
