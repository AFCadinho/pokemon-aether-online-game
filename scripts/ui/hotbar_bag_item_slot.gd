extends PanelContainer

class_name HotbarBagItemSlot

const HeldItemDropTarget := preload("res://scripts/ui/held_item_drop_target_button.gd")

var hotbar_item: Dictionary = {}
var icon_texture: Texture2D


func _get_drag_data(_position: Vector2) -> Variant:
	if hotbar_item.is_empty():
		return null
	var item_id := str(hotbar_item.get("id", ""))
	var gameplay: Variant = hotbar_item.get("gameplay", {})
	var field_move_id := str(hotbar_item.get("fieldMove", "")).strip_edges()
	var hotbar_eligible := (
		item_id == "escape-rope-action"
		or field_move_id != ""
		or (gameplay is Dictionary and not (gameplay as Dictionary).is_empty())
	)
	var held_item_eligible := HeldItemDropTarget.can_accept_drag_data({
		"kind": "bag_held_item",
		"item": hotbar_item,
	})
	if not hotbar_eligible and not held_item_eligible:
		return null
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(42, 42)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.top_level = true
	preview.z_as_relative = false
	preview.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	preview.texture = icon_texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if get_viewport() != null and get_viewport().gui_is_dragging():
		set_drag_preview(preview)
	else:
		preview.queue_free()
	return {
		"kind": (
			"bag_hotbar_field_move" if field_move_id != ""
			else "bag_hotbar_item" if hotbar_eligible
			else "bag_held_item"
		),
		"item": hotbar_item.duplicate(true),
		"moveId": field_move_id,
		"moveName": field_move_id.replace("_", "-").replace("-", " ").capitalize(),
	}
