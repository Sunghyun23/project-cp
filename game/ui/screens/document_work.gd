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
var finish_button: Button
var reload_button: Button
var invoice
var fields: Array[Control]=[]
var invoice_fields: Dictionary = {}
var marking_style: StyleBoxFlat
var scroll: ScrollContainer
var stamp_mark: Label
var stamp_tween: Tween
var stamp_sound: AudioStreamPlayer

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
	rules=text("거래처 · 금액 · 납기일 대조\n같으면 결재 · 다르면 청구서 항목 누르기",22)
	layout.add_child(rules)
	scroll=ScrollContainer.new();scroll.size_flags_vertical=SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	papers=BoxContainer.new();papers.size_flags_horizontal=SIZE_EXPAND_FILL;papers.size_flags_vertical=SIZE_EXPAND_FILL;papers.add_theme_constant_override("separation",8);scroll.add_child(papers)
	feedback=text("다른 항목을 누르면 바로 보완 요청해요.",22)
	feedback.custom_minimum_size.y=38;layout.add_child(feedback)
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",12);layout.add_child(actions)
	approve=make_stamp("결재","approve","406949");approve.tooltip_text="키보드 1 · 결재";actions.add_child(approve)
	finish_button=Button.new();finish_button.text="퇴근하기";finish_button.custom_minimum_size.y=56
	finish_button.pressed.connect(func(): send("office_finish"));layout.add_child(finish_button)
	reload_button=Button.new();reload_button.text="저장된 업무 다시 확인";reload_button.custom_minimum_size.y=56
	reload_button.pressed.connect(func(): reload_requested.emit());layout.add_child(reload_button)
	marking_style = StyleBoxFlat.new()
	marking_style.bg_color = Color("efbc99")
	marking_style.border_color = Color("9d4633")
	marking_style.set_border_width_all(2)
	stamp_sound = AudioStreamPlayer.new()
	stamp_sound.stream = preload("res://assets/audio/office-stamp.wav")
	stamp_sound.volume_db = -16
	add_child(stamp_sound)
	stamp_mark = text("", 48, Color("a4312e"))
	stamp_mark.add_theme_color_override("font_outline_color", Color("fff4d3"))
	stamp_mark.add_theme_constant_override("outline_size", 9)
	var seal := StyleBoxFlat.new()
	seal.bg_color = Color("fff1d9e8")
	seal.border_color = Color("aa3934")
	seal.set_border_width_all(4)
	seal.set_corner_radius_all(7)
	stamp_mark.add_theme_stylebox_override("normal", seal)
	stamp_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp_mark.z_index = 1
	stamp_mark.hide()
	add_child(stamp_mark)
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
	paper.size_flags_vertical=SIZE_EXPAND_FILL
	var style:=StyleBoxFlat.new();style.bg_color=Color("f2e5bc") if not draggable else Color("fff4d3")
	style.border_color=Color("bba87d");style.set_border_width_all(3)
	style.content_margin_left=10;style.content_margin_right=10;style.content_margin_top=5;style.content_margin_bottom=5
	paper.add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",0);paper.add_child(column)
	column.add_child(text(heading,19,Color("304c45")))
	paper.tooltip_text="전표 "+current_case+(" · 아래 도장으로 끌어 놓기" if draggable else " · 대조 기준")
	column.add_child(HSeparator.new())
	for key in ["supplier","amount","due"]:
		var entry := VBoxContainer.new()
		entry.size_flags_vertical = SIZE_EXPAND_FILL
		entry.alignment = BoxContainer.ALIGNMENT_CENTER
		entry.add_theme_constant_override("separation", 0)
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(entry)
		var caption: String={"supplier":"거래처","amount":"금액","due":"납기일"}[key]
		entry.add_child(text(caption,15,Color("67583f")))
		var rendered: String=str(value.get(key,""))
		if key=="amount": rendered+="원"
		if key=="due": rendered+="일"
		if draggable:
			var marker := Button.new()
			marker.text = rendered
			marker.alignment = HORIZONTAL_ALIGNMENT_LEFT
			marker.tooltip_text = caption + " 보완 요청"
			var plain := StyleBoxEmpty.new()
			marker.add_theme_stylebox_override("normal", plain)
			marker.add_theme_stylebox_override("disabled", plain)
			for variant in ["hover", "pressed", "hover_pressed"]:
				marker.add_theme_stylebox_override(variant, marking_style)
			for variant in ["font_color", "font_pressed_color", "font_hover_color", "font_disabled_color", "font_focus_color"]:
				marker.add_theme_color_override(variant, Color("26332b"))
			marker.add_theme_font_size_override("font_size", 20)
			marker.pressed.connect(func(): judge("revise", key))
			entry.add_child(marker)
			fields.append(marker)
			invoice_fields[key] = marker
		else:
			var field := text(rendered,20,Color("26332b"))
			field.autowrap_mode = TextServer.AUTOWRAP_OFF
			entry.add_child(field)
			fields.append(field)
	return paper

