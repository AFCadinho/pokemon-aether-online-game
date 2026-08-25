extends Button

const MOVE_DISPLAY_TYPE := preload("res://scripts/battle/battle_ui/move_display_type.gd")
const TYPE_BANNER_PATH := "res://assets/sprites/types/small/%s.png"
const MOVE_TYPE_INDEX_PATH := "res://data/move_type_index.json"
const NEUTRAL_BACKGROUND := Color("#020612f5")
const NEUTRAL_BORDER := Color("#1e60b4dc")
const DISABLED_BACKGROUND := Color("#10131af0")
const DISABLED_MODULATE := Color(0.42, 0.45, 0.52, 0.72)
const Z_MOVE_BORDER := Color("#ffd35a")
const Z_MOVE_GLOW := Color("#ff8a2a")

signal selected
signal hovered(move_data: Dictionary, slot_rect: Rect2)
signal unhovered

@onready var type_banner: TextureRect = $MarginContainer/VBoxContainer/TopRow/TypeBanner
@onready var pp_label: Label = $MarginContainer/VBoxContainer/BottomRow/PPLabel
@onready var move_name_label: Label = $MarginContainer/VBoxContainer/TopRow/MoveNameLabel
@onready var effectiveness_label: Label = $MarginContainer/VBoxContainer/BottomRow/EffectivenessLabel

var current_move_data: Dictionary = {}
var localization_manager: Node
static var move_type_index: Dictionary = {}
static var move_type_index_loaded := false

func _ready() -> void:
	localization_manager = get_tree().root.get_node_or_null("LocalizationManager")
	if localization_manager != null and not localization_manager.locale_changed.is_connected(_on_locale_changed):
		localization_manager.locale_changed.connect(_on_locale_changed)
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
	modulate = DISABLED_MODULATE if disabled else Color.WHITE
	tooltip_text = str(move_data.get("disabledReason", "")) if disabled else ""
	
	move_name_label.text = _localized_move_name(move_data)
	
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
	var is_z_move := bool(move_data.get("zMove", false))
	_apply_type_style(move_type, disabled, is_z_move)
	
	if bool(move_data.get("zMoveUnavailable", false)):
		effectiveness_label.text = _t("battle.move.no_z_move")
		effectiveness_label.add_theme_color_override("font_color", Color("#9ba5b8"))
	elif is_z_move:
		effectiveness_label.text = _t("battle.move.z_power")
		effectiveness_label.add_theme_color_override("font_color", Z_MOVE_BORDER)
		tooltip_text = _t("battle.move.z_power_tooltip")
	else:
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


func _apply_type_style(move_type: String, is_disabled: bool, is_z_move := false) -> void:
	var background := NEUTRAL_BACKGROUND
	var border := NEUTRAL_BORDER
	var accent := Color("#d8dee9")
	if move_type != "":
		background = TypeColors.get_slot_background(move_type, NEUTRAL_BACKGROUND)
		border = TypeColors.get_slot_border(move_type, NEUTRAL_BORDER)
		accent = TypeColors.get_slot_accent(move_type, border)

	# Keep the text surface dark, but make each move type immediately recognisable
	# through a saturated card tint and a deliberately heavier top/left type edge.
	var type_surface := background.lerp(border, 0.18)
	var normal := _make_slot_style(type_surface, border, 1)
	var hover := _make_slot_style(type_surface.lightened(0.08), accent, 2)
	hover.shadow_color = Color(border.r, border.g, border.b, 0.22)
	hover.shadow_size = 10
	hover.shadow_offset = Vector2(0, 3)
	var pressed := _make_slot_style(type_surface.darkened(0.08), accent, 2)
	var disabled_style := _make_slot_style(type_surface.lerp(DISABLED_BACKGROUND, 0.58), Color(border.r, border.g, border.b, 0.38), 1)
	if is_z_move and not is_disabled:
		normal = _make_slot_style(type_surface.lerp(Color("#6b3b17"), 0.34), Z_MOVE_BORDER, 2)
		normal.shadow_color = Color(Z_MOVE_GLOW.r, Z_MOVE_GLOW.g, Z_MOVE_GLOW.b, 0.38)
		normal.shadow_size = 12
		normal.shadow_offset = Vector2(0, 3)
		hover = _make_slot_style(type_surface.lightened(0.12), Z_MOVE_BORDER.lightened(0.1), 3)
		hover.shadow_color = Color(Z_MOVE_GLOW.r, Z_MOVE_GLOW.g, Z_MOVE_GLOW.b, 0.58)
		hover.shadow_size = 16
		hover.shadow_offset = Vector2(0, 3)
		pressed = _make_slot_style(type_surface.darkened(0.04), Z_MOVE_BORDER, 3)

	add_theme_stylebox_override("normal", disabled_style if is_disabled else normal)
	add_theme_stylebox_override("hover", disabled_style if is_disabled else hover)
	add_theme_stylebox_override("pressed", disabled_style if is_disabled else pressed)
	add_theme_stylebox_override("disabled", disabled_style)
	add_theme_stylebox_override("focus", disabled_style if is_disabled else normal)


