extends PanelContainer

class_name PokemonHoverCard

const TYPE_ICON_DIR := "res://assets/sprites/types"
const SPECIES_PATH := "res://data/pokemon/species/%s.json"
const LOW_SPEED_COLOR := Color(0.9372549, 0.26666668, 0.26666668, 1.0)
const HIGH_SPEED_COLOR := Color(0.3882353, 0.83137256, 0.44313726, 1.0)

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var type_icon_1: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer/TypeIcon
@onready var type_icon_2: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer/TypeIcon2
@onready var ability_row: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer2
@onready var ability_label: Label = $MarginContainer/VBoxContainer/HBoxContainer2/AbilityLabel
@onready var ability_value_label: Label = $MarginContainer/VBoxContainer/HBoxContainer2/AbilityLabel2
@onready var item_label: Label = $MarginContainer/VBoxContainer/ItemLabel
@onready var boosts_row: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer4
@onready var boosts_value_label: Label = $MarginContainer/VBoxContainer/HBoxContainer4/BoostsLabel2
@onready var drops_row: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer5
@onready var drops_value_label: Label = $MarginContainer/VBoxContainer/HBoxContainer5/DropsLabel2
@onready var speed_row: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer3
@onready var lowest_speed_label: Label = $MarginContainer/VBoxContainer/HBoxContainer3/LowestSpeedLabel
@onready var lowest_neutral_speed_label: Label = $MarginContainer/VBoxContainer/HBoxContainer3/LowestNeutralSpeedlabel
@onready var highest_neutral_speed_label: Label = $MarginContainer/VBoxContainer/HBoxContainer3/HighestNeutralSpeedLabel
@onready var highest_speed_label: Label = $MarginContainer/VBoxContainer/HBoxContainer3/HighestSpeedLabel
@onready var moves_separator: ColorRect = $MarginContainer/VBoxContainer/SeperationLabel3
@onready var move_label_1: Label = $MarginContainer/VBoxContainer/VBoxContainer/MoveLabel
@onready var move_label_2: Label = $MarginContainer/VBoxContainer/VBoxContainer/MoveLabel2
@onready var move_label_3: Label = $MarginContainer/VBoxContainer/VBoxContainer/MoveLabel3
@onready var move_label_4: Label = $MarginContainer/VBoxContainer/VBoxContainer/MoveLabel4

var move_labels: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_labels = [move_label_1, move_label_2, move_label_3, move_label_4]
	lowest_speed_label.add_theme_color_override("font_color", LOW_SPEED_COLOR)
	highest_speed_label.add_theme_color_override("font_color", HIGH_SPEED_COLOR)
	hide_card()


func show_for_pokemon(
	pokemon_data: Dictionary,
	confirmed_moves: Array = [],
	confirmed_item: String = "",
	confirmed_ability: String = "",
	stat_changes: Dictionary = {},
	speed_data: Dictionary = {}
) -> void:
	set_pokemon_data(pokemon_data, confirmed_moves, confirmed_item, confirmed_ability, stat_changes, speed_data)
	visible = true


func hide_card() -> void:
	visible = false


func set_pokemon_data(
	pokemon_data: Dictionary,
	confirmed_moves: Array = [],
	confirmed_item: String = "",
	confirmed_ability: String = "",
	stat_changes: Dictionary = {},
	speed_data: Dictionary = {}
) -> void:
	var species_name: String = _get_species_name(pokemon_data)
	name_label.text = species_name if species_name != "" else "Unknown"

	_set_type_icons(PokemonFactory.get_species_types(species_name))
	_set_abilities(_get_possible_abilities(species_name), confirmed_ability)
	_set_item(confirmed_item)
	_set_stat_changes(stat_changes)
	_set_speed_data(speed_data)
	_set_moves(_get_display_moves(confirmed_moves))


func position_near_mouse(mouse_position: Vector2, viewport_size: Vector2) -> void:
	var padding := 12.0
	var card_size: Vector2 = size
	var target_position := mouse_position + Vector2(padding, padding)

	if target_position.x + card_size.x > viewport_size.x:
		target_position.x = mouse_position.x - card_size.x - padding
	if target_position.y + card_size.y > viewport_size.y:
		target_position.y = mouse_position.y - card_size.y - padding

	global_position = target_position


func _get_species_name(pokemon_data: Dictionary) -> String:
	var details: String = str(pokemon_data.get("details", ""))
	if details != "":
		return details.split(",")[0].strip_edges()

	var species: String = str(pokemon_data.get("species", ""))
	if species != "":
		return species

	var ident: String = str(pokemon_data.get("ident", ""))
	if ident.contains(":"):
		return ident.split(":", false, 1)[1].strip_edges()

	return ident.strip_edges()


func _set_type_icons(types: Array) -> void:
	var icons: Array[TextureRect] = [type_icon_1, type_icon_2]
	for index in range(icons.size()):
		var icon: TextureRect = icons[index]
		if index >= types.size():
			icon.visible = false
			icon.texture = null
			continue

		var type_name: String = str(types[index])
		var texture: Texture2D = _load_type_icon(type_name)
		icon.texture = texture
		icon.visible = texture != null


func _load_type_icon(type_name: String) -> Texture2D:
	var icon_path := "%s/%s.png" % [TYPE_ICON_DIR, type_name.to_lower()]
	if not ResourceLoader.exists(icon_path):
		return null

	return load(icon_path) as Texture2D


