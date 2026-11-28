extends Control

signal action_requested(command: String, choice: String, extra: Dictionary)
signal reload_requested
signal effects_toggled(enabled: bool)
signal night_preview_toggled(enabled: bool)
signal installation_requested(id: String, point: Vector3, angle: int)
signal installation_cancelled
signal account_requested
const Assets = preload("res://ui/components/mvp_assets.gd")
const Catalog = preload("res://ui/components/character_catalog.gd")
const UiInput = preload("res://ui/ui_input.gd")
const Editor3D = preload("res://ui/components/camp_editor_3d.gd")
const Board = preload("res://ui/components/grid_board.gd")
const GearCard = preload("res://ui/components/camp_gear_card.gd")
const PackingItem = preload("res://ui/components/packing_item.gd")
const Paper = preload("res://ui/components/paper_panel.tscn")
const Action = preload("res://ui/components/action_button.tscn")
const Chip = preload("res://ui/components/hud_chip.tscn")
const Notice = preload("res://ui/components/notice.tscn")
const CampSleep = preload("res://ui/screens/camp_sleep.gd")
var state: Dictionary = {}
var locked := false
var purchase_dialog: ConfirmationDialog
var pending_purchase: Dictionary = {}
var sleep_scene: Control
var status_bar: PanelContainer
var status_row: HBoxContainer
var camp_menu: HBoxContainer
var options: MenuButton
var forecast_button: Button
var scenery_toggle: Button
var clothes_menu: PopupMenu
var details_dialog: AcceptDialog
var details: VBoxContainer
var details_mode := ""
var settlement_shown := false
var network_busy := false
var check_required := false
var signature := ""
var selected_item := ""
var item_rotated := false
var packing_rotation := 0
var field_rotation := 0
var placement_controls: HBoxContainer
var field_rotate: Button
var effects_button: Button
var night_button: Button
var viewing_scenery := false
var scenery_hint: Label
var preview_dirty := false
var installing := false
var placement_cancel: Button
var packing_confirm := false
var show_forecast := false
var elapsed := 0.0
var info: Label
var money: PanelContainer
var stamina: PanelContainer
var dock: PanelContainer
var scroll: ScrollContainer
var packing_footer: VBoxContainer
var content: VBoxContainer
var status: PanelContainer
var field_editor
var field_position := Vector3(4,0,3)
var field_initialized_for := ""
var field_coordinates: Array[SpinBox] = []
var field_height: OptionButton
var board: Control
var last_cursor := Vector2i.ZERO
var tools_button: Button
var tools_hidden := false
var placement_bar: VBoxContainer
var placement_message: Label
var placement_commit: Button
var placement_done: Button
var drop_pending := false
var placement_error := ""
var tick_label: Label
var selected_ids: Array = []
var action_buttons: Array[Button] = []
var gear_tray: PanelContainer
var gear_toggle: Button
var gear_scroll: ScrollContainer
var gear_cards: HBoxContainer
var gear_tray_open := true
var gear_signature := ""
var external_drag := false
var external_pointer := -2

func label(value: String, large: bool = false) -> Label:
	var node := Label.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", 32 if large else 16)
	return node

