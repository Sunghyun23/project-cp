extends SceneTree

class OfflineMain extends "res://scripts/main.gd":
	var requests: Array=[]
	var test_active := true
	func _camp_is_active() -> bool: return test_active
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		super._ready()
	func _load_state() -> void: pass
	func _send(endpoint: String, body: Variant = null) -> void:
		if body is Dictionary: requests.append(body.duplicate(true))

var game
var ui
var world
func _initialize() -> void: run.call_deferred()

func fixture() -> Dictionary:
	var catalog: Array=[]
	for id in ["chair","table","lantern"]:
		catalog.append({"id":id,"name":id,"stackable":id == "table","surface_height":.9 if id == "table" else 0})
	return {"mvp_version":1,"phase":"setup","place":"lake","week":1,"day":5,"money":200,"stamina":100,"character_id":"male","outfit":"basic","camp_day":0,"camp_minute":1000,"owned":["chair","table","lantern"],"cargo":{"chair":{},"table":{},"lantern":{}},"field":{},"item_catalog":catalog,"weather":[],"meal_owned":false,"cooked":false,"rested":true}

func run() -> void:
	create_timer(90).timeout.connect(func(): printerr("FAIL camp actions timeout");quit(1))
	root.size=Vector2i(820,920)
	game=OfflineMain.new()
	game.session_save_path="/tmp/cp-actions-no-session.cfg"
	root.add_child(game)
	game.set_process(false)
	game.state=fixture()
	game._render()
	ui=game.mvp_screen;world=game.camp_world
	ui.set_process(false)
	await frames()
	await drag("chair",Vector3(3,0,2),false)
	assert(ui.preview_dirty and ui.placement_commit.visible and ui.placement_cancel.visible)
	assert(world.selected_node.get_child(0).modulate.a<.3)
	assert(ui.placement_done.disabled and game.requests.is_empty())
	await frames()
	root.get_texture().get_image().save_png("/tmp/cp-placement-confirm.png")
	ui.placement_done.pressed.emit()
	assert(game.requests.is_empty(),"Unconfirmed placement cannot advance")
	# A heartbeat must preserve an unsaved preview.
	game._render()
	assert(ui.preview_dirty and ui.field_position.is_equal_approx(Vector3(3,0,2)))
	ui.placement_cancel.pressed.emit()
	assert(not ui.preview_dirty and game.state.field.is_empty() and game.requests.is_empty())
	await drag("chair",Vector3(3,0,2),true)
	ui.placement_commit.pressed.emit()
	assert(ui.installing and not ui.drop_pending and game.requests.is_empty())
	assert(game.actor.mode == "approach_install")
	assert(not world.selected_node.visible,"Equipment must wait for the actor to put it down")
	var paused_at: Vector3=game.actor.position
	game.test_active=false;game._process(1.0)
	assert(game.actor.position.is_equal_approx(paused_at))
	game.test_active=true
	var saw_walk := false
	var saw_install := false
	for i in range(900):
		game.actor.advance(1.0/60)
		saw_walk = saw_walk or game.actor.animation() == "walk"
		if not saw_install and game.actor.animation() == "install":
			await frames()
			root.get_texture().get_image().save_png("/tmp/cp-installing.png")
		saw_install = saw_install or game.actor.animation() == "install"
		if game.actor.mode == "saving": break
	assert(saw_walk and saw_install and ui.drop_pending)
	assert(game.requests.size() == 1 and game.requests[0].command == "place_item")
	for i in range(120): game.actor.advance(1.0/60)
	assert(game.requests.size() == 1,"Animation must never duplicate a mutation")
	assert(game.state.field.is_empty(),"Only the server response commits the field")
	accept_install()
	assert(not ui.installing and not ui.preview_dirty and not ui.drop_pending)
	assert(world.selected_node.visible and world.selected_node.get_child(0).modulate.a==1.0)
	# Cancellation after confirmation, before saving, retains the previously installed position.
	await drag("chair",Vector3(4.5,0,3),false)
	ui.placement_commit.pressed.emit()
	game.actor.advance(.1)
	assert(not world.selected_node.visible and is_instance_valid(world.saved_model))
	assert(world.saved_model.position.is_equal_approx(Vector3(3-world.origin_x,0,2-world.origin_z)))
	ui.cancel_field()
	assert(game.actor.mode == "idle" and game.requests.size() == 1)
	assert(ui.field_position.is_equal_approx(Vector3(3,0,2)))
	# Rotation is also a preview; cancel restores the saved orientation.
	ui.rotate_field()
	assert(ui.preview_dirty and ui.field_rotation == 90 and game.requests.size() == 1)
	ui.cancel_field()
	assert(ui.field_rotation == 0)
	# A lost connection requires requery and never replays the pending installation.
	await drag("chair",Vector3(4.5,0,3),false)
	ui.placement_commit.pressed.emit()
	for i in range(900):
		game.actor.advance(1.0/60)
		if game.actor.mode == "saving": break
	ui.apply_state(game.state,false,"연결 실패: 다시 확인",true,false)
	assert(ui.check_required and not ui.installing and not ui.preview_dirty)
	assert(game.actor.mode == "idle")
	ui.apply_state(game.state,false,"",false,false)
	game.state.phase="free"
	game._render()
	ui.begin_scenery()
	assert(ui.viewing_scenery and not ui.dock.visible and ui.scenery_exit.visible)
	await frames()
	# Real touch input reaches Main while the scenery view stays open.
	var at: Vector2=world.screen_point(Vector3(5-world.origin_x,0,4-world.origin_z))
	var touch := InputEventScreenTouch.new();touch.position=at;touch.index=0;touch.pressed=true
	Input.parse_input_event(touch);await process_frame
	touch.pressed=false;Input.parse_input_event(touch);await process_frame
	assert(ui.viewing_scenery and game.actor.mode == "walk")
	var before: Vector3=game.actor.position
	game.actor.advance(.2)
	assert(not game.actor.position.is_equal_approx(before))
	# Direct keyboard/pad input overrides the destination and stands up from a seat.
	for pad in [false,true]:
		var event: InputEvent
		if pad:
			event=InputEventJoypadMotion.new();event.axis=JOY_AXIS_LEFT_X;event.axis_value=1.0
		else:
			event=InputEventKey.new();event.physical_keycode=KEY_D;event.pressed=true
		Input.parse_input_event(event);await process_frame
		var old: Vector3=game.actor.position
		game._process(.2)
		assert(not game.actor.position.is_equal_approx(old))
		if pad: event.axis_value=0.0
		else: event.pressed=false
		Input.parse_input_event(event);await process_frame
	# An actual chair click starts approaching the seat while scenery remains open.
	var chair_node
	for child in world.items_root.get_children():
		if child.get_child(1).get_meta("item") == "chair": chair_node=child
	var chair_sprite: Sprite3D=chair_node.get_child(0)
	var chair_at: Vector2=world.screen_point(chair_sprite.global_position-world.camera.global_basis.y*42*chair_sprite.pixel_size)
	for down in [true,false]:
		var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down;click.position=chair_at
		Input.parse_input_event(click);await process_frame
	assert(game.actor.mode == "approach_seat" and ui.viewing_scenery)
	# Directional sitting sprites attach to the corresponding installed chair.
	for angle in [0,90,180,270]:
		game.state.field.chair.rotation_degrees=angle
		game._render()
		assert(game.actor.seat(Vector3(3,0,2),angle))
		for i in range(900):
			game.actor.advance(1.0/60)
			if game.actor.mode == "sit": break
		assert(game.actor.mode == "sit" and game.actor.animation() == preload("res://ui/components/mvp_assets.gd").seated_animation(angle))
		for id in ["male","female"]:
			for outfit in ["basic","rain"]:
				game.state.character_id=id;game.state.outfit=outfit;game._render()
				await frames()
				assert(world.camper_3d.animation == preload("res://ui/components/mvp_assets.gd").seated_animation(angle))
				if id=="female" and outfit=="basic": root.get_texture().get_image().save_png("/tmp/cp-seat-direction-%d.png"%angle)
				if angle==0 and id=="female" and outfit=="basic":
					for dimensions in [Vector2i(390,844),Vector2i(820,920),Vector2i(1280,900)]:
						root.size=dimensions;await frames()
						root.get_texture().get_image().save_png("/tmp/cp-sitting-%dx%d.png"%[dimensions.x,dimensions.y])
					root.size=Vector2i(820,920)
		game.actor.move_to(Vector3(5,0,4))
		assert(game.actor.mode == "walk" and game.actor.seat_id.is_empty())
	# Keyboard and gamepad cancellation still end scenery, without triggering movement.
	for pad in [false,true]:
		var event: InputEvent
		if pad:
			event=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_B;event.pressed=true
		else:
			event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true
		Input.parse_input_event(event);await process_frame
		assert(not ui.viewing_scenery)
		event.pressed=false;Input.parse_input_event(event);await process_frame
		ui.begin_scenery()
	print("PASS camp actions: mouse/touch preview / confirm / cancel / walk+install / once-only save / failure / rotation / scenery movement / four seat directions / both characters+outfits / phone-fold-PC")
	game.queue_free();await process_frame;quit()

