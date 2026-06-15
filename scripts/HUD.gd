extends CanvasLayer
## HUD: 골드·체력·웨이브·경과시간을 Events 시그널로 받아 실시간 갱신. 게임오버 패널 제어.

const HEART_FULL := preload("res://assets/ui/ui_heart_full.png")
const HEART_EMPTY := preload("res://assets/ui/ui_heart_empty.png")

@onready var gold_label: Label = $GoldLabel
@onready var heart_row: HBoxContainer = $HeartRow
@onready var wave_label: Label = $WaveLabel
@onready var time_label: Label = $TimeLabel
@onready var progress_label: Label = $ProgressLabel
@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var wave_clear_label: Label = $WaveClearLabel
@onready var game_over_panel: ColorRect = $GameOverPanel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton

var _prev_health: int = -1
var _max_health: int = 0


func _ready() -> void:
	Events.gold_changed.connect(_on_gold_changed)
	Events.player_health_changed.connect(_on_player_health_changed)
	Events.player_died.connect(_on_player_died)
	Events.wave_changed.connect(_on_wave_changed)
	Events.elapsed_changed.connect(_on_elapsed_changed)
	Events.wave_progress_changed.connect(_on_wave_progress_changed)
	Events.wave_complete.connect(_on_wave_complete)
	restart_button.pressed.connect(_on_restart_pressed)
	_on_gold_changed(Events.total_gold)
	if Events.player_max_health > 0:
		_on_player_health_changed(Events.player_health, Events.player_max_health)
	_on_wave_changed(Events.current_wave)
	_on_elapsed_changed(Events.elapsed_time)
	_on_wave_progress_changed(Events.wave_kill_progress, Events.wave_kill_total)
	_apply_korean_font()


func _load_kr_font() -> Font:
	# TextServerAdvanced(FreeType) 환경에서 raw TTF 바이트를 직접 파싱 가능.
	# .bin = 임포트 파이프라인을 우회한 NotoSansKR TTF 복사본.
	var fa := FileAccess.open("res://assets/fonts/NotoSansKR.bin", FileAccess.READ)
	if fa == null:
		ScreenLog.err(".bin NOT found  err=%d" % FileAccess.get_open_error())
		return null
	var font := FontFile.new()
	font.data = fa.get_buffer(fa.get_length())
	fa.close()
	# 글리프 검증 — char_w=0 이면 TextServerFallback(CJK 미지원) 환경
	var char_w: float = font.get_char_size(65, 16).x
	if char_w <= 0.0:
		ScreenLog.warn("KR font no glyphs — TextServerFallback? (char_w=0)")
		return null
	ScreenLog.ok("KR font OK  bytes=%d  char_w=%.0fpx" % [font.data.size(), char_w])
	return font


func _apply_korean_font() -> void:
	var font := _load_kr_font()
	if font == null:
		ScreenLog.warn("Korean font unavailable — using default")
		return

	var korean_nodes: Array = [wave_clear_label, restart_button]
	for n in korean_nodes:
		if is_instance_valid(n):
			n.add_theme_font_override("font", font)

	# 인라인 한글 렌더 테스트
	var test := Label.new()
	test.text = "한글OK: 이동속도 공격속도"
	test.add_theme_font_override("font", font)
	test.add_theme_font_size_override("font_size", 22)
	test.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	test.position = Vector2(10, 440)
	add_child(test)


func _on_gold_changed(total: int) -> void:
	gold_label.text = "%d" % total


func _on_player_health_changed(health: int, max_health: int) -> void:
	if max_health != _max_health:
		_max_health = max_health
		_rebuild_hearts(max_health)
	_update_hearts(health)
	if _prev_health > 0 and health < _prev_health and health > 0:
		_flash_hurt()
	_prev_health = health


func _rebuild_hearts(max_health: int) -> void:
	for child in heart_row.get_children():
		child.queue_free()
	for i in range(max_health):
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(44, 44)
		tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = HEART_FULL
		heart_row.add_child(tr)


func _update_hearts(health: int) -> void:
	var children := heart_row.get_children()
	for i in range(children.size()):
		children[i].texture = HEART_FULL if i < health else HEART_EMPTY


func _flash_hurt() -> void:
	flash_overlay.color = Color(1, 0, 0, 0.35)
	var tw := create_tween()
	tw.tween_property(flash_overlay, "color", Color(1, 0, 0, 0.0), 0.4)


func _on_wave_changed(wave: int) -> void:
	wave_label.text = "Wave %d" % wave


func _on_elapsed_changed(seconds: float) -> void:
	var m := int(seconds) / 60
	var s := int(seconds) % 60
	time_label.text = "%02d:%02d" % [m, s]


func _on_wave_progress_changed(killed: int, total: int) -> void:
	if total > 0:
		progress_label.text = "%d / %d" % [killed, total]
	else:
		progress_label.text = ""


func _on_wave_complete(wave: int) -> void:
	wave_clear_label.text = "Wave %d 클리어!" % wave
	wave_clear_label.modulate.a = 1.0
	wave_clear_label.visible = true
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(wave_clear_label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): wave_clear_label.visible = false)


func _on_player_died() -> void:
	game_over_panel.visible = true


func _on_restart_pressed() -> void:
	Events.reset()
	Pool.clear()
	get_tree().reload_current_scene()
