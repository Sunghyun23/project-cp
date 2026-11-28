extends Control

signal action_requested(command: String, choice: String, extra: Dictionary)
signal reload_requested
signal effects_toggled(enabled: bool)
signal night_preview_toggled(enabled: bool)
signal account_requested
const Assets = preload("res://ui/components/mvp_assets.gd")
const Catalog = preload("res://ui/components/character_catalog.gd")
const UiInput = preload("res://ui/ui_input.gd")
const Editor3D = preload("res://ui/components/camp_editor_3d.gd")
const Board = preload("res://ui/components/grid_board.gd")
const PackingItem = preload("res://ui/components/packing_item.gd")
const Paper = preload("res://ui/components/paper_panel.tscn")
const Action = preload("res://ui/components/action_button.tscn")
const Chip = preload("res://ui/components/hud_chip.tscn")
const Notice = preload("res://ui/components/notice.tscn")
const TITLES = {"place":"이번엔 어디로 떠날까요?", "equipment":"나만의 캠핑 장비", "prepare":"날씨에 맞춰 준비해요", "packing":"주말을 트렁크에 담아요", "setup":"나만의 캠프를 펼쳐요", "free":"여유로운 캠핑 시간", "cooking":"보글보글, 따뜻한 한 끼", "meal_ready":"밖에서 먹으면 더 맛있죠", "sleep_required":"오늘은 푹 쉬어가요", "teardown":"머문 자리를 정리해요", "return_pack":"다시 차곡차곡, 집으로", "settlement":"이번 주말도 잘 쉬었어요"}
var state: Dictionary = {}
var locked := false
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
var packing_confirm := false
var show_forecast := false
var elapsed := 0.0
var toolbar: HBoxContainer
var header: VBoxContainer
var title: Label
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

func label(value: String, large: bool = false) -> Label:
	var node := Label.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", 32 if large else 16)
	return node

