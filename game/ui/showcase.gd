extends Control

const Action = preload("res://ui/components/action_button.tscn")
const Paper = preload("res://ui/components/paper_panel.tscn")
const HudChip = preload("res://ui/components/hud_chip.tscn")
const ChoiceCard = preload("res://ui/components/choice_card.tscn")
const GridCell = preload("res://ui/components/grid_cell.tscn")
const Notice = preload("res://ui/components/notice.tscn")
const StaminaMeter = preload("res://ui/components/stamina_meter.tscn")
var scroll: ScrollContainer
var cards: GridContainer
var feedback: Label

func text(value: String, size_px: int = 16, color: String = "263626") -> Label:
	var label := Label.new()
	label.text = value
	# 16px 도트 글꼴을 정수 배율로 사용한다. 제목은 2배, 본문은 1배.
	size_px = 32 if size_px >= 24 else 16
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", Color(color))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func section(title: String, note: String) -> VBoxContainer:
	var panel := Paper.instantiate()
	cards.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(text(title, 21))
	column.add_child(text(note, 14, "5d604e"))
	return column

func button(label: String, primary: bool = false) -> Button:
	var item := Action.instantiate()
	item.text = label
	if primary:
		item.theme_type_variation = "PrimaryButton"
	item.pressed.connect(func(): feedback.text = "미리보기 · “%s” 선택" % label)
	return item

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("263c2e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	scroll.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)
	root.add_child(text("이번 주말은 캠핑", 34, "fff7df"))
	root.add_child(text("UI 작업실  /  DESIGN SYSTEM 01", 14, "e5bc70"))
	root.add_child(text("도트 풍경에 어울리는 작은 창과 버튼, 편하게 읽히는 글자", 16, "eee3c9"))
	cards = GridContainer.new()
	cards.columns = 2
	cards.add_theme_constant_override("h_separation", 20)
	cards.add_theme_constant_override("v_separation", 20)
	root.add_child(cards)
	var palette := section("01  숲 · 천 · 나무 · 불빛", "따뜻한 바탕과 선명한 테두리")
	var colors := HBoxContainer.new()
	palette.add_child(colors)
	for item in [["263c2e", "숲"], ["4b6542", "솔잎"], ["fff7df", "천"], ["77583b", "나무"], ["e5bc70", "불빛"]]:
		var swatch := VBoxContainer.new()
		swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		colors.add_child(swatch)
		var block := ColorRect.new()
		block.color = Color(item[0])
		block.custom_minimum_size.y = 38
		swatch.add_child(block)
		swatch.add_child(text(item[1], 14))
	var typography := section("02  또렷한 한국어", "도스필기 · 손으로 쓴 듯한 도트 글자")
	typography.add_child(text("주말을 준비하는 작은 설렘", 24))
	typography.add_child(text("본문 16 · 제목 32 · 터치 영역 최소 48", 16))
	var actions := section("03  버튼과 상태", "숲색은 주요 행동 · 테두리는 키보드 포커스")
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	actions.add_child(row)
	row.add_child(button("선택 확정", true))
	row.add_child(button("돌아가기"))
	var disabled := button("처리 중…")
	disabled.disabled = true
	row.add_child(disabled)
	var hud := section("04  작고 명확한 HUD", "풍경을 가리지 않는 핵심 정보 · 수치는 예시")
	var chips := HFlowContainer.new()
	hud.add_child(chips)
	for value in ["토요일 · 16:20", "12,800 원"]:
		var chip := HudChip.instantiate()
		chip.get_node("Value").text = value
		chips.add_child(chip)
	hud.add_child(StaminaMeter.instantiate())
	var choices := section("05  예보와 의상", "선택과 부적합을 문구로도 구분 · 내용은 예시")
	var group := HFlowContainer.new()
	group.add_theme_constant_override("h_separation", 12)
	group.add_theme_constant_override("v_separation", 12)
	choices.add_child(group)
	var choice_group := ButtonGroup.new()
	choice_group.allow_unpress = false
	for value in ["토요일 · 맑음", "일요일 · 비"]:
		var choice := ChoiceCard.instantiate()
		choice.text = value + "\n미선택"
		choice.button_group = choice_group
		choice.toggled.connect(func(selected: bool):
			choice.text = value + ("\n✓ 선택됨" if selected else "\n미선택"))
		group.add_child(choice)
	choices.add_child(text("긴소매 · 선택됨 / 비에 부적합하면 체력 소모 증가", 16))
	var packing := section("06  적재와 손실 안내", "배치 상태는 테두리와 표시를 함께 사용")
	var cells := HFlowContainer.new()
	cells.add_theme_constant_override("h_separation", 12)
	cells.add_theme_constant_override("v_separation", 12)
	packing.add_child(cells)
	for state in range(3):
		var cell := GridCell.instantiate()
		cell.state = state
		cells.add_child(cell)
	var notice := Notice.instantiate()
	notice.severity = 2
	packing.add_child(notice)
	feedback = text("버튼을 누르거나 Tab 키로 포커스를 확인해 보세요.", 14, "fff7df")
	root.add_child(feedback)
	root.add_child(text("독립 UI 전시 씬 · 실제 플레이 규칙과 수량을 확정하는 화면이 아닙니다.", 14, "c6cbb1"))
	resized.connect(fit)
	fit()
	if "--capture" in OS.get_cmdline_user_args():
		capture.call_deferred()

func fit() -> void:
	cards.columns = 1 if size.x < 760 else 2

func capture() -> void:
	for frame in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var target := "/tmp/project-cp-ui-showcase.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			target = argument.trim_prefix("--capture-output=")
	get_viewport().get_texture().get_image().save_png(target)
	# 선택 상태도 렌더링하고 긴 화면은 하단까지 확인한다.
	var choices := find_children("ChoiceCard*", "Button", true, false)
	if not choices.is_empty():
		choices[0].button_pressed = true
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	for frame in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(target.get_basename() + "-bottom.png")
	print("UI capture: ", size, " / content minimum width: ", cards.get_combined_minimum_size().x)
	get_tree().quit()
