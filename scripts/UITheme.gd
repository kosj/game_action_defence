extends Node
## 전역 UI 테마 (Autoload "UITheme").
## 루트 윈도우에 Theme 를 설치해 모든 컨트롤의 기본 폰트/크기/버튼·패널 스타일·색을 통일한다.
## (개별 위젯의 add_theme_*_override 는 그대로 우선 적용되므로 기존 강조 스타일은 유지된다.)

# 공용 팔레트 — 다른 UI 코드에서도 참조해 톤을 맞출 수 있다.
const BG_DEEP   := Color(0.06, 0.07, 0.10)
const BG_PANEL  := Color(0.11, 0.12, 0.17, 0.98)
const BTN_BG    := Color(0.17, 0.19, 0.26)
const BTN_LINE  := Color(0.38, 0.42, 0.52)
const ACCENT    := Color(1.00, 0.82, 0.25)   # 금색 강조
const TEXT      := Color(0.90, 0.92, 0.96)
const TEXT_DIM  := Color(0.66, 0.70, 0.78)

# 로고("ZOMBIE BUSTER")에서 뽑은 색 — 타이틀/인트로 텍스트를 로고와 같은 문법으로 맞춘다.
const LOGO_CREAM := Color(0.93, 0.90, 0.82)   # 글자 본체(크림)
const LOGO_BLOOD := Color(0.70, 0.12, 0.13)   # 외곽선/흘러내림(핏빛)

# 섹션 강조색 — 패널마다 흩어져 있던 색 리터럴을 한곳에 모은다. 화면이 늘어도 톤이 흔들리지
# 않도록 새 패널은 반드시 아래 상수 중 하나를 쓸 것. (프레임 색은 텍스처 아트가 담당하므로
# 실제로 눈에 보이는 건 제목 라벨 색이다 — SEC_*_TXT 는 어두운 패널 위에서 읽히게 밝힌 값.)
const SEC_NEUTRAL := Color(0.35, 0.38, 0.50)   # 옵션·랭킹
const SEC_POWER   := Color(0.60, 0.45, 0.90)   # 강화
const SEC_CHAR    := Color(0.40, 0.80, 0.95)   # 캐릭터
const SEC_ARENA   := Color(0.50, 0.85, 0.50)   # 아레나(테마)
const SEC_QUEST   := Color(0.45, 0.90, 0.50)   # 과제
const SEC_ACHIEVE := Color(0.90, 0.75, 0.30)   # 도전과제
const SEC_REWARD  := Color(1.00, 0.85, 0.35)   # 보상함
const SEC_CODEX   := Color(0.55, 0.70, 0.95)   # 도감

# 메인 메뉴 버튼 3단 위계 — 플레이트는 모두 같은 금속으로 두고 위계는 크기·명도로 만든다.
# (색을 8가지 쓰면 오히려 구분이 안 된다: 예전엔 도전과제/보상/랭킹이 틴트 후 거의 같은 금색이었다.)
const MENU_PRIMARY   := Color(0.78, 0.16, 0.16)   # 1차 CTA — 로고의 핏빛 계열
const MENU_SECONDARY := Color(0.52, 0.56, 0.66)   # 2차 — 밝은 건메탈
const MENU_TERTIARY  := Color(0.32, 0.35, 0.43)   # 3차 — 어두운 건메탈(6개 전부 동일)

# 3차 버튼의 구분은 플레이트 색이 아니라 "좌측 아이콘의 모양+색"이 담당한다.
const MENU_ICON_REWARD := Color(1.00, 0.82, 0.30)   # 보상 계열(도전과제·보상함·랭킹)
const MENU_ICON_QUEST  := Color(0.55, 0.95, 0.55)   # 과제
const MENU_ICON_POWER  := Color(0.78, 0.58, 1.00)   # 영구 강화
const MENU_ICON_PLAIN  := Color(0.70, 0.74, 0.84)   # 설정
const MENU_ICON_CODEX  := Color(0.68, 0.82, 1.00)   # 도감