func _ready() -> void:
	UiInput.ensure()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header = VBoxContainer.new()
	header.size.x = size.x - 40
	header.add_theme_constant_override("separation", 8)
	add_child(header)
	var top := HBoxContainer.new()
	toolbar = top
	header.add_child(top)
	info = label("이번 주말은 캠핑")
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_color_override("font_color", Color("fff7df"))
	info.add_theme_color_override("font_shadow_color", Color("213428"))
	info.add_theme_constant_override("shadow_offset_x", 2)
	info.add_theme_constant_override("shadow_offset_y", 2)
	top.add_child(info)
	var forecast := Action.instantiate()
	forecast.custom_minimum_size.x = 80
	forecast.text = "예보"
	forecast.pressed.connect(func():
		show_forecast = not show_forecast
		update_placement_visibility()
		signature = ""
		render_body())
	top.add_child(forecast)
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
	top.add_child(tools_button)
	effects_button=Action.instantiate()
	effects_button.text="효과"
	effects_button.custom_minimum_size.x=64
	effects_button.toggle_mode=true
	effects_button.button_pressed=true
	effects_button.tooltip_text="3D 광원·입자·그림자 켜기/끄기"
	effects_button.toggled.connect(func(value: bool): effects_toggled.emit(value))
	top.add_child(effects_button)
	night_button=Action.instantiate()
	night_button.text="낮"
	night_button.custom_minimum_size.x=56
	night_button.toggle_mode=true
	night_button.tooltip_text="낮/밤 미리보기 전환 · 게임 시간은 유지해요"
	night_button.toggled.connect(func(value: bool):
		night_button.text="밤" if value else "낮"
		night_preview_toggled.emit(value))
	top.add_child(night_button)
	if OS.has_feature("web"):
		var account := Action.instantiate()
		account.custom_minimum_size.x = 64
		account.text = "계정"
		account.pressed.connect(func(): account_requested.emit())
		top.add_child(account)
	title = label("주말을 준비해요", true)
	title.add_theme_color_override("font_color", Color("fff7df"))
	title.add_theme_color_override("font_shadow_color", Color("213428"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	header.add_child(title)
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 8)
	stats.add_theme_constant_override("v_separation", 8)
	header.add_child(stats)
	money = Chip.instantiate()
	money.get_node("Value").text = "소지금 · 0원"
	stats.add_child(money)
	stamina = Chip.instantiate()
	stamina.get_node("Value").text = "체력 · 0 / 100"
	stats.add_child(stamina)
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
	placement_commit.text = "놓기"
	placement_commit.visible = false
	placement_commit.theme_type_variation = "PrimaryButton"
	placement_commit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placement_commit.pressed.connect(commit_field)
	placement_actions.add_child(placement_commit)
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
	scenery_hint=label("터치 · Esc · 패드 B로 복귀")
	scenery_hint.add_theme_color_override("font_color",Color("fff7df"))
	scenery_hint.add_theme_color_override("font_shadow_color",Color("213428"))
	scenery_hint.add_theme_constant_override("shadow_offset_x",2)
	scenery_hint.add_theme_constant_override("shadow_offset_y",2)
	scenery_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	scenery_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scenery_hint.visible=false
	add_child(scenery_hint)
	update_placement_visibility()
	resized.connect(fit)
	content.minimum_size_changed.connect(func(): fit.call_deferred())
	fit()

func phase() -> String:
	return state.get("phase", "")

func item_name(id: String) -> String:
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
	if not locked:
		action_requested.emit(command, choice, extra)

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
	if value.get("phase", "") != state.get("phase", ""):
		packing_confirm=false
	if value.get("phase", "") != "free" or must_check or not message.is_empty():
		viewing_scenery=false
	if state.get("phase", "") != "setup" and value.get("phase", "") == "setup":
		field_initialized_for = ""
		tools_hidden = true
	state = value
	var packing_now:=phase() in ["packing","return_pack"]
	title.visible=not packing_now
	money.visible=not packing_now
	stamina.visible=not packing_now
	tools_button.visible = phase() == "setup"
	if must_check: tools_hidden = false
	update_placement_visibility()
	var saved_drop: Dictionary = state.get("field",{}).get(selected_item,{})
	var drop_matches := not saved_drop.is_empty() and Vector3(float(saved_drop.get("x",0)),float(saved_drop.get("y",0)),float(saved_drop.get("z",0))).is_equal_approx(field_position) and Editor3D.rotation_of(saved_drop) == field_rotation
	if drop_pending and not request_busy and (drop_matches or not message.is_empty() or phase() != "setup"):
		drop_pending = false
		placement_error = message if not message.begins_with("서버 저장 완료") else ""
		field_initialized_for = ""
		if phase() == "setup": render_body()
	locked = saving or must_check
	network_busy = request_busy
	check_required = must_check
	money.get_node("Value").text = "소지금 · %d원" % int(state.get("money", 0))
	stamina.get_node("Value").text = "체력 · %d / 100" % int(state.get("stamina", 0))
	var camp := phase() in ["setup", "free", "cooking", "meal_ready", "sleep_required", "teardown", "return_pack"]
	var day := "일요일" if int(state.get("camp_day", 0)) == 1 else "토요일"
	info.text = "%d주 · %s · %s" % [int(state.get("week", 1)), day if camp else "금요일 준비", Assets.weather_name(Assets.current_weather(state))]
	title.text = TITLES.get(phase(), phase())
	if phase() in ["packing", "return_pack"]:
		info.text = "%d주 · 남은 시간 %d초" % [int(state.get("week", 1)), int(ceil(float(state.get("pack_remaining_ms", 45000)) / 1000))]
	elif camp:
		var minute := int(state.get("camp_minute", 960))
		info.text += " · %02d:%02d" % [(minute / 60) % 24, minute % 60]
	var structural := [phase(), state.get("owned"), state.get("meal_owned"), state.get("cargo", {}).keys() if phase() in ["setup","packing","return_pack"] else null, state.get("field", {}).keys() if phase() in ["setup", "teardown"] else null, state.get("outfit"), state.get("pack_started"), state.get("cooking"), state.get("camp_day"), state.get("rested"), int(state.get("stamina", 100)) <= 20, state.get("lost"), show_forecast, check_required]
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
			node.disabled = locked or not node.get_meta("available", true)
	placement_commit.disabled = locked or selected_item.is_empty()
	placement_done.disabled = locked or drop_pending
	placement_message.text = message.split("  ·")[0] if phase() == "setup" and not message.is_empty() and not message.begins_with("서버 저장 완료") else "물건을 잡아 끌어서 놓으세요"
	placement_message.visible = not placement_message.text.is_empty()
	if field_editor != null:
		field_editor.interaction_locked = locked or drop_pending
		field_editor.configure(state, selected_item if phase() == "setup" else "", field_position, field_rotation)
		update_placement_caption()
	if board != null:
		update_grid()
		board.interactive = not locked and (phase() == "setup" or state.get("pack_started", false))
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
			content.add_child(label("풍경과 자리 크기를 비교해 골라요. 이용료는 이번 방문에만 내요."))
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
			content.add_child(label("기본 텐트와 버너는 준비되어 있어요. 마음에 드는 장비를 더해요."))
			var items := GridContainer.new()
			items.columns = 2
			items.add_theme_constant_override("h_separation", 8)
			items.add_theme_constant_override("v_separation", 8)
			content.add_child(items)
			for item in state.item_catalog:
				if item.id == "meal":
					continue
				var owned: bool = item.id in state.owned
				var purchase := button(items, item.name + ("\n✓ 보유 중" if owned else "\n%d원" % item.price), "buy_item", item.id, not owned and int(state.money) >= int(item.price))
				purchase.icon = Assets.item_texture(item.id)
				purchase.expand_icon = true
				purchase.add_theme_constant_override("icon_max_width", 44)
				purchase.custom_minimum_size = Vector2(0, 80)
			button(content, "음식과 옷 준비하기  →", "shop_done", "", true, true)
		"prepare":
			content.add_child(label("이번 주말 예보"))
			for index in [5, 6]:
				var forecast: Dictionary = state.weather[index]
				content.add_child(label("%d일 · %s · %s" % [int(forecast.date), "토요일" if index == 5 else "일요일", Assets.weather_name(forecast.weather)]))
			content.add_child(label("이번 여행에 입을 옷을 골라요. 맞지 않으면 체력이 더 빨리 줄어요."))
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
				button(column, ("✓ " if state.outfit == outfit else "") + ("캠핑복" if outfit == "basic" else "방수 겉옷"), "set_clothes", outfit)
			button(content, "✓ 라면 준비 완료" if state.meal_owned else "라면 한 끼 준비 · 20원", "buy_meal", "", not state.meal_owned and int(state.money) >= 20)
			if not state.meal_owned:
				note("음식 없이도 출발할 수 있어요. 캠핑 중 먹을 음식이 없다는 점을 기억해요.", 1)
			button(content, "짐 싸러 가기  →", "prepare_done", "", true, true)
		"packing", "return_pack":
			build_grid()
		"setup":
			build_field_3d()
		"free":
			if not Assets.suitable(state):
				note("지금 날씨에 옷이 맞지 않아 체력이 더 빨리 줄어요.", 1)
			if int(state.stamina) <= 20:
				note("체력이 얼마 남지 않았어요. 먹거나 쉬고, 토요일에는 잠을 자요.", 1)
			content.add_child(label("캠프에서 잠시 쉬어가요."))
			var activities := GridContainer.new()
			activities.columns = 2
			activities.add_theme_constant_override("h_separation", 8)
			activities.add_theme_constant_override("v_separation", 8)
			content.add_child(activities)
			button(activities, "배치 편집", "edit_camp")
			var can_cook: bool = state.meal_owned and state.cargo.has("meal") and state.field.has("stove")
			button(activities, "식사 준비" if state.get("cooked",false) else "라면 끓이기", "cook_begin", "", can_cook)
			if not can_cook and state.meal_owned:
				content.add_child(label("요리하려면 재료를 싣고 버너를 설치해야 해요."))
			var admire := button(activities, "풍경 감상", "", "")
			admire.pressed.connect(begin_scenery)
			if int(state.camp_day) == 0:
				button(activities, "잠들기  →", "sleep", "", true, true)
			else:
				button(activities, "귀가 준비  →", "leave_camp", "", true, true)
		"cooking":
			content.add_child(label("버너 앞에서 라면을 끓여요.\n%d / 3 단계" % int(state.cooking)))
			var illustration := TextureRect.new()
			illustration.texture = Assets.item_texture("stove")
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
			for id in state.field:
				button(content, item_name(id) + " 철거하기", "take_down", id)
			button(content, "귀가 짐 싸기  →", "teardown_done", "", state.field.is_empty(), true)
		"settlement":
			content.add_child(label("이번 주 수입  +%d원\n준비에 쓴 돈  %d원\n현재 소지금  %d원" % [int(state.week_income), int(state.week_spent), int(state.money)]))
			content.add_child(label("집에 보관할 장비\n" + names(state.owned)))
			content.add_child(label("남은 라면: 1끼" if state.meal_owned else "남은 음식 없음"))
			if not state.lost.is_empty():
				note("싣지 못해 잃어버린 물건: " + names(state.lost) + "\n다시 회수할 수 없어요.", 2)
			else:
				note("가져간 물건을 모두 챙겨 돌아왔어요.")
			button(content, "저장하고 다음 주 시작  →", "next_week", "", true, true)
	if restore_grid_focus and board != null:
		restore_board_focus.call_deferred()
	fit.call_deferred()

func restore_board_focus() -> void:
	if is_instance_valid(board) and board.is_inside_tree(): board.grab_focus()

func use_field_editor(editor) -> void:
	field_editor = editor
	field_editor.item_selected.connect(func(id: String):
		if phase() != "setup": return
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
		drop_pending = true
		field_editor.interaction_locked = true
		act("place_item",id,{"x":point.x,"y":point.z,"z":point.y,"rotated":field_rotation%180!=0,"rotation_degrees":field_rotation,"coordinate_system":"z_up"}))

func update_placement_visibility() -> void:
	if dock == null or placement_bar == null: return
	var placing := phase() == "setup"
	dock.visible = (not placing or not tools_hidden or show_forecast) and not viewing_scenery
	if scenery_hint != null: scenery_hint.visible=viewing_scenery
	placement_bar.visible = placing and tools_hidden and not show_forecast
	placement_controls.visible = placement_bar.visible
	placement_done.visible = placement_bar.visible
	tools_button.text = "장비" if tools_hidden else "닫기"

func begin_scenery() -> void:
	if locked or phase() != "free": return
	show_forecast=false
	viewing_scenery=true
	update_placement_visibility()
	if not state.get("rested",false): act("rest")

func _input(event: InputEvent) -> void:
	if not viewing_scenery: return
	var pointer: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed)
	# 감상 중에도 상단 낮/밤·효과 버튼은 바로 사용할 수 있다.
	if pointer and header.get_global_rect().has_point(event.position): return
	var key: bool = event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE,KEY_ENTER,KEY_SPACE,KEY_BACK]
	var pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A,JOY_BUTTON_B]
	if pointer or key or pad:
		viewing_scenery=false
		update_placement_visibility()
		get_viewport().set_input_as_handled()

