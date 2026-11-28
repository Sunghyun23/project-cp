extends Control

signal finished

const Assets = preload("res://ui/components/mvp_assets.gd")
const LAKE_NIGHT = preload("res://assets/pixel/campsite-night-terrain.png")
const DURATION := 2.65
const TENT_INTERIOR = preload("res://assets/pixel/open-tent-sleep.png")

var background: Texture2D
var props: Array[Dictionary] = []
var tent_anchor := Vector2.ZERO
var tent_width := 1.0
var bag_turn := 0
var elapsed := 0.0

func play(state: Dictionary, editor: Control) -> void:
	z_index = 20
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background = Assets.PINE_NIGHT if state.get("place") == "pine" else LAKE_NIGHT
	for item in editor.items_root.get_children():
		var id: String = item.get_child(1).get_meta("item")
		var sprite: Sprite3D = item.get_child(0)
		var rect: Rect2 = editor.item_screen_rect(item)
		if id == "tent":
			tent_anchor = editor.screen_point(item.global_position)
			tent_width = rect.size.x
		elif id == "sleeping_bag":
			bag_turn = posmod(int(item.get_meta("rotation_degrees")) / 90, 4)
		else:
			props.append({"texture": sprite.texture, "rect": rect,
				"depth": editor.screen_point(item.global_position).y})
	props.sort_custom(func(a: Dictionary, b: Dictionary): return a.depth < b.depth)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= DURATION:
		set_process(false)
		finished.emit()

func _draw() -> void:
	if background == null: return
	var cover := maxf(size.x / background.get_width(), size.y / background.get_height())
	var backdrop_size := Vector2(background.get_size()) * cover
	draw_texture_rect(background, Rect2((size - backdrop_size) * .5, backdrop_size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color("10193138"))
	var width := minf(size.x * .88, size.y * .68)
	var tent_size := width * Vector2(1.0, float(TENT_INTERIOR.get_height()) / TENT_INTERIOR.get_width())
	var base := size * Vector2(.5, .77)
	var zoom := clampf(width / tent_width, 1.0, 2.15)
	for prop in props:
		var source: Rect2 = prop.rect
		var rect := Rect2(base + (source.position - tent_anchor) * zoom, source.size * zoom)
		draw_texture_rect(prop.texture, rect, false, Color("9ca5bd"))
	var tent_rect := Rect2(base - tent_size * Vector2(.5, 1.0), tent_size)
	var mirrored := bag_turn in [2, 3]
	if mirrored:
		draw_set_transform(base, 0, Vector2(-1, 1))
		draw_texture_rect(TENT_INTERIOR, Rect2(tent_rect.position - base, tent_size), false)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect(TENT_INTERIOR, tent_rect, false)
	var nose := tent_rect.position + tent_size * Vector2(.365 if mirrored else .635, .59)
	draw_sleep_bubble(nose, width / 170.0, -1.0 if mirrored else 1.0)

func draw_sleep_bubble(bubble_origin: Vector2, pixel: float, facing: float) -> void:
	if elapsed < 1.92:
		var whisper := bubble_origin + Vector2(-22 if facing > 0 else 5, -16 - minf(elapsed, 1.4) * 3) * pixel
		var font := ThemeDB.fallback_font
		var font_size := maxi(12, roundi(pixel * 8))
		draw_string_outline(font, whisper, "Zzz…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color("352538"))
		draw_string(font, whisper, "Zzz…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("fff1d7"))
		var swell := clampf(elapsed / 1.92, 0.0, 1.0) * (5.6 + sin(elapsed * TAU * 1.25))
		var center := bubble_origin + Vector2(-.8 * facing, -1) * swell * pixel
		draw_circle(center, maxf(0.5, swell * pixel), Color("c7ecff8c"), true, -1, true)
		draw_arc(center, maxf(.5, swell * pixel), 0, TAU, 24, Color("d7f5ff"), maxf(1.0, pixel * .55), true)
		draw_circle(center - Vector2.ONE * swell * pixel * .25, maxf(.5, pixel * .8), Color("f0fbff"), true, -1, true)
	elif elapsed < 2.25:
		var pop := (elapsed - 1.92) / .33
		var center := bubble_origin + Vector2(-4 * facing, -6) * pixel
		for ray in range(6):
			var outward := Vector2.from_angle(ray * TAU / 6.0)
			draw_line(center + outward * (5 + 4 * pop) * pixel,
				center + outward * (8 + 6 * pop) * pixel, Color(0.82, 0.95, 1, 1 - pop), maxf(1.0, pixel), true)
