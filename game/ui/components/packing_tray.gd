extends HFlowContainer

signal item_unpacked(id: String)
var packed_ids: Array = []
var interactive := true

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return interactive and data is Dictionary and data.get("packing_item","") in packed_ids

func _drop_data(at: Vector2, data: Variant) -> void:
	if _can_drop_data(at,data): item_unpacked.emit(data.packing_item)
