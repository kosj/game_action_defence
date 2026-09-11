extends Node
## Export feature tags select editions without maintaining separate game copies.
const LANDSCAPE := Vector2i(2272,1278)
const PORTRAIT := Vector2i(720,1280)
var _browser_window: JavaScriptObject
var _browser_navigator: JavaScriptObject
var _resize_clock := 0.0
var _browser_extent := Vector2i.ZERO
var _browser_touch := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_browser_window = JavaScriptBridge.get_interface("window")
		_browser_navigator = JavaScriptBridge.get_interface("navigator")
		get_tree().root.size_changed.connect(_queue_browser_fit)
		_fit_browser()
	else:
		set_process(false)

func _queue_browser_fit() -> void:
	# Changing stretch settings inside the resize signal can race the canvas resize.
	call_deferred("_fit_browser")

func _process(delta: float) -> void:
	_resize_clock -= delta
	if _resize_clock<=0:
		_resize_clock = 0.2
		_fit_browser()

func _fit_browser() -> void:
	if _browser_window == null: return
	# These are the same CSS dimensions used by Godot's canvas resize policy 2.
	# Window.size/size_changed alone are not a reliable browser rotation source.
	var extent := Vector2i(int(_browser_window.innerWidth),int(_browser_window.innerHeight))
	var touch := DisplayServer.is_touchscreen_available() or int(_browser_navigator.maxTouchPoints)>0
	apply_browser_sample(extent,touch)

func apply_browser_sample(extent: Vector2i, touch: bool) -> void:
	if extent.x<=0 or extent.y<=0: return
	if extent == _browser_extent and touch == _browser_touch: return
	_browser_extent = extent
	_browser_touch = touch
	apply_browser_layout(get_tree().root,touch,extent)

func apply_browser_layout(window: Window, touch: bool, browser_size := Vector2i.ZERO) -> void:
	# Keep the web demo edition on phones; only the presentation changes.
	# EXPAND reveals more world on tall phones instead of adding black bars.
	var extent := browser_size if browser_size != Vector2i.ZERO else window.size
	var portrait := touch and extent.y>extent.x
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
