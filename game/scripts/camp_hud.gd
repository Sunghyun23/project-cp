extends Control
signal account_requested
signal reload_requested
signal view_selected(id: int)

var content: VBoxContainer
var topbar: PanelContainer
var stats: HFlowContainer
var status: Label
var dock: PanelContainer
var scroll: ScrollContainer
var view_menu: MenuButton
var title: Label
var shadow_mode := true

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	topbar=PanelContainer.new()
	topbar.add_theme_stylebox_override("panel",panel(Color(0.07,0.16,0.16,0.92),14,12))
	add_child(topbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	topbar.add_child(row)
	title=Label.new()
	title.text="△ 이번 주말은 캠핑"
	title.add_theme_font_size_override("font_size",19)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var reload_button := Button.new()
	reload_button.text="갱신";reload_button.tooltip_text="저장된 진행 다시 불러오기"
	reload_button.custom_minimum_size=Vector2(42,42)
	reload_button.pressed.connect(func():reload_requested.emit())
	row.add_child(reload_button)
	view_menu=MenuButton.new()
	view_menu.text="보기";view_menu.custom_minimum_size=Vector2(48,42)
	row.add_child(view_menu)
	var popup := view_menu.get_popup()
	popup.add_item("진행에 맞춰 낮·밤",0)
	popup.add_item("낮 풍경",1)
	popup.add_item("밤 풍경",2)
	popup.add_separator()
	popup.add_check_item("3D 광원 데모",3)
	popup.add_check_item("3D 그림자",4)
	popup.set_item_checked(popup.get_item_index(4),true)
	popup.id_pressed.connect(func(id):view_selected.emit(id))
	var account := Button.new()
	account.text="계정";account.custom_minimum_size=Vector2(48,42)
	account.pressed.connect(func():account_requested.emit())
	row.add_child(account)
	stats=HFlowContainer.new()
	stats.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override("h_separation",6)
	stats.add_theme_constant_override("v_separation",6)
	add_child(stats)
	status=Label.new()
	status.add_theme_font_size_override("font_size",11)
	status.add_theme_color_override("font_color",Color("eff3d4"))
	status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(status)
	dock=PanelContainer.new()
	dock.add_theme_stylebox_override("panel",panel(Color(0.99,0.96,0.86,0.97),18,16))
	add_child(dock)
	scroll=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	dock.add_child(scroll)
	content=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",9)
	scroll.add_child(content)
	content.minimum_size_changed.connect(func():fit.call_deferred())
	stats.minimum_size_changed.connect(func():fit.call_deferred())

func panel(color: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=color;style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.shadow_color=Color(0,0,0,0.16);style.shadow_size=8
	return style

func update_stats(state: Dictionary, message: String) -> void:
	for child in stats.get_children():
		stats.remove_child(child);child.queue_free()
	if not state.is_empty():
		for text in ["%d주 차"%state.week,"소지금 %d"%state.money,"힘 %d"%state.strength,"행운 %d"%state.luck,"체력 %d"%state.stamina]:
			var chip := PanelContainer.new()
			chip.add_theme_stylebox_override("panel",panel(Color(0.07,0.17,0.15,0.85),10,8))
			var label := Label.new()
			label.text=text;label.add_theme_font_size_override("font_size",12)
			label.add_theme_color_override("font_color",Color("fff0cc"))
			chip.add_child(label);stats.add_child(chip)
	status.text="● "+message.split("  ·")[0]
	fit.call_deferred()

func set_view(real_3d: bool, shadows: bool) -> void:
	var popup := view_menu.get_popup()
	popup.set_item_checked(popup.get_item_index(3),real_3d)
	popup.set_item_checked(popup.get_item_index(4),shadows)

func fit() -> void:
	if topbar==null:return
	preload("res://ui/ui_metrics.gd").apply(self, size.x <= 960)
	var phone := size.x<600
	var edge := 12 if phone else 22
	topbar.position=Vector2(edge,edge)
	topbar.size=Vector2(size.x-edge*2,66)
	title.add_theme_font_size_override("font_size",24 if size.x <= 960 else 20)
	title.text="△ 주말 캠핑" if size.x<360 else "△ 이번 주말은 캠핑"
	stats.position=Vector2(edge,topbar.position.y+topbar.size.y+8)
	stats.size=Vector2(size.x-edge*2,0)
	stats.size.y=stats.get_combined_minimum_size().y
	status.position=Vector2(edge,stats.position.y+stats.size.y+6)
	var width := minf(size.x-edge*2,460 if size.x>=1000 else (380 if size.x>=600 else 520))
	var limit := size.y*(0.48 if phone else 0.50)
	# Recompute after text wrap; keep all actions scrollable on short screens.
	dock.size=Vector2(width,minf(limit,content.get_combined_minimum_size().y+32))
	var left: float = edge if size.x>=1000 or size.y<500 else (size.x-width-edge if size.x>=600 else (size.x-width)/2)
	dock.position=Vector2(left,size.y-dock.size.y-edge)
