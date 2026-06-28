extends PanelContainer

class_name PartyHoverCard

const TYPE_ICON_PATH := "res://assets/sprites/types/%s.png"
const CARD_WIDTH := 300.0
const STAT_BOOST_COLOR := Color(0.3882353, 0.83137256, 0.44313726, 1.0)
const STAT_DROP_COLOR := Color(0.9372549, 0.26666668, 0.26666668, 1.0)

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var type_icon_1: TextureRect = $MarginContainer/VBoxContainer/TypeBoxContainer/TypeIcon
@onready var type_icon_2: TextureRect = $MarginContainer/VBoxContainer/TypeBoxContainer/TypeIcon2
@onready var hp_percent_label: Label = $MarginContainer/VBoxContainer/HPBoxContainer/HpContainer/HpPercentLabel
@onready var hp_value_label: Label = $MarginContainer/VBoxContainer/HPBoxContainer/HpContainer/HpValueLabel
@onready var ability_value_label: Label = $MarginContainer/VBoxContainer/AbilityBoxContainer/HBoxContainer/AbilityValueLabel
@onready var item_value_label: Label = $MarginContainer/VBoxContainer/HPBoxContainer/ItemContainer/ItemValueLabel
@onready var nature_value_label: Label = $MarginContainer/VBoxContainer/AbilityBoxContainer/NatureContainer/NatureValueLabel
@onready var atk_value_label: Label = $MarginContainer/VBoxContainer/StatsBoxContainer/AttackContainer/ValueLabel
@onready var def_value_label: Label = $MarginContainer/VBoxContainer/StatsBoxContainer/DefContainer/ValueLabel
@onready var spa_value_label: Label = $MarginContainer/VBoxContainer/StatsBoxContainer/SpAContainer/ValueLabel
@onready var spd_value_label: Label = $MarginContainer/VBoxContainer/StatsBoxContainer/SpDContainer/ValueLabel
@onready var spe_value_label: Label = $MarginContainer/VBoxContainer/StatsBoxContainer/SpeContainer/ValueLabel
@onready var move_rows: Array[HBoxContainer] = [
	$MarginContainer/VBoxContainer/VBoxContainer/HBoxContainer,
	$MarginContainer/VBoxContainer/VBoxContainer/HBoxContainer2,
	$MarginContainer/VBoxContainer/VBoxContainer/HBoxContainer3,
	$MarginContainer/VBoxContainer/VBoxContainer/HBoxContainer4,
]


func _ready() -> void:
	custom_minimum_size.x = CARD_WIDTH
	size.x = CARD_WIDTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide_card()


func show_for_pokemon(pokemon_data: Dictionary) -> void:
	_set_pokemon_data(pokemon_data)
	visible = true


func hide_card() -> void:
	visible = false


func position_near_mouse(mouse_position: Vector2, viewport_size: Vector2) -> void:
	var padding := 12.0
	custom_minimum_size.x = CARD_WIDTH
	reset_size()
	var card_size: Vector2 = size
	var target_position := mouse_position + Vector2(padding, padding)

	if target_position.x + card_size.x > viewport_size.x:
		target_position.x = mouse_position.x - card_size.x - padding
	if target_position.y + card_size.y > viewport_size.y:
		target_position.y = mouse_position.y - card_size.y - padding

	global_position = target_position


func position_near_rect(anchor_rect: Rect2, viewport_size: Vector2) -> void:
	var padding := 10.0
	custom_minimum_size.x = CARD_WIDTH
	reset_size()
	var card_size: Vector2 = size
	var target_position := Vector2(anchor_rect.position.x, anchor_rect.position.y - card_size.y - padding)

	if target_position.y < padding:
		target_position.y = anchor_rect.end.y + padding
	if target_position.x + card_size.x > viewport_size.x - padding:
		target_position.x = viewport_size.x - card_size.x - padding
	if target_position.x < padding:
		target_position.x = padding

	global_position = target_position


func _set_pokemon_data(pokemon_data: Dictionary) -> void:
	name_label.text = _get_display_species(pokemon_data)
	_set_type_icons(pokemon_data)
	_set_hp(pokemon_data)
	ability_value_label.text = _format_value(str(pokemon_data.get("ability", "")), "Unknown")
	item_value_label.text = _format_value(str(pokemon_data.get("item", "")), "No item")
	nature_value_label.text = _format_value(str(pokemon_data.get("nature", "")), "Unknown")
	_set_stats(
		pokemon_data.get("stats", pokemon_data.get("evs", {})),
		pokemon_data.get("statStages", pokemon_data.get("stat_stages", {}))
	)
	_set_moves(pokemon_data.get("moves", []))


func _get_display_species(pokemon_data: Dictionary) -> String:
	var species := str(pokemon_data.get("displaySpecies", pokemon_data.get("species", "")))
	if species != "":
		return species

	var ident := str(pokemon_data.get("ident", ""))
	if ident.contains(": "):
		return str(ident.split(": ")[1]).strip_edges()

	return "Unknown"


func _set_type_icons(pokemon_data: Dictionary) -> void:
	var types: Array = []
	var types_value: Variant = pokemon_data.get("types", [])
	if types_value is Array:
		types = types_value

	_set_type_icon(type_icon_1, str(types[0]) if types.size() > 0 else "")
	_set_type_icon(type_icon_2, str(types[1]) if types.size() > 1 else "")


