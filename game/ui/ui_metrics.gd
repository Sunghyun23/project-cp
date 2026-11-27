extends RefCounted

# 물리 해상도와 UI의 논리 크기를 분리한다. 폰·폴드 모두 같은 터치 기준.
static func configure_window(window: Window) -> void:
	var logical := Vector2(window.size)
	if OS.has_feature("web"):
		var value = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify([document.getElementById('canvas').clientWidth, document.getElementById('canvas').clientHeight])")))
		if value is Array and value.size() == 2:
			logical = Vector2(float(value[0]), float(value[1]))
	elif OS.has_feature("android"):
		logical /= maxf(1.0, float(DisplayServer.screen_get_dpi()) / 160.0)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	window.content_scale_size = Vector2i(maxi(1, roundi(logical.x)), maxi(1, roundi(logical.y)))

static func apply(node: Node, compact: bool) -> void:
	if node is Label or node is Button or node is LineEdit:
		if not node.has_meta("base_ui_font"):
			node.set_meta("base_ui_font", node.get_theme_font_size("font_size"))
		var original: int = node.get_meta("base_ui_font")
		var target := maxi(original, 24) if compact else original
		if node.get_theme_font_size("font_size") != target:
			node.add_theme_font_size_override("font_size", target)
	if node is Button:
		if not node.has_meta("base_ui_height"):
			node.set_meta("base_ui_height", node.custom_minimum_size.y)
		var height: float = node.get_meta("base_ui_height")
		node.custom_minimum_size.y = maxf(height, 56) if compact else height
	for child in node.get_children():
		apply(child, compact)
