extends Node
## Export feature tags select editions without maintaining separate game copies.
const LANDSCAPE := Vector2i(2272,1278)
const PORTRAIT := Vector2i(720,1280)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		get_tree().root.size_changed.connect(_fit_browser)
		_fit_browser()

func _fit_browser() -> void:
	apply_browser_layout(get_tree().root,DisplayServer.is_touchscreen_available())

func apply_browser_layout(window: Window, touch: bool) -> void:
	# Keep the web demo edition on phones; only the presentation changes.
	# EXPAND reveals more world on tall phones instead of adding black bars.
	var portrait := touch and window.size.y>window.size.x
	var target := PORTRAIT if portrait else LANDSCAPE
	var aspect := Window.CONTENT_SCALE_ASPECT_EXPAND if portrait else Window.CONTENT_SCALE_ASPECT_KEEP
	if window.content_scale_size != target: window.content_scale_size = target
	if window.content_scale_aspect != aspect: window.content_scale_aspect = aspect

func is_demo() -> bool:
	return OS.has_feature("demo")

func is_mobile() -> bool:
	return OS.has_feature("mobile_preview") or OS.has_feature("android") or OS.has_feature("ios")

func touch_controls() -> bool:
	return is_mobile() or DisplayServer.is_touchscreen_available()

func edition_label() -> String:
	if is_mobile():
		return "MOBILE PREVIEW"
	return "WEB DEMO" if is_demo() else "FULL VERSION"
