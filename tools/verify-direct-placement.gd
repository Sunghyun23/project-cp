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
	root.size = Vector2i(820,920)
	snapshot = JSON.parse_string(FileAccess.get_file_as_string("/tmp/cp-mvp-fixtures.json")).setup.duplicate(true)
	snapshot.field = {}
	world = World.new()
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(world)
	ui = Flow.instantiate()
	root.add_child(ui)
	ui.use_field_editor(world)
	ui.action_requested.connect(func(command,choice,extra): sent={"command":command,"id":choice,"point":Vector3(extra.get("x",0),extra.get("y",0),extra.get("z",0))})
	ui.apply_state(snapshot,false,"",false,false)
	for i in range(12): await process_frame
	assert(world.items_root.get_child_count() == snapshot.cargo.size()-1)
	assert(not world.gizmo.visible and not ui.placement_commit.visible and not ui.dock.visible)
	drag("tent", Vector3(3,0,4), false)
	assert(sent.id == "tent" and sent.point.is_equal_approx(Vector3(3,0,4)))
	accept_drop()
	drag("table",Vector3(4.75,0,3.5),true)
	assert(sent.id == "table" and sent.point.is_equal_approx(Vector3(4.75,0,3.5)))
	accept_drop()
	drag("stove",Vector3(4.75,.9,3.5),true)
	assert(sent.id == "stove" and is_equal_approx(sent.point.y, .9))
	accept_drop()
	var original: Vector3 = sent.point
	drag("stove",Vector3(3,0,4),false)
	ui.apply_state(snapshot,false,"다른 장비와 겹쳐요",false,false)
	assert(world.selected_node.position.is_equal_approx(Vector3(original.x-4,original.y,original.z-3)))
	assert(ui.placement_message.text == "다른 장비와 겹쳐요")
	world.begin_drag(world.screen_point(world.selected_node.position+Vector3(0,.3,0)),-1)
	world.move_drag(world.screen_point(Vector3(0,0,0)))
	world.end_drag(true)
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
		var press := InputEventScreenTouch.new(); press.index=0; press.position=start; press.pressed=true; world._gui_input(press)
		var motion := InputEventScreenDrag.new(); motion.index=0; motion.position=end; world._gui_input(motion)
		var release := InputEventScreenTouch.new(); release.index=0; release.position=end; release.pressed=false; world._gui_input(release)
	else:
		var press := InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.position=start; press.pressed=true; world._gui_input(press)
		var motion := InputEventMouseMotion.new(); motion.position=end; world._gui_input(motion)
		var release := InputEventMouseButton.new(); release.button_index=MOUSE_BUTTON_LEFT; release.position=end; release.pressed=false; world._gui_input(release)
func accept_drop() -> void:
	snapshot.field[sent.id] = {"x":sent.point.x,"y":sent.point.y,"z":sent.point.z,"rotated":false}
	ui.apply_state(snapshot,false,"",false,false)