func _ready() -> void:
	UiInput.ensure()
	purchase_dialog = ConfirmationDialog.new()
	purchase_dialog.title = "장비 구매"
	purchase_dialog.ok_button_text = "구매 확정"
	purchase_dialog.cancel_button_text = "취소"
	purchase_dialog.confirmed.connect(func():
		if phase() == "equipment" and not pending_purchase.is_empty():
			act(pending_purchase.command, pending_purchase.id)
		pending_purchase.clear())
	purchase_dialog.canceled.connect(func(): pending_purchase.clear())
	add_child(purchase_dialog)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	status_bar = Paper.instantiate()
	status_bar.z_index = 22
	add_child(status_bar)
	status_row = HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 5)
	status_bar.add_child(status_row)
	camp_menu = HBoxContainer.new()
	camp_menu.z_index = 22
	camp_menu.add_theme_constant_override("separation", 4)
	add_child(camp_menu)
	options = MenuButton.new()
	options.text = "⋯"
	options.tooltip_text = "캠핑 메뉴"
	status_row.add_child(options)
	options.get_popup().id_pressed.connect(camp_option)
	options.about_to_popup.connect(refresh_options)
	clothes_menu = PopupMenu.new()
	clothes_menu.id_pressed.connect(func(id: int): act("set_clothes", ["auto", "basic", "rain"][id]))
	options.get_popup().add_child(clothes_menu)
	details_dialog = AcceptDialog.new()
	details_dialog.exclusive = true
	details_dialog.theme = preload("res://ui/theme/camping.tres")
	details_dialog.ok_button_text = "닫기"
	add_child(details_dialog)
	var details_scroll := ScrollContainer.new()
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_scroll.custom_minimum_size = Vector2(260, 180)
	details_dialog.add_child(details_scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.add_child(details)
	info = label("이번 주말은 캠핑")
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_color_override("font_color", Color("fff7df"))
	info.add_theme_color_override("font_shadow_color", Color("213428"))
	info.add_theme_constant_override("shadow_offset_x", 2)
	info.add_theme_constant_override("shadow_offset_y", 2)
	status_row.add_child(info)
	info.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var forecast := Action.instantiate()
	forecast_button = forecast
	forecast.custom_minimum_size.x = 80
	forecast.text = "예보"
	forecast.pressed.connect(func():
		show_forecast = not show_forecast
		update_placement_visibility()
		signature = ""
		render_body())
	add_child(forecast)
	forecast.hide()
	tools_button = Action.instantiate()
	tools_button.custom_minimum_size.x = 64
	tools_button.text = "도구"
	tools_button.visible = false
	tools_button.pressed.connect(func():
		tools_hidden = not tools_hidden
		show_forecast = false
		signature = ""
		render_body()
		update_placement_visibility())
	add_child(tools_button)
	tools_button.hide()
	effects_button=Action.instantiate()
	effects_button.text="효과"
	effects_button.custom_minimum_size.x=64
	effects_button.toggle_mode=true
	effects_button.button_pressed=true
	effects_button.tooltip_text="3D 광원·입자·그림자 켜기/끄기"
	effects_button.toggled.connect(func(value: bool): effects_toggled.emit(value))
	add_child(effects_button)
	effects_button.hide()
	night_button=Action.instantiate()
	night_button.text="낮"
	night_button.custom_minimum_size.x=56
	night_button.toggle_mode=true
	night_button.tooltip_text="낮/밤 미리보기 전환 · 게임 시간은 유지해요"
	night_button.toggled.connect(func(value: bool):
		night_button.text="밤" if value else "낮"
		night_preview_toggled.emit(value))
	add_child(night_button)
	night_button.hide()
	money = Chip.instantiate()
	stamina = Chip.instantiate()
	for chip in [money, stamina]:
		chip.custom_minimum_size = Vector2.ZERO
		chip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		status_row.add_child(chip)
	status_row.move_child(options, -1)
	var strip := StyleBoxFlat.new()
	strip.bg_color = Color("24362deb")
	strip.border_color = Color("8b634a")
	strip.set_border_width_all(2)
	strip.set_corner_radius_all(6)
	strip.content_margin_left = 9
	strip.content_margin_right = 5
	status_bar.add_theme_stylebox_override("panel", strip)
	options.custom_minimum_size = Vector2(36, 42)
	dock = Paper.instantiate()
	dock.custom_minimum_size.x = minf(700, size.x - 24)
	add_child(dock)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var dock_layout:=VBoxContainer.new()
	dock.add_child(dock_layout)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	dock_layout.add_child(scroll)
	packing_footer=VBoxContainer.new()
	packing_footer.visible=false
	dock_layout.add_child(packing_footer)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	placement_bar = VBoxContainer.new()
	add_child(placement_bar)
	placement_message = label("")
	placement_message.add_theme_color_override("font_color", Color("fff7df"))
	placement_message.add_theme_color_override("font_shadow_color", Color("213428"))
	placement_message.add_theme_constant_override("shadow_offset_x", 2)
	placement_message.add_theme_constant_override("shadow_offset_y", 2)
	placement_bar.add_child(placement_message)
	var placement_actions := HBoxContainer.new()
	placement_bar.add_child(placement_actions)
	placement_commit = Action.instantiate()
	placement_commit.text = "확정"
	placement_commit.visible = false
	placement_commit.theme_type_variation = "PrimaryButton"
	placement_commit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placement_commit.pressed.connect(commit_field)
	placement_actions.add_child(placement_commit)
	placement_cancel = Action.instantiate()
	placement_cancel.text = "취소"
	placement_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placement_cancel.pressed.connect(cancel_field)
	placement_actions.add_child(placement_cancel)
	placement_controls = HBoxContainer.new()

	placement_controls.add_theme_constant_override("separation",8)
	add_child(placement_controls)
	field_rotate = Action.instantiate()
	field_rotate.text = "회전 90°"
	field_rotate.custom_minimum_size = Vector2(112,56)
	field_rotate.pressed.connect(rotate_field)
	placement_controls.add_child(field_rotate)
	placement_done = Action.instantiate()
	placement_done.text = "배치 완료"
	placement_done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placement_done.pressed.connect(func(): act("setup_done"))
	placement_controls.add_child(placement_done)
	placement_done.custom_minimum_size = Vector2(144,56)
	scenery_hint=label("터치: 이동 · 의자에 앉기")
	scenery_hint.add_theme_color_override("font_color",Color("fff7df"))
	scenery_hint.add_theme_color_override("font_shadow_color",Color("213428"))
	scenery_hint.add_theme_constant_override("shadow_offset_x",2)
	scenery_hint.add_theme_constant_override("shadow_offset_y",2)
	scenery_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	scenery_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scenery_hint.visible=false
	add_child(scenery_hint)
	gear_tray=Paper.instantiate()
	add_child(gear_tray)
	var gear_layout := VBoxContainer.new()
	gear_tray.add_child(gear_layout)
	gear_toggle=Action.instantiate()
	gear_toggle.custom_minimum_size.y=44
	gear_toggle.pressed.connect(func():
		if preview_dirty or installing or drop_pending: return
		gear_tray_open=not gear_tray_open
		update_placement_visibility();fit.call_deferred())
	gear_layout.add_child(gear_toggle)
	gear_scroll=ScrollContainer.new()
	gear_scroll.follow_focus=true
	gear_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	gear_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	gear_scroll.custom_minimum_size.y=114
	gear_layout.add_child(gear_scroll)
	gear_cards=HBoxContainer.new()
	gear_cards.add_theme_constant_override("separation",8)
	gear_scroll.add_child(gear_cards)
	update_placement_visibility()
	resized.connect(func():
		if external_drag: cancel_field()
		fit())
	content.minimum_size_changed.connect(func(): fit.call_deferred())
	fit()

func phase() -> String:
	return state.get("phase", "")

func item_name(id: String) -> String:
	if id in state.get("gear_upgrades", []):
		return {"tent":"캠핑 텐트","stove":"새 버너·코펠","sleeping_bag":"누빔 침낭","chair":"캠핑 의자","table":"캠핑 테이블","lantern":"캠핑 랜턴"}.get(id, id)
	for item in state.get("item_catalog", []):
		if item.id == id:
			return item.name
	return id

func names(ids: Array) -> String:
	var values: Array[String] = []
	for id in ids:
		values.append(item_name(id))
	return ", ".join(values) if not values.is_empty() else "없음"

func act(command: String, choice: String = "", extra: Dictionary = {}) -> void:
	if locked or is_instance_valid(sleep_scene): return
	if command != "tick" and phase() == "setup" and (preview_dirty or installing or drop_pending): return
	if command == "sleep" and field_editor != null and field_editor.bag_inside_tent():
		sleep_scene = CampSleep.new()
		add_child(sleep_scene)
		sleep_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sleep_scene.play(state, field_editor)
		options.disabled = true
		for item in camp_menu.get_children(): item.disabled = true
		sleep_scene.finished.connect(func():
			sleep_scene.queue_free()
			sleep_scene = null
			options.disabled = false
			for item in camp_menu.get_children(): item.disabled = locked or not item.get_meta("available", true)
			action_requested.emit(command, choice, extra))
		return
	action_requested.emit(command, choice, extra)

func confirm_equipment(id: String, price: int, upgrade: bool) -> void:
	if locked or phase() != "equipment" or purchase_dialog.visible: return
	pending_purchase = {"id": id, "command": "upgrade_gear" if upgrade else "buy_item"}
	purchase_dialog.dialog_text = "%s\n%s %d원 · 보유 %d원" % [
		item_name(id), "교체" if upgrade else "구매", price, int(state.money)]
	purchase_dialog.popup_centered(Vector2i(mini(360, int(size.x)-24), 0))

func button(parent: Node, caption: String, command: String, choice: String = "", enabled: bool = true, primary: bool = false) -> Button:
	var node := Action.instantiate()
	node.text = caption
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.disabled = locked or not enabled
	node.set_meta("available", enabled)
	action_buttons.append(node)
	if primary:
		node.theme_type_variation = "PrimaryButton"
	if not command.is_empty(): node.pressed.connect(func(): act(command, choice))
	parent.add_child(node)
	return node

func note(text: String, severity: int = 0) -> void:
	var node := Notice.instantiate()
	node.message = text
	node.severity = severity
	content.add_child(node)

func apply_state(value: Dictionary, saving: bool, message: String, must_check: bool, request_busy: bool) -> void:
	if must_check and (preview_dirty or installing or drop_pending):
		external_drag=false;external_pointer=-2
		field_editor.end_drag(true)
		installation_cancelled.emit()
		preview_dirty=false
		installing=false
		drop_pending=false
		field_initialized_for=""
	if value.get("phase", "") != state.get("phase", ""):
		external_drag=false;external_pointer=-2
		packing_confirm=false
		if preview_dirty or installing:
			installation_cancelled.emit()
		preview_dirty=false
		installing=false
		drop_pending=false
	if value.get("phase", "") != "free" or must_check or not message.is_empty():
		viewing_scenery=false
	if state.get("phase", "") != "setup" and value.get("phase", "") == "setup":
		field_initialized_for = ""
		selected_item = ""
		gear_tray_open=true
		tools_hidden = true
	if value.get("phase", "") != phase():
		details_dialog.hide()
		settlement_shown = false
	state = value
	if must_check: tools_hidden = false
	update_placement_visibility()
	var saved_drop: Dictionary = state.get("field",{}).get(selected_item,{})
	var drop_matches := not saved_drop.is_empty() and Vector3(float(saved_drop.get("x",0)),float(saved_drop.get("y",0)),float(saved_drop.get("z",0))).is_equal_approx(field_position) and Editor3D.rotation_of(saved_drop) == field_rotation
	if drop_pending and not request_busy and (drop_matches or not message.is_empty() or phase() != "setup"):
		drop_pending = false
		installing = false
		preview_dirty = false
		installation_cancelled.emit()
		placement_error = message if not message.begins_with("서버 저장 완료") else ""
		field_initialized_for = ""
		if phase() == "setup": render_body()
	locked = saving or must_check
	network_busy = request_busy
	check_required = must_check
	money.get_node("Value").text = "● %d원" % int(state.get("money", 0))
	stamina.get_node("Value").text = "♥ %d/100" % int(state.get("stamina", 0))
	var camp := phase() in ["setup", "free", "cooking", "meal_ready", "sleep_required", "teardown", "return_pack"]
	var day := "일요일" if int(state.get("camp_day", 0)) == 1 else "토요일"
	info.text = "%d주 · %s" % [int(state.get("week", 1)), day if camp else ("정산" if phase() == "settlement" else "금요일")]
	info.tooltip_text = Assets.weather_name(Assets.current_weather(state))
	if phase() in ["packing", "return_pack"]:
		info.text = "%d주 · 남은 시간 %d초" % [int(state.get("week", 1)), int(ceil(float(state.get("pack_remaining_ms", 45000)) / 1000))]
	elif camp:
		var minute := int(state.get("camp_minute", 960))
		info.text += " %02d:%02d" % [(minute / 60) % 24, minute % 60]
	var structural := [phase(), state.get("owned"), state.get("gear_upgrades"), state.get("meal_owned"), state.get("cargo", {}).keys() if phase() in ["setup","packing","return_pack"] else null, state.get("field", {}).keys() if phase() in ["setup", "teardown"] else null, state.get("outfit"), state.get("outfit_auto"), state.get("pack_started"), state.get("cooking"), state.get("camp_day"), state.get("rested"), int(state.get("stamina", 100)) <= 20, state.get("parcel_box"), show_forecast, check_required]
	var next_signature := JSON.stringify(structural)
	if signature != next_signature:
		signature = next_signature
		render_body()
	if status != null:
		status.visible = saving or must_check or not message.is_empty()
		status.message = "진행을 저장하고 있어요." if saving else message
		status.severity = 1 if must_check or not message.is_empty() else 0
	for node in action_buttons:
		if is_instance_valid(node):
			node.disabled = locked or (phase() == "setup" and (preview_dirty or installing or drop_pending)) or not node.get_meta("available", true)
	placement_commit.disabled = locked or selected_item.is_empty() or installing or drop_pending
	placement_done.disabled = locked or drop_pending
	placement_message.text = message.split("  ·")[0] if phase() == "setup" and not message.is_empty() and not message.begins_with("서버 저장 완료") else "물건을 잡아 끌어서 놓으세요"
	placement_message.visible = not placement_message.text.is_empty()
	if field_editor != null:
		field_editor.interaction_locked = locked or drop_pending or installing
		field_editor.pending_item = selected_item if preview_dirty else ""
		field_editor.configure(state, selected_item if phase() == "setup" else "", field_position, field_rotation)
		update_placement_caption()
	if board != null:
		update_grid()
		board.interactive = not locked and (phase() == "setup" or state.get("pack_started", false))
	update_placement_visibility()
	if details_dialog.visible:
		render_details()
	if phase() == "settlement" and not settlement_shown and not check_required:
		settlement_shown = true
		open_details.call_deferred("settlement")
	fit.call_deferred()

func render_body() -> void:
	if content == null or state.is_empty():
		return
	var restore_grid_focus := board != null and board.has_focus()
	if board != null:
		last_cursor = board.cursor
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for child in camp_menu.get_children():
		camp_menu.remove_child(child)
		child.queue_free()
	for child in packing_footer.get_children():
		packing_footer.remove_child(child)
		child.queue_free()
	packing_footer.visible=phase() in ["packing","return_pack"] and not check_required and not show_forecast
	content.add_theme_constant_override("separation",8 if phase() in ["packing","return_pack"] else 12)
	board = null
	field_coordinates.clear()
	action_buttons.clear()
	tick_label = null
	status = Notice.instantiate()
	status.visible = false
	content.add_child(status)
	if check_required:
		var reload_button := Action.instantiate()
		reload_button.text = "저장 상태 다시 확인"
		reload_button.pressed.connect(func(): reload_requested.emit())
		content.add_child(reload_button)
	if show_forecast:
		content.add_child(label("날짜별 일기예보"))
		for day in state.get("weather", []):
			content.add_child(label("%d일 · %s요일 · %s" % [int(day.date), ["월", "화", "수", "목", "금", "토", "일"][int(day.day)], Assets.weather_name(day.weather)]))
		note("플레이 중에는 예보를 봐도 시간이 흘러요.")
		var close := Action.instantiate()
		close.text = "플레이로 돌아가기"
		close.pressed.connect(func(): show_forecast = false; signature = ""; render_body())
		content.add_child(close)
		fit.call_deferred()
		return
	match phase():
		"place":
			content.add_child(label("원하는 장소를 고르고 이번 방문의 이용료를 내요. 바로 떠날 수 있어요."))
			if not state.get("parcel_box", []).is_empty(): show_parcels()
			for id in ["lake", "pine"]:
				var picture := TextureRect.new()
				picture.texture = Assets.LAKE if id == "lake" else Assets.PINE
				picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				picture.custom_minimum_size.y = 140
				content.add_child(picture)
				var cost := 15 if id == "lake" else 30
				button(content, ("호숫가 · 8×6 자리" if id == "lake" else "소나무 숲 · 10×7 자리") + "\n%d원 · 선택 후 %d원" % [cost, int(state.money) - cost], "choose_place", id, int(state.money) >= cost)
		"equipment":
			var starter: Array = state.get("starter_pack", [])
			if not starter.is_empty() and int(state.get("week", 1)) == 1:
				content.add_child(label("무료 초보 꾸러미 · " + names(starter)))
			content.add_child(label("장비를 새로 사지 않아도 준비를 계속할 수 있어요."))
			if not state.get("parcel_box", []).is_empty(): show_parcels()
			var items := GridContainer.new()
			items.columns = 2
			items.add_theme_constant_override("h_separation", 8)
			items.add_theme_constant_override("v_separation", 8)
			content.add_child(items)
			for item in state.item_catalog:
				if item.id in ["meal", "rainwear"]:
					continue
				var owned: bool = item.id in state.owned
				var waiting: bool = item.id in state.get("parcel_box", [])
				var upgrade_price := int(item.get("upgrade_price",0))
				var upgraded: bool = item.id in state.get("gear_upgrades", [])
				var can_upgrade: bool = owned and upgrade_price > 0 and not upgraded
				var subtitle := "보유 중" if owned else "택배함" if waiting else "%d원" % item.price
				if can_upgrade: subtitle = "새 장비로 교체 · %d원" % upgrade_price
				if upgraded: subtitle = "✓ 교체 완료"
				var can_buy: bool = not owned and not waiting and int(state.money) >= int(item.price)
				var purchase := button(items, item_name(item.id) + "\n" + subtitle,
					"", "", can_buy or (can_upgrade and int(state.money) >= upgrade_price))
				var price := upgrade_price if can_upgrade else int(item.price)
				purchase.pressed.connect(confirm_equipment.bind(str(item.id), price, can_upgrade))
				purchase.icon = Assets.item_texture(item.id, upgraded or can_upgrade)
				purchase.expand_icon = true
				purchase.add_theme_constant_override("icon_max_width", 44)
				purchase.custom_minimum_size = Vector2(0, 80)
			button(content, "음식과 옷 준비하기  →", "shop_done", "", true, true)
		"prepare":
			content.add_child(label("이번 주말 예보"))
			for index in [5, 6]:
				var forecast: Dictionary = state.weather[index]
				content.add_child(label("%d일 · %s · %s" % [int(forecast.date), "토요일" if index == 5 else "일요일", Assets.weather_name(forecast.weather)]))
			content.add_child(label("캠핑복을 입고 출발해요. 방수 겉옷은 짐 싸기에서 1칸에 실어요. 자동 착용을 켜면 비 오는 날에 실어 온 겉옷을 입어요."))
			button(content, ("✓ " if state.get("outfit_auto", false) else "") + "날씨에 맞춰 자동 착용", "set_clothes", "auto")
			var wardrobe := HBoxContainer.new()
			content.add_child(wardrobe)
			for outfit in ["basic", "rain"]:
				var column := VBoxContainer.new()
				column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				wardrobe.add_child(column)
				var portrait := TextureRect.new()
				portrait.texture = Catalog.frames(state.get("character_id", "female"), outfit).get_frame_texture("idle", 0)
				portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				portrait.custom_minimum_size.y = 120
				column.add_child(portrait)
				button(column, ("✓ " if not state.get("outfit_auto", false) and state.outfit == outfit else "") + ("캠핑복" if outfit == "basic" else "방수 겉옷"), "set_clothes", outfit)
			var meal_price := 5
			for item in state.item_catalog:
				if item.id == "meal": meal_price = int(item.price)
			button(content, "✓ 라면 준비 완료" if state.meal_owned else "라면 한 끼 준비 · %d원" % meal_price, "buy_meal", "", not state.meal_owned and int(state.money) >= meal_price)
			if not state.meal_owned:
				note("음식 없이도 출발할 수 있어요. 캠핑 중 먹을 음식이 없다는 점을 기억해요.", 1)
			button(content, "짐 싸러 가기  →", "prepare_done", "", true, true)
		"packing", "return_pack":
			build_grid()
		"setup":
			build_field_3d()
		"free":
			if not Assets.suitable(state):
				note("옷이 날씨에 맞지 않아요.", 1)
			if int(state.stamina) <= 20:
				note("체력이 얼마 남지 않았어요.", 1)
			camp_button("배치", "edit_camp")
			var can_cook: bool = state.meal_owned and state.cargo.has("meal") and state.field.has("stove")
			var cook_button := camp_button("요리", "cook_begin", can_cook)
			cook_button.tooltip_text = "재료와 설치한 버너가 필요해요." if not can_cook else "요리 시작"
			scenery_toggle = camp_button("감상", "")
			scenery_toggle.pressed.connect(func():
				if viewing_scenery: end_scenery()
				else: begin_scenery())
			if int(state.camp_day) == 0:
				camp_button("잠자기", "sleep", true, true)
			else:
				camp_button("귀가", "leave_camp", true, true)
		"cooking":
			content.add_child(label("버너 앞에서 라면을 끓여요.\n%d / 3 단계" % int(state.cooking)))
			var illustration := TextureRect.new()
			illustration.texture = Assets.item_texture("stove", "stove" in state.get("gear_upgrades", []))
			illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			illustration.custom_minimum_size.y = 140
			content.add_child(illustration)
			button(content, ["물 올리기", "면과 수프 넣기", "저어서 완성하기"][clampi(int(state.cooking), 0, 2)], "cook", "", true, true)
		"meal_ready":
			content.add_child(label("따뜻한 한 끼가 완성됐어요.\n먹으면 음식이 소모되고 체력을 회복해요."))
			button(content, "맛있게 먹기  →", "eat", "", true, true)
		"sleep_required":
			note("체력이 바닥났어요. 오늘은 잠들어 회복해요.", 1)
			button(content, "푹 자고 일요일 맞기", "sleep", "", true, true)
		"teardown":
			content.add_child(label("설치한 장비를 하나씩 철거해요. 체력이 없어도 정리는 할 수 있어요."))
			var field_items: Array = state.field.keys()
			if field_items.has("sleeping_bag"):
				field_items.erase("sleeping_bag")
				field_items.push_front("sleeping_bag")
			for id in field_items:
				var blocked: bool = id == "tent" and field_items.has("sleeping_bag") and field_editor != null and field_editor.bag_inside_tent()
				button(content, "침낭을 먼저 접어 주세요" if blocked else item_name(id) + " 철거하기", "take_down", id, not blocked)
			button(content, "귀가 짐 싸기  →", "teardown_done", "", state.field.is_empty(), true)
		"settlement":
			camp_button("정산", "").pressed.connect(open_details.bind("settlement"))
			camp_button("택배함", "").pressed.connect(open_details.bind("parcels"))
			camp_button("다음 주", "next_week", true, true)
	update_placement_visibility()
	if restore_grid_focus and board != null:
		restore_board_focus.call_deferred()
	fit.call_deferred()

func camp_button(caption: String, command: String, enabled := true, primary := false) -> Button:
	var node := button(camp_menu, caption, command, "", enabled, primary)
	node.custom_minimum_size = Vector2(0, 48)
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	return node

func refresh_clothes() -> void:
	var popup := clothes_menu
	popup.clear()
	for index in 3:
		popup.add_radio_check_item(["자동 착용", "캠핑복", "방수 겉옷"][index], index)
		var active: String = "auto" if state.get("outfit_auto", false) else state.get("outfit", "basic")
		popup.set_item_checked(index, ["auto", "basic", "rain"][index] == active)
	popup.set_item_disabled(2, state.get("weather_cargo", false) and not state.cargo.has("rainwear"))

func refresh_options() -> void:
	var popup := options.get_popup()
	popup.clear()
	popup.add_item("예보", 0)
	popup.add_check_item("효과", 1)
	popup.set_item_checked(popup.get_item_index(1), effects_button.button_pressed)
	popup.add_check_item("밤 미리보기", 2)
	popup.set_item_checked(popup.get_item_index(2), night_button.button_pressed)
	if phase() == "setup": popup.add_item(tools_button.text, 3)
	if phase() == "free":
		refresh_clothes()
		popup.add_submenu_node_item("옷 갈아입기", clothes_menu, 6)
	popup.add_item("집 택배함 · %d개" % state.get("parcel_box", []).size(), 4)
	if OS.has_feature("web"): popup.add_item("계정", 5)

func camp_option(id: int) -> void:
	match id:
		0: forecast_button.pressed.emit()
		1: effects_button.button_pressed = not effects_button.button_pressed
		2: night_button.button_pressed = not night_button.button_pressed
		3: tools_button.pressed.emit()
		4: open_details.call_deferred("parcels")
		5: account_requested.emit()

func show_parcels() -> void:
	var open := button(content, "집 택배함 · %d개" % state.get("parcel_box", []).size(), "")
	open.pressed.connect(open_details.bind("parcels"))

func open_details(mode: String) -> void:
	if not is_inside_tree() or (mode == "settlement" and phase() != "settlement"): return
	details_mode = mode
	render_details()
	if not details_dialog.visible:
		details_dialog.popup_centered(Vector2i(mini(390, int(size.x) - 24), 0))

func render_details() -> void:
	for child in details.get_children():
		if child is Button: action_buttons.erase(child)
		details.remove_child(child)
		child.queue_free()
	if details_mode == "settlement":
		details_dialog.title = "이번 주 정산"
		var metrics := HBoxContainer.new()
		details.add_child(metrics)
		for metric in [["↑ 수입", "+%d원" % int(state.week_income)], ["↓ 지출", "−%d원" % int(state.week_spent)], ["● 잔액", "%d원" % int(state.money)]]:
			var value := label(metric[0] + "\n" + metric[1])
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			metrics.add_child(value)
		var next := button(details, "다음 주 시작", "next_week", "", true, true)
		next.custom_minimum_size.x = 0
		var parcels := button(details, "택배함 · %d개" % state.get("parcel_box", []).size(), "")
		parcels.pressed.connect(open_details.bind("parcels"))
	else:
		details_dialog.title = "집 택배함"
		var parcels: Array = state.get("parcel_box", [])
		var fee := int(state.get("parcel_fee", 5))
		if parcels.is_empty(): details.add_child(label("받을 장비가 없어요."))
		for id in parcels:
			button(details, "%s 받기 · %d원" % [item_name(id), fee], "claim_parcel", id, int(state.money) >= fee)
		if not parcels.is_empty() and int(state.money) < fee:
			details.add_child(label("소지금이 부족해요."))
		if phase() == "settlement":
			button(details, "정산으로", "").pressed.connect(open_details.bind("settlement"))

func restore_board_focus() -> void:
	if is_instance_valid(board) and board.is_inside_tree(): board.grab_focus()

func use_field_editor(editor) -> void:
	field_editor = editor
	field_editor.item_selected.connect(func(id: String):
		if phase() != "setup" or preview_dirty or installing or drop_pending: return
		selected_item = id
		placement_error = ""
		field_initialized_for = ""
		tools_hidden = true
		update_placement_visibility()
		render_body()
		update_placement_caption())
	field_editor.drag_state_changed.connect(update_placement_caption)
	field_editor.position_changed.connect(func(point: Vector3):
		field_position = point
		tools_hidden = true
		update_placement_visibility()
		if field_coordinates.size() == 2:
			field_coordinates[0].set_value_no_signal(point.x)
			field_coordinates[1].set_value_no_signal(point.z)
		if is_instance_valid(field_height): field_height.select(1 if point.y > .1 else 0)
		field_editor.configure(state,selected_item,field_position,field_rotation)
		update_placement_caption())

	field_editor.placement_rejected.connect(func(reason: String):
		placement_error = reason
		update_placement_caption())

	field_editor.item_dropped.connect(func(id: String, point: Vector3):
		if phase() != "setup" or locked: return
		selected_item = id
		field_position = point
		preview_dirty = true
		field_initialized_for = selected_item
		field_editor.pending_item = selected_item
		placement_error = ""
		update_placement_visibility()
		update_placement_caption())

func refresh_gear_tray() -> void:
	if gear_tray == null: return
	var ids: Array=[]
	for id in state.get("cargo",{}):
		if id not in ["meal","rainwear"] and not state.get("field",{}).has(id): ids.append(id)
	var key := JSON.stringify([ids,state.get("gear_upgrades",[])])
	if key != gear_signature:
		gear_signature=key
		for child in gear_cards.get_children():
			gear_cards.remove_child(child);child.queue_free()
		for id in ids:
			var card := GearCard.new()
			card.item_id=id;card.caption=item_name(id);card.upgraded=id in state.get("gear_upgrades",[])
			card.activated.connect(choose_gear)
			card.drag_requested.connect(begin_gear_drag)
			card.scrolled.connect(func(pixels: float): gear_scroll.scroll_horizontal-=int(pixels))
			gear_cards.add_child(card)
	gear_toggle.text="가져온 짐 · 모두 설치됨" if ids.is_empty() else "가져온 짐 · %d개  %s"%[ids.size(),"접기" if gear_tray_open else "펼치기"]
	gear_toggle.disabled=locked or preview_dirty or installing or drop_pending or ids.is_empty()
	for card in gear_cards.get_children():
		card.disabled=locked or preview_dirty or installing or drop_pending
		card.queue_redraw()

func choose_gear(id: String) -> void:
	if phase() != "setup" or locked or preview_dirty or installing or drop_pending or field_editor == null: return
	selected_item=id
	field_initialized_for=id
	field_rotation=0
	field_position=Vector3(field_editor.site_width/2,0,field_editor.site_depth/2)
	if id == "sleeping_bag" and state.get("field",{}).has("tent"):
		var tent: Dictionary=state.field.tent
		field_position=Vector3(float(tent.x),0,float(tent.z))
	field_editor.configure(state,id,field_position,field_rotation)
	if not field_editor.validation_reason(id,field_position).is_empty():
		var distance := INF
		var center: Vector3=field_position
		for x in range(1,int(field_editor.site_width*2)):
			for z in range(1,int(field_editor.site_depth*2)):
				var point := Vector3(x*.5,0,z*.5)
				if point.distance_squared_to(center)<distance and field_editor.validation_reason(id,point).is_empty():
					field_position=point;distance=point.distance_squared_to(center)
	preview_dirty=true
	gear_tray_open=false
	tools_hidden=true
	placement_error=""
	field_editor.pending_item=id
	field_editor.configure(state,id,field_position,field_rotation)
	update_placement_visibility();update_placement_caption()

func begin_gear_drag(id: String, point: Vector2, pointer: int) -> void:
	choose_gear(id)
	if not preview_dirty or selected_item!=id or installing or drop_pending: return
	external_drag=true;external_pointer=pointer
	field_editor.grab_focus()
	field_editor.begin_external_drag(field_editor.get_global_transform().affine_inverse()*point,pointer)
	update_placement_visibility()

func update_placement_visibility() -> void:
	if dock == null or placement_bar == null: return
	var placing := phase() == "setup"
	if gear_tray != null:
		gear_tray.visible=placing and not show_forecast and not external_drag
		gear_scroll.visible=gear_tray_open and gear_cards.get_child_count()>0
		refresh_gear_tray()
	var compact_dock := phase() in ["free", "settlement"]
	var has_notice := phase() == "free" and (not Assets.suitable(state) or int(state.get("stamina", 100)) <= 20 or (is_instance_valid(status) and status.visible))
	dock.visible = show_forecast or (not viewing_scenery and (check_required or (not compact_dock and (not placing or not tools_hidden)) or has_notice))
	camp_menu.visible = compact_dock and not show_forecast and not check_required
	if is_instance_valid(scenery_toggle):
		scenery_toggle.text = "감상 종료" if viewing_scenery else "감상"
	if scenery_hint != null: scenery_hint.visible=viewing_scenery
	placement_commit.visible = placing and preview_dirty
	placement_cancel.visible = placing and (preview_dirty or installing)
	placement_bar.visible = placing and tools_hidden and not show_forecast and not external_drag
	placement_controls.visible = placement_bar.visible
	placement_done.visible = placement_bar.visible
	tools_button.text = "장비" if tools_hidden else "닫기"

func begin_scenery() -> void:
	if locked or phase() != "free": return
	show_forecast=false
	viewing_scenery=true
	get_viewport().gui_release_focus()
	update_placement_visibility()
	if not state.get("rested",false): act("rest")

func end_scenery() -> void:
	viewing_scenery=false
	update_placement_visibility()

func _input(event: InputEvent) -> void:
	if external_drag:
		var moving: bool=(event is InputEventMouseMotion and external_pointer==-1) or (event is InputEventScreenDrag and event.index==external_pointer)
		var released: bool=(event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and external_pointer==-1) or (event is InputEventScreenTouch and not event.pressed and event.index==external_pointer)
		if moving:
			field_editor.move_drag(field_editor.get_global_transform().affine_inverse()*event.position)
			get_viewport().set_input_as_handled();return
		if released:
			external_drag=false;external_pointer=-2
			if event is InputEventScreenTouch and event.canceled:
				cancel_field()
				get_viewport().set_input_as_handled();return
			field_editor.end_drag(false)
			update_placement_visibility();update_placement_caption()
			get_viewport().set_input_as_handled();return
	if not viewing_scenery: return
	var key: bool = event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE,KEY_BACK]
	var pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B
	if key or pad:
		end_scenery()
		get_viewport().set_input_as_handled()

