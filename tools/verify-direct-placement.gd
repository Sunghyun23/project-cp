extends SceneTree
const Flow = preload("res://ui/screens/mvp_flow.tscn")
const World = preload("res://ui/components/camp_editor_3d.gd")
var snapshot: Dictionary
var ui
var world
var sent := {}
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	create_timer(20).timeout.connect(func(): printerr("FAIL routed drag timeout"); quit(1))
	root.size = Vector2i(820,920)
	snapshot = JSON.parse_string(FileAccess.get_file_as_string("/tmp/cp-mvp-fixtures.json")).setup.duplicate(true)
	snapshot.field = {}
	world = World.new()
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(world)
	ui = Flow.instantiate()
	root.add_child(ui)
	ui.use_field_editor(world)
	ui.action_requested.connect(func(command,choice,extra): sent={"command":command,"id":choice,"point":Vector3(extra.get("x",0),extra.get("z",0),extra.get("y",0))})
	ui.apply_state(snapshot,false,"",false,false)
	for i in range(12): await process_frame
	assert(world.items_root.get_child_count() == snapshot.cargo.size()-1)
	assert(world.gizmo.visible and not ui.placement_commit.visible and not ui.dock.visible)
	await drag("tent", Vector3(1.5,0,1), false)
	assert(sent.id == "tent" and sent.point.is_equal_approx(Vector3(1.5,0,1)))
	accept_drop()
	await drag("table",Vector3(4.75,0,3.5),true)
	assert(sent.id == "table" and sent.point.is_equal_approx(Vector3(4.75,0,3.5)))
	accept_drop()
	await drag("stove",Vector3(4.75,.9,3.5),true)
	assert(sent.id == "stove" and is_equal_approx(sent.point.y, .9))
	accept_drop()
	var original: Vector3 = sent.point
	await drag("stove",Vector3(1.5,0,1),false)
	ui.apply_state(snapshot,false,"다른 장비와 겹쳐요",false,false)
	assert(world.selected_node.position.is_equal_approx(Vector3(original.x-4,original.y,original.z-3)))
	assert("다른 장비와 겹쳐요" in ui.placement_message.text)
	world.begin_drag(world.screen_point(world.selected_node.position+Vector3(0,.3,0)),-1)
	world.move_drag(world.screen_point(Vector3(0,0,0)))
	world.end_drag(true)
	for dimensions_value in [Vector2i(390,844),Vector2i(820,920),Vector2i(1280,900)]:
		root.size=dimensions_value
		for i in range(12): await process_frame
		var button_rect: Rect2=ui.placement_done.get_rect()
		assert(button_rect.position.x>=0 and button_rect.end.x<=dimensions_value.x)
		assert(button_rect.position.y>=0 and button_rect.end.y<=dimensions_value.y)
		var tip: Vector2=world.screen_point(Vector3(ui.field_position.x-world.origin_x,ui.field_position.y+1.8,ui.field_position.z-world.origin_z))
		assert(button_rect.end.y < tip.y)
	ui.apply_state(JSON.parse_string(FileAccess.get_file_as_string("/tmp/cp-mvp-fixtures.json")).free,false,"",false,false)
	world.readonly=true
	world.configure(ui.state)
	assert(not world.grid_root.visible and not world.gizmo.visible and not world.footprint.visible and not world.support_surfaces.visible and not ui.placement_done.visible)
	print("PASS direct placement: all sprites / mouse / touch / ground / tabletop / auto-save / rejected-drop rollback")
	quit()
func drag(id: String, target: Vector3, touch: bool) -> void:
	var node
	for child in world.items_root.get_children():
		if child.get_child(1).get_meta("item") == id: node=child
	var start: Vector2 = world.screen_point(node.position+Vector3(0,world.dimensions(id).y*.45,0))
	var offset: Vector2 = start-world.screen_point(node.position)
	var end: Vector2 = world.screen_point(Vector3(target.x-4,target.y,target.z-3))+offset
	if touch:
		var press := InputEventScreenTouch.new(); press.index=0; press.position=start; press.pressed=true; Input.parse_input_event(press); await process_frame
		var motion := InputEventScreenDrag.new(); motion.index=0; motion.position=end; Input.parse_input_event(motion); await process_frame
		var release := InputEventScreenTouch.new(); release.index=0; release.position=end; release.pressed=false; Input.parse_input_event(release); await process_frame
	else:
		var press := InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.position=start; press.pressed=true; Input.parse_input_event(press); await process_frame
		var motion := InputEventMouseMotion.new(); motion.position=end; motion.button_mask=MOUSE_BUTTON_MASK_LEFT; Input.parse_input_event(motion); await process_frame
		var release := InputEventMouseButton.new(); release.button_index=MOUSE_BUTTON_LEFT; release.position=end; release.pressed=false; Input.parse_input_event(release); await process_frame
func accept_drop() -> void:
	snapshot.field[sent.id] = {"x":sent.point.x,"y":sent.point.y,"z":sent.point.z,"rotated":false}
	ui.apply_state(snapshot,false,"",false,false)
