extends Control

signal work_requested
signal reload_requested
signal account_requested
signal office_action_requested(command: String, choice: String, extra: Dictionary)

const UiInput = preload("res://ui/ui_input.gd")
const ROOM = preload("res://assets/pixel/workroom-day.png")
const Paper = preload("res://ui/components/paper_panel.tscn")
const Action = preload("res://ui/components/action_button.tscn")
const Chip = preload("res://ui/components/hud_chip.tscn")
const Notice = preload("res://ui/components/notice.tscn")
var scenery: TextureRect
var header: VBoxContainer
var title: Label
var week_label: Label
var money_chip: PanelContainer
var stamina_chip: PanelContainer
var dock: PanelContainer
var guide: Label
var result_label: Label
var notice: PanelContainer
var work_button: Button
var reload_button: Button
var account_button: Button
var snapshot: Dictionary = {}
var outcome := ""
var pending := false
var office_button: Button
var office_screen
var mailbox_button: Button
var mailbox_dialog: AcceptDialog
var mailbox_scroll: ScrollContainer
var mailbox_items: VBoxContainer

func label(value: String, font_size: int = 16, floating: bool = false) -> Label:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", font_size)
	if floating:
		item.add_theme_color_override("font_color", Color("fff7df"))
		item.add_theme_color_override("font_shadow_color", Color("25372af0"))
		item.add_theme_constant_override("shadow_offset_x", 2)
		item.add_theme_constant_override("shadow_offset_y", 2)
	return item

func _ready() -> void:
	UiInput.ensure()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scenery = TextureRect.new()
	scenery.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scenery.stretch_mode = TextureRect.STRETCH_SCALE
	scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scenery)
	var shade := ColorRect.new()
	shade.color = Color(0.07, 0.12, 0.08, 0.12)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	header = VBoxContainer.new()
	header.size.x = size.x - 40
	header.add_theme_constant_override("separation", 12)
	add_child(header)
	var top := HBoxContainer.new()
	header.add_child(top)
	week_label = label("첫 번째 주말을 향해", 16, true)
	week_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(week_label)
	account_button = Action.instantiate()
	account_button.text = "계정"
	account_button.custom_minimum_size.x = 64
	account_button.visible = OS.has_feature("web")
	account_button.pressed.connect(func(): account_requested.emit())
	top.add_child(account_button)
	title = label("주말을 기다리는 월요일", 32, true)
	header.add_child(title)
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 8)
	stats.add_theme_constant_override("v_separation", 8)
	header.add_child(stats)
	money_chip = Chip.instantiate()
	money_chip.get_node("Value").text = "소지금 · 0원"
	stats.add_child(money_chip)
	stamina_chip = Chip.instantiate()
	stamina_chip.get_node("Value").text = "체력 · 0 / 100"
	stats.add_child(stamina_chip)
	dock = Paper.instantiate()
	dock.custom_minimum_size.x = minf(520, size.x - 40)
	add_child(dock)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	dock.add_child(column)
	guide = label("평일에는 일을 마쳐 캠핑 비용을 모아요.")
	column.add_child(guide)
	result_label = label("")
	result_label.visible = false
	column.add_child(result_label)
	notice = Notice.instantiate()
	notice.visible = false
	column.add_child(notice)
	work_button = Action.instantiate()
	work_button.theme_type_variation = "PrimaryButton"
	work_button.text = "오늘 일 마치기  →"
	work_button.pressed.connect(func():
		if not pending:
			work_requested.emit())
	column.add_child(work_button)
	office_button=Action.instantiate()
	office_button.theme_type_variation="PrimaryButton"
	office_button.text="서류 검토 업무 시작"
	office_button.pressed.connect(func():
		if not pending: office_action_requested.emit("office_start","",{}))
	column.add_child(office_button)
	column.move_child(office_button,work_button.get_index())
	work_button.theme_type_variation=""
	reload_button = Action.instantiate()
	reload_button.text = "저장 상태 다시 확인"
	reload_button.visible = false
	reload_button.pressed.connect(func(): reload_requested.emit())
	column.add_child(reload_button)
	mailbox_button = Action.instantiate()
	mailbox_button.text = "집 택배함"
	mailbox_button.pressed.connect(func():
		mailbox_dialog.popup_centered(Vector2i(mini(390, int(size.x) - 24), 0)))
	column.add_child(mailbox_button)
	mailbox_dialog = AcceptDialog.new()
	mailbox_dialog.title = "집 택배함"
	mailbox_dialog.ok_button_text = "닫기"
	mailbox_dialog.exclusive = true
	mailbox_dialog.theme = preload("res://ui/theme/camping.tres")
	add_child(mailbox_dialog)
	mailbox_scroll = ScrollContainer.new()
	mailbox_scroll.custom_minimum_size = Vector2(260, 180)
	mailbox_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mailbox_dialog.add_child(mailbox_scroll)
	mailbox_items = VBoxContainer.new()
	mailbox_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mailbox_scroll.add_child(mailbox_items)
	office_screen=preload("res://ui/screens/document_work.gd").new()
	office_screen.z_index=30
	add_child(office_screen)
	office_screen.visible=false
	office_screen.action_requested.connect(func(command,choice,extra): office_action_requested.emit(command,choice,extra))
	office_screen.reload_requested.connect(func(): reload_requested.emit())
	resized.connect(fit)
	dock.minimum_size_changed.connect(func(): fit.call_deferred())
	fit()
	focus_initial.call_deferred()
	if "--capture-work" in OS.get_cmdline_user_args():
		capture.call_deferred()