func update_placement_caption() -> void:
	if phase() != "setup" or field_editor == null: return
	field_editor.set_installation_preview(preview_dirty or installing or field_editor.dragging_item, installing)
	placement_done.disabled = locked or preview_dirty or installing or drop_pending or field_editor.dragging_item
	field_rotate.visible = not selected_item.is_empty()
	field_rotate.disabled = locked or installing or drop_pending or field_editor.dragging_item or selected_item.is_empty()
	placement_commit.visible = preview_dirty
	placement_commit.disabled = locked or installing or drop_pending or field_editor.dragging_item or not field_editor.placement_reason.is_empty()
	placement_cancel.visible = preview_dirty or installing
	placement_cancel.disabled = drop_pending or check_required
	var reason: String = placement_error if not placement_error.is_empty() else field_editor.placement_reason
	var hint := "저장 중…" if drop_pending else "캐릭터가 이동해 설치 중이에요" if installing else "확정하면 캐릭터가 와서 설치해요 · 취소 가능" if preview_dirty else "끌어서 위치를 정해 주세요" if reason.is_empty() else reason
	var position_type := "테이블 위 가능" if field_editor.support_info(selected_item).get("can_place_on_table", false) else "바닥 전용"
	placement_message.text = "아래 가져온 짐에서 장비를 골라 끌어 놓으세요" if selected_item.is_empty() else "%s · %s\n%s" % [item_name(selected_item),position_type,hint]

	fit.call_deferred()