const SEC_POWER_TXT   := Color(0.85, 0.70, 1.00)
const SEC_CHAR_TXT    := Color(0.60, 0.90, 1.00)
const SEC_ARENA_TXT   := Color(0.70, 1.00, 0.70)
const SEC_QUEST_TXT   := Color(0.60, 1.00, 0.60)
const SEC_ACHIEVE_TXT := Color(1.00, 0.85, 0.40)
const SEC_REWARD_TXT  := Color(1.00, 0.88, 0.45)
const SEC_CODEX_TXT   := Color(0.72, 0.84, 1.00)

const FONT_PATH := "res://assets/fonts/NotoSansCJK-Subset.otf"
const BOLD_PATH := "res://assets/fonts/NotoSansCJK-Subset-Bold.otf"

var _bold_cache: Font = null


func _ready() -> void:
	# 루트(Window)는 이미 트리에 있으나, 안전하게 다음 프레임에 설치한다.
	call_deferred("_install")
	# 전역 버튼 피드백 — 이후 트리에 추가되는 모든 Button 에 눌림 팝(스케일) 을 자동 부여.
	get_tree().node_added.connect(_hook_button)


## 씬 전환 후에도 새로 생성되는 버튼마다 눌림 애니메이션을 연결한다(개별 위젯 수정 불필요).
##
## node_added 는 트리에 추가되는 모든 노드에 발화하므로 오브젝트 풀이 재사용하는 총알·FX 도
## 여기를 지나간다. 그래도 전역 훅을 유지하는 이유는 커버리지다 — 씬에 직접 배치된 버튼은
## UIStyle.apply_button_style() 을 거치지 않아, 그쪽으로 옮기면 눌림 피드백이 조용히 사라진다.
## 대신 비용은 아래 `n is Button` 한 번의 타입 검사로 끝난다(풀 스폰은 전부 Node2D 라 즉시 탈락).
func _hook_button(n: Node) -> void:
	if not (n is Button):
		return
	# 버튼이 트리에서 빠졌다 다시 추가되면 node_added 가 재발화한다 — 중복 연결 시 Godot 이
	# 에러를 내고 눌림 스케일도 두 번 적용되므로 메타로 1회만 연결한다.
	if n.has_meta("_btn_pop"):
		return
	n.set_meta("_btn_pop", true)
	n.button_down.connect(_btn_press.bind(n))
	n.button_up.connect(_btn_release.bind(n))


func _btn_press(b: Button) -> void:
	if not is_instance_valid(b):
		return
	b.pivot_offset = b.size * 0.5   # 중심 기준 스케일
	b.scale = Vector2(0.94, 0.94)


func _btn_release(b: Button) -> void:
	if not is_instance_valid(b):
		return
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _install() -> void:
	var root := get_tree().root
	if root:
		root.theme = build()


func build() -> Theme:
	var t := Theme.new()
	# 기본 폰트는 ProjectSettings(gui/theme/custom_font)에서 엔진 레벨로 지정한다.
	# 런타임 테마의 default_font 는 웹 빌드에서 적용이 누락돼 CJK 가 깨지므로 여기서 설정하지 않는다.
	# (제목/버튼의 굵은 폰트는 아래 per-type 오버라이드로 계속 적용한다.)
	t.default_font_size = 19

	# ── Button ────────────────────────────────────────────────
	t.set_stylebox("normal",   "Button", _btn(BTN_LINE))
	t.set_stylebox("hover",    "Button", _btn(BTN_LINE, 0.28))
	t.set_stylebox("pressed",  "Button", _btn(ACCENT, 0.52))
	t.set_stylebox("disabled", "Button", _btn(Color(0.40, 0.40, 0.45), 0.45))
	t.set_stylebox("focus",    "Button", _empty())
	var bold := bold_font()
	if bold:
		t.set_font("font", "Button", bold)   # 버튼 라벨은 굵게
	t.set_color("font_color",          "Button", TEXT)
	t.set_color("font_hover_color",    "Button", Color.WHITE)
	t.set_color("font_pressed_color",  "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))
	t.set_font_size("font_size", "Button", 20)

	# ── Panel / PanelContainer ────────────────────────────────
	t.set_stylebox("panel", "Panel", _panel())
	t.set_stylebox("panel", "PanelContainer", _panel())

	# ── ProgressBar ───────────────────────────────────────────
	# 지금까지 진행바는 스타일이 없어 엔진 기본 회색 막대로 그려졌다(퀘스트 팝업이 미완성으로
	# 보이던 주된 이유). HUD 게이지와 같은 "어두운 함몰 트랙 + 골드 헤어라인" 문법으로 통일한다.
	# 텍스처 나인패치 대신 StyleBoxFlat 을 쓰는 이유: ProgressBar 는 채움을 x=0 부터 전체 높이로
	# 그려서 프레임 림을 덮고, 바가 얇으면(12~20px) 나인패치 코너가 서로 겹쳐 뭉개진다.
	t.set_stylebox("background", "ProgressBar", progress_track())
	t.set_stylebox("fill", "ProgressBar", progress_fill(ACCENT))
	t.set_color("font_color", "ProgressBar", TEXT)

	# ── Label ─────────────────────────────────────────────────
	t.set_color("font_color", "Label", TEXT)

	# ── HSeparator ────────────────────────────────────────────
	var sep := StyleBoxLine.new()
	sep.color = Color(1, 1, 1, 0.10)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)

	return t


