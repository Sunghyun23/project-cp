extends PanelContainer

var case_id := ""
var draggable := false

func _get_drag_data(_at: Vector2) -> Variant:
	if not draggable or case_id.is_empty(): return null
	var preview:=Label.new()
	preview.text="접수 서류\n검토 도장 찍기"
	preview.add_theme_color_override("font_color",Color("fff0cb"))
	preview.add_theme_font_size_override("font_size",24)
	set_drag_preview(preview)
	return {"office_case":case_id}
