extends Control

class_name TrainerAvatarPreview

const TRAINER_HEAD_PORTRAIT_SCRIPT := preload("res://scripts/ui/trainer_head_portrait.gd")

var trainer_state: Dictionary = {}
var fallback_text := "?"
var portrait: TrainerHeadPortrait
var fallback_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(42, 42)
	_build_visuals()
	_refresh_visuals()


func set_trainer_state(state: Dictionary, fallback: String = "?") -> void:
	trainer_state = state.duplicate(true)
	fallback_text = fallback.strip_edges().left(2).to_upper()
	if fallback_text == "":
		fallback_text = "?"
	if is_inside_tree():
		_build_visuals()
		_refresh_visuals()


func _build_visuals() -> void:
	if portrait != null and is_instance_valid(portrait):
		return
	portrait = TRAINER_HEAD_PORTRAIT_SCRIPT.new() as TrainerHeadPortrait
	portrait.name = "SpritePortrait"
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.custom_minimum_size = Vector2.ZERO
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)

	fallback_label = Label.new()
	fallback_label.name = "InitialsFallback"
	fallback_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback_label.add_theme_font_size_override("font_size", 14)
	fallback_label.add_theme_color_override("font_color", Color("#8fe4ff"))
	fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fallback_label)


func _refresh_visuals() -> void:
	if portrait == null or fallback_label == null:
		return
	var appearance := _appearance_from_trainer_state(trainer_state)
	var has_appearance := not appearance.is_empty()
	portrait.visible = has_appearance
	fallback_label.visible = not has_appearance
	fallback_label.text = fallback_text
	if has_appearance:
		portrait.set_appearance_state(appearance)


func _appearance_from_trainer_state(state: Dictionary) -> Dictionary:
	var appearance_value: Variant = state.get("appearance", {})
	var appearance: Dictionary = (
		(appearance_value as Dictionary).duplicate(true)
		if appearance_value is Dictionary
		else {}
	)
	if appearance.is_empty():
		return {}
	var gender := str(state.get("gender", appearance.get("gender", ""))).strip_edges()
	if gender != "":
		appearance["gender"] = gender
	return appearance
