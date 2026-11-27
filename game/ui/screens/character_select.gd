extends Control

signal confirm_requested(character_id: String)
signal reload_requested

const UiInput = preload("res://ui/ui_input.gd")
const Catalog = preload("res://ui/components/character_catalog.gd")
const Paper = preload("res://ui/components/paper_panel.tscn")
const Choice = preload("res://ui/components/choice_card.tscn")
const Action = preload("res://ui/components/action_button.tscn")
const Notice = preload("res://ui/components/notice.tscn")
const DAY = preload("res://assets/pixel/campsite-day.png")
const SCENERY_SHADER = preload("res://assets/pixel/campsite.gdshader")
var selected_id := ""
var pending := false
var must_check := false
var cards: Array[Button] = []
var avatar: AnimatedSprite2D
var selected_label: Label
var confirm_button: Button
var reload_button: Button
var notice: PanelContainer
var dock: PanelContainer
var header: VBoxContainer
var scenery: TextureRect
var avatar_foot := Vector2.ZERO
var ground_shadow: Polygon2D

func label(value: String, font_size: int = 16, floating: bool = false) -> Label:
	var result := Label.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	if floating:
		result.add_theme_color_override("font_color", Color("fff7df"))
		result.add_theme_color_override("font_shadow_color", Color("14251cf0"))
		result.add_theme_constant_override("shadow_offset_x", 2)
		result.add_theme_constant_override("shadow_offset_y", 2)
	return result

func _ready() -> void:
	UiInput.ensure()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scenery = TextureRect.new()
	scenery.texture = DAY
	var material := ShaderMaterial.new()
	material.shader = SCENERY_SHADER
	scenery.material = material
	scenery.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scenery.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scenery)
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.12, 0.08, 0.18)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	header = VBoxContainer.new()
	header.size.x = size.x - 40
	header.add_theme_constant_override("separation", 12)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	header.add_child(label("이번 주말은 캠핑", 16, true))
	header.add_child(label("어떤 캠퍼로 떠나볼까요?", 32, true))
	header.add_child(label("함께할 캠퍼를 골라주세요.", 16, true))
	ground_shadow = Polygon2D.new()
	ground_shadow.color = Color(0.03, 0.08, 0.04, 0.35)
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * i / 24.0
		points.append(Vector2(cos(angle) * 55, sin(angle) * 12))
	ground_shadow.polygon = points
	add_child(ground_shadow)
	avatar = AnimatedSprite2D.new()
	avatar.sprite_frames = Catalog.frames("female")
	avatar.play("idle")
	add_child(avatar)

	dock = Paper.instantiate()
	dock.custom_minimum_size.x = minf(560, size.x - 40)
	add_child(dock)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	dock.add_child(content)
	var choices := HBoxContainer.new()
	content.add_child(choices)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for id in Catalog.IDS:
		var card := Choice.instantiate()
		card.custom_minimum_size = Vector2(0, 48)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.text = "남성" if id == "male" else "여성"
		card.button_group = group
		card.toggled.connect(func(active: bool):
			card.text = ("✓ " if active else "") + ("남성" if id == "male" else "여성")
			if active:
				select_character(id))
		choices.add_child(card)
		cards.append(card)
	selected_label = label("어떤 모습으로 떠날까요?")
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(selected_label)
	notice = Notice.instantiate()
	notice.message = "선택한 모습으로 첫 주를 시작해요."
	notice.severity = 0
	notice.visible = false
	content.add_child(notice)
	confirm_button = Action.instantiate()
	confirm_button.theme_type_variation = "PrimaryButton"
	confirm_button.text = "함께 떠나기  →"
	confirm_button.disabled = true
	confirm_button.pressed.connect(func():
		if not pending and not must_check and not selected_id.is_empty():
			set_request_state(true, "선택한 캐릭터를 저장하고 있어요.", false)
			confirm_requested.emit(selected_id))
	content.add_child(confirm_button)
	reload_button = Action.instantiate()
	reload_button.text = "저장 상태 다시 확인"
	reload_button.visible = false
	reload_button.pressed.connect(func(): reload_requested.emit())
	content.add_child(reload_button)
	resized.connect(fit)
	dock.minimum_size_changed.connect(func(): fit.call_deferred())
	fit()
	cards[0].grab_focus.call_deferred()
	if "--capture-character" in OS.get_cmdline_user_args():
		capture.call_deferred()

func select_character(id: String) -> void:
	selected_id = id
	selected_label.text = "좋아요, 함께 떠나볼까요?"
	avatar.sprite_frames = Catalog.frames(id)
	avatar.play("idle")
	confirm_button.disabled = pending or must_check
	fit.call_deferred()

func set_request_state(saving: bool, message: String, check_required: bool) -> void:
	pending = saving
	must_check = check_required
	for card in cards:
		card.disabled = saving or check_required
	confirm_button.disabled = saving or check_required or selected_id.is_empty()
	confirm_button.text = "저장 중…" if saving else "함께 떠나기  →"
	reload_button.visible = check_required
	reload_button.disabled = saving
	notice.visible = saving or check_required
	notice.message = message
	notice.severity = 1 if check_required else 0
	fit.call_deferred()

func fit() -> void:
	if dock == null:
		return
	preload("res://ui/ui_metrics.gd").apply(self, size.x <= 960)
	var narrow := size.x < 760
	header.get_child(1).text = "어떤 캠퍼로\n떠나볼까요?" if narrow else "어떤 캠퍼로 떠나볼까요?"
	var margin := 20.0 if narrow else 36.0
	header.position = Vector2(margin, margin)
	header.size = Vector2(size.x - margin * 2, 0)
	var width := minf(560, size.x - margin * 2)
	dock.custom_minimum_size.x = width
	dock.size = Vector2(width, 0)
	dock.position = Vector2(floorf((size.x - width) / 2), maxf(header.position.y + header.size.y + 24, size.y - dock.size.y - margin))
	var head_end := header.position.y + header.size.y + 16
	var available := maxf(64, dock.position.y - head_end - 16)
	var height := minf(220 if narrow else 320, available)
	var frame := avatar.sprite_frames.get_frame_texture("idle", 0)
	avatar.scale = Vector2.ONE * height / frame.get_height()
	avatar_foot = Vector2(size.x * 0.5, dock.position.y - 16)
	avatar.position = avatar_foot - Vector2(0, height * 0.5)
	ground_shadow.position = avatar_foot - Vector2(0, height * 0.065)
	ground_shadow.scale = Vector2.ONE * height / 320.0
	queue_redraw()

func capture() -> void:
	for frame in range(12):
		await get_tree().process_frame
	cards[1 if "--preview-female" in OS.get_cmdline_user_args() else 0].button_pressed = true
	for frame in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var target := "/tmp/cp-character.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			target = argument.trim_prefix("--capture-output=")
	get_viewport().get_texture().get_image().save_png(target)
	print("Character select capture: ", size, " header=", header.get_rect(), " dock=", dock.get_rect())
	get_tree().quit()