func update_placement_caption() -> void:
	if phase() != "setup" or field_editor == null: return
	placement_done.disabled = locked or drop_pending or field_editor.dragging_item
	field_rotate.disabled = placement_done.disabled or selected_item.is_empty()
	var reason: String = placement_error if not placement_error.is_empty() else field_editor.placement_reason
	var hint := "저장 중…" if drop_pending else "끌어서 배치 · 초록이면 놓을 수 있어요" if reason.is_empty() else reason
	var position_type := "테이블 위 가능" if field_editor.support_info(selected_item).get("can_place_on_table", false) else "바닥 전용"
	placement_message.text = "%s · %s\n%s" % [item_name(selected_item),position_type,hint]
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
	commit_field()

func _unhandled_input(event: InputEvent) -> void:
	if phase() != "setup": return
	var rotate_key: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R
	var rotate_pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y
	if rotate_key or rotate_pad:
		rotate_field()
		get_viewport().set_input_as_handled()

func commit_field() -> void:
	if selected_item.is_empty() or locked or drop_pending: return
	drop_pending = true
	field_editor.interaction_locked = true
	tools_hidden = true
	update_placement_visibility()
	act("place_item",selected_item,{"x":field_position.x,"y":field_position.z,"z":field_position.y,"rotated":field_rotation%180!=0,"rotation_degrees":field_rotation,"coordinate_system":"z_up"})

