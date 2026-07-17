extends Button

const TYPE_BANNER_PATH := "res://assets/sprites/types/small/%s.png"
const MOVE_TYPE_INDEX_PATH := "res://data/move_type_index.json"
const NEUTRAL_BACKGROUND := Color("#020612f5")
const NEUTRAL_BORDER := Color("#1e60b4dc")
const DISABLED_BACKGROUND := Color("#10131af0")

signal selected
signal hovered(move_data: Dictionary, slot_rect: Rect2)
signal unhovered

@onready var type_banner: TextureRect = $MarginContainer/VBoxContainer/TopRow/TypeBanner
@onready var pp_label: Label = $MarginContainer/VBoxContainer/BottomRow/PPLabel
@onready var move_name_label: Label = $MarginContainer/VBoxContainer/TopRow/MoveNameLabel
@onready var effectiveness_label: Label = $MarginContainer/VBoxContainer/BottomRow/EffectivenessLabel

var current_move_data: Dictionary = {}
static var move_type_index: Dictionary = {}
static var move_type_index_loaded := false

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
	var move_type := _get_move_type(move_data)
	_set_type_banner(move_type)
	_apply_type_style(move_type, disabled)
	
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


func _apply_type_style(move_type: String, is_disabled: bool) -> void:
	var background := NEUTRAL_BACKGROUND
	var border := NEUTRAL_BORDER
	if move_type != "":
		background = TypeColors.get_slot_background(move_type, NEUTRAL_BACKGROUND)
		border = TypeColors.get_slot_border(move_type, NEUTRAL_BORDER)

	var normal := _make_slot_style(background, border, 1)
	var hover := _make_slot_style(background.lightened(0.08), border.lightened(0.18), 2)
	hover.shadow_color = Color(border.r, border.g, border.b, 0.22)
	hover.shadow_size = 10
	hover.shadow_offset = Vector2(0, 3)
	var pressed := _make_slot_style(background.darkened(0.08), border, 2)
	var disabled_style := _make_slot_style(background.lerp(DISABLED_BACKGROUND, 0.58), Color(border.r, border.g, border.b, 0.38), 1)

	add_theme_stylebox_override("normal", disabled_style if is_disabled else normal)
	add_theme_stylebox_override("hover", disabled_style if is_disabled else hover)
	add_theme_stylebox_override("pressed", disabled_style if is_disabled else pressed)
	add_theme_stylebox_override("disabled", disabled_style)
	add_theme_stylebox_override("focus", disabled_style if is_disabled else normal)


func _make_slot_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	return style


func _get_move_type(move_data: Dictionary) -> String:
	for key in ["type", "moveType", "move_type"]:
		var type_text := str(move_data.get(key, "")).strip_edges()
		if type_text != "":
			return type_text

	var metadata_value: Variant = move_data.get("metadata", move_data.get("data", {}))
	if metadata_value is Dictionary:
		var metadata: Dictionary = metadata_value as Dictionary
		for key in ["type", "moveType", "move_type"]:
			var type_text := str(metadata.get(key, "")).strip_edges()
			if type_text != "":
				return type_text

	for key in ["id", "move", "moveId", "move_id", "name"]:
		var indexed_type := _lookup_move_type(str(move_data.get(key, "")))
		if indexed_type != "":
			return indexed_type

	if metadata_value is Dictionary:
		var metadata: Dictionary = metadata_value as Dictionary
		for key in ["id", "move", "moveId", "move_id", "name"]:
			var indexed_type := _lookup_move_type(str(metadata.get(key, "")))
			if indexed_type != "":
				return indexed_type

	return ""


func _lookup_move_type(move_key: String) -> String:
	var normalized_key := _normalize_move_lookup_key(move_key)
	if normalized_key == "":
		return ""

	_ensure_move_type_index_loaded()
	if move_type_index.is_empty():
		return ""

	return str(move_type_index.get(normalized_key, ""))


func _ensure_move_type_index_loaded() -> void:
	if move_type_index_loaded:
		return

	move_type_index_loaded = true
	move_type_index.clear()

	if not FileAccess.file_exists(MOVE_TYPE_INDEX_PATH):
		return

	var json_text := FileAccess.get_file_as_string(MOVE_TYPE_INDEX_PATH)
	if json_text.strip_edges() == "":
		return

	var parsed_value: Variant = JSON.parse_string(json_text)
	if not (parsed_value is Dictionary):
		return

	var parsed_dictionary: Dictionary = parsed_value as Dictionary
	for key_value: Variant in parsed_dictionary.keys():
		var normalized_key := _normalize_move_lookup_key(str(key_value))
		var move_type := str(parsed_dictionary.get(key_value, "")).strip_edges().to_lower()
		if normalized_key != "" and move_type != "":
			move_type_index[normalized_key] = move_type


func _normalize_move_lookup_key(value: String) -> String:
	var normalized_key := value.strip_edges().to_lower()
	if normalized_key == "":
		return ""

	normalized_key = normalized_key.replace("_", "-")
	normalized_key = normalized_key.replace(" ", "-")
	while normalized_key.contains("--"):
		normalized_key = normalized_key.replace("--", "-")

	return normalized_key
	
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
	_apply_type_style("", true)

	
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
	
