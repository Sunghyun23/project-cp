extends RefCounted

# MVP 외형 수는 확정, 현재 그림은 교체 가능한 프로토타입 어셋이다.
const FEMALE = preload("res://assets/pixel/camper-animations.png")
const MALE = preload("res://assets/pixel/camper-male-animations.png")
const MALE_RAIN = preload("res://assets/pixel/camper-male-rain.png")
const FEMALE_RAIN = preload("res://assets/pixel/camper-female-rain.png")
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
	return result