func build_field_3d() -> void:
	selected_ids = state.cargo.keys()
	selected_ids.erase("meal")
	if not selected_item in selected_ids:
		selected_item = selected_ids[0] if not selected_ids.is_empty() else ""
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
	content.add_child(label("물건을 직접 잡아 끌어 배치해요. 손을 놓으면 저장됩니다."))
	content.add_child(label("선택한 장비 · " + item_name(selected_item)))
	button(content, "선택한 장비를 차로", "remove_item", selected_item, state.field.has(selected_item))

func build_grid() -> void:
	var field := phase() == "setup"
	var returning := phase() == "return_pack"
	selected_ids = state.cargo.keys() if field else state.get("return_candidates", []) if returning else state.owned.duplicate()
	if not field and not returning and state.meal_owned:
		selected_ids.append("meal")
	if field:
		selected_ids.erase("meal")
	if not selected_item in selected_ids:
		selected_item = selected_ids[0] if not selected_ids.is_empty() else ""
	if returning:
		content.add_child(label("미적재품은 잃어버려요."))
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
			packing_footer.add_child(label("잃어버릴 물건: "+names(missed)))
			var cancel:=button(packing_footer,"계속 짐싸기","")
			cancel.pressed.connect(func(): packing_confirm=false; render_body())
			var confirm:=button(packing_footer,"남겨두고 귀가하기", "", "", true, true)
			confirm.pressed.connect(func(): act("finish_pack","",{"confirm_loss":true}))
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
	preload("res://ui/ui_metrics.gd").apply(self, size.x <= 960)
	if size.x <= 960 and info.get_parent() == toolbar:
		info.reparent(header)
		header.move_child(info, 0)
	elif size.x > 960 and info.get_parent() == header:
		info.reparent(toolbar)
		toolbar.move_child(info, 0)
	if not state.is_empty():
		money.get_node("Value").text = ("%d원" if size.x < 600 else "소지금 · %d원") % int(state.get("money", 0))
		stamina.get_node("Value").text = ("체력 %d/100" if size.x < 600 else "체력 · %d / 100") % int(state.get("stamina", 0))
	var margin := 12.0 if size.x < 760 else 28.0
	placement_bar.size = Vector2(minf(460, size.x - margin * 2), 0)
	placement_bar.position = Vector2((size.x - placement_bar.size.x) / 2, size.y - placement_bar.size.y - margin)
	update_placement_action_position()
	header.position = Vector2(margin, margin)
	header.size = Vector2(size.x - margin * 2, 0)
	if scenery_hint != null:
		scenery_hint.position=Vector2(margin,size.y-48)
		scenery_hint.size=Vector2(size.x-margin*2,40)
	var width := minf(700, size.x - margin * 2)
	dock.custom_minimum_size.x = width
	var available := maxf(160, size.y - header.position.y - header.size.y - margin * 2 - 16)
	var desired: float = content.get_combined_minimum_size().y + (packing_footer.get_combined_minimum_size().y+8 if packing_footer.visible else 0) + 40
	dock.size = Vector2(width, minf(available, maxf(120, desired)))
	dock.position = Vector2(floorf((size.x - width) / 2), size.y - dock.size.y - margin)

func _process(delta: float) -> void:
	if state.is_empty():
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
