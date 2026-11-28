extends RefCounted

const FIELD_FURNITURE = preload("res://assets/pixel/field-furniture.png")
const PROPS = preload("res://assets/pixel/camping-props.png")
const PINE = preload("res://assets/pixel/campsite-pine-terrain.png")
const PINE_NIGHT = preload("res://assets/pixel/places/pine/night.png")
const LAKE = preload("res://assets/pixel/campsite-day-terrain.png")
const DIRECTIONAL_PROPS = preload("res://assets/pixel/camping-props-directions.png")
static var directional_meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel/camping-props-directions-metadata.json"))
const INDICES = {"tent":0, "chair":1, "table":2, "lantern":3, "stove":4, "rug":5}
const CARGO_COLORS = {"tent":"b96349", "chair":"556ca2", "table":"917047", "lantern":"96753a", "stove":"4e7d75", "rug":"8e5d83", "meal":"667e46", "rainwear":"4f6f97"}

static func cargo_color(id: String) -> Color:
	return Color(CARGO_COLORS.get(id, "72856b"))

static func item_texture(id: String) -> Texture2D:
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

static func field_texture(id: String, angle: int = 0) -> Texture2D:
	if id in ["table", "chair"]:
		var furniture := AtlasTexture.new()
		furniture.atlas = FIELD_FURNITURE
		furniture.region = Rect2(Vector2i(posmod(angle / 90, 4), 0 if id == "table" else 1) * 256, Vector2i(256, 256))
		return furniture
	if not directional_meta.items.has(id): return item_texture(id)
	var item: Dictionary = directional_meta.items[id]
	var cell := Vector2(directional_meta.cell_size_px[0],directional_meta.cell_size_px[1])
	var atlas := AtlasTexture.new()
	atlas.atlas=DIRECTIONAL_PROPS
	atlas.region=Rect2(Vector2((angle/90)%4,item.row)*cell,cell)
	return atlas

static func field_pivot(id: String, angle: int) -> Vector2:
	if id in ["table", "chair"]: return Vector2(.5, .75)
	var point: Array = directional_meta.items[id].frames[(angle/90)%4].pivot_px
	return Vector2(float(point[0])/directional_meta.cell_size_px[0],float(point[1])/directional_meta.cell_size_px[1])

static func field_sprite_width(id: String) -> float:
	if id in ["table", "chair"]: return 256.0 / 47.0
	return float(directional_meta.items[id].sprite_world_width)
