extends SceneTree
const World = preload("res://ui/components/camp_editor_3d.gd")
const ThemeAsset = preload("res://ui/theme/camping.tres")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var axes_only := "--axes-only" in OS.get_cmdline_user_args()
	var target := "/tmp/cp-xyz-preview.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): target=arg.trim_prefix("--output=")
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = ThemeAsset
	root.add_child(host)
	var background := TextureRect.new()
	background.texture = load("res://assets/pixel/campsite-day-terrain.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(background)
	var world := World.new()
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(world)
	var snapshot := {"place":"lake","cargo":{"tent":{},"table":{},"lantern":{},"chair":{}},"field":{
		"tent":{"x":1.5,"y":0,"z":1.5},"table":{"x":5,"y":0,"z":3},"lantern":{"x":5,"y":.9,"z":3},"chair":{"x":4.5,"y":0,"z":4.75}}}
	world.configure(snapshot,"lantern",Vector3(5,.9,3))
	for i in range(10): await process_frame
	world.gizmo.hide()
	world.footprint.hide()
	for child in world.grid_root.get_children():
		world.grid_root.remove_child(child)
		child.queue_free()
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color=Color(1,.98,.85,.24)
	if not axes_only:
		for y in [0.0,.9,1.8]:
			for x in range(9):
				line(world,Vector3(x-4,y,-3),Vector3(x-4,y,3),material)
			for z in range(7):
				line(world,Vector3(-4,y,z-3),Vector3(4,y,z-3),material)
		for x in range(9):
			for z in range(7):
				line(world,Vector3(x-4,0,z-3),Vector3(x-4,1.8,z-3),material)
	var axes := [["X",Vector3(-4,0,3),Vector3(4.4,0,3),Color("ef947d")],["Z",Vector3(-4,0,3),Vector3(-4,2.25,3),Color("8cbcf0")],["Y",Vector3(-4,0,3),Vector3(-4,0,-3.5),Color("9ce5a9")]]
	if axes_only:
		var at := Vector3(1,.9,0)
		axes = [["X",at,at+Vector3(1.8,0,0),Color("ef947d")],["Z",at,at+Vector3(0,1.8,0),Color("8cbcf0")],["Y",at,at+Vector3(0,0,1.8),Color("9ce5a9")]]
	for row in axes:
		var colored := material.duplicate()
		colored.albedo_color=row[3]
		line(world,row[1],row[2],colored,.045)
		var caption := Label3D.new()
		caption.text=row[0]
		caption.position=row[2]
		caption.font_size=64
		caption.pixel_size=.007
		caption.modulate=row[3]
		caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		world.grid_root.add_child(caption)
	world.camera.position=Vector3(8,11,13)
	world.camera.look_at(Vector3(0,.9,0))
	world.camera.size=maxf(11.5,7.1/(.50*float(root.size.y)/root.size.x))
	world.camera.h_offset=0
	world.camera.v_offset=world.camera.size*float(root.size.y)/root.size.x*.12
	var heading := Label.new()
	heading.text="선택 아이템 XYZ축 · 시안" if axes_only else "XYZ 입체 격자 · 시안"
	heading.add_theme_font_size_override("font_size",32)
	heading.add_theme_color_override("font_color",Color("fff7df"))
	heading.add_theme_color_override("font_shadow_color",Color("20382a"))
	heading.add_theme_constant_override("shadow_offset_x",2)
	heading.add_theme_constant_override("shadow_offset_y",2)
	heading.position=Vector2(20,24)
	host.add_child(heading)
	var hint := Label.new()
	hint.text="X · Y 바닥 이동 / Z 높이\n선택한 아이템에만 축 표시" if axes_only else "2D 아이템을 직접 드래그\n지면 · 테이블 위로 배치"
	hint.add_theme_font_size_override("font_size",24)
	hint.add_theme_color_override("font_color",Color("fff7df"))
	hint.add_theme_color_override("font_shadow_color",Color("20382a"))
	hint.add_theme_constant_override("shadow_offset_x",2)
	hint.add_theme_constant_override("shadow_offset_y",2)
	hint.position=Vector2(20,root.size.y-116)
	host.add_child(hint)
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(target)
	print("XYZ volume concept: ",target)
	quit()
func line(world, a: Vector3, b: Vector3, material: StandardMaterial3D, thickness: float = .018) -> void:
	var difference := b-a
	var shape := BoxMesh.new()
	shape.size=Vector3(maxf(thickness,absf(difference.x)),maxf(thickness,absf(difference.y)),maxf(thickness,absf(difference.z)))
	var mesh := MeshInstance3D.new()
	mesh.mesh=shape
	mesh.position=(a+b)/2
	mesh.material_override=material
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.grid_root.add_child(mesh)
