extends SceneTree

static func box(fill: String, edge: String = "77583b", inset: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color(edge)
	style.set_border_width_all(2)
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color("17291f80")
	style.shadow_size = 0
	style.shadow_offset = Vector2(0, 3)
	return style

static func skin(name: String, padding: int = 12) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/ui/" + name + ".svg")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 12)
		style.set_content_margin(side, padding)
	return style

func _initialize() -> void:
	var theme := Theme.new()
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
	font.variation_opentype = {"wght": 500}
	theme.default_font = font
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", Color("263626"))
	theme.set_color("font_color", "Button", Color("263626"))
	theme.set_color("font_focus_color", "Button", Color("263626"))
	theme.set_color("font_hover_color", "Button", Color("263626"))
	theme.set_color("font_pressed_color", "Button", Color("263626"))
	theme.set_color("font_disabled_color", "Button", Color("746e5a"))
	for state in {"normal":"eee3c9", "hover":"fff3cf", "pressed":"dbc296", "disabled":"d6cfbc"}:
		theme.set_stylebox(state, "Button", skin({"normal":"wood-button", "hover":"wood-hover", "pressed":"wood-pressed", "disabled":"wood-disabled"}[state]))
	var focus := box("00000000", "a36a25", 0)
	focus.set_border_width_all(3)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("panel", "PanelContainer", skin("camp-panel", 20))
	theme.set_stylebox("normal", "LineEdit", skin("wood-button",10))
	theme.set_stylebox("read_only", "LineEdit", skin("wood-disabled",10))
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_color", "LineEdit", Color("263626"))
	theme.set_color("font_uneditable_color", "LineEdit", Color("746e5a"))
	theme.set_color("caret_color", "LineEdit", Color("77583b"))
	theme.set_color("selection_color", "LineEdit", Color("4b6542"))
	theme.set_color("font_selected_color", "LineEdit", Color("fff7df"))
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 12)
	theme.set_type_variation("PrimaryButton", "Button")
	for state in ["normal", "hover", "pressed"]:
		theme.set_stylebox(state, "PrimaryButton", skin({"normal":"leaf-button", "hover":"leaf-hover", "pressed":"leaf-pressed"}[state]))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "PrimaryButton", Color("fff7df"))
	# 반복 컴포넌트의 상태 스타일도 Theme에서 관리한다.
	for kind in ["ChoiceCard", "GridEmpty", "GridOccupied", "GridInvalid"]:
		theme.set_type_variation(kind, "Button")
	theme.set_stylebox("pressed", "ChoiceCard", skin("choice-selected"))
	theme.set_stylebox("hover_pressed", "ChoiceCard", skin("choice-selected"))
	theme.set_color("font_pressed_color", "ChoiceCard", Color("263626"))
	theme.set_color("font_hover_pressed_color", "ChoiceCard", Color("263626"))
	for kind in ["GridOccupied", "GridInvalid"]:
		var fill: String = "4b6542" if kind == "GridOccupied" else "f8e3d4"
		var ink: String = "fff7df" if kind == "GridOccupied" else "9b3d30"
		for state in ["normal", "hover", "pressed"]:
			theme.set_stylebox(state, kind, box(fill))
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			theme.set_color(state, kind, Color(ink))
	for kind in ["InfoNotice", "WarningNotice", "DangerNotice"]:
		theme.set_type_variation(kind, "PanelContainer")
		theme.set_stylebox("panel", kind, box({"InfoNotice":"e6eed5", "WarningNotice":"faebc2", "DangerNotice":"f8e3d4"}[kind]))
	var track := StyleBoxFlat.new()
	track.bg_color = Color("d6cfbc")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("71825b")
	theme.set_stylebox("background", "ProgressBar", track)
	theme.set_stylebox("fill", "ProgressBar", fill)
	ResourceSaver.save(theme, "res://ui/theme/camping.tres")
	quit()