func update_placement_action_position() -> void:
	if field_editor == null or placement_done == null or not placement_done.visible: return
	placement_controls.size = placement_controls.get_combined_minimum_size()
	var height := maxf(12, placement_bar.position.y - placement_controls.size.y - 12)
	placement_controls.position = Vector2((size.x-placement_controls.size.x)/2,height)

func rotate_field() -> void:
	if phase() != "setup" or locked or drop_pending or field_editor == null or field_editor.dragging_item or selected_item.is_empty(): return
	var previous := field_rotation
	field_rotation = (field_rotation+90)%360
	field_editor.configure(state,selected_item,field_position,field_rotation)
	var reason: String = field_editor.validation_reason(selected_item,field_position)
	if not reason.is_empty():
		field_rotation = previous
		field_editor.configure(state,selected_item,field_position,field_rotation)
		placement_error = reason + " · 위치를 옮긴 뒤 회전해 주세요"
		update_placement_caption()
		return
	placement_error = ""
	preview_dirty = true
	field_initialized_for = selected_item
	field_editor.pending_item = selected_item
	update_placement_visibility()
	update_placement_caption()

func _unhandled_input(event: InputEvent) -> void:
	if phase() != "setup": return
	var cancel_key: bool = event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
	var cancel_pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B
	if (cancel_key or cancel_pad) and (preview_dirty or installing):
		cancel_field()
		get_viewport().set_input_as_handled()
		return
	var rotate_key: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R
	var rotate_pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y
	if rotate_key or rotate_pad:
		rotate_field()
		get_viewport().set_input_as_handled()

