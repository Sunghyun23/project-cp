extends RefCounted

const PROPS = preload("res://assets/pixel/camping-props.png")
const PINE = preload("res://assets/pixel/campsite-pine-terrain.png")
const LAKE = preload("res://assets/pixel/campsite-day-terrain.png")
const INDICES = {"tent":0, "chair":1, "table":2, "lantern":3, "stove":4, "rug":5}
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
