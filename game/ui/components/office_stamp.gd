extends Button

signal paper_received
var case_id := ""

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return not disabled and data is Dictionary and not case_id.is_empty() and data.get("office_case","")==case_id

func _drop_data(at: Vector2,data: Variant) -> void:
	if _can_drop_data(at,data): paper_received.emit()