func commit_field() -> void:
	if selected_item.is_empty() or locked or drop_pending or installing or not preview_dirty: return
	var reason: String = field_editor.validation_reason(selected_item,field_position)
	if not reason.is_empty():
		placement_error=reason
		update_placement_caption()
		return
	installing = true
	field_editor.interaction_locked = true
	tools_hidden = true
	update_placement_visibility()
	update_placement_caption()
	installation_requested.emit(selected_item,field_position,field_rotation)

func save_installation() -> void:
	if not installing or drop_pending or phase() != "setup" or check_required: return
	drop_pending = true
	update_placement_caption()
	# Only the finished animation issues one mutation; preview and cancellation never save.
	action_requested.emit("place_item",selected_item,{"x":field_position.x,"y":field_position.z,"z":field_position.y,"rotated":field_rotation%180!=0,"rotation_degrees":field_rotation,"coordinate_system":"z_up"})

func install_failed(reason: String) -> void:
	installing=false
	field_editor.interaction_locked=false
	placement_error=reason
	update_placement_caption()

func cancel_field() -> void:
	if drop_pending or check_required: return
	external_drag=false;external_pointer=-2
	field_editor.end_drag(true)
	installation_cancelled.emit()
	installing=false
	preview_dirty=false
	placement_error=""
	field_initialized_for=""
	field_editor.interaction_locked=locked
	field_editor.pending_item=""
	if state.get("field",{}).has(selected_item):
		build_field_position()
	else:
		selected_item="";field_initialized_for="";gear_tray_open=true
	field_editor.configure(state,selected_item,field_position,field_rotation)
	update_placement_visibility()
	update_placement_caption()