func frames() -> void:
	game.queue_redraw()
	for i in range(8): await process_frame
	RenderingServer.force_draw()

func accept_install() -> void:
	var request: Dictionary=game.requests.back()
	game.state.field[request.choice]={"x":request.x,"y":request.z,"z":request.y,"rotation_degrees":request.rotation_degrees,"rotated":request.rotated}
	game._render()

func drag(id: String, target: Vector3, touch: bool) -> void:
	await frames()
	var node
	for child in world.items_root.get_children():
		if child.get_child(1).get_meta("item") == id: node=child
	var start: Vector2=world.screen_point(node.position+Vector3(0,world.dimensions(id).y*.45,0))
	var offset: Vector2=start-world.screen_point(node.position)
	var end: Vector2=world.screen_point(target-Vector3(world.origin_x,0,world.origin_z))+offset
	if touch:
		var press:=InputEventScreenTouch.new();press.index=0;press.position=start;press.pressed=true;Input.parse_input_event(press);await process_frame
		var motion:=InputEventScreenDrag.new();motion.index=0;motion.position=end;Input.parse_input_event(motion);await process_frame
		var release:=InputEventScreenTouch.new();release.index=0;release.position=end;release.pressed=false;Input.parse_input_event(release);await process_frame
	else:
		var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=start;press.pressed=true;Input.parse_input_event(press);await process_frame
		var motion:=InputEventMouseMotion.new();motion.position=end;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;Input.parse_input_event(motion);await process_frame
		var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=end;release.pressed=false;Input.parse_input_event(release);await process_frame
