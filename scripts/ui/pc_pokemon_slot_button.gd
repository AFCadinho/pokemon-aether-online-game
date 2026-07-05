extends Button

class_name PcPokemonSlotButton

signal slot_dropped(source: Dictionary, target: Dictionary)

const DRAG_KIND := "pokemon_pc_slot"

var drag_source: Dictionary = {}
var drop_target: Dictionary = {}
var drag_title := "Pokemon"
var drag_subtitle := ""
var drag_texture: Texture2D


func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled or drag_source.is_empty():
		return null

	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(150, 44)
	preview.modulate = Color(1, 1, 1, 0.88)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	preview.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = drag_texture
	row.add_child(icon)

	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_stack)

	var title := Label.new()
	title.text = drag_title
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = drag_subtitle
	subtitle.clip_text = true
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle.add_theme_font_size_override("font_size", 11)
	text_stack.add_child(subtitle)

	set_drag_preview(preview)
	return {
		"kind": DRAG_KIND,
		"source": drag_source.duplicate(true),
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if drop_target.is_empty() or not (data is Dictionary):
		return false

	var payload: Dictionary = data
	if str(payload.get("kind", "")) != DRAG_KIND:
		return false

	var source := _dictionary_from_variant(payload.get("source", {}))
	if source.is_empty():
		return false

	return not _locations_match(source, drop_target)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return

	var payload: Dictionary = data
	var source := _dictionary_from_variant(payload.get("source", {}))
	slot_dropped.emit(source.duplicate(true), drop_target.duplicate(true))


static func _locations_match(a: Dictionary, b: Dictionary) -> bool:
	var a_type := str(a.get("type", ""))
	if a_type != str(b.get("type", "")):
		return false
	if a_type == "party":
		return int(a.get("partySlot", -1)) == int(b.get("partySlot", -2))
	if a_type == "box":
		return int(a.get("boxIndex", -1)) == int(b.get("boxIndex", -2)) and int(a.get("slotIndex", -1)) == int(b.get("slotIndex", -2))
	return false


static func _dictionary_from_variant(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
