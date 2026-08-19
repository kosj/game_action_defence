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
	"title_tagline":   {"en": "SURVIVE THE OUTBREAK", "ko": "감염에서 살아남아라", "ja": "アウトブレイクを生きのびろ"},
	"title_tap":       {"en": "TAP TO START", "ko": "화면을 터치해 시작", "ja": "タップしてスタート"},
	"menu_sound":      {"en": "Sound",       "ko": "사운드",    "ja": "サウンド"},
	"sound_on":        {"en": "On",          "ko": "켜짐",      "ja": "オン"},
	"sound_off":       {"en": "Off",         "ko": "꺼짐",      "ja": "オフ"},
	"menu_options":    {"en": "Options",     "ko": "옵션",      "ja": "オプション"},
	"menu_close":      {"en": "Close",       "ko": "닫기",      "ja": "とじる"},
	"menu_ranking":    {"en": "Ranking",     "ko": "랭킹",      "ja": "ランキング"},
	# 일본어는 가나 표기가 기본이다 — 서브셋 폰트의 한자는 89자뿐이고, 원본에도 없어 되살릴 수
	# 없는 글자가 많다(実/績/強/選/択/宝/箱/体/分 등). tools/font_known_absent.txt 참고.
	"menu_achievements": {"en": "Achievements", "ko": "도전과제",  "ja": "アチーブメント"},
	"menu_quests":       {"en": "Quests",       "ko": "퀘스트",    "ja": "クエスト"},
	"menu_rewards":      {"en": "Rewards",      "ko": "보상함",    "ja": "報酬"},
	"menu_powerup":      {"en": "Power Up",     "ko": "영구 강화", "ja": "パワーアップ"},
	"menu_codex":        {"en": "Codex",         "ko": "도감",      "ja": "コレクション"},
	"rewards_src_quest": {"en": "Quest reward",       "ko": "퀘스트 보상",   "ja": "クエスト報酬"},
	"rewards_src_ach":   {"en": "Achievement reward", "ko": "도전과제 보상", "ja": "アチーブメント報酬"},
	"rewards_empty":     {"en": "No rewards waiting", "ko": "받을 보상이 없습니다", "ja": "受け取る報酬はありません"},

	# ── 팝업 제목/문구 (전부 하드코딩 영어·한국어였다) ────────────────────
	"opt_copy_log":      {"en": "COPY PLAY LOG (%d)", "ko": "플레이 기록 복사 (%d)",
		"ja": "プレイ記録をコピー (%d)"},
	"opt_copy_log_done": {"en": "COPIED", "ko": "복사했습니다", "ja": "コピーしました"},
	"opt_log_hint":      {"en": "Runs saved on this device. Nothing is sent anywhere.",
		"ko": "이 기기에만 저장된 플레이 기록입니다. 어디로도 전송되지 않습니다.",
		"ja": "このデバイスにだけのこります。どこにもおくりません。"},
	"popup_power":       {"en": "PERMANENT UPGRADES", "ko": "영구 강화", "ja": "パワーアップ"},

	# ── 도감(P1-13) ───────────────────────────────────────────────────────
	# 일본어는 **가나만** 쓴다. 서브셋 폰트의 한자는 89자뿐이고 図/鑑/項/目/名/前/隠 이 전부
	# 없다(subset_fonts.py 문서 참고). 되살릴 원본도 없으므로 한자를 피하는 것이 유일한 길이다.
	# 항목 이름(무기·캐릭터·아레나)은 카탈로그의 display 라서 전 언어 공통 영어다.
	"codex_hint":        {"en": "Undiscovered entries keep their name hidden.",
		"ko": "아직 보지 못한 항목은 이름이 가려집니다.",
		"ja": "まだみつけていないものはシルエットのままです。"},
	"codex_progress":    {"en": "Discovered %d / %d", "ko": "발견 %d / %d",
		"ja": "みつけた %d / %d"},
	"codex_sec_weapon":    {"en": "WEAPONS",    "ko": "무기",    "ja": "ウェポン"},
	"codex_sec_evolution": {"en": "EVOLUTIONS", "ko": "진화",    "ja": "エボリューション"},
	"codex_sec_passive":   {"en": "PASSIVES",   "ko": "패시브",  "ja": "パッシブ"},
	"codex_sec_zombie":    {"en": "ZOMBIES",    "ko": "좀비",    "ja": "ゾンビ"},
	"codex_sec_boss":      {"en": "BOSSES",     "ko": "보스",    "ja": "ボス"},
	"codex_sec_survivor":  {"en": "SURVIVORS",  "ko": "생존자",  "ja": "サバイバー"},
	"codex_sec_arena":     {"en": "ARENAS",     "ko": "아레나",  "ja": "アリーナ"},

	# ── 위협 등급(P1-12) ──────────────────────────────────────────────────
	# 일본어는 가나 표기다(서브셋 폰트 제약 — 위 도감 주석과 같은 이유).
	"popup_threat":      {"en": "THREAT RANK", "ko": "위협 등급", "ja": "スレットランク"},
	"threat_badge_fmt":  {"en": "THREAT %d",   "ko": "위협 %d",   "ja": "スレット %d"},
	"threat_rank_fmt":   {"en": "RANK %d",     "ko": "등급 %d",   "ja": "ランク %d"},
	"threat_hint":       {"en": "Clearing a boss unlocks the next rank.",
		"ko": "보스를 처치하면 다음 등급이 열립니다.",
		"ja": "ボスをたおすとつぎのランクがひらきます。"},
	"threat_locked":     {"en": "Locked", "ko": "잠김", "ja": "ロック"},
	"threat_best_fmt":   {"en": "Best %s", "ko": "최고 %s", "ja": "ベスト %s"},
	"threat_base":       {"en": "Baseline difficulty", "ko": "기본 난이도",
		"ja": "きほんのむずかしさ"},
	"threat_rule_enemy_hp":    {"en": "Enemy HP %s",       "ko": "적 체력 %s",     "ja": "てきのHP %s"},
	"threat_rule_enemy_speed": {"en": "Enemy speed %s",    "ko": "적 이동속도 %s", "ja": "てきのそくど %s"},
	"threat_rule_boss_hp":     {"en": "Boss HP %s",        "ko": "보스 체력 %s",   "ja": "ボスのHP %s"},
	"threat_rule_boss_heal":   {"en": "Boss self-heal %s", "ko": "보스 자가회복 %s", "ja": "ボスのかいふく %s"},
	"threat_rule_chest":       {"en": "Chest interval %s", "ko": "보물상자 주기 %s", "ja": "たからばこのかんかく %s"},
	"threat_rule_elite":       {"en": "Elite interval %s", "ko": "엘리트 주기 %s", "ja": "エリートのかんかく %s"},
	"threat_rule_start_hp":    {"en": "Starting HP %s",    "ko": "시작 체력 %s",   "ja": "スタートHP %s"},
	"popup_character":   {"en": "CHOOSE YOUR SURVIVOR", "ko": "생존자 선택", "ja": "サバイバー"},
	"popup_achievements":{"en": "ACHIEVEMENTS", "ko": "도전과제", "ja": "アチーブメント"},
	"popup_quests":      {"en": "QUESTS", "ko": "퀘스트", "ja": "クエスト"},
	"popup_rewards":     {"en": "REWARDS", "ko": "보상함", "ja": "報酬"},
	"popup_arena":       {"en": "CHOOSE ARENA", "ko": "아레나 선택", "ja": "アリーナ"},
	"quest_hint":        {"en": "Rewards stack in REWARDS. Finishing a tier unlocks a bigger one.",
						  "ko": "완료 보상은 보상함에 쌓입니다. 달성하면 더 큰 목표가 열립니다.",
						  "ja": "報酬はリワードにたまります。クリアすると、つぎのクエストが開きます。"},
	"rewards_hint":      {"en": "Quest and achievement rewards arrive here. Claim them as meta gold.",
						  "ko": "퀘스트·도전과제 보상이 여기 쌓입니다. 받아서 메타 골드로 바꾸세요.",
						  "ja": "クエストとアチーブメントの報酬がここにたまります。"},
	"rewards_claim":     {"en": "CLAIM", "ko": "받기", "ja": "受け取る"},
	"rewards_claim_all": {"en": "CLAIM ALL", "ko": "모두 받기", "ja": "すべて受け取る"},
	"rewards_total_fmt": {"en": "Total waiting  %d", "ko": "대기 중 합계  %d", "ja": "トータル  %d"},

	# ── 공용: 골드·해금 상태 (P2-3, 캐릭터/아레나 팝업이 함께 쓴다) ──────────
	"gold_fmt":        {"en": "Gold: %d", "ko": "골드: %d", "ja": "ゴールド: %d"},
	"unlock_cost_fmt": {"en": "Unlock: %d gold  (tap to buy)",
						"ko": "해금: %d 골드  (탭하여 구매)",
						"ja": "アンロック: %d ゴールド（タップ）"},
	"locked":          {"en": "Locked", "ko": "잠금", "ja": "ロック"},
	"locked_by_fmt":   {"en": "Locked — %s", "ko": "잠금 — %s", "ja": "ロック — %s"},
	"locked_by_ach":   {"en": "complete an achievement", "ko": "도전과제 달성 필요",
						"ja": "アチーブメントでアンロック"},

	# ── 레벨업 모달 (레벨업마다 뜬다 — 인게임 최다 노출) ────────────────────
	"levelup_title_fmt": {"en": "LEVEL %d  ·  CHOOSE AN UPGRADE",
						  "ko": "레벨 %d  ·  강화 선택",
						  "ja": "レベル %d  ·  アップグレードをえらぶ"},

	# ── 보물상자 보상 카드 ────────────────────────────────────────────────
	"tap_continue":    {"en": "tap to continue", "ko": "탭하여 계속", "ja": "タップでつづける"},

	# ── 필드 아이템 픽업 라벨(월드에 그린다) ───────────────────────────────
	"pickup_bomb":     {"en": "Bomb", "ko": "폭탄", "ja": "ボム"},
	"pickup_evolution": {"en": "Evolution", "ko": "진화", "ja": "エボリューション"},
	"pickup_treasure": {"en": "Treasure", "ko": "보물", "ja": "トレジャー"},

	# ── 랭킹 오버레이 ─────────────────────────────────────────────────────
	"rank_title":      {"en": "RANKING",     "ko": "랭킹",      "ja": "ランキング"},
	"rank_local_note": {"en": "Best score per mode (this device)",
						"ko": "모드별 최고 점수 (이 기기)",
						"ja": "モードごとのハイスコア（このデバイス）"},
	"rank_online":     {"en": "View Google Play Leaderboard",
						"ko": "Google Play 랭킹 보기",
						"ja": "Google Play ランキングへ"},
	"diff_easy":       {"en": "Easy",       "ko": "쉬움",      "ja": "イージー"},
	"diff_normal":     {"en": "Normal",     "ko": "보통",      "ja": "ノーマル"},
	"diff_hard":       {"en": "Hard",       "ko": "어려움",    "ja": "ハード"},

	# ── HUD (포맷 문자열은 %d 자리 유지) ──────────────────────────────────
	"hud_score_fmt":   {"en": "Score %d",   "ko": "점수 %d",   "ja": "スコア %d"},
	"hud_hp_fmt":      {"en": "HP %d / %d", "ko": "체력 %d / %d", "ja": "HP %d / %d"},
	"hud_best_fmt":    {"en": "Best %d",    "ko": "최고 %d",   "ja": "ベスト %d"},
	"hud_kills_fmt":   {"en": "%d Kills",   "ko": "%d 처치",   "ja": "%d キル"},
	"boss_cleared":    {"en": "Boss %d Clear!", "ko": "보스 %d 클리어!", "ja": "ボス %d クリア！"},
	"run_cleared":     {"en": "SURVIVED 30:00\nCLEAR!", "ko": "30분 생존\n클리어!", "ja": "30:00 生存\nクリア！"},
	"hud_magnet_fmt":  {"en": "XP Magnet  %ds", "ko": "잼 자석  %d초", "ja": "ジェム磁石  %d秒"},
	"hud_revive":      {"en": "REVIVE  (Watch Ad)", "ko": "부활  (광고 시청)", "ja": "復活（広告を視聴）"},
	# 서브셋 폰트 주의: 일본어는 한자 글리프가 서브셋에 없을 수 있어 가나 위주로 쓴다.
	"hud_goal_fmt":    {"en": "SURVIVE %s → CLEAR", "ko": "%s 생존 → 클리어", "ja": "%s 生存 → クリア"},
	"hud_overtime":    {"en": "OVERTIME", "ko": "연장전", "ja": "OVERTIME"},
	"hud_swarm":       {"en": "!! SWARM !!", "ko": "!! 좀비 무리 !!", "ja": "!! ゾンビラッシュ !!"},
	"hud_elite":       {"en": "!! ELITE PACK !!", "ko": "!! 정예 무리 !!", "ja": "!! エリート !!"},
	# 마일스톤 카운트다운(P1-4). 기존 문구의 글자만 조합해 폰트 서브셋을 늘리지 않는다.
	"hud_boss_in_fmt":  {"en": "BOSS IN %ds",  "ko": "보스 %d초",  "ja": "ボス %d秒"},
	"hud_elite_in_fmt": {"en": "ELITE IN %ds", "ko": "정예 %d초", "ja": "エリート %d秒"},

	# ── 날씨 전환 배너(WeatherSystem) ─────────────────────────────────────
	# ja 는 가나로 적는다 — 번들 폰트에 한자가 89자뿐이라 雨/雪/霧/砂嵐/晴 이 들어 있지 않다.
	# (게임 HUD 에서 가타카나 외래어 표기는 일본어로도 자연스럽다)
	"weather_rain":    {"en": "RAIN",       "ko": "비",         "ja": "レイン"},
	"weather_snow":    {"en": "SNOW",       "ko": "눈",         "ja": "スノー"},
	"weather_dust":    {"en": "DUST STORM", "ko": "모래바람",   "ja": "サンドストーム"},
	"weather_clear":   {"en": "CLEARING",   "ko": "날이 갠다",  "ja": "はれてきた"},

	"go_victory":      {"en": "VICTORY!", "ko": "승리!", "ja": "VICTORY!"},
	"pause_title":     {"en": "PAUSED", "ko": "일시정지", "ja": "ポーズ"},
	"pause_time_fmt":  {"en": "Time  %s", "ko": "생존 시간  %s", "ja": "タイム  %s"},

	# ── 게임오버 패널 ─────────────────────────────────────────────────────
	"go_score_fmt":      {"en": "Score  %d", "ko": "점수  %d", "ja": "スコア  %d"},
	"go_new_best_fmt":   {"en": "NEW BEST!  %d", "ko": "신기록!  %d", "ja": "新記録！  %d"},
	"go_best_fmt":       {"en": "Best  %d", "ko": "최고  %d", "ja": "ベスト  %d"},
	"go_retry":          {"en": "Retry",     "ko": "다시하기",   "ja": "リトライ"},
	"go_menu":           {"en": "Main Menu", "ko": "메인 메뉴",  "ja": "メインメニュー"},
	"pause_resume":      {"en": "Resume", "ko": "계속하기", "ja": "再開"},

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
