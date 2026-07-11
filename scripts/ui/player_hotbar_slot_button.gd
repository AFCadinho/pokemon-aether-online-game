extends TextureButton

class_name PlayerHotbarSlotButton

signal bag_item_dropped(slot_index: int, item: Dictionary)

var slot_index := -1


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and str((data as Dictionary).get("kind", "")) == "bag_hotbar_item"


func _drop_data(_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_position, data):
		return
	var item: Variant = (data as Dictionary).get("item", {})
	if item is Dictionary:
		bag_item_dropped.emit(slot_index, (item as Dictionary).duplicate(true))
