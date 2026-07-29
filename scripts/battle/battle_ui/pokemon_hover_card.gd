extends PanelContainer

class_name PokemonHoverCard

const TYPE_ICON_DIR := "res://assets/sprites/types"
const LOW_SPEED_COLOR := Color(0.9372549, 0.26666668, 0.26666668, 1.0)
const HIGH_SPEED_COLOR := Color(0.3882353, 0.83137256, 0.44313726, 1.0)
const MIN_CARD_WIDTH := 220.0

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var hp_label: Label = $MarginContainer/VBoxContainer/HpLabel
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
@onready var moves_container: VBoxContainer = $MarginContainer/VBoxContainer/VBoxContainer
@onready var move_label_1: Label = $MarginContainer/VBoxContainer/VBoxContainer/MoveLabel
@onready var move_label_2: Label = $MarginContainer/VBoxContainer/VBoxContainer/MoveLabel2
@onready var move_label_3: Label = $MarginContainer/VBoxContainer/VBoxContainer/MoveLabel3
@onready var move_label_4: Label = $MarginContainer/VBoxContainer/VBoxContainer/MoveLabel4

var move_labels: Array[Label] = []
var current_pokemon_data: Dictionary = {}
var current_confirmed_moves: Array = []
var current_confirmed_item := ""
var current_confirmed_ability := ""
var current_speed_data: Dictionary = {}
var localization_manager: Node


func _ready() -> void:
	localization_manager = get_tree().root.get_node_or_null("LocalizationManager")
	if localization_manager != null and not localization_manager.locale_changed.is_connected(_on_locale_changed):
		localization_manager.locale_changed.connect(_on_locale_changed)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(MIN_CARD_WIDTH, 0.0)
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
	_resize_to_content()
	visible = true


func hide_card() -> void:
	visible = false


func set_pokemon_data(
	pokemon_data: Dictionary,
	confirmed_moves: Array = [],
	confirmed_item: String = "",
	confirmed_ability: String = "",
	_stat_changes: Dictionary = {},
	speed_data: Dictionary = {}
) -> void:
	current_pokemon_data = pokemon_data.duplicate(true)
	current_confirmed_moves = confirmed_moves.duplicate(true)
	current_confirmed_item = confirmed_item
	current_confirmed_ability = confirmed_ability
	current_speed_data = speed_data.duplicate(true)
	var species_name: String = _get_species_name(pokemon_data)
	name_label.text = species_name if species_name != "" else _t("common.unknown")
	_set_hp_label(pokemon_data)

	_set_type_icons(_get_types_from_data(pokemon_data, species_name))
	_set_abilities(_get_possible_abilities(pokemon_data, species_name), confirmed_ability)
	_set_item(confirmed_item)
	_hide_stat_changes()
	_set_speed_data(speed_data)
	_set_moves(_get_display_moves(confirmed_moves))
	_resize_to_content()


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
	var display_species: String = str(pokemon_data.get("displaySpecies", ""))
	if display_species != "":
		return display_species

	var species: String = str(pokemon_data.get("species", ""))
	if species != "":
		return species

	var ident: String = str(pokemon_data.get("ident", ""))
	if ident.contains(":"):
		return ident.split(":", false, 1)[1].strip_edges()

	return ident.strip_edges()


func _set_hp_label(pokemon_data: Dictionary) -> void:
	if bool(pokemon_data.get("fainted", false)):
		hp_label.visible = true
		hp_label.text = _t("battle.hover.hp_fainted")
		return

	if not pokemon_data.has("hp") or not pokemon_data.has("maxHp"):
		hp_label.visible = false
		hp_label.text = ""
		return

	var hp: int = int(pokemon_data.get("hp", 0))
	var max_hp: int = int(pokemon_data.get("maxHp", 0))
	if max_hp <= 0:
		hp_label.visible = false
		hp_label.text = ""
		return

	var hp_percent: int = int(round((float(hp) / float(max_hp)) * 100.0))
	hp_label.visible = true
	hp_label.text = _t("battle.hover.hp_percent", {
		"percent": clamp(hp_percent, 0, 100),
	})