func apply_state(value: Dictionary, saving: bool, message: String, check_required: bool) -> void:
	snapshot = value
	pending = saving or check_required
	week_label.text = "첫 번째 주말을 향해" if int(value.get("week", 1)) == 1 else "%d번째 주말을 향해" % int(value.get("week", 1))
	money_chip.get_node("Value").text = "소지금 · %d원" % int(value.get("money", 0))
	stamina_chip.get_node("Value").text = "체력 · %d / 100" % int(value.get("stamina", 0))
	guide.text = "시작한 서류 검토를 이어서 할 수 있어요." if value.has("office_task") else "20초 동안 서류를 검토해 캠핑 비용을 모아요.\n간단 업무로 바로 마칠 수도 있어요."
	result_label.text = outcome
	result_label.visible = not outcome.is_empty()
	notice.visible = saving or check_required
	notice.severity = 1 if check_required else 0
	notice.message = message
	work_button.disabled = pending or value.has("office_task")
	work_button.text = "저장 중…" if saving else "간단 업무로 마치기  →"
	office_button.disabled=pending
	office_button.text="서류 검토 이어하기" if value.has("office_task") else "서류 검토 업무 시작"
	var was_open: bool=office_screen.visible
	office_screen.visible=bool(value.get("office_task",{}).get("active",false))
	for button in [work_button,office_button,reload_button,account_button,mailbox_button]:
		button.focus_mode=Control.FOCUS_NONE if office_screen.visible else Control.FOCUS_ALL
	if office_screen.visible:
		mailbox_dialog.hide()
		office_screen.apply_state(value,saving,message,check_required)
		if not was_open: office_screen.focus_action.call_deferred()
	elif was_open:
		office_button.grab_focus.call_deferred()
	reload_button.visible = check_required
	reload_button.disabled = saving
	account_button.disabled = saving
	refresh_mailbox()
	fit.call_deferred()

func refresh_mailbox() -> void:
	var parcels: Array = snapshot.get("parcel_box", [])
	var fee := int(snapshot.get("parcel_fee", 5))
	mailbox_button.text = "집 택배함 · %d개" % parcels.size()
	mailbox_button.disabled = pending or office_screen.visible
	for child in mailbox_items.get_children():
		mailbox_items.remove_child(child)
		child.queue_free()
	if parcels.is_empty():
		mailbox_items.add_child(label("받을 장비가 없어요."))
	for id in parcels:
		var item_name: String = id
		for item in snapshot.get("item_catalog", []):
			if item.id == id: item_name = item.name
		var claim: Button = Action.instantiate()
		claim.text = "%s 받기 · %d원" % [item_name, fee]
		claim.disabled = mailbox_button.disabled or int(snapshot.get("money", 0)) < fee
		claim.focus_mode = Control.FOCUS_NONE if office_screen.visible else Control.FOCUS_ALL
		claim.pressed.connect(func(): office_action_requested.emit("claim_parcel", id, {}))
		mailbox_items.add_child(claim)
	if not parcels.is_empty() and int(snapshot.get("money", 0)) < fee:
		mailbox_items.add_child(label("소지금이 부족해요. 장비는 계속 보관돼요."))

func focus_initial() -> void:
	if office_screen.visible: office_screen.focus_action()
	else: work_button.grab_focus()

func show_result(before: Dictionary, after: Dictionary) -> void:
	office_screen.visible=false
	office_button.disabled=true
	var day: String = ["월", "화", "수", "목", "금"][clampi(int(before.get("day", 0)), 0, 4)]
	var earned := int(after.get("money", 0)) - int(before.get("money", 0))
	var spent := int(before.get("stamina", 0)) - int(after.get("stamina", 0))
	guide.text = "오늘도 수고했어요."
	money_chip.get_node("Value").text = "소지금 · %d원" % int(after.get("money", 0))
	stamina_chip.get_node("Value").text = "체력 · %d / 100" % int(after.get("stamina", 0))
	outcome = "%s요일 수입  %+d원 · 체력  -%d" % [day, earned, spent]
	result_label.text = outcome
	result_label.visible = true
	work_button.disabled = true
	work_button.text = "오늘도 수고했어요"
	fit.call_deferred()

func fit() -> void:
	if dock == null:
		return
	var metrics = preload("res://ui/ui_metrics.gd")
	metrics.apply(header, size.x <= 960)
	metrics.apply(dock, size.x <= 960)
	var narrow := size.x < 760
	var margin := 20.0 if narrow else 36.0
	var day: String = ["월", "화", "수", "목", "금"][clampi(int(snapshot.get("day", 0)), 0, 4)]
	title.text = "주말을 기다리는\n%s요일" % day if narrow else "주말을 기다리는 %s요일" % day
	header.position = Vector2(margin, margin)
	header.size = Vector2(size.x - margin * 2, 0)
	var width := minf(520, size.x - margin * 2)
	dock.custom_minimum_size.x = width
	dock.size = Vector2(width, 0)
	dock.position = Vector2(floorf((size.x - width) / 2), maxf(header.position.y + header.size.y + 24, size.y - dock.size.y - margin))
	var factor := maxf(size.x / ROOM.get_width(), size.y / ROOM.get_height())
	var source_size := size / factor
	var crop := AtlasTexture.new()
	crop.atlas = ROOM
	crop.region = Rect2((Vector2(ROOM.get_size()) - source_size) * Vector2(0.78 if narrow else 0.5, 0.5), source_size)
	scenery.texture = crop

func capture() -> void:
	apply_state({"week": 1, "day": 0, "money": 80, "stamina": 80, "character_id": "male"}, false, "", false)
	for frame in range(16):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var target := "/tmp/cp-first-week.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			target = argument.trim_prefix("--capture-output=")
	get_viewport().get_texture().get_image().save_png(target)
	print("Work screen capture: ", size)
	get_tree().quit()