func _set_abilities(abilities: Array[String], confirmed_ability: String = "") -> void:
	if confirmed_ability != "":
		ability_row.visible = true
		ability_label.text = "Ability: "
		ability_value_label.text = _format_display_name(confirmed_ability)
		return

	ability_row.visible = not abilities.is_empty()
	ability_label.text = "Ability: " if abilities.size() == 1 else "Possible abilities: "
	var ability_text: PackedStringArray = []
	for ability in abilities:
		ability_text.append(ability)

	ability_value_label.text = " / ".join(ability_text)


func _get_possible_abilities(species_name: String) -> Array[String]:
	var species_data: Dictionary = _load_species_data(species_name)
	var abilities: Array[String] = []
	var abilities_value: Variant = species_data.get("abilities", {})

	if abilities_value is Dictionary:
		var ability_data: Dictionary = abilities_value
		for key in ["primary", "secondary", "hidden"]:
			var ability_name: String = _format_display_name(str(ability_data.get(key, "")))
			if ability_name != "" and not abilities.has(ability_name):
				abilities.append(ability_name)
	elif abilities_value is Array:
		var ability_array: Array = abilities_value
		for ability in ability_array:
			var ability_name: String = _format_display_name(str(ability))
			if ability_name != "" and not abilities.has(ability_name):
				abilities.append(ability_name)

	return abilities


func _set_item(item: String) -> void:
	item_label.visible = item != ""
	item_label.text = "Item: %s" % _format_display_name(item)


func _set_stat_changes(stat_changes: Dictionary) -> void:
	var boost_parts: PackedStringArray = []
	var drop_parts: PackedStringArray = []
	for stat_key in ["atk", "def", "spa", "spd", "spe", "accuracy", "evasion"]:
		if not stat_changes.has(stat_key):
			continue

		var amount: int = int(stat_changes.get(stat_key, 0))
		if amount == 0:
			continue

		if amount > 0:
			boost_parts.append("%s +%s" % [_format_stat_name(stat_key), amount])
		else:
			drop_parts.append("%s %s" % [_format_stat_name(stat_key), amount])

	boosts_row.visible = not boost_parts.is_empty()
	boosts_value_label.text = " / ".join(boost_parts)
	drops_row.visible = not drop_parts.is_empty()
	drops_value_label.text = " / ".join(drop_parts)


func _set_speed_data(speed_data: Dictionary) -> void:
	if speed_data.is_empty():
		speed_row.visible = false
		return

	speed_row.visible = true
	lowest_speed_label.text = _format_speed_value(speed_data.get("min", ""))
	lowest_neutral_speed_label.text = _format_speed_value(speed_data.get("minNeutral31Iv", speed_data.get("min_neutral_31_iv", "")))
	highest_neutral_speed_label.text = _format_speed_value(speed_data.get("maxNeutral31Iv", speed_data.get("max_neutral_31_iv", "")))
	highest_speed_label.text = _format_speed_value(speed_data.get("max", ""))


func _format_speed_value(value: Variant) -> String:
	if value == null or str(value) == "":
		return ""

	return str(int(value))


func _format_stat_name(stat_key: String) -> String:
	match stat_key.strip_edges().to_lower():
		"atk":
			return "Atk"
		"def":
			return "Def"
		"spa":
			return "SpA"
		"spd":
			return "SpD"
		"spe":
			return "Spe"
		"accuracy":
			return "Acc"
		"evasion":
			return "Eva"

	return _format_display_name(stat_key)


func _get_display_moves(confirmed_moves: Array) -> Array:
	return confirmed_moves


func _set_moves(moves: Array) -> void:
	var has_moves := not moves.is_empty()
	moves_separator.visible = has_moves

	for index in range(move_labels.size()):
		var label: Label = move_labels[index]
		if index >= moves.size():
			label.visible = false
			label.text = ""
			continue

		label.visible = true
		label.text = _format_move_text(moves[index])


func _format_move_text(move_value: Variant) -> String:
	if move_value is Dictionary:
		var move_data: Dictionary = move_value
		var move_name: String = str(move_data.get("name", move_data.get("move", move_data.get("id", ""))))
		var pp_text: String = _format_pp_text(move_data)
		if pp_text != "":
			return "• %s (%s)" % [move_name, pp_text]

		return "• %s" % move_name

	return "• %s" % str(move_value)


func _format_pp_text(move_data: Dictionary) -> String:
	var current_pp_value: Variant = move_data.get("pp", null)
	var max_pp_value: Variant = _get_first_dictionary_value(move_data, [
		"maxpp",
		"maxPp",
		"maxPP",
		"max_pp",
	])
	if current_pp_value == null or max_pp_value == null:
		return ""

	var current_pp: int = int(current_pp_value)
	var max_pp: int = int(max_pp_value)
	return "%d/%d" % [current_pp, max_pp]


func _get_first_dictionary_value(data: Dictionary, keys: Array[String]) -> Variant:
	for key in keys:
		if data.has(key):
			return data.get(key)

	return null


func _load_species_data(species_name: String) -> Dictionary:
	var normalized_species_id: String = _normalize_species_id(species_name)
	if normalized_species_id == "":
		return {}

	var path := SPECIES_PATH % normalized_species_id
	if not FileAccess.file_exists(path):
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed

	return {}


func _normalize_species_id(species_name: String) -> String:
	return species_name.to_lower().replace(" ", "-").replace("-mega-x", "-megax").replace("-mega-y", "-megay")


func _format_display_name(raw_value: String) -> String:
	if raw_value == "":
		return ""

	var words: PackedStringArray = raw_value.replace("_", "-").split("-")
	for index in range(words.size()):
		words[index] = words[index].capitalize()

	return " ".join(words)
