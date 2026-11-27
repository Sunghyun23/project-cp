extends SceneTree

const Work=preload("res://ui/screens/first_week.tscn")
var ui
var sent: Array=[]
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	create_timer(20).timeout.connect(func(): printerr("FAIL office input timeout");quit(1))
	root.size=Vector2i(390,844)
	ui=Work.instantiate();root.add_child(ui)
	ui.office_action_requested.connect(func(command,choice,extra): sent.append({"command":command,"choice":choice,"extra":extra}))
	var state={"mvp_version":1,"phase":"work","week":1,"day":0,"money":80,"stamina":80,"character_id":"male","office_total":6,
		"office_task":{"week":1,"day":0,"index":0,"mistakes":0,"active":true,"feedback":"서류 검토"},
		"office_case":{"id":"W1-D0-0","order":{"supplier":"솔숲상사","amount":12000,"due":12},"invoice":{"supplier":"솔숲상사","amount":12000,"due":12}}}
	ui.apply_state(state,false,"",false)
	for i in range(8): await process_frame
	var desk=ui.office_screen
	assert(desk.visible and desk.size.is_equal_approx(Vector2(root.size)))
	assert(desk.is_ancestor_of(root.gui_get_focus_owner()))
	desk.approve.pressed.emit();assert(sent.back().choice=="approve" and sent.back().extra.case_id=="W1-D0-0")
	for touch in [false,true]:
		var before_drag:=sent.size()
		await drag(desk.invoice.global_position+Vector2(35,30),desk.revise.get_global_rect().get_center(),touch)
		assert(sent.size()==before_drag+1 and sent.back().command=="office_review" and sent.back().choice=="revise")
	var key:=InputEventKey.new();key.keycode=KEY_1;key.pressed=true;Input.parse_input_event(key);await process_frame
	assert(sent.back().choice=="approve")
	desk.approve.grab_focus()
	var before_pad:=sent.size()
	for down in [true,false]:
		var pad:=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_A;pad.pressed=down;Input.parse_input_event(pad);await process_frame
	assert(sent.size()==before_pad+1 and sent.back().choice=="approve")
	ui.apply_state(state,true,"저장 중",false)
	var count:=sent.size();desk.judge("approve");assert(sent.size()==count and desk.approve.disabled and not desk.invoice.draggable)
	ui.apply_state(state,false,"연결을 확인해 주세요",true)
	assert(desk.reload_button.visible and desk.revise.disabled)
	ui.apply_state(state,false,"",false)
	desk.pause_button.pressed.emit();assert(sent.back().command=="office_pause")
	state.office_task.active=false;ui.apply_state(state,false,"",false)
	for i in range(3): await process_frame
	count=sent.size()
	key=InputEventKey.new();key.keycode=KEY_2;key.pressed=true;Input.parse_input_event(key);await process_frame
	assert(sent.size()==count and not desk.visible and root.gui_get_focus_owner()==ui.office_button)
	state.office_task.active=true;ui.apply_state(state,false,"",false)
	for dimensions in [Vector2i(320,720),Vector2i(390,844),Vector2i(820,920),Vector2i(1280,900),Vector2i(844,390)]:
		root.size=dimensions
		for i in range(8): await process_frame
		assert(desk.size.is_equal_approx(Vector2(dimensions)))
		assert(desk.papers.vertical==(dimensions.x<700))
		assert(desk.layout.get_rect().end.x<=dimensions.x and desk.layout.get_rect().end.y<=dimensions.y)
		assert(desk.approve.get_global_rect().end.y<=dimensions.y)
		for field in desk.fields: assert(field.get_global_rect().end.x<=dimensions.x)
	state.office_task.index=6;state.erase("office_case");ui.apply_state(state,false,"",false)
	assert(desk.finish_button.visible and not desk.approve.visible)
	desk.finish_button.pressed.emit();assert(sent.back().command=="office_finish")
	print("PASS office: fullscreen phone/cover/fold/PC/landscape / click / mouse+touch drag / keyboard / saving lock / recovery / finish")
	quit()

func drag(start: Vector2,finish: Vector2,touch: bool) -> void:
	if touch:
		Input.emulate_mouse_from_touch=true
		var press:=InputEventScreenTouch.new();press.position=start;press.pressed=true;Input.parse_input_event(press);await process_frame
		var previous:=start
		for point in [start+Vector2(18,10),finish]:
			var move:=InputEventScreenDrag.new();move.position=point;move.relative=point-previous;Input.parse_input_event(move);previous=point
			for i in range(3): await process_frame
		press=InputEventScreenTouch.new();press.position=finish;press.pressed=false;Input.parse_input_event(press)
	else:
		var press:=InputEventMouseButton.new();press.position=start;press.global_position=start;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;Input.parse_input_event(press);await process_frame
		for point in [start+Vector2(18,10),finish]:
			var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point;move.relative=Vector2(18,10);move.button_mask=MOUSE_BUTTON_MASK_LEFT;Input.parse_input_event(move)
			for i in range(3): await process_frame
		press=InputEventMouseButton.new();press.position=finish;press.global_position=finish;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=false;Input.parse_input_event(press)
	for i in range(5): await process_frame
