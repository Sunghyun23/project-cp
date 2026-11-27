extends Control

signal action_requested(command: String, choice: String, extra: Dictionary)
signal reload_requested
const Paper=preload("res://ui/components/office_paper.gd")
const Stamp=preload("res://ui/components/office_stamp.gd")
var state: Dictionary={}
var pending := false
var check_required := false
var current_case := ""
var layout: VBoxContainer
var papers: BoxContainer
var progress: Label
var feedback: Label
var rules: Label
var pause_button: Button
var approve: Button
var revise: Button
var finish_button: Button
var reload_button: Button
var invoice
var fields: Array[Label]=[]
var scroll: ScrollContainer

func text(value: String, font_size: int=24, ink: Color=Color("f7edce")) -> Label:
	var node:=Label.new();node.text=value
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",ink)
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return node

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	layout=VBoxContainer.new();layout.add_theme_constant_override("separation",12);add_child(layout)
	var top:=HBoxContainer.new();layout.add_child(top)
	progress=text("서류 검토",26);progress.size_flags_horizontal=SIZE_EXPAND_FILL;top.add_child(progress)
	pause_button=Button.new();pause_button.text="잠시 나가기";pause_button.custom_minimum_size=Vector2(120,56)
	pause_button.pressed.connect(func(): send("office_pause"));top.add_child(pause_button)
	rules=text("거래처 · 금액 · 납기일 대조\n같음: 결재 / 다름: 보완 요청",22)
	layout.add_child(rules)
	scroll=ScrollContainer.new();scroll.size_flags_vertical=SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	papers=BoxContainer.new();papers.size_flags_horizontal=SIZE_EXPAND_FILL;papers.size_flags_vertical=SIZE_EXPAND_FILL;papers.add_theme_constant_override("separation",16);scroll.add_child(papers)
	feedback=text("접수 서류를 읽고 아래 도장으로 끌어 놓거나 버튼을 누르세요.",22)
	feedback.custom_minimum_size.y=54;layout.add_child(feedback)
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",12);layout.add_child(actions)
	approve=make_stamp("결재","approve","406949");approve.tooltip_text="키보드 1 · 결재";actions.add_child(approve)
	revise=make_stamp("보완 요청","revise","8f5143");revise.tooltip_text="키보드 2 · 보완 요청";actions.add_child(revise)
	finish_button=Button.new();finish_button.text="퇴근하기 · 수입 10원";finish_button.custom_minimum_size.y=56
	finish_button.pressed.connect(func(): send("office_finish"));layout.add_child(finish_button)
	reload_button=Button.new();reload_button.text="저장된 업무 다시 확인";reload_button.custom_minimum_size.y=56
	reload_button.pressed.connect(func(): reload_requested.emit());layout.add_child(reload_button)
	resized.connect(fit);fit()

func make_stamp(caption: String, decision: String, color: String) -> Button:
	var node:=Stamp.new();node.text=caption;node.custom_minimum_size=Vector2(0,64);node.size_flags_horizontal=SIZE_EXPAND_FILL
	var style:=StyleBoxFlat.new();style.bg_color=Color(color);style.border_color=Color("d8c89f")
	style.set_border_width_all(3);style.content_margin_left=8;style.content_margin_right=8
	node.add_theme_stylebox_override("normal",style)
	node.add_theme_font_size_override("font_size",24)
	node.add_theme_color_override("font_color",Color("fff5d9"))
	for variant in ["font_focus_color","font_hover_color","font_pressed_color"]:
		node.add_theme_color_override(variant,Color("fff5d9"))
	node.pressed.connect(func(): judge(decision));node.paper_received.connect(func(): judge(decision))
	return node

