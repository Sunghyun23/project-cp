extends Button

const Assets=preload("res://ui/components/mvp_assets.gd")
var item_id := ""
var item_rotated := false
var packing_angle := 0
var can_drag := true
var footprint_cells: Array = []
var caption := ""
var packed := false

func _ready() -> void:
	var title:=Label.new()
	title.text=caption.replace("라면 재료","라면").replace("방수 겉옷","우비")
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.position=Vector2(0,78)
	title.size=Vector2(custom_minimum_size.x,26)
	title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(title)

func _draw() -> void:
	var ink := Assets.cargo_color(item_id)
	var border := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	draw_rect(border, ink, false, 3)
	if packed:
		draw_rect(Rect2(Vector2(4, 4), Vector2(28, 22)), ink.darkened(.30))
		draw_string(get_theme_default_font(),Vector2(6,20),"✓",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("fff7df"))
	var texture:=Assets.item_texture(item_id)
	if texture: draw_texture_rect(texture,Rect2(Vector2((size.x-44)/2,2),Vector2(44,44)),false)
	else: draw_string(get_theme_default_font(),Vector2(20,36),"우비" if item_id == "rainwear" else "음식",HORIZONTAL_ALIGNMENT_LEFT,-1,18)
	var shape: Array=[]
	for cell in footprint_cells:
		shape.append(Vector2i(cell[0],cell[1]))
	for turn in range(packing_angle/90):
		var height:=0
		for cell in shape: height=maxi(height,cell.y+1)
		shape=shape.map(func(cell): return Vector2i(height-1-cell.y,cell.x))
	var extent:=Vector2i.ONE
	for cell in shape: extent=extent.max(cell+Vector2i.ONE)
	var origin:=Vector2((size.x-extent.x*12)/2,44)
	for point in shape:
		draw_rect(Rect2(origin+Vector2(point)*12,Vector2(11,11)),ink if packed else ink.lightened(.35))
		draw_rect(Rect2(origin+Vector2(point)*12,Vector2(11,11)),ink.darkened(.48),false,2)

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	return get_parent()._can_drop_data(position+at,data)

func _drop_data(at: Vector2, data: Variant) -> void:
	get_parent()._drop_data(position+at,data)

func _get_drag_data(_at: Vector2) -> Variant:
	if disabled or not can_drag: return null
	pressed.emit()
	var preview:=TextureRect.new()
	preview.texture=Assets.item_texture(item_id)
	preview.custom_minimum_size=Vector2(80,80)
	preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	preview.modulate.a=.8
	set_drag_preview(preview)
	return {"packing_item":item_id,"rotated":item_rotated,"rotation_degrees":packing_angle,"grab_cell":Vector2i.ZERO}