func build_field_position() -> void:
	if state.get("field",{}).has(selected_item):
		var p: Dictionary=state.field[selected_item]
		field_position=Vector3(float(p.x),float(p.y),float(p.z))
		field_rotation=Editor3D.rotation_of(p)
	else:
		var index := maxi(0,selected_ids.find(selected_item))
		field_position=field_editor.staging_position(index)
		field_rotation=0
	field_initialized_for=selected_item

func build_field_3d() -> void:
	selected_ids = state.cargo.keys()
	selected_ids.erase("meal")
	selected_ids.erase("rainwear")
	if not selected_item in selected_ids:
		selected_item = ""
	if field_initialized_for != selected_item:
		field_initialized_for = selected_item
		if state.field.has(selected_item):
			var p: Dictionary = state.field[selected_item]
			field_position = Vector3(float(p.x),float(p.y),float(p.z))
			field_rotation = Editor3D.rotation_of(p)
		else:
			var index := maxi(0,selected_ids.find(selected_item))
			field_position = field_editor.staging_position(index) if field_editor != null else Vector3(1.25+(index%3)*2.25,0,(2.3 if state.place == "pine" else 1.0)+(index/3)*2.3)
			field_rotation = 0
	if field_editor != null:
		field_editor.configure(state,selected_item,field_position,field_rotation)
	content.add_child(label("가져온 짐에서 하나를 골라 끌어 놓고 확정하면 캐릭터가 와서 설치해요."))
	content.add_child(label("선택한 장비 · " + item_name(selected_item)))
	var tent_has_bag: bool = selected_item == "tent" and field_editor != null and field_editor.bag_inside_tent()
	button(content, "침낭을 먼저 접어 주세요" if tent_has_bag else "선택한 장비를 차로", "remove_item", selected_item, state.field.has(selected_item) and not tent_has_bag)

