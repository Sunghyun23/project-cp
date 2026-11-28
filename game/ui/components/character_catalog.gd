extends RefCounted

# MVP 외형 수는 확정, 현재 그림은 교체 가능한 프로토타입 어셋이다.
const FEMALE = preload("res://assets/pixel/camper-animations.png")
const MALE = preload("res://assets/pixel/camper-male-animations.png")
const MALE_RAIN = preload("res://assets/pixel/camper-male-rain.png")
const FEMALE_RAIN = preload("res://assets/pixel/camper-female-rain.png")
const ACTIONS = {
	"female_basic": preload("res://assets/pixel/characters/female/basic-actions.png"),
	"male_basic": preload("res://assets/pixel/characters/male/basic-actions.png"),
	"female_rain": preload("res://assets/pixel/characters/female/rain-actions.png"),
	"male_rain": preload("res://assets/pixel/characters/male/rain-actions.png")
}
const IDS = ["male", "female"]
const LABELS = {"male": "남성 캐릭터", "female": "여성 캐릭터"}

static func frames(id: String, outfit: String = "basic") -> SpriteFrames:
	var sheet: Texture2D = MALE if id == "male" else FEMALE
	if outfit == "rain":
		sheet = MALE_RAIN if id == "male" else FEMALE_RAIN
	var result := SpriteFrames.new()
	result.remove_animation("default")
	var cell := Vector2(sheet.get_size()) / Vector2(4, 2)
	for row in range(2):
		var animation := "idle" if row == 0 else "walk"
		result.add_animation(animation)
		result.set_animation_speed(animation, 1.0 if row == 0 else 7.0)
		for column in range(4):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(Vector2(column, row) * cell, cell)
			result.add_frame(animation, atlas, [2.2, 0.45, 0.12, 0.45][column] if row == 0 else 1.0)
	var actions: Texture2D = ACTIONS[(id if id in IDS else "female")+"_"+("rain" if outfit == "rain" else "basic")]
	var action_cell := Vector2(actions.get_size()) / Vector2(4,2)
	for column in range(4):
		# Pose names describe the original atlas. Chair rotation is mapped by chair metadata.
		var animation := "sit_%d"%(column*90)
		result.add_animation(animation)
		var atlas := AtlasTexture.new()
		atlas.atlas=actions
		atlas.region=Rect2(Vector2(column,0)*action_cell,action_cell)
		result.add_frame(animation,atlas)
	result.add_animation("install")
	result.set_animation_speed("install",5.0)
	for column in range(4):
		var atlas := AtlasTexture.new()
		atlas.atlas=actions
		atlas.region=Rect2(Vector2(column,1)*action_cell,action_cell)
		result.add_frame("install",atlas)
	return result