func _make_slot_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width + 3
	style.border_width_top = border_width + 2
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
	var display_type := MOVE_DISPLAY_TYPE.resolve(move_data)
	if display_type != "":
		return display_type

	var metadata_value: Variant = move_data.get("metadata", move_data.get("data", {}))
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


func _localized_move_name(move_data: Dictionary) -> String:
	var fallback_name := str(move_data.get(
		"name",
		move_data.get("move", move_data.get("id", ""))
	)).strip_edges()
	var move_id := str(move_data.get(
		"id",
		move_data.get("move", move_data.get("moveId", move_data.get("move_id", fallback_name)))
	))
	var content_localization := get_node_or_null("/root/ContentLocalization")
	if content_localization != null and content_localization.has_method("display_name"):
		return str(content_localization.call("display_name", "moves", move_id, fallback_name))
	return fallback_name
	
func set_empty() -> void:
	visible = true
	current_move_data = {}
	disabled = true
	modulate = DISABLED_MODULATE
	tooltip_text = ""
	move_name_label.text = _t("battle.move.empty")
	pp_label.text = "--/--"
	effectiveness_label.text = ""
	type_banner.texture = null
	type_banner.visible = false
	effectiveness_label.remove_theme_color_override("font_color")
	_apply_type_style("", true)

	
func _set_effectiveness(move_data: Dictionary) -> void:
	var category := str(move_data.get("category", ""))
	
	if category == "Status":
		effectiveness_label.text = _t("battle.move.effect.status")
		effectiveness_label.add_theme_color_override("font_color", Color("#9aa7ff"))
		return
	
	var effectiveness = move_data.get("effectiveness", {})
	if typeof(effectiveness) != TYPE_DICTIONARY:
		effectiveness = {}
		
	var multiplier := float(effectiveness.get("multiplier", 1.0))
	var immune := bool(effectiveness.get("immune", false))
	
	if immune or multiplier == 0.0:
		effectiveness_label.text = _t("battle.move.effect.none")
		effectiveness_label.add_theme_color_override("font_color", Color("#d66a6a"))
	elif multiplier <1.0:
		effectiveness_label.text = _t("battle.move.effect.resisted")
		effectiveness_label.add_theme_color_override("font_color", Color("#d9a441"))
	elif multiplier > 1.0:
		effectiveness_label.text = _t("battle.move.effect.super")
		effectiveness_label.add_theme_color_override("font_color", Color("#65d46e"))
	else:
		effectiveness_label.text = _t("battle.move.effect.normal")
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


func _on_locale_changed(_locale: String) -> void:
	if current_move_data.is_empty():
		set_empty()
	else:
		set_move_data(current_move_data)


func _t(key: String, replacements: Dictionary = {}) -> String:
	if localization_manager != null:
		return str(localization_manager.call("text", key, replacements))
	return key