func sheet(heading: String, value: Dictionary, draggable: bool) -> PanelContainer:
	var paper:=Paper.new();paper.case_id=current_case;paper.draggable=draggable
	paper.size_flags_horizontal=SIZE_EXPAND_FILL
	var style:=StyleBoxFlat.new();style.bg_color=Color("f2e5bc") if not draggable else Color("fff4d3")
	style.border_color=Color("bba87d");style.set_border_width_all(3)
	style.content_margin_left=16;style.content_margin_right=16;style.content_margin_top=10;style.content_margin_bottom=10
	style.shadow_color=Color(0,0,0,.3);style.shadow_size=5;style.shadow_offset=Vector2(4,5)
	paper.add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",6);paper.add_child(column)
	column.add_child(text(heading,22,Color("304c45")))
	paper.tooltip_text="전표 "+current_case+(" · 아래 도장으로 끌어 놓기" if draggable else " · 대조 기준")
	column.add_child(HSeparator.new())
	for key in ["supplier","amount","due"]:
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);column.add_child(row)
		var caption: String={"supplier":"거래처","amount":"금액","due":"납기일"}[key]
		var name_label:=text(caption,22,Color("7a6b50"));name_label.autowrap_mode=TextServer.AUTOWRAP_OFF;name_label.size_flags_horizontal=SIZE_EXPAND_FILL;row.add_child(name_label)
		var rendered: String=str(value.get(key,""))
		if key=="amount": rendered+="원"
		if key=="due": rendered+="일"
		var field:=text(rendered,24,Color("2b332e"));field.autowrap_mode=TextServer.AUTOWRAP_OFF;field.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;row.add_child(field);fields.append(field)
	var space:=Control.new();space.size_flags_vertical=SIZE_EXPAND_FILL;space.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(space)
	column.add_child(text("대조 후 처리해 주세요" if draggable else "이 문서를 기준으로 확인",18,Color("9b8a65")))
	return paper

func apply_state(value: Dictionary, saving: bool, message: String, must_check: bool) -> void:
	state=value;pending=saving;check_required=must_check
	var task: Dictionary=state.get("office_task",{})
	var index:=int(task.get("index",0));var total:=int(state.get("office_total",6));var done:=index>=total
	var was_complete:=finish_button.visible
	progress.text="%s · %d / %d건"%[["월","화","수","목","금"][clampi(int(state.get("day",0)),0,4)],index,total]
	var paper: Dictionary=state.get("office_case",{})
	var next_id: String=paper.get("id","")
	if current_case!=next_id or papers.get_child_count()==0:
		current_case=next_id;fields.clear()
		for child in papers.get_children(): papers.remove_child(child);child.queue_free()
		invoice=null
		if not done and not paper.is_empty():
			papers.add_child(sheet("발주서 · 원본",paper.order,false))
			invoice=sheet("청구서 · 접수",paper.invoice,true);papers.add_child(invoice)
		else:
			var summary:=text("오늘의 서류 검토 완료\n\n%d건 처리 · 다시 확인 %d회\n\n수고했어요. 캠핑 비용을 모았어요."%[total,int(task.get("mistakes",0))],28)
			summary.size_flags_horizontal=SIZE_EXPAND_FILL;papers.add_child(summary)
	feedback.text="저장 중…" if saving else message if must_check or (not message.is_empty() and not message.begins_with("서버 저장 완료")) else str(task.get("feedback","서류 내용을 대조해 주세요."))
	if done and not saving and not must_check: feedback.text="검토 완료! 퇴근하면 오늘 급여를 받아요."
	feedback.add_theme_color_override("font_color",Color("ffdb98") if int(task.get("mistakes",0))>0 else Color("f7edce"))
	for button in [approve,revise]:
		button.disabled=saving or must_check or done;button.visible=not done;button.case_id=current_case
	if invoice!=null: invoice.draggable=not saving and not must_check
	pause_button.disabled=saving or must_check
	finish_button.visible=done;finish_button.disabled=saving or must_check
	if done and not was_complete: focus_action.call_deferred()
	reload_button.visible=must_check;reload_button.disabled=saving
	fit.call_deferred()

func judge(choice: String) -> void:
	if pending or check_required or current_case.is_empty(): return
	action_requested.emit("office_review",choice,{"case_id":current_case})

func send(command: String) -> void:
	if not pending and not check_required: action_requested.emit(command,"",{})

func focus_action() -> void:
	if not is_visible_in_tree(): return
	if check_required: reload_button.grab_focus()
	elif finish_button.visible: finish_button.grab_focus()
	else: approve.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_1: judge("approve");accept_event()
		elif event.keycode==KEY_2: judge("revise");accept_event()
		elif event.keycode==KEY_ESCAPE: send("office_pause");accept_event()
	elif event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B:
		send("office_pause");accept_event()

func fit() -> void:
	if layout==null: return
	var margin:=16.0 if size.x<700 else 28.0
	layout.position=Vector2.ONE*margin;layout.size=size-Vector2.ONE*margin*2
	papers.vertical=size.x<700
	for field in fields: field.add_theme_font_size_override("font_size",22 if size.x<700 else 28)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("263b3a"))
	var start:=150.0 if size.y>600 else 112.0
	draw_rect(Rect2(0,start,size.x,size.y-start),Color("594636"))
	for line in range(int(start),int(size.y),28):
		draw_line(Vector2(0,line),Vector2(size.x,line),Color("514030"),2)
	for x in range(0,int(size.x),180):
		draw_rect(Rect2(x+14,size.y-8,150,3),Color("876747"))
