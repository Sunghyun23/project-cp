extends SceneTree

const Flow=preload("res://ui/screens/mvp_flow.tscn")
const PackingItem=preload("res://ui/components/packing_item.gd")
var ui
var sent: Array=[]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(20).timeout.connect(func(): printerr("FAIL MVP UX timeout"); quit(1))
	root.size=Vector2i(390,844)
	var fixtures: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("/tmp/cp-mvp-fixtures.json"))
	ui=Flow.instantiate()
	root.add_child(ui)
	ui.action_requested.connect(func(command,choice,extra): sent.append({"command":command,"id":choice,"extra":extra}))
	var free: Dictionary=fixtures.free.duplicate(true)
	free.rested=false
	ui.apply_state(free,false,"",false,false)
	for i in range(6): await process_frame
	ui.begin_scenery()
	assert(ui.viewing_scenery and not ui.dock.visible and ui.scenery_hint.visible)
	assert(sent.back().command=="rest")
	free.rested=true
	ui.apply_state(free,false,"",false,false)
	assert(not ui.dock.visible)
	var toggle_at: Vector2=ui.night_button.get_global_rect().get_center()
	for down in [true,false]:
		var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down;click.position=toggle_at;click.global_position=toggle_at;Input.parse_input_event(click)
		await process_frame
	assert(ui.viewing_scenery and not ui.dock.visible and ui.night_button.button_pressed)
	ui.night_button.button_pressed=false
	for kind in ["touch","key","pad"]:
		var event: InputEvent
		if kind=="touch":
			event=InputEventScreenTouch.new();event.pressed=true;event.position=Vector2(190,400)
		elif kind=="key":
			event=InputEventKey.new();event.pressed=true;event.keycode=KEY_ESCAPE
		else:
			event=InputEventJoypadButton.new();event.pressed=true;event.button_index=JOY_BUTTON_B
		Input.parse_input_event(event)
		await process_frame
		assert(not ui.viewing_scenery and ui.dock.visible)
		event.pressed=false
		Input.parse_input_event(event)
		await process_frame
		ui.begin_scenery()
	assert(sent.size()==1) # 휴식 보상을 반복 요청하지 않는다.
	var minute=free.camp_minute
	var preview: Array=[]
	ui.night_preview_toggled.connect(func(value): preview.append(value))
	ui.night_button.button_pressed=true
	ui.night_button.button_pressed=false
	assert(preview==[true,false] and free.camp_minute==minute)
	var pack: Dictionary=fixtures.packing.duplicate(true)
	pack.cargo={};pack.pack_started=true;pack.pack_remaining_ms=30000
	# API가 내려 주는 오목한 점유 모양을 UI가 사각형으로 치환하지 않는지 확인한다.
	for item in pack.item_catalog:
		if item.id=="tent": item.cells=[[0,0],[1,0],[2,0],[0,1],[1,1]]
	ui.apply_state(pack,false,"",false,false)
	for i in range(12): await process_frame
	assert(not ui.viewing_scenery and ui.packing_footer.visible)
	assert(find_type(ui,"OptionButton")==null)
	var card=find_card("tent")
	assert(card!=null and card.footprint_cells.size()==5)
	assert(ui.board.get_global_rect().end.y<=ui.packing_footer.global_position.y)
	await drag(card.global_position+Vector2(30,25),ui.board.global_position+Vector2(15,15))
	assert(sent.back().command=="place_item" and sent.back().id=="tent")
	assert(sent.back().extra.x==0 and sent.back().extra.y==0)
	pack.cargo={"tent":{"x":0,"y":0,"rotation_degrees":0,"rotated":false}}
	ui.apply_state(pack,false,"",false,false)
	for i in range(8): await process_frame
	await drag(ui.board.global_position+Vector2(12,12),ui.board.global_position+Vector2(156,12))
	assert(sent.back().extra.x==3 and sent.back().extra.y==0)
	await drag(ui.board.global_position+Vector2(12,12),find_card("tent").global_position+Vector2(30,25))
	assert(sent.back().command=="remove_item" and sent.back().id=="tent")
	pack.cargo={}
	ui.apply_state(pack,false,"",false,false)
	for i in range(8): await process_frame
	await touch_drag(find_card("stove").global_position+Vector2(30,25),ui.board.global_position+Vector2(156,156))
	assert(sent.back().command=="place_item" and sent.back().id=="stove")
	assert(sent.back().extra.x==3 and sent.back().extra.y==3)
	ui.rotate_packing_item()
	assert(ui.packing_rotation==90 and ui.board.packing_angle==90)
	ui.rotate_packing_item();ui.rotate_packing_item();ui.rotate_packing_item()
	assert(ui.packing_rotation==0)
	var data={"packing_item":"tent","rotated":false,"rotation_degrees":0,"grab_cell":Vector2i.ZERO}
	assert(not ui.board._can_drop_data(Vector2(-48,0),data))
	assert(not ui.board._can_drop_data(Vector2(300,0),data))
	var finish: Button=ui.packing_footer.get_child(0)
	finish.pressed.emit()
	assert(sent.back().command=="finish_pack")
	pack.phase="return_pack";pack.return_candidates=["tent","stove"];pack.cargo={}
	ui.apply_state(pack,false,"",false,false)
	var count:=sent.size()
	ui.packing_footer.get_child(0).pressed.emit()
	assert(ui.packing_confirm and sent.size()==count)
	ui.packing_footer.get_child(2).pressed.emit()
	assert(sent.back().extra.confirm_loss)
	for dimensions in [Vector2i(390,844),Vector2i(820,920),Vector2i(1280,900)]:
		root.size=dimensions
		for i in range(8): await process_frame
		assert(ui.packing_footer.get_global_rect().end.y<=dimensions.y)
	print("PASS MVP UX: scenery hide/restore / day-night preview / tray-to-grid drag / move / four turns / early departure / return confirmation / phone-fold-PC")
	quit()

func find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name): return node
	for child in node.get_children():
		var found=find_type(child,type_name)
		if found!=null: return found
	return null

func find_card(id: String) -> Button:
	for node in ui.action_buttons:
		if node is PackingItem and node.item_id==id: return node
	return null

func drag(start: Vector2,finish: Vector2) -> void:
	var move:=InputEventMouseMotion.new();move.position=start;move.global_position=start;Input.parse_input_event(move)
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=start;press.global_position=start;Input.parse_input_event(press)
	await process_frame
	for point in [start+Vector2(18,10),finish]:
		move=InputEventMouseMotion.new();move.position=point;move.global_position=point;move.button_mask=MOUSE_BUTTON_MASK_LEFT;move.relative=Vector2(18,10);Input.parse_input_event(move)
		for i in range(3): await process_frame
	press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=false;press.position=finish;press.global_position=finish;Input.parse_input_event(press)
	for i in range(5): await process_frame

func touch_drag(start: Vector2,finish: Vector2) -> void:
	Input.emulate_mouse_from_touch=true
	var press:=InputEventScreenTouch.new();press.index=0;press.pressed=true;press.position=start;Input.parse_input_event(press)
	await process_frame
	var previous:=start
	for point in [start+Vector2(18,10),finish]:
		var move:=InputEventScreenDrag.new();move.index=0;move.position=point;move.relative=point-previous;Input.parse_input_event(move)
		previous=point
		for i in range(3): await process_frame
	press=InputEventScreenTouch.new();press.index=0;press.pressed=false;press.position=finish;Input.parse_input_event(press)
	for i in range(5): await process_frame
