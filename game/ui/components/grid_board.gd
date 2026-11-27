extends Control

signal cell_activated(x: int, y: int)
signal rotate_requested
const Assets = preload("res://ui/components/mvp_assets.gd")
var columns := 6
var rows := 5
var cell_size := 48
var catalog: Dictionary = {}
var placements: Dictionary = {}
var selected := ""
var rotated := false
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
	blocked = has_trees
	custom_minimum_size = Vector2(columns, rows) * cell_size
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	cursor.x = clampi(cursor.x, 0, columns - 1)
	cursor.y = clampi(cursor.y, 0, rows - 1)
	queue_redraw()

func cells(id: String, rotation: bool) -> Array:
	var source: Array = catalog.get(id, {}).get("cells", [])
	var result: Array = []
	var height := 0
	for cell in source:
		height = maxi(height, int(cell[1]) + 1)
	for cell in source:
		result.append(Vector2i(height - 1 - int(cell[1]), int(cell[0])) if rotation else Vector2i(int(cell[0]), int(cell[1])))
	return result

func valid_at(point: Vector2i) -> bool:
	if selected.is_empty():
		return false
	var occupied := {}
	for id in placements:
		if id == selected:
			continue
		var p: Dictionary = placements[id]
		for offset in cells(id, p.get("rotated", false)):
			occupied[Vector2i(p.x, p.y) + offset] = true
	for offset in cells(selected, rotated):
		var p: Vector2i = point + offset
		if p.x >= columns or p.y >= rows or occupied.has(p) or (blocked and p.x < 2 and p.y < 2):
			return false
	return true

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
		var footprint := cells(id, p.get("rotated", false))
		var largest := Vector2i.ZERO
		for offset in footprint:
			largest = largest.max(offset)
			var box := Rect2(Vector2(origin + offset) * cell_size + Vector2(2, 2), Vector2.ONE * (cell_size - 4))
			draw_rect(box, Color("789367"))
		var item_rect := Rect2(Vector2(origin) * cell_size + Vector2(5, 5), Vector2(largest + Vector2i.ONE) * cell_size - Vector2(10, 10))
		var texture := Assets.item_texture(id)
		if texture:
			var length := minf(item_rect.size.x, item_rect.size.y)
			draw_texture_rect(texture, Rect2(item_rect.get_center() - Vector2.ONE * length / 2, Vector2.ONE * length), false)
		else:
			draw_string(get_theme_default_font(), item_rect.position + Vector2(1, 24), "음식", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("fff7df"))
	if interactive and not selected.is_empty():
		var color := Color(0.25, 0.48, 0.28, 0.50) if valid_at(cursor) else Color(0.7, 0.2, 0.14, 0.45)
		for offset in cells(selected, rotated):
			var point: Vector2i = cursor + offset
			if point.x < columns and point.y < rows:
				draw_rect(Rect2(Vector2(point) * cell_size + Vector2.ONE, Vector2.ONE * (cell_size - 2)), color, false, 3)
	if has_focus():
		draw_rect(Rect2(Vector2(cursor) * cell_size + Vector2.ONE * 4, Vector2.ONE * (cell_size - 8)), Color("a36a25"), false, 2)
