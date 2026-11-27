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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--angle=") and snapshot.get("field",{}).has("chair"):
			snapshot.field.chair.rotation_degrees=int(arg.trim_prefix("--angle="))
			snapshot.field.chair.rotated=int(arg.trim_prefix("--angle="))%180!=0
	var night := "--night" in OS.get_cmdline_user_args()
	if night: snapshot.camp_minute=1200
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var background := TextureRect.new()
	background.texture = Assets.PINE if snapshot.get("place","") == "pine" else load("res://assets/pixel/campsite-night-terrain.png") if night else Assets.LAKE
	if night and snapshot.get("place","") == "pine": background.modulate=Color("7188ae")
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
	if "--admire" in OS.get_cmdline_user_args(): ui.begin_scenery()
	if overlay != null:
		overlay.effects.enabled=not "--effects-off" in OS.get_cmdline_user_args()
		ui.effects_button.set_pressed_no_signal(overlay.effects.enabled)
		ui.night_button.set_pressed_no_signal(night)
		ui.night_button.text="밤" if night else "낮"
		ui.effects_toggled.connect(func(value: bool): overlay.effects.enabled=value)
		overlay.update_camper(preload("res://ui/components/character_catalog.gd").frames(snapshot.get("character_id","female"),snapshot.get("outfit","basic")),overlay.screen_point(Vector3(.5,0,-1.5)),false,false)
		overlay.effects.clock=3.0
		overlay.effects.frozen=true
		overlay.effects.shadows=not "--shadows-off" in OS.get_cmdline_user_args()
	for i in range(30): await process_frame
	if overlay != null:
		overlay.effects.active=true
		overlay.effects._process(0)
		# 비활성 창의 자동 일시정지를 고정하고 최종 GPU 상태를 기다린다.
		overlay.set_process(false)
		overlay.effects.set_process(false)
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	if overlay != null and "--save-fx-layer" in OS.get_cmdline_user_args():
		var layer: Image=overlay.viewport_3d.get_texture().get_image()
		layer.save_png("/tmp/cp-vfx-layer.png")
		var node=overlay.effects.motes[0]
		var pixel:Vector2i=overlay.camera.unproject_position(node.global_position)
		print("MOTE ",node.visible," ",node.scale," @",pixel," pixel ",layer.get_pixelv(pixel)," tint ",node.material_override.get_shader_parameter("tint"))
	root.get_texture().get_image().save_png(target)
	print("MVP capture: ",phase," ",root.size," dock=",ui.dock.get_rect())
	quit()
