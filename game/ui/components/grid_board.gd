extends Control

signal cell_activated(x: int, y: int)
signal rotate_requested
signal item_selected(id: String)
signal item_dropped(id: String, x: int, y: int, rotation: int)
const Assets = preload("res://ui/components/mvp_assets.gd")
var columns := 6
var rows := 5
var cell_size := 48
var catalog: Dictionary = {}
var placements: Dictionary = {}
var selected := ""
var rotated := false
var packing_angle := 0
var blocked := false
var interactive := true
var cursor := Vector2i.ZERO
var press_position := Vector2.ZERO
var dragged := false

func configure(width: int, height: int, items: Array, values: Dictionary, id: String, rotation: bool, has_trees: bool) -> void:
	columns = width
	rows = height
	catalog.clear()
	for item in items:
		catalog[item.id] = item
	placements = values
	selected = id
	rotated = rotation
	packing_angle=90 if rotation else 0
	blocked = has_trees
	custom_minimum_size = Vector2(columns, rows) * cell_size
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	cursor.x = clampi(cursor.x, 0, columns - 1)
	cursor.y = clampi(cursor.y, 0, rows - 1)
	queue_redraw()

func cells(id: String, rotation: Variant) -> Array:
	var source: Array = catalog.get(id, {}).get("cells", [])
	var result: Array = []
	for cell in source:
		result.append(Vector2i(int(cell[0]),int(cell[1])))
	var angle: int = (90 if rotation else 0) if rotation is bool else int(rotation)
	for turn in range(angle/90):
		var height:=0
		for cell in result: height=maxi(height,cell.y+1)
		result=result.map(func(cell): return Vector2i(height-1-cell.y,cell.x))
	return result

static func angle_of(pose: Dictionary) -> int:
	return int(pose.get("rotation_degrees",90 if pose.get("rotated",false) else 0))

func valid_at(point: Vector2i) -> bool:
	if selected.is_empty():
		return false
	var occupied := {}
	for id in placements:
		if id == selected:
			continue
		var p: Dictionary = placements[id]
		for offset in cells(id, angle_of(p)):
			occupied[Vector2i(p.x, p.y) + offset] = true
	for offset in cells(selected, packing_angle):
		var p: Vector2i = point + offset
		if p.x < 0 or p.y < 0 or p.x >= columns or p.y >= rows or occupied.has(p) or (blocked and p.x < 2 and p.y < 2):
			return false
	return true

func _get_drag_data(at: Vector2) -> Variant:
	if not interactive: return null
	var cell:=Vector2i(at/cell_size)
	for id in placements:
		var pose: Dictionary=placements[id]
		var origin:=Vector2i(pose.x,pose.y)
		if cell-origin not in cells(id,angle_of(pose)): continue
		selected=id
		rotated=pose.get("rotated",false)
		packing_angle=angle_of(pose)
		item_selected.emit(id)
		dragged=true
		var preview:=TextureRect.new()
		preview.texture=Assets.item_texture(id)
		preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.custom_minimum_size=Vector2(80,80)
		preview.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		preview.modulate.a=.8
		set_drag_preview(preview)
		return {"packing_item":id,"rotated":rotated,"rotation_degrees":packing_angle,"grab_cell":cell-origin}
	return null

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if not interactive or not data is Dictionary or not catalog.has(data.get("packing_item","")): return false
	selected=data.packing_item
	rotated=data.get("rotated",false)
	packing_angle=angle_of(data)
	cursor=Vector2i(at/cell_size)-Vector2i(data.get("grab_cell",Vector2i.ZERO))
	queue_redraw()
	return valid_at(cursor)

func _drop_data(at: Vector2, data: Variant) -> void:
	if _can_drop_data(at,data): item_dropped.emit(selected,cursor.x,cursor.y,packing_angle)

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_position = event.position
			dragged = false
			grab_focus()
		elif not dragged:
			cursor = Vector2i(event.position / cell_size)
			if cursor.x >= 0 and cursor.y >= 0 and cursor.x < columns and cursor.y < rows:
				cell_activated.emit(cursor.x, cursor.y)
		queue_redraw()
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT and event.position.distance_to(press_position) > 8:
			dragged = true
		cursor = Vector2i(event.position / cell_size).clamp(Vector2i.ZERO, Vector2i(columns - 1, rows - 1))
		queue_redraw()
	elif event.is_pressed():
		if event.is_action("ui_left"):
			cursor.x = maxi(0, cursor.x - 1)
		elif event.is_action("ui_right"):
			cursor.x = mini(columns - 1, cursor.x + 1)
		elif event.is_action("ui_up"):
			cursor.y = maxi(0, cursor.y - 1)
		elif event.is_action("ui_down"):
			cursor.y = mini(rows - 1, cursor.y + 1)
		elif event.is_action("ui_accept"):
			cell_activated.emit(cursor.x, cursor.y)
		elif (event is InputEventKey and event.keycode == KEY_R) or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_Y):
			rotate_requested.emit()
		else:
			return
		accept_event()
		queue_redraw()

func _draw() -> void:
	for y in range(rows):
		for x in range(columns):
			var box := Rect2(Vector2(x, y) * cell_size + Vector2.ONE, Vector2.ONE * (cell_size - 2))
			var tree := blocked and x < 2 and y < 2
			draw_rect(box, Color("71825b") if tree else Color("e9dec3"))
			draw_rect(box, Color("b6a481"), false, 1)
			if tree:
				draw_string(get_theme_default_font(), box.position + Vector2(12, 29), "숲", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("fff7df"))
	for id in placements:
		var p: Dictionary = placements[id]
		var origin := Vector2i(p.x, p.y)
		var footprint := cells(id, angle_of(p))
		var largest := Vector2i.ZERO
		for offset in footprint:
			largest = largest.max(offset)
			var box := Rect2(Vector2(origin + offset) * cell_size + Vector2(2, 2), Vector2.ONE * (cell_size - 4))
			draw_rect(box, Assets.cargo_color(id))
			draw_rect(box, Assets.cargo_color(id).darkened(.48), false, 3)
		var item_rect := Rect2(Vector2(origin) * cell_size + Vector2(5, 5), Vector2(largest + Vector2i.ONE) * cell_size - Vector2(10, 10))
		var texture := Assets.item_texture(id)
		if texture:
			# 그림이 비어 있는 칸을 덮지 않게 첫 점유 칸에 식별용 그림을 둔다.
			draw_texture_rect(texture,Rect2(Vector2(origin+footprint[0])*cell_size+Vector2(4,4),Vector2.ONE*(cell_size-8)),false)
		else:
			draw_string(get_theme_default_font(), item_rect.position + Vector2(1, 24), "우비" if id == "rainwear" else "음식", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("fff7df"))
	if interactive and not selected.is_empty():
		var color := Color(0.25, 0.48, 0.28, 0.50) if valid_at(cursor) else Color(0.7, 0.2, 0.14, 0.45)
		for offset in cells(selected, packing_angle):
			var point: Vector2i = cursor + offset
			if point.x < columns and point.y < rows:
				draw_rect(Rect2(Vector2(point) * cell_size + Vector2.ONE, Vector2.ONE * (cell_size - 2)), color, false, 3)
	if has_focus():
		draw_rect(Rect2(Vector2(cursor) * cell_size + Vector2.ONE * 4, Vector2.ONE * (cell_size - 8)), Color("a36a25"), false, 2)
