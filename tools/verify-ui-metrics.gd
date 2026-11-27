extends SceneTree
const Flow = preload("res://ui/screens/mvp_flow.tscn")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string("/tmp/cp-mvp-fixtures.json"))
	var ui = Flow.instantiate()
	root.add_child(ui)
	ui.apply_state(fixtures.free, false, "", false, false)
	for dimensions in [Vector2i(390,844), Vector2i(820,920), Vector2i(1280,900), Vector2i(390,844)]:
		root.size = dimensions
		for i in range(12): await process_frame
		var compact: bool = dimensions.x <= 960
		assert(ui.money.get_node("Value").get_theme_font_size("font_size") == (24 if compact else 16))
		assert(ui.tools_button.custom_minimum_size.y == (56 if compact else 48))
		assert(ui.header.get_rect().end.y < ui.dock.position.y)
		assert(ui.dock.get_rect().end.x <= dimensions.x)
		assert(ui.dock.get_rect().end.y <= dimensions.y)
		print("PASS UI font/touch/layout/resize: ",dimensions)
	root.size = Vector2i(1170,2532)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(390,844)
	for i in range(12): await process_frame
	assert(root.get_visible_rect().size.is_equal_approx(Vector2(390,844)))
	assert(ui.money.get_node("Value").get_theme_font_size("font_size") == 24)
	print("PASS DPR 3: physical1170x2532 / logical390x844")
	var world = preload("res://ui/components/camp_editor_3d.gd").new()
	root.add_child(world)
	ui.use_field_editor(world)
	ui.apply_state(fixtures.setup, false, "", false, false)
	assert(not ui.dock.visible and ui.placement_bar.visible)
	ui.tools_button.pressed.emit()
	assert(ui.dock.visible and not ui.placement_bar.visible)
	world.position_changed.emit(Vector3(2,0,2))
	assert(not ui.dock.visible and ui.placement_bar.visible)
	ui.apply_state(fixtures.setup, false, "서버 저장 완료", false, false)
	assert(not ui.dock.visible)
	ui.apply_state(fixtures.setup, false, "연결을 확인해 주세요", true, false)
	assert(ui.dock.visible)
	ui.apply_state(fixtures.free, false, "", false, false)
	assert(ui.dock.visible and not ui.placement_bar.visible)
	print("PASS placement: hide/open/drag/heartbeat/recovery/exit")
	quit()
