extends PanelContainer

class_name HotbarBagItemSlot

var hotbar_item: Dictionary = {}
var icon_texture: Texture2D


func _get_drag_data(_position: Vector2) -> Variant:
	if hotbar_item.is_empty():
		return null
	var item_id := str(hotbar_item.get("id", ""))
	var gameplay: Variant = hotbar_item.get("gameplay", {})
	if item_id != "escape-rope-action" and (not gameplay is Dictionary or (gameplay as Dictionary).is_empty()):
		return null
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(42, 42)
	preview.texture = icon_texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {
		"kind": "bag_hotbar_item",
		"item": hotbar_item.duplicate(true),
	}