func build_grid() -> void:
	var field := phase() == "setup"
	var returning := phase() == "return_pack"
	selected_ids = state.cargo.keys() if field else state.get("return_candidates", []) if returning else state.owned.duplicate()
	if not field and not returning:
		if state.meal_owned: selected_ids.append("meal")
		if state.get("weather_cargo", false) and not "rainwear" in state.get("parcel_box", []):
			selected_ids.append("rainwear")
	if field:
		selected_ids.erase("meal")
		selected_ids.erase("rainwear")
	if not selected_item in selected_ids:
		selected_item = selected_ids[0] if not selected_ids.is_empty() else ""
	if returning:
		content.add_child(label("못 실은 장비는 집 택배함으로 보내요. 받을 때 개당 %d원이에요." % int(state.get("parcel_fee", 5))))
	elif field:
		content.add_child(label("원하는 장비만 놓아요. 물건을 고르고 격자의 시작 칸을 눌러요."))
		if not state.get("packing_result", []).is_empty():
			content.add_child(label("집에 보관한 물건: " + names(state.packing_result)))
	else:
		content.add_child(label("미적재품은 집에 남아요."))
	if not field and not state.pack_started:
		button(content, "45초 짐 싸기 시작", "start_pack", "", true, true)
	var controls := HBoxContainer.new()
	content.add_child(controls)
	var selected_label:=label("선택: "+item_name(selected_item))
	selected_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	controls.add_child(selected_label)
	var rotate := Action.instantiate()
	rotate.custom_minimum_size.x = 80
	rotate.text = "회전 ↻"
	rotate.pressed.connect(rotate_packing_item)
	controls.add_child(rotate)
	var tray:=preload("res://ui/components/packing_tray.gd").new()
	tray.add_theme_constant_override("h_separation",6)
	tray.add_theme_constant_override("v_separation",6)
	tray.packed_ids=state.cargo.keys()
	tray.interactive=not locked and state.get("pack_started",false)
	tray.item_unpacked.connect(func(id: String): act("remove_item",id))
	content.add_child(tray)
	for id in selected_ids:
		var card:=PackingItem.new()
		card.item_id=id
		card.upgraded=id in state.get("gear_upgrades", [])
		card.item_rotated=state.cargo.get(id,{}).get("rotated",false)
		card.packing_angle=Board.angle_of(state.cargo.get(id,{}))
		card.can_drag=state.get("pack_started",false)
		card.caption=item_name(id)
		card.packed=state.cargo.has(id)
		card.tooltip_text=item_name(id)+(" · 적재됨, 끌어서 옮기거나 빼세요" if card.packed else " · 끌어서 적재하세요")
		for item in state.item_catalog:
			if item.id==id: card.footprint_cells=item.cells
		card.custom_minimum_size=Vector2(76,104)
		card.disabled=locked
		action_buttons.append(card)
		card.pressed.connect(func():
			selected_item=card.item_id
			item_rotated=card.item_rotated
			packing_rotation=card.packing_angle
			selected_label.text="선택: "+item_name(selected_item)
			update_grid()
			if board != null: board.grab_focus())
		tray.add_child(card)
	var viewport := ScrollContainer.new()
	viewport.custom_minimum_size.y = (6 if field else 5) * 48 + 14
	viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(viewport)
	board = Board.new()
	board.upgraded_ids = state.get("gear_upgrades", [])
	board.cursor = last_cursor
	board.cell_activated.connect(func(x: int, y: int): act("place_item", selected_item, {"x":x, "y":y, "rotated":item_rotated,"rotation_degrees":packing_rotation}))
	board.item_selected.connect(func(id: String):
		selected_item=id
		item_rotated=state.cargo.get(id,{}).get("rotated",false)
		packing_rotation=Board.angle_of(state.cargo.get(id,{}))
		selected_label.text="선택: "+item_name(id))
	board.item_dropped.connect(func(id: String,x: int,y: int,rotation: int):
		selected_item=id
		packing_rotation=rotation
		item_rotated=rotation%180!=0
		act("place_item",id,{"x":x,"y":y,"rotated":item_rotated,"rotation_degrees":rotation}))
	board.rotate_requested.connect(rotate_packing_item)
	viewport.add_child(board)
	update_grid()
	board.tooltip_text="그림을 끌어 싣기 · 목록으로 빼기 · R / 패드 Y 회전"
	var remove := Action.instantiate()
	remove.text = "빼기"
	remove.custom_minimum_size.x=64
	remove.disabled = locked or selected_item.is_empty()
	remove.pressed.connect(func(): act("remove_item", selected_item))
	controls.add_child(remove)
	if field:
		button(content, "이대로 캠핑 즐기기  →", "setup_done", "", true, true)
	elif state.get("pack_started",false):
		var missed:=selected_ids.filter(func(id): return not state.cargo.has(id))
		if returning and packing_confirm and not missed.is_empty():
			var mailed := missed.filter(func(id): return id != "meal")
			if not mailed.is_empty():
				packing_footer.add_child(label("착불 택배 · %s · 총 %d원" % [names(mailed), mailed.size() * int(state.get("parcel_fee", 5))]))
			if missed.has("meal"): packing_footer.add_child(label("남은 식재료는 현장에 두고 가요."))
			var cancel:=button(packing_footer,"계속 짐싸기","")
			cancel.pressed.connect(func(): packing_confirm=false; render_body())
			var confirm:=button(packing_footer,"확인하고 귀가하기", "", "", true, true)
			confirm.pressed.connect(func(): act("finish_pack","",{"confirm_mail":true}))
		else:
			var finish:=button(packing_footer,"귀가하기  →" if returning else "출발하기  →", "", "", true, true)
			finish.pressed.connect(func():
				if returning and not missed.is_empty():
					packing_confirm=true
					render_body()
				else: act("finish_pack"))