func apply_state(value: Dictionary, saving: bool, message: String, must_check: bool) -> void:
	state=value;pending=saving;check_required=must_check
	var task: Dictionary=state.get("office_task",{})
	var index := int(task.get("index", 0))
	var remaining := int(state.get("office_remaining_ms", 20000))
	var done := remaining <= 0
	var was_complete:=finish_button.visible
	var pay := int(state.get("office_pay", 0))
	progress.text="%s · %d초 · %d건 · %d원"%[["월","화","수","목","금"][clampi(int(state.get("day",0)),0,4)],ceili(remaining/1000.0),index,pay]
	finish_button.text="퇴근하기 · 수입 %d원"%pay
	var paper: Dictionary=state.get("office_case",{})
	var next_id: String=paper.get("id","")
	if current_case!=next_id or papers.get_child_count()==0:
		current_case=next_id;fields.clear();invoice_fields.clear()
		for child in papers.get_children(): papers.remove_child(child);child.queue_free()
		invoice=null
		if not done and not paper.is_empty():
			papers.add_child(sheet("발주서 · 원본",paper.order,false))
			invoice=sheet("청구서 · 접수",paper.invoice,true);papers.add_child(invoice)
		else:
			var summary:=text("업무 시간이 끝났어요\n\n%d건 처리 · 오답 %d건\n\n오늘 급여 %d원"%[index,int(task.get("mistakes",0)),pay],28)
			summary.size_flags_horizontal=SIZE_EXPAND_FILL;papers.add_child(summary)
	feedback.text="저장 중…" if saving else message if must_check or (not message.is_empty() and not message.begins_with("서버 저장 완료")) else str(task.get("feedback","서류 내용을 대조해 주세요."))
	if done and not saving and not must_check and not feedback.text.contains("−2초"):
		feedback.text="검토 완료! 퇴근하면 오늘 급여를 받아요."
	feedback.add_theme_color_override("font_color",Color("ffdb98") if int(task.get("mistakes",0))>0 else Color("f7edce"))
	approve.disabled=saving or must_check or done;approve.visible=not done;approve.case_id=current_case
	if invoice!=null: invoice.draggable=not saving and not must_check
	for marker in invoice_fields.values(): marker.disabled = saving or must_check
	pause_button.disabled=saving or must_check or done
	finish_button.visible=done;finish_button.disabled=saving or must_check
	if done and not was_complete: focus_action.call_deferred()
	reload_button.visible=must_check;reload_button.disabled=saving
	fit.call_deferred()

func judge(choice: String, field := "") -> void:
	if pending or check_required or current_case.is_empty(): return
	show_stamp(choice)
	action_requested.emit("office_review",choice,{"case_id":current_case,"field":field})

func show_stamp(choice: String) -> void:
	if not is_instance_valid(invoice): return
	if stamp_tween != null: stamp_tween.kill()
	var approving := choice == "approve"
	stamp_mark.text = "결재" if approving else "보완 요청"
	stamp_mark.add_theme_font_size_override("font_size", 48 if approving else 37)
	var ink := Color("a4312e") if approving else Color("31577f")
	stamp_mark.add_theme_color_override("font_color", ink)
	var seal: StyleBoxFlat = stamp_mark.get_theme_stylebox("normal")
	seal.border_color = ink
	stamp_mark.size = Vector2(minf(200, size.x * .56), 78)
	stamp_mark.position = get_global_transform().affine_inverse() * papers.get_global_rect().get_center() - stamp_mark.size * 0.5
	stamp_mark.pivot_offset = stamp_mark.size * 0.5
	stamp_mark.rotation_degrees = -12
	stamp_mark.scale = Vector2.ONE * 1.7
	stamp_mark.modulate.a = 1
	stamp_mark.show()
	stamp_sound.play()
	stamp_tween = create_tween()
	stamp_tween.tween_property(stamp_mark, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stamp_tween.tween_interval(0.18)
	stamp_tween.tween_property(stamp_mark, "modulate:a", 0.0, 0.16)
	stamp_tween.tween_callback(stamp_mark.hide)

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
		elif event.keycode==KEY_ESCAPE: send("office_pause");accept_event()
	elif event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B:
		send("office_pause");accept_event()

func fit() -> void:
	if layout==null: return
	var margin:=12.0 if size.y<470 else 16.0 if size.x<700 else 28.0
	layout.position=Vector2.ONE*margin;layout.size=size-Vector2.ONE*margin*2
	var compact := size.y < 470
	layout.add_theme_constant_override("separation", 6 if compact else 12)
	pause_button.custom_minimum_size.y = 44 if compact else 56
	rules.text = "거래처 · 금액 · 납기일 대조  |  같으면 결재 · 다르면 청구서 항목 누르기" if compact else "거래처 · 금액 · 납기일 대조\n같으면 결재 · 다르면 청구서 항목 누르기"
	rules.add_theme_font_size_override("font_size", 16 if compact else 20)
	feedback.add_theme_font_size_override("font_size", 15 if compact else 18)
	feedback.custom_minimum_size.y = 24 if compact else 38
	approve.custom_minimum_size.y = 48 if compact else 60
	papers.vertical=false
	for field in fields: field.add_theme_font_size_override("font_size",18 if compact or size.x<450 else 22 if size.x<700 else 26)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("263b3a"))
	var start:=150.0 if size.y>600 else 112.0
	draw_rect(Rect2(0,start,size.x,size.y-start),Color("594636"))
	for line in range(int(start),int(size.y),28):
		draw_line(Vector2(0,line),Vector2(size.x,line),Color("514030"),2)
	for x in range(0,int(size.x),180):
		draw_rect(Rect2(x+14,size.y-8,150,3),Color("876747"))
