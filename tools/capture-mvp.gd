extends SceneTree

const Flow = preload("res://ui/screens/mvp_flow.tscn")
const World = preload("res://ui/components/camp_editor_3d.gd")
const Assets = preload("res://ui/components/mvp_assets.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var phase := "setup"
	var target := "/tmp/cp-mvp-preview.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
		if arg.begins_with("--output="): target = arg.trim_prefix("--output=")
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string("/tmp/cp-mvp-fixtures.json"))
	var snapshot: Dictionary = fixtures[phase].duplicate(true)
	if "--staged" in OS.get_cmdline_user_args(): snapshot.field = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--place="):
			snapshot.place=arg.trim_prefix("--place=")
			snapshot.erase("placement_site")
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var background := TextureRect.new()
	background.texture = Assets.PINE if snapshot.get("place","") == "pine" else Assets.LAKE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(background)
	var overlay
	if phase in ["setup","free","cooking","meal_ready","teardown","return_pack"]:
		var world := World.new()
		world.readonly = phase != "setup"
		world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host.add_child(world)
		world.configure(snapshot)
		overlay = world
	var ui := Flow.instantiate()
	host.add_child(ui)
	if overlay != null: ui.use_field_editor(overlay)
	ui.apply_state(snapshot,false,"",false,false)
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(target)
	print("MVP capture: ",phase," ",root.size," dock=",ui.dock.get_rect())
	quit()
