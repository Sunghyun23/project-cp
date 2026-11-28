extends Control
signal activated(id: String)
signal scrolled(pixels: float)
signal drag_requested(id: String, point: Vector2, pointer: int)
const Assets=preload("res://ui/components/mvp_assets.gd")
var item_id := ""
var caption := ""
var upgraded := false
var disabled := false
var pointer := -2
var press_at := Vector2.ZERO
var dragging := false
var scrolling := false
var icon_texture: Texture2D
var icon_region := Rect2()
func _ready() -> void:
	custom_minimum_size=Vector2(112,100)
	focus_mode=Control.FOCUS_ALL
	mouse_filter=Control.MOUSE_FILTER_STOP
	tooltip_text=caption+" · 위로 끌어 배치 · 옆으로 넘기기"
	icon_texture=Assets.item_texture(item_id,upgraded)
	if icon_texture != null:
		var bitmap := icon_texture.get_image()
		if bitmap != null:
			if bitmap.is_compressed(): bitmap.decompress()
			icon_region=Rect2(bitmap.get_used_rect())
		if not icon_region.has_area(): icon_region=Rect2(Vector2.ZERO,Vector2(icon_texture.get_size()))
func _draw() -> void:
	draw_style_box(get_theme_stylebox("disabled" if disabled else "normal","Button"),Rect2(Vector2.ZERO,size))
	if icon_texture != null and icon_region.has_area():
		var extent: Vector2=icon_region.size*minf(60/icon_region.size.x,60/icon_region.size.y)
		draw_texture_rect_region(icon_texture,Rect2(Vector2((size.x-extent.x)/2,5+(60-extent.y)/2),extent),icon_region)
	draw_string(get_theme_default_font(),Vector2(4,86),caption,HORIZONTAL_ALIGNMENT_CENTER,size.x-8,16,Color("354c3b"))
	if has_focus(): draw_style_box(get_theme_stylebox("focus","Button"),Rect2(Vector2.ZERO,size))
func _gui_input(event: InputEvent) -> void:
	if disabled: return
	var down: bool = (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	var up: bool = (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if down:
		pointer=event.index if event is InputEventScreenTouch else -1
		press_at=get_global_transform()*event.position
		dragging=false;scrolling=false
		grab_focus();queue_redraw();accept_event()
	elif (event is InputEventMouseMotion and pointer==-1) or (event is InputEventScreenDrag and event.index==pointer):
		var point: Vector2=get_global_transform()*event.position
		var delta: Vector2=point-press_at
		if scrolling or (not dragging and absf(delta.x)>6 and absf(delta.x)>absf(delta.y)*1.2):
			scrolling=true;scrolled.emit(delta.x);press_at=point
		elif not dragging and point.distance_to(press_at)>6:
			dragging=true
			drag_requested.emit(item_id,point,pointer)
		accept_event()
	elif up and pointer!=-2:
		var was_dragging:=dragging or scrolling
		pointer=-2;dragging=false
		if not was_dragging and not (event is InputEventScreenTouch and event.canceled): activated.emit(item_id)
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		activated.emit(item_id);accept_event()
func _notification(what: int) -> void:
	if what in [NOTIFICATION_FOCUS_ENTER,NOTIFICATION_FOCUS_EXIT]: queue_redraw()
