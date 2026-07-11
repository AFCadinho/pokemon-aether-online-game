extends TextureButton

class_name PlayerHotbarSlotButton

signal bag_item_dropped(slot_index: int, item: Dictionary)
signal hotbar_entry_dropped(source_slot: int, target_slot: int)
signal drop_highlight_changed(slot_index: int, highlighted: bool)

var slot_index := -1
var hotbar_entry: Dictionary = {}
var preview_texture: Texture2D


func _get_drag_data(_position: Vector2) -> Variant:
	if hotbar_entry.is_empty():
		return null
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(42, 42)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.top_level = true
	preview.z_as_relative = false
	preview.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	preview.texture = preview_texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if get_viewport() != null and get_viewport().gui_is_dragging():
		set_drag_preview(preview)
	else:
		preview.queue_free()
	return {"kind": "hotbar_entry", "sourceSlot": slot_index}


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var kind := str((data as Dictionary).get("kind", ""))
	var accepted := kind == "bag_hotbar_item" or (kind == "hotbar_entry" and int((data as Dictionary).get("sourceSlot", -1)) != slot_index)
	if accepted:
		drop_highlight_changed.emit(slot_index, true)
	return accepted


func _drop_data(_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_position, data):
		return
	drop_highlight_changed.emit(slot_index, false)
	if str((data as Dictionary).get("kind", "")) == "hotbar_entry":
		hotbar_entry_dropped.emit(int((data as Dictionary).get("sourceSlot", -1)), slot_index)
		return
	var item: Variant = (data as Dictionary).get("item", {})
	if item is Dictionary:
		bag_item_dropped.emit(slot_index, (item as Dictionary).duplicate(true))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or (what == NOTIFICATION_MOUSE_EXIT and get_viewport() != null and get_viewport().gui_is_dragging()):
		drop_highlight_changed.emit(slot_index, false)
