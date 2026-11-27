@tool
extends Button

## 시각 상태만 제공한다. 실제 적재 판정은 게임 로직의 책임이다.
@export_enum("빈 칸", "적재됨", "배치 불가") var state: int = 0:
	set(value):
		state = clampi(value, 0, 2)
		refresh()

func _ready() -> void:
	refresh()

func refresh() -> void:
	text = ["빈 칸", "✓ 적재", "× 불가"][state]
	theme_type_variation = ["GridEmpty", "GridOccupied", "GridInvalid"][state]
	tooltip_text = ["물건을 놓을 수 있는 빈 칸", "정상적으로 적재된 상태", "이 위치에는 물건을 놓을 수 없습니다"][state]
