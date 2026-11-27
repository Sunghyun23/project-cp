@tool
extends PanelContainer

@export_multiline var message: String = "귀가할 때 싣지 못한 물건은 잃어버려요.":
	set(value):
		message = value
		refresh()
@export_enum("안내", "주의", "손실·오류") var severity: int = 1:
	set(value):
		severity = clampi(value, 0, 2)
		refresh()

func _ready() -> void:
	refresh()

func refresh() -> void:
	theme_type_variation = ["InfoNotice", "WarningNotice", "DangerNotice"][severity]
	var label := get_node_or_null("Message") as Label
	if label:
		label.text = ["안내 · ", "주의 · ", "손실 · "][severity] + message
