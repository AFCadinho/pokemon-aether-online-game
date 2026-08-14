extends Button

class_name HeldItemDropTargetButton

signal held_item_dropped(item: Dictionary)
signal drop_highlight_changed(highlighted: bool)

var held_item_drop_enabled := true


static func can_accept_drag_data(data: Variant) -> bool:
	return not item_from_drag_data(data).is_empty()


static func item_from_drag_data(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {}
	var payload := data as Dictionary
	if str(payload.get("kind", "")) not in ["bag_held_item", "bag_hotbar_item", "bag_hotbar_field_move"]:
		return {}
	var item_value: Variant = payload.get("item", {})
	if not item_value is Dictionary:
		return {}
	var item := item_value as Dictionary
	if not _is_holdable_item(item):
		return {}
	return item


static func _is_holdable_item(item: Dictionary) -> bool:
	if bool(item.get("isHoldable", false)):
		return true
	var category := str(item.get("category", "")).strip_edges().to_lower()
	var item_id := str(item.get("id", "")).strip_edges().to_lower().replace("_", "-")
	return (
		item_id in ["blue-orb", "red-orb"]
		or category in ["held_items", "power_stones"]
		or item_id.ends_with("berry")
		or item_id.ends_with("--held")
	)


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	var accepted := held_item_drop_enabled and not disabled and can_accept_drag_data(data)
	drop_highlight_changed.emit(accepted)
	return accepted


func _drop_data(_position: Vector2, data: Variant) -> void:
	var item := item_from_drag_data(data)
	if not held_item_drop_enabled or disabled or item.is_empty():
		return
	drop_highlight_changed.emit(false)
	held_item_dropped.emit(item.duplicate(true))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or (
		what == NOTIFICATION_MOUSE_EXIT
		and get_viewport() != null
		and get_viewport().gui_is_dragging()
	):
		drop_highlight_changed.emit(false)
