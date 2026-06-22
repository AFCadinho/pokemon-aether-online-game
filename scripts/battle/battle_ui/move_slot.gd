extends Button

const TYPE_BANNER_PATH := "res://assets/sprites/types/small/%s.png"

signal selected
signal hovered(move_data: Dictionary, slot_rect: Rect2)
signal unhovered

@onready var type_banner: TextureRect = $MarginContainer/VBoxContainer/TopRow/TypeBanner
@onready var pp_label: Label = $MarginContainer/VBoxContainer/BottomRow/PPLabel
@onready var move_name_label: Label = $MarginContainer/VBoxContainer/TopRow/MoveNameLabel
@onready var effectiveness_label: Label = $MarginContainer/VBoxContainer/BottomRow/EffectivenessLabel

var current_move_data: Dictionary = {}

func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func set_move_data(move_data: Dictionary) -> void:
	visible = true
	current_move_data = move_data.duplicate(true)
	disabled = move_data.get("disabled", false) == true
	
	move_name_label.text = str(move_data.get("name", ""))
	
	var current_pp_value = move_data.get("pp", 0)
	var current_pp := 0

	if current_pp_value != null:
		current_pp = int(current_pp_value)

	var max_pp_value = _get_first_dictionary_value(move_data, ["maxpp", "maxPp", "maxPP", "max_pp"], current_pp)
	var max_pp := current_pp
	if max_pp < 0:
		max_pp = 0

	if max_pp_value != null:
		max_pp = int(max_pp_value)
	
	pp_label.text = "%s/%s" %[
		current_pp,
		max_pp
	]
	_set_type_banner(str(move_data.get("type", "")))
	
	_set_effectiveness(move_data)
	
func _set_type_banner(move_type: String) -> void:
	if move_type == "":
		type_banner.texture = null
		type_banner.visible = false
		return
		
	var path := TYPE_BANNER_PATH % move_type.to_lower()
	var texture := load(path) as Texture2D
	
	if texture == null:
		print("Missing type banner: ", path)
		type_banner.texture = null
		type_banner.visible = false
		return
		
	type_banner.texture = texture
	type_banner.visible = true
	
func set_empty() -> void:
	visible = true
	current_move_data = {}
	disabled = true
	move_name_label.text = "Empty"
	pp_label.text = "--/--"
	effectiveness_label.text = ""
	type_banner.texture = null
	type_banner.visible = false
	effectiveness_label.remove_theme_color_override("font_color")

	
func _set_effectiveness(move_data: Dictionary) -> void:
	var category := str(move_data.get("category", ""))
	
	if category == "Status":
		effectiveness_label.text = "status"
		effectiveness_label.add_theme_color_override("font_color", Color("#9aa7ff"))
		return
	
	var effectiveness = move_data.get("effectiveness", {})
	if typeof(effectiveness) != TYPE_DICTIONARY:
		effectiveness = {}
		
	var multiplier := float(effectiveness.get("multiplier", 1.0))
	var immune := bool(effectiveness.get("immune", false))
	
	if immune or multiplier == 0.0:
		effectiveness_label.text = "no effect"
		effectiveness_label.add_theme_color_override("font_color", Color("#d66a6a"))
	elif multiplier <1.0:
		effectiveness_label.text = "not effective"
		effectiveness_label.add_theme_color_override("font_color", Color("#d9a441"))
	elif multiplier > 1.0:
		effectiveness_label.text = "super effective"
		effectiveness_label.add_theme_color_override("font_color", Color("#65d46e"))
	else:
		effectiveness_label.text = "effective"
		effectiveness_label.add_theme_color_override("font_color", Color("#b8b8b8"))


func _get_first_dictionary_value(data: Dictionary, keys: Array[String], fallback: Variant) -> Variant:
	for key in keys:
		if data.has(key):
			return data.get(key)

	return fallback


func _on_pressed() -> void:
	if disabled:
		return
		
	selected.emit()


func _on_mouse_entered() -> void:
	if current_move_data.is_empty():
		return

	hovered.emit(current_move_data, get_global_rect())


func _on_mouse_exited() -> void:
	unhovered.emit()
	
