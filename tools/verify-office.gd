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
	var state={"mvp_version":1,"phase":"work","week":1,"day":0,"money":80,"stamina":80,"character_id":"male","office_remaining_ms":20000,"office_pay":0,
		"office_task":{"week":1,"day":0,"index":0,"mistakes":0,"active":true,"feedback":"서류 검토"},
		"office_case":{"id":"W1-D0-0","order":{"supplier":"솔숲상사","amount":12000,"due":12},"invoice":{"supplier":"솔숲상사","amount":12000,"due":12}}}
	ui.apply_state(state,false,"",false)
	for i in range(8): await process_frame
	var desk=ui.office_screen
	assert(desk.visible and desk.size.is_equal_approx(Vector2(root.size)))
	assert(desk.is_ancestor_of(root.gui_get_focus_owner()))
	desk.approve.pressed.emit();assert(desk.stamp_mark.visible);assert(sent.back().choice=="approve" and sent.back().extra.case_id=="W1-D0-0")
	var before_mark := sent.size()
	desk.invoice_fields.amount.pressed.emit()
	assert(sent.size()==before_mark+1 and sent.back().choice=="revise" and sent.back().extra.field=="amount")
	var midpoint: Vector2 = desk.stamp_mark.position+desk.stamp_mark.size/2
	assert(midpoint.is_equal_approx(desk.papers.get_global_rect().get_center()))
	for touch in [false,true]:
		var before_drag:=sent.size()
		await drag(desk.invoice.global_position+Vector2(35,30),desk.approve.get_global_rect().get_center(),touch)
		assert(sent.size()==before_drag+1 and sent.back().command=="office_review" and sent.back().choice=="approve")
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
	assert(desk.reload_button.visible and desk.invoice_fields.amount.disabled)
	ui.apply_state(state,false,"",false)
	desk.pause_button.pressed.emit();assert(sent.back().command=="office_pause")
	state.office_task.active=false;ui.apply_state(state,false,"",false)
	for i in range(3): await process_frame
	count=sent.size()
	key=InputEventKey.new();key.keycode=KEY_2;key.pressed=true;Input.parse_input_event(key);await process_frame
	assert(sent.size()==count and not desk.visible and root.gui_get_focus_owner()==ui.office_button)
	state.parcel_box=["tent"];state.parcel_fee=5
	state.item_catalog=[{"id":"tent","name":"낡은 텐트"}]
	ui.apply_state(state,false,"",false)
	ui.mailbox_button.pressed.emit()
	assert(ui.mailbox_scroll.visible)
	var parcel_button: Button=ui.mailbox_items.get_child(0)
	assert(parcel_button.text.contains("5원") and not parcel_button.disabled)
	parcel_button.pressed.emit()
	assert(sent.back().command=="claim_parcel" and sent.back().choice=="tent")
	ui.mailbox_button.pressed.emit()

	state.office_task.active=true;ui.apply_state(state,false,"",false)
	for dimensions in [Vector2i(320,720),Vector2i(390,844),Vector2i(820,920),Vector2i(1280,900),Vector2i(844,390)]:
		root.size=dimensions
		for i in range(8): await process_frame
		assert(desk.size.is_equal_approx(Vector2(dimensions)))
		assert(not desk.papers.vertical)
		for paper in desk.papers.get_children():
			assert(desk.scroll.get_global_rect().encloses(paper.get_global_rect()), "%s: scroll=%s, paper=%s" % [dimensions, desk.scroll.get_global_rect(), paper.get_global_rect()])
		assert(desk.layout.get_rect().end.x<=dimensions.x and desk.layout.get_rect().end.y<=dimensions.y)
		assert(desk.approve.get_global_rect().end.y<=dimensions.y)
		for field in desk.fields: assert(field.get_global_rect().end.x<=dimensions.x)
	state.office_task.index=2;state.office_pay=3;state.office_remaining_ms=0;state.erase("office_case");ui.apply_state(state,false,"",false)
	assert(desk.finish_button.visible and not desk.approve.visible )
	assert(desk.finish_button.text.contains("3원") and desk.progress.text.contains("0초"))
	desk.finish_button.pressed.emit();assert(sent.back().command=="office_finish")
	print("PASS office: one-tap correction / centered approval stamp / fullscreen phone/cover/fold/PC/landscape / click / mouse+touch drag / keyboard / saving lock / recovery / finish")
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
