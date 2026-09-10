extends Node
## Export feature tags select editions without maintaining separate game copies.

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
