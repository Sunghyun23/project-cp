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
	Input.use_accumulated_input=false
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
	assert(world.items_root.get_child_count()==0 and ui.gear_cards.get_child_count()==3)
	for dimensions in [Vector2i(390,844),Vector2i(820,920),Vector2i(1280,900)]:
		root.size=dimensions;await frames()
		assert(ui.gear_tray.get_global_rect().position.x>=0 and ui.gear_tray.get_global_rect().end.x<=dimensions.x)
		assert(ui.gear_tray.get_global_rect().end.y<=dimensions.y)
		root.get_texture().get_image().save_png("/tmp/cp-gear-tray-%dx%d.png"%[dimensions.x,dimensions.y])
	root.size=Vector2i(820,920);await frames()
	var card=ui.gear_cards.get_child(0)
	var start: Vector2=card.get_global_rect().get_center()
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=start;press.pressed=true;Input.parse_input_event(press);await process_frame
	var motion:=InputEventMouseMotion.new();motion.position=start+Vector2(-20,0);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;Input.parse_input_event(motion);await process_frame
	press.pressed=false;press.position=motion.position;Input.parse_input_event(press);await process_frame
	assert(not ui.preview_dirty and not ui.external_drag,"Horizontal tray scrolling must not place gear")
	card.grab_focus()
	var confirm:=InputEventKey.new();confirm.keycode=KEY_ENTER;confirm.physical_keycode=KEY_ENTER;confirm.pressed=true;Input.parse_input_event(confirm);await process_frame
	confirm.pressed=false;Input.parse_input_event(confirm);await process_frame
	assert(ui.preview_dirty and ui.selected_item=="chair","Keyboard confirmation chooses from the tray")
	ui.cancel_field()

	await drag("chair",Vector3(3,0,2),false)
	assert(ui.preview_dirty and ui.placement_commit.visible and ui.placement_cancel.visible)
	assert(world.selected_node.get_child(0).modulate.a<.3)
	for item in world.items_root.get_children():
		var id: String=item.get_child(1).get_meta("item")
		if id != "chair": assert(not item.visible,"Uninstalled cargo must not obscure the destination")
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
	for item in world.items_root.get_children(): assert(item.visible)
	await drag("chair",Vector3(3,0,2),true)
	ui.placement_commit.pressed.emit()
	assert(ui.installing and not ui.drop_pending and game.requests.is_empty())
	assert(game.actor.mode == "approach_install")
	assert(game.actor.position.is_equal_approx(Vector3(.5,0,world.site_depth+.55)),"Installation must start at the visibly waiting character")
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
	assert(ui.viewing_scenery and not ui.dock.visible and ui.camp_menu.visible and ui.scenery_toggle.text == "감상 종료")
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
				var pose: AtlasTexture=world.camper_3d.sprite_frames.get_frame_texture(world.camper_3d.animation, 0)
				assert(is_equal_approx(pose.region.position.x / pose.region.size.x, 3 - angle / 90))

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
	ui.viewing_scenery = false
	game.state.phase = "free"
	game.state.field.tent = {"x":5, "y":0, "z":4, "rotation_degrees":0}
	game.state.field.sleeping_bag = {"x":5, "y":0, "z":4, "rotation_degrees":90}
	game._render()
	root.size = Vector2i(390, 844)
	await frames()
	assert(world.bag_inside_tent())
	assert(game.actor.install("sleeping_bag", Vector3(5, 0, 4), 90))
	game.actor.cancel()
	assert(world.validation_reason("sleeping_bag", Vector3(5, 0, 4)).is_empty())
	assert(not world.validation_reason("sleeping_bag", Vector3(7, 0, 4)).is_empty())
	assert(not world.validation_reason("tent", Vector3(6, 0, 4)).is_empty())
	var before_sleep: int = game.requests.size()
	ui.act("sleep")
	assert(is_instance_valid(ui.sleep_scene))
	ui.sleep_scene.set_process(false)
	ui.sleep_scene._process(1.8)
	await frames()
	root.get_texture().get_image().save_png("/tmp/cp-sleep-phone.png")
	ui.act("sleep")
	assert(game.requests.size() == before_sleep)
	ui.sleep_scene._process(1.0)
	assert(game.requests.size() == before_sleep + 1 and game.requests.back().command == "sleep")

	game.state.phase = "equipment"
	game.state.item_catalog = [{"id":"chair","name":"의자","price":25,"upgrade_price":15}]
	game._render()
	await frames()
	var equipment: Button
	for candidate in ui.action_buttons:
		if candidate.text.contains("15원"): equipment = candidate
	assert(equipment != null)
	var before_buy: int = game.requests.size()
	equipment.pressed.emit()
	await frames()
	assert(ui.purchase_dialog.visible and game.requests.size() == before_buy)
	ui.purchase_dialog.get_cancel_button().pressed.emit()
	await frames()
	assert(not ui.purchase_dialog.visible and game.requests.size() == before_buy)
	equipment.pressed.emit()
	await frames()
	assert(ui.purchase_dialog.visible)
	ui.purchase_dialog.get_ok_button().pressed.emit()
	await frames()
	assert(game.requests.size() == before_buy + 1 and game.requests.back().command == "upgrade_gear")
	game.state.phase = "settlement"
	game.state.week_income = 45
	game.state.week_spent = 20
	game.state.parcel_box = ["lantern"]
	game._render()
	await frames()
	assert(ui.details_dialog.visible and ui.details_mode == "settlement")
	assert(ui.camp_menu.visible and not ui.dock.visible)
	ui.open_details("parcels")
	assert(ui.details_dialog.visible and ui.details_mode == "parcels" and ui.details.get_child(0).text.contains("5원"))
	ui.details_dialog.hide()
	assert(ui.camp_menu.visible)
	print("PASS camp actions: mouse/touch preview / confirm / cancel / walk+install / once-only save / failure / rotation / scenery movement / four seat directions / both characters+outfits / phone-fold-PC / sleep / purchase confirmation")
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
	var start: Vector2
	var offset := Vector2.ZERO
	if game.state.field.has(id):
		var node
		for child in world.items_root.get_children():
			if child.get_child(1).get_meta("item") == id: node=child
		start=world.screen_point(node.position+Vector3(0,world.dimensions(id).y*.45,0))
		offset=start-world.screen_point(node.position)
	else:
		ui.gear_tray_open=true;ui.update_placement_visibility();ui.fit()
		await frames()
		var card
		for child in ui.gear_cards.get_children():
			if child.item_id==id: card=child
		assert(card!=null)
		start=card.get_global_rect().get_center()
		offset=Vector2(0,28)
	var end: Vector2=world.screen_point(target-Vector3(world.origin_x,0,world.origin_z))+offset
	if touch:
		var press:=InputEventScreenTouch.new();press.index=0;press.position=start;press.pressed=true;Input.parse_input_event(press);await process_frame
		for at in [start+Vector2(0,-14),end]:
			var motion:=InputEventScreenDrag.new();motion.index=0;motion.position=at;Input.parse_input_event(motion);await process_frame
		var release:=InputEventScreenTouch.new();release.index=0;release.position=end;release.pressed=false;Input.parse_input_event(release);await process_frame
	else:
		var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=start;press.pressed=true;Input.parse_input_event(press);await process_frame
		for at in [start+Vector2(0,-14),end]:
			var motion:=InputEventMouseMotion.new();motion.position=at;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;Input.parse_input_event(motion);await process_frame
		var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=end;release.pressed=false;Input.parse_input_event(release);await process_frame
