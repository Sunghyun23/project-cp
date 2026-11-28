extends RefCounted

const FIELD_FURNITURE = preload("res://assets/pixel/field-furniture.png")
const STARTER_FURNITURE = preload("res://assets/pixel/starter-furniture.png")
const WORN_TENT = preload("res://assets/pixel/items/worn_tent/directions.png")
const UPGRADED_SLEEPING_BAG = preload("res://assets/pixel/items/upgraded_sleeping_bag/directions.png")
static var reference_gear: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel/items/reference-gear.json"))
const STARTER = preload("res://assets/pixel/starter-gear.png")
const PROPS = preload("res://assets/pixel/camping-props.png")
const PINE = preload("res://assets/pixel/campsite-pine-terrain.png")
const PINE_NIGHT = preload("res://assets/pixel/places/pine/night.png")
const LAKE = preload("res://assets/pixel/campsite-day-terrain.png")
const DIRECTIONAL_PROPS = preload("res://assets/pixel/camping-props-directions.png")
static var directional_meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel/camping-props-directions-metadata.json"))
const INDICES = {"tent":0, "chair":1, "table":2, "lantern":3, "stove":4, "rug":5}
const CARGO_COLORS = {"tent":"b96349", "chair":"556ca2", "table":"917047", "lantern":"96753a", "stove":"4e7d75", "rug":"8e5d83", "meal":"667e46", "rainwear":"4f6f97", "sleeping_bag":"536584"}

static func cargo_color(id: String) -> Color:
	return Color(CARGO_COLORS.get(id, "72856b"))

static func starter_texture(row: int, frame: int) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = STARTER
	atlas.region = Rect2(frame * 160, row * 160, 160, 160)
	return atlas

static func reference_gear_key(id: String, upgraded: bool) -> String:
	if id == "tent" and not upgraded: return "worn_tent"
	if id == "sleeping_bag" and upgraded: return "upgraded_sleeping_bag"
	return ""

static func reference_texture(key: String, angle: int = 0) -> Texture2D:
	var source: Texture2D=WORN_TENT if key == "worn_tent" else UPGRADED_SLEEPING_BAG
	var cell := Vector2(source.get_size())/2.0
	var frame := posmod(angle/90,4)
	var texture := AtlasTexture.new()
	texture.atlas=source
	texture.region=Rect2(Vector2(frame%2,frame/2)*cell,cell)
	return texture

static func item_texture(id: String, upgraded: bool = false) -> Texture2D:
	var reference := reference_gear_key(id,upgraded)
	if not reference.is_empty(): return reference_texture(reference)
	if id == "sleeping_bag": return starter_texture(4, 1 if upgraded else 0)
	if not upgraded:
		if id in ["table", "chair"]: return field_texture(id)
		if id in ["tent", "stove", "lantern"]:
			return starter_texture(0 if id == "tent" else 1 if id == "stove" else 5, 0)
	if not INDICES.has(id):
		return null
	var atlas := AtlasTexture.new()
	var cell := Vector2(PROPS.get_size()) / Vector2(3, 2)
	var index: int = INDICES[id]
	atlas.atlas = PROPS
	atlas.region = Rect2(Vector2(index % 3, index / 3) * cell, cell)
	return atlas

static func weather_name(id: String) -> String:
	return {"sun":"맑음", "cloud":"흐림", "rain":"비"}.get(id, id)

static func current_weather(state: Dictionary) -> String:
	var days: Array = state.get("weather", [])
	if days.size() < 7:
		return "sun"
	return days[5 + int(state.get("camp_day", 0))].weather

static func suitable(state: Dictionary) -> bool:
	var weather := current_weather(state)
	return state.get("outfit", "basic") == "rain" if weather == "rain" else weather != "sun" or state.get("outfit", "basic") == "basic"

static func uses_starter_atlas(id: String, upgraded: bool) -> bool:
	return id == "sleeping_bag" or (not upgraded and id in ["tent", "stove", "lantern"])

static func field_texture(id: String, angle: int = 0, upgraded: bool = false) -> Texture2D:
	var reference := reference_gear_key(id,upgraded)
	if not reference.is_empty(): return reference_texture(reference,angle)
	if uses_starter_atlas(id, upgraded):
		var canvas_row := 0 if id == "tent" else 1 if id == "stove" else 5 if id == "lantern" else 3 if upgraded else 2
		return starter_texture(canvas_row, posmod(angle / 90, 4))
	if id in ["table", "chair"]:
		var furniture := AtlasTexture.new()
		furniture.atlas = FIELD_FURNITURE if upgraded else STARTER_FURNITURE
		furniture.region = Rect2(Vector2i(posmod(angle / 90, 4), 0 if id == "table" else 1) * 256, Vector2i(256, 256))
		return furniture
	if not directional_meta.items.has(id): return item_texture(id)
	var item: Dictionary = directional_meta.items[id]
	var cell := Vector2(directional_meta.cell_size_px[0],directional_meta.cell_size_px[1])
	var atlas := AtlasTexture.new()
	atlas.atlas=DIRECTIONAL_PROPS
	atlas.region=Rect2(Vector2((angle/90)%4,item.row)*cell,cell)
	return atlas

static func field_pivot(id: String, angle: int, upgraded: bool = false) -> Vector2:
	var reference := reference_gear_key(id,upgraded)
	if not reference.is_empty():
		var meta: Dictionary=reference_gear[reference]
		var pivot: Array=meta.pivot_px_by_angle[str(posmod(angle,360))]
		return Vector2(float(pivot[0])/float(meta.cell_size_px[0]),float(pivot[1])/float(meta.cell_size_px[1]))
	if uses_starter_atlas(id, upgraded): return Vector2(.5, .8)
	if id in ["table", "chair"]: return Vector2(.5, .75)
	var point: Array = directional_meta.items[id].frames[(angle/90)%4].pivot_px
	return Vector2(float(point[0])/directional_meta.cell_size_px[0],float(point[1])/directional_meta.cell_size_px[1])

static func field_sprite_width(id: String, upgraded: bool = false) -> float:
	var reference := reference_gear_key(id,upgraded)
	if not reference.is_empty(): return float(reference_gear[reference].sprite_world_width)
	if uses_starter_atlas(id, upgraded):
		return 3.65 if id == "tent" else 2.4 if id == "stove" else 1.30 if id == "lantern" else 160.0 / 52.0
	if id in ["table", "chair"]: return 256.0 / 47.0
	return float(directional_meta.items[id].sprite_world_width)

static func seated_animation(chair_angle: int) -> String:
	return str(directional_meta.items.chair.interaction.character_animation_by_angle[str(posmod(chair_angle,360))])

static func field_sprite_scale_y(id: String, upgraded: bool = false) -> float:
	var reference := reference_gear_key(id,upgraded)
	return float(reference_gear[reference].get("sprite_scale_y",1.0)) if not reference.is_empty() else 1.0