func _get_types_from_data(pokemon_data: Dictionary, species_name: String) -> Array:
	var types: Array = []
	var types_value: Variant = pokemon_data.get("types", [])
	if types_value is Array:
		for type_name in types_value:
			types.append(str(type_name))

	if not types.is_empty():
		return types

	push_warning("PokemonHoverCard missing type metadata for %s. Backend payload should include types." % species_name)
	return []


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
		ability_label.text = _t("battle.hover.ability")
		ability_value_label.text = _format_display_name(confirmed_ability)
		return

	ability_row.visible = not abilities.is_empty()
	ability_label.text = _t(
		"battle.hover.ability"
		if abilities.size() == 1
		else "battle.hover.possible_abilities"
	)
	var ability_text: PackedStringArray = []
	for ability in abilities:
		ability_text.append(ability)

	ability_value_label.text = " / ".join(ability_text)


func _get_possible_abilities(pokemon_data: Dictionary, species_name: String) -> Array[String]:
	var abilities: Array[String] = []
	var payload_abilities := _get_possible_abilities_from_data(pokemon_data)
	if not payload_abilities.is_empty():
		for ability in payload_abilities:
			abilities.append(ability)
		return abilities

	push_warning("PokemonHoverCard missing possibleAbilities metadata for %s. Backend payload should include possibleAbilities." % species_name)
	return abilities


func _get_possible_abilities_from_data(pokemon_data: Dictionary) -> Array:
	var abilities: Array = []
	var abilities_value: Variant = pokemon_data.get("possibleAbilities", pokemon_data.get("possible_abilities", []))
	if not (abilities_value is Array):
		return abilities

	for ability in abilities_value:
		var ability_name: String = _format_display_name(str(ability))
		if ability_name != "" and not abilities.has(ability_name):
			abilities.append(ability_name)

	return abilities


func _set_item(item: String) -> void:
	if item == "":
		item_label.visible = false
		item_label.text = ""
		return

	item_label.visible = true
	item_label.text = _t("battle.hover.item", {
		"item": _format_item_display_name(item),
	})

func _format_item_display_name(item: String) -> String:
	var knocked_suffix := " (Knocked off)"
	if item.ends_with(knocked_suffix):
		return _t("battle.hover.item_knocked_off", {
			"item": _format_display_name(item.substr(0, item.length() - knocked_suffix.length())),
		})

	var consumed_suffix := " (Consumed)"
	if item.ends_with(consumed_suffix):
		return _t("battle.hover.item_consumed", {
			"item": _format_display_name(item.substr(0, item.length() - consumed_suffix.length())),
		})

	return _format_display_name(item)


func _hide_stat_changes() -> void:
	boosts_row.visible = false
	boosts_value_label.text = ""
	drops_row.visible = false
	drops_value_label.text = ""


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


func _get_display_moves(confirmed_moves: Array) -> Array:
	return confirmed_moves


func _set_moves(moves: Array) -> void:
	var has_moves := not moves.is_empty()
	moves_separator.visible = has_moves
	moves_container.visible = has_moves

	for index in range(move_labels.size()):
		var label: Label = move_labels[index]
		if index >= moves.size():
			label.visible = false
			label.text = ""
			continue

		label.visible = true
		label.text = _format_move_text(moves[index])


func _resize_to_content() -> void:
	update_minimum_size()
	var content_size: Vector2 = get_combined_minimum_size()
	size = Vector2(maxf(MIN_CARD_WIDTH, content_size.x), content_size.y)


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



func _format_display_name(raw_value: String) -> String:
	if raw_value == "":
		return ""

	var words: PackedStringArray = raw_value.replace("_", "-").split("-")
	for index in range(words.size()):
		words[index] = words[index].capitalize()

	return " ".join(words)


func _on_locale_changed(_locale: String) -> void:
	if current_pokemon_data.is_empty():
		return
	set_pokemon_data(
		current_pokemon_data,
		current_confirmed_moves,
		current_confirmed_item,
		current_confirmed_ability,
		{},
		current_speed_data
	)


func _t(key: String, replacements: Dictionary = {}) -> String:
	if localization_manager != null:
		return str(localization_manager.call("text", key, replacements))
	return key