func update_grid() -> void:
	if board == null:
		return
	var field := phase() == "setup"
	var pine: bool = state.get("place", "") == "pine"
	board.configure((10 if pine else 8) if field else 6, (7 if pine else 6) if field else 5, state.item_catalog, state.field if field else state.cargo, selected_item, item_rotated, field and pine)
	board.packing_angle=packing_rotation
	board.interactive = not locked and (field or state.get("pack_started", false))

func rotate_packing_item() -> void:
	if locked: return
	packing_rotation=(packing_rotation+90)%360
	item_rotated=packing_rotation%180!=0
	if get_viewport().gui_is_dragging():
		var drag_data: Variant=get_viewport().gui_get_drag_data()
		if drag_data is Dictionary and drag_data.get("packing_item","")==selected_item:
			drag_data.rotation_degrees=packing_rotation
			drag_data.rotated=item_rotated
	for card in action_buttons:
		if is_instance_valid(card) and card is PackingItem and card.item_id==selected_item:
			card.item_rotated=item_rotated
			card.packing_angle=packing_rotation
			card.queue_redraw()
	update_grid()

func fit() -> void:
	if dock == null:
		return
	preload("res://ui/ui_metrics.gd").apply(dock, size.x <= 960)
	for node in [info, money.get_node("Value"), stamina.get_node("Value")]:
		node.add_theme_font_size_override("font_size", 15 if size.x < 400 else 18)
		node.add_theme_color_override("font_color", Color("fff2d9"))
		node.add_theme_color_override("font_outline_color", Color("192922"))
		node.add_theme_constant_override("outline_size", 2)
	var margin := 12.0 if size.x < 760 else 28.0
	var tray_height := 0.0
	if gear_tray != null and gear_tray.visible:
		var tray_width := minf(720,size.x-margin*2)
		gear_tray.custom_minimum_size.x=tray_width
		gear_tray.size=Vector2(tray_width,0)
		gear_tray.size.y=gear_tray.get_combined_minimum_size().y
		gear_tray.position=Vector2((size.x-tray_width)/2,size.y-margin-gear_tray.size.y)
		tray_height=gear_tray.size.y+8
	placement_bar.size = Vector2(minf(460, size.x - margin * 2), 0)
	placement_bar.position = Vector2((size.x - placement_bar.size.x) / 2, size.y - placement_bar.size.y - margin-tray_height)
	update_placement_action_position()
	status_bar.position = Vector2(margin, margin)
	status_bar.size = Vector2(size.x - margin * 2, 42)
	var menu_width := minf(560, size.x - margin * 2)
	camp_menu.size = Vector2(menu_width, 48)
	camp_menu.position = Vector2((size.x - menu_width) * .5, size.y - camp_menu.size.y - margin)
	for item in camp_menu.get_children():
		item.add_theme_font_size_override("font_size", 16 if size.x < 430 else 19)
	if scenery_hint != null:
		scenery_hint.position=Vector2(margin,camp_menu.position.y-42)
		scenery_hint.size=Vector2(size.x-margin*2,40)
	var width := minf(700, size.x - margin * 2)
	dock.custom_minimum_size.x = width
	var available := maxf(160, size.y - status_bar.position.y - status_bar.size.y - margin * 2 - 16)
	var desired: float = content.get_combined_minimum_size().y + (packing_footer.get_combined_minimum_size().y+8 if packing_footer.visible else 0) + 40
	var compact_notice := phase() == "free" and not show_forecast and not check_required
	dock.size = Vector2(width, minf(available, desired if compact_notice else maxf(120, desired)))
	var dock_bottom := camp_menu.position.y - 6 if compact_notice else size.y - margin
	dock.position = Vector2(floorf((size.x - width) / 2), dock_bottom - dock.size.y)

func _process(delta: float) -> void:
	if state.is_empty() or is_instance_valid(sleep_scene):
		return
	var active := not bool(JavaScriptBridge.eval("document.hidden")) if OS.has_feature("web") else DisplayServer.window_is_focused()
	if not active or check_required:
		elapsed = 0
		return
	if phase() in ["packing", "return_pack"] and not state.get("pack_started", false):
		elapsed = 0
		return
	if phase() in ["setup", "free", "cooking", "meal_ready", "teardown", "packing", "return_pack"]:
		elapsed = minf(2.0, elapsed + delta)
		if elapsed >= 1.0 and not network_busy and not locked:
			var duration := mini(2000, int(elapsed * 1000))
			elapsed = 0
			action_requested.emit("tick", "", {"elapsed_ms":duration})

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and external_drag:
		cancel_field()