func _set_type_icon(icon: TextureRect, type_name: String) -> void:
	if type_name == "":
		icon.texture = null
		icon.visible = false
		return

	var icon_path := TYPE_ICON_PATH % type_name.to_lower()
	if not ResourceLoader.exists(icon_path):
		icon.texture = null
		icon.visible = false
		return

	icon.texture = load(icon_path) as Texture2D
	icon.visible = icon.texture != null


func _set_hp(pokemon_data: Dictionary) -> void:
	var hp: int = int(pokemon_data.get("hp", pokemon_data.get("currentHp", 0)))
	var raw_max_hp: int = int(pokemon_data.get("maxHp", pokemon_data.get("max_hp", 1)))
	var max_hp: int = raw_max_hp if raw_max_hp > 0 else 1
	var clamped_hp: int = mini(maxi(hp, 0), max_hp)
	if bool(pokemon_data.get("fainted", false)) or str(pokemon_data.get("condition", "")).contains("fnt"):
		hp_percent_label.text = "fnt"
	else:
		var hp_percent: int = int(round((float(clamped_hp) / float(max_hp)) * 100.0))
		var clamped_hp_percent: int = mini(maxi(hp_percent, 0), 100)
		hp_percent_label.text = "%s%%" % clamped_hp_percent

	hp_value_label.text = "(%s/%s)" % [clamped_hp, max_hp]


func _set_stats(stats_value: Variant, stat_stages_value: Variant = {}) -> void:
	var stats: Dictionary = {}
	if stats_value is Dictionary:
		stats = stats_value as Dictionary

	var stat_stages: Dictionary = {}
	if stat_stages_value is Dictionary:
		stat_stages = stat_stages_value as Dictionary

	_set_stat_label(atk_value_label, stats, stat_stages, "atk")
	_set_stat_label(def_value_label, stats, stat_stages, "def")
	_set_stat_label(spa_value_label, stats, stat_stages, "spa")
	_set_stat_label(spd_value_label, stats, stat_stages, "spd")
	_set_stat_label(spe_value_label, stats, stat_stages, "spe")


func _set_stat_label(label: Label, stats: Dictionary, stat_stages: Dictionary, stat_key: String) -> void:
	var stage_value: int = int(stat_stages.get(stat_key, 0))
	label.text = _format_stat_value(stats, stat_stages, stat_key)
	if stage_value > 0:
		label.add_theme_color_override("font_color", STAT_BOOST_COLOR)
	elif stage_value < 0:
		label.add_theme_color_override("font_color", STAT_DROP_COLOR)
	else:
		label.remove_theme_color_override("font_color")


func _format_stat_value(stats: Dictionary, stat_stages: Dictionary, stat_key: String) -> String:
	var stat_value: int = int(stats.get(stat_key, 0))
	var stage_value: int = int(stat_stages.get(stat_key, 0))
	if stage_value == 0:
		return str(stat_value)

	var effective_stat: int = int(floor(float(stat_value) * _get_stat_stage_multiplier(stage_value)))
	var stage_prefix := "+" if stage_value > 0 else ""
	return "%s (%s%s)" % [effective_stat, stage_prefix, stage_value]


func _get_stat_stage_multiplier(stage: int) -> float:
	if stage >= 0:
		return float(2 + stage) / 2.0

	return 2.0 / float(2 - stage)


func _set_moves(moves_value: Variant) -> void:
	var moves: Array = moves_value if moves_value is Array else []
	for index in range(move_rows.size()):
		var row := move_rows[index]
		row.visible = index < moves.size()
		if not row.visible:
			continue

		var move_data: Variant = moves[index]
		var move_name := _get_move_display_name(move_data)
		var move_label := row.get_node_or_null("MoveLabel") as Label
		var pp_label := row.get_node_or_null("Label") as Label
		if move_label != null:
			move_label.text = "• %s" % move_name
		if pp_label != null:
			pp_label.text = _get_move_pp_text(move_data)


func _get_move_display_name(move_data: Variant) -> String:
	if move_data is Dictionary:
		var move_dictionary := move_data as Dictionary
		return str(move_dictionary.get("name", move_dictionary.get("move", "")))

	return str(move_data)


func _get_move_pp_text(move_data: Variant) -> String:
	if not (move_data is Dictionary):
		return ""

	var move_dictionary := move_data as Dictionary
	if not _has_any_key(move_dictionary, ["pp", "currentPp", "currentPP", "current_pp"]):
		return ""
	if not _has_any_key(move_dictionary, ["maxpp", "maxPp", "maxPP", "max_pp"]):
		return ""

	var current_pp: int = int(_get_first_dictionary_value(move_dictionary, ["pp", "currentPp", "currentPP", "current_pp"], 0))
	var max_pp: int = int(_get_first_dictionary_value(move_dictionary, ["maxpp", "maxPp", "maxPP", "max_pp"], current_pp))
	return "%s/%s" % [current_pp, max_pp]


func _has_any_key(dictionary: Dictionary, keys: Array[String]) -> bool:
	for key in keys:
		if dictionary.has(key):
			return true

	return false


func _get_first_dictionary_value(dictionary: Dictionary, keys: Array[String], fallback: Variant) -> Variant:
	for key in keys:
		if dictionary.has(key):
			return dictionary.get(key)

	return fallback


func _format_value(value: String, fallback: String) -> String:
	var cleaned := value.strip_edges()
	if cleaned == "":
		return fallback

	var words: PackedStringArray = cleaned.replace("_", "-").split("-")
	for index in range(words.size()):
		words[index] = words[index].capitalize()

	return " ".join(words)