## 기본 버튼도 UIStyle 과 같은 금속 플레이트를 쓰되 여백만 테마 기본값으로 조정.
func _btn(accent: Color, darken: float = 0.42) -> StyleBoxTexture:
	var sb := UIStyle.button_box(accent, darken)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	return sb


func _panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_PANEL
	sb.border_color = Color(0.32, 0.36, 0.46)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	return sb


func _empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


## 진행바 트랙(배경) — 어두운 함몰부 + 옅은 골드 테두리. 0% 일 때도 이 트랙이 보이므로
## 진행 0 인 항목이 "바가 없는 빈 행"으로 보이지 않는다.
static func progress_track() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.07, 0.92)
	sb.set_corner_radius_all(6)
	sb.corner_detail = 6
	sb.anti_aliasing = true
	sb.set_border_width_all(1)
	sb.border_color = Color(0.62, 0.50, 0.22, 0.55)
	return sb


## 진행바 채움 — 호출부가 색만 바꿔 쓸 수 있게 색을 인자로 받는다(퀘스트=금색, 완료=초록 등).
static func progress_fill(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(6)
	sb.corner_detail = 6
	sb.anti_aliasing = true
	return sb


## 굵은(Bold) 폰트 — 제목/헤더용. 번들 Bold 서브셋이 있으면 사용, 없으면 기본 폰트.
func bold_font() -> Font:
	if _bold_cache:
		return _bold_cache
	if ResourceLoader.exists(BOLD_PATH):
		var f = load(BOLD_PATH)
		if f is Font:
			_bold_cache = f
			return _bold_cache
	_bold_cache = _font()
	return _bold_cache


## 라벨을 제목 스타일(굵게)로 만든다. 색/크기는 호출부 설정을 유지.
func heading(label: Label) -> void:
	var b := bold_font()
	if b:
		label.add_theme_font_override("font", b)


## 라벨에 어두운 외곽선을 넣어 밝은 배경/전장 위에서도 글자가 또렷하게 읽히도록 한다.
static func outline_label(label: Label, size: int = 5, col: Color = Color(0.0, 0.0, 0.0, 0.7)) -> void:
	label.add_theme_constant_override("outline_size", size)
	label.add_theme_color_override("font_outline_color", col)


## 세로 그라데이션 배경(TextureRect, 전체 앵커). 메뉴/팝업 등 단색 배경 대체용.
static func make_gradient_bg(top: Color, bottom: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	var tr := TextureRect.new()
	tr.texture = tex
	tr.anchor_right = 1.0
	tr.anchor_bottom = 1.0
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## 화면 가장자리를 부드럽게 어둡게 하는 비네트 오버레이.
static func make_vignette() -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load("res://assets/ui/vignette.png")
	tr.anchor_right = 1.0
	tr.anchor_bottom = 1.0
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		var f = load(FONT_PATH)
		if f is Font:
			return f
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([
		"Noto Sans CJK KR", "Noto Sans KR", "Malgun Gothic", "Apple SD Gothic Neo",
		"Noto Sans CJK JP", "Hiragino Sans", "Yu Gothic", "sans-serif"])
	sf.allow_system_fallback = true
	return sf
