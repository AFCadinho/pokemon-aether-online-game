extends PanelContainer

class_name PartyHoverCard

const TYPE_ICON_PATH := "res://assets/sprites/types/%s.png"
const CARD_WIDTH := 300.0
const STORAGE_CARD_HEIGHT := 315.0
const IV_STAT_ENTRIES: Array[Array] = [
	["HP", "hp"],
	["Atk", "atk"],
	["Def", "def"],
	["SpA", "spa"],
	["SpD", "spd"],
	["Spe", "spe"],
]
const STAT_BOOST_COLOR := Color(0.3882353, 0.83137256, 0.44313726, 1.0)
const STAT_DROP_COLOR := Color(0.9372549, 0.26666668, 0.26666668, 1.0)
const NATURE_DROP_COLOR := Color(0.9372549, 0.26666668, 0.26666668, 1.0)

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
var iv_details_container: HBoxContainer
var iv_value_labels: Dictionary = {}
var ev_value_label: Label
var show_ivs := false
var show_evs := false
var storage_visuals := false
var current_pokemon_data: Dictionary = {}
var localization_manager: Node


func _ready() -> void:
	localization_manager = get_tree().root.get_node_or_null("LocalizationManager")
	if localization_manager != null and not localization_manager.locale_changed.is_connected(_on_locale_changed):
		localization_manager.locale_changed.connect(_on_locale_changed)
	if localization_manager != null:
		localization_manager.call("localize_tree", self)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = CARD_WIDTH
	offset_bottom = 0.0
	custom_minimum_size.x = CARD_WIDTH
	custom_minimum_size.y = 0.0
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	size.x = CARD_WIDTH
	size.y = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	iv_details_container = _create_iv_details()
	ev_value_label = Label.new()
	ev_value_label.name = "EVValueLabel"
	ev_value_label.add_theme_font_size_override("font_size", 11)
	ev_value_label.add_theme_color_override("font_color", Color(0.96, 0.70, 0.40, 1.0))
	ev_value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var content := $MarginContainer/VBoxContainer as VBoxContainer
	content.add_child(ev_value_label)
	content.add_child(iv_details_container)
	var details_index := $MarginContainer/VBoxContainer/SeperationLabel2.get_index() + 1
	content.move_child(ev_value_label, details_index)
	content.move_child(iv_details_container, details_index + 1)
	if storage_visuals:
		_apply_storage_visuals()
	hide_card()


func show_for_pokemon(pokemon_data: Dictionary) -> void:
	_set_pokemon_data(pokemon_data)
	visible = true


func set_show_ivs(enabled: bool) -> void:
	show_ivs = enabled
	if iv_details_container != null:
		iv_details_container.visible = enabled


func set_show_storage_details(enabled: bool) -> void:
	show_ivs = enabled
	show_evs = enabled
	storage_visuals = enabled
	if iv_details_container != null:
		iv_details_container.visible = enabled
	if ev_value_label != null:
		ev_value_label.visible = enabled
	if is_node_ready():
		_apply_storage_visuals()


func hide_card() -> void:
	visible = false


func _apply_storage_visuals() -> void:
	if not storage_visuals:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#06111df5")
	style.border_color = Color("#60d3ff73")
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.expand_margin_left = 6.0
	style.expand_margin_top = 5.0
	style.expand_margin_right = 6.0
	style.expand_margin_bottom = 5.0
	style.shadow_color = Color("#00000073")
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("panel", style)
	name_label.add_theme_font_size_override("font_size", 19)
	($MarginContainer/VBoxContainer as VBoxContainer).add_theme_constant_override("separation", 3)
	custom_minimum_size.y = STORAGE_CARD_HEIGHT
	size.y = STORAGE_CARD_HEIGHT


func _create_iv_details() -> HBoxContainer:
	var details := HBoxContainer.new()
	details.name = "IVDetailsContainer"
	details.add_theme_constant_override("separation", 5)

	var heading := Label.new()
	heading.name = "IVHeadingLabel"
	heading.custom_minimum_size.x = 24.0
	heading.text = "IVs"
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 10)
	heading.add_theme_color_override("font_color", Color(0.38431373, 0.84313726, 1.0, 1.0))
	details.add_child(heading)

	var grid := GridContainer.new()
	grid.name = "IVGrid"
	grid.columns = IV_STAT_ENTRIES.size()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 0)
	details.add_child(grid)

	for entry: Array in IV_STAT_ENTRIES:
		var header := Label.new()
		header.name = "%sHeader" % str(entry[1]).to_pascal_case()
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.text = str(entry[0]).to_upper()
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override("font_size", 9)
		header.add_theme_color_override("font_color", Color(0.48, 0.61, 0.70, 1.0))
		grid.add_child(header)

	for entry: Array in IV_STAT_ENTRIES:
		var value := Label.new()
		value.name = "%sValue" % str(entry[1]).to_pascal_case()
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.text = "–"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 11)
		value.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0, 1.0))
		grid.add_child(value)
		iv_value_labels[str(entry[1])] = value

	return details


func position_near_mouse(mouse_position: Vector2, viewport_size: Vector2) -> void:
	var padding := 12.0
	custom_minimum_size.x = CARD_WIDTH
	custom_minimum_size.y = STORAGE_CARD_HEIGHT if storage_visuals else 0.0
	size.y = 0.0
	reset_size()
	size.x = minf(CARD_WIDTH, maxf(1.0, viewport_size.x - padding * 2.0))
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
	custom_minimum_size.y = STORAGE_CARD_HEIGHT if storage_visuals else 0.0
	size.y = 0.0
	reset_size()
	# Long move/item labels can otherwise expand this root-level card to the
	# width of the calculator behind it.
	size.x = minf(CARD_WIDTH, maxf(1.0, viewport_size.x - padding * 2.0))
	var card_size: Vector2 = size
	var target_position: Vector2
	if anchor_rect.get_center().x > viewport_size.x * 0.65:
		target_position = Vector2(
			anchor_rect.position.x - card_size.x - padding,
			anchor_rect.get_center().y - card_size.y * 0.5
		)
	else:
		target_position = Vector2(anchor_rect.position.x, anchor_rect.position.y - card_size.y - padding)
		if target_position.y < padding:
			target_position.y = anchor_rect.end.y + padding

	if target_position.x + card_size.x > viewport_size.x - padding:
		target_position.x = viewport_size.x - card_size.x - padding
	if target_position.x < padding:
		target_position.x = padding
	target_position.y = clampf(target_position.y, padding, maxf(padding, viewport_size.y - card_size.y - padding))

	global_position = target_position


func _set_pokemon_data(pokemon_data: Dictionary) -> void:
	current_pokemon_data = pokemon_data.duplicate(true)
	name_label.text = _get_display_species(pokemon_data)
	_set_type_icons(pokemon_data)
	_set_hp(pokemon_data)
	ability_value_label.text = _format_value(
		_localized_content_name(
			"abilities",
			str(pokemon_data.get("ability", "")),
			str(pokemon_data.get("ability", ""))
		),
		_t("common.unknown")
	)
	item_value_label.text = _format_value(
		str(pokemon_data.get("item", "")),
		_t("battle.hover.no_item")
	)
	var canonical_nature := str(pokemon_data.get("nature", ""))
	nature_value_label.text = _format_value(
		_localized_nature_name(canonical_nature),
		_t("common.unknown")
	)
	_set_stats(
		pokemon_data.get("stats", pokemon_data.get("evs", {})),
		pokemon_data.get("statStages", pokemon_data.get("stat_stages", {})),
		str(pokemon_data.get("nature", "")),
		pokemon_data.get("itemStatModifiers", pokemon_data.get("item_stat_modifiers", {}))
	)
	_set_ivs(pokemon_data.get("ivs", {}))
	_set_evs(pokemon_data.get("evs", {}))
	_set_moves(pokemon_data.get("moves", []))


func _get_display_species(pokemon_data: Dictionary) -> String:
	var species := str(pokemon_data.get("displaySpecies", pokemon_data.get("species", "")))
	if species != "":
		var species_id := str(pokemon_data.get(
			"speciesId",
			pokemon_data.get("species_id", pokemon_data.get("species", species))
		))
		return _localized_content_name("species", species_id, species)

	var ident := str(pokemon_data.get("ident", ""))
	if ident.contains(": "):
		var ident_species := str(ident.split(": ")[1]).strip_edges()
		return _localized_content_name("species", ident_species, ident_species)

	return _t("common.unknown")


func _localized_nature_name(nature: String) -> String:
	var content_localization := _get_content_localization()
	if content_localization != null and content_localization.has_method("nature_name"):
		return str(content_localization.call("nature_name", nature, nature))
	return nature


func _localized_content_name(kind: String, content_id: String, fallback_name: String) -> String:
	var content_localization := _get_content_localization()
	if content_localization != null and content_localization.has_method("display_name"):
		return str(content_localization.call("display_name", kind, content_id, fallback_name))
	return fallback_name


func _get_content_localization() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/ContentLocalization")
	var scene_tree := Engine.get_main_loop() as SceneTree
	return scene_tree.root.get_node_or_null("ContentLocalization") if scene_tree != null else null


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
		hp_percent_label.text = _t("battle.status.compact.fainted").to_lower()
	else:
		var hp_percent: int = int(round((float(clamped_hp) / float(max_hp)) * 100.0))
		var clamped_hp_percent: int = mini(maxi(hp_percent, 0), 100)
		hp_percent_label.text = "%s%%" % clamped_hp_percent

	hp_value_label.text = "(%s/%s)" % [clamped_hp, max_hp]


func _set_stats(
	stats_value: Variant,
	stat_stages_value: Variant = {},
	nature_value: String = "",
	item_modifiers_value: Variant = {}
) -> void:
	var stats: Dictionary = {}
	if stats_value is Dictionary:
		stats = stats_value as Dictionary

	var stat_stages: Dictionary = {}
	if stat_stages_value is Dictionary:
		stat_stages = stat_stages_value as Dictionary

	var nature_modifiers := _nature_modifiers(nature_value)
	var item_modifiers: Dictionary = item_modifiers_value if item_modifiers_value is Dictionary else {}
	_set_stat_label(atk_value_label, stats, stat_stages, "atk", nature_modifiers, item_modifiers)
	_set_stat_label(def_value_label, stats, stat_stages, "def", nature_modifiers, item_modifiers)
	_set_stat_label(spa_value_label, stats, stat_stages, "spa", nature_modifiers, item_modifiers)
	_set_stat_label(spd_value_label, stats, stat_stages, "spd", nature_modifiers, item_modifiers)
	_set_stat_label(spe_value_label, stats, stat_stages, "spe", nature_modifiers, item_modifiers)


func _nature_modifiers(nature_value: String) -> Dictionary:
	var nature := nature_value.strip_edges().to_lower().replace("-", "_")
	var modifiers := {
		"adamant": ["atk", "spa"], "bashful": ["", ""], "bold": ["def", "atk"],
		"brave": ["atk", "spe"], "calm": ["spd", "atk"], "careful": ["spd", "spa"],
		"docile": ["", ""], "gentle": ["spd", "def"], "hardy": ["", ""],
		"hasty": ["spe", "def"], "impish": ["def", "spa"], "jolly": ["spe", "spa"],
		"lax": ["def", "spd"], "lonely": ["atk", "def"], "mild": ["spa", "def"],
		"modest": ["spa", "atk"], "naive": ["spe", "spd"], "naughty": ["atk", "spd"],
		"quirky": ["", ""], "relaxed": ["def", "spe"], "sassy": ["spd", "spe"],
		"serious": ["", ""], "timid": ["spe", "atk"],
	}
	var pair: Array = modifiers.get(nature, ["", ""])
	return {"up": str(pair[0]), "down": str(pair[1])}


func _set_ivs(ivs_value: Variant) -> void:
	if iv_details_container == null:
		return
	if not show_ivs or not (ivs_value is Dictionary):
		iv_details_container.visible = false
		return
	var ivs: Dictionary = ivs_value as Dictionary
	var has_values := false
	for entry: Array in IV_STAT_ENTRIES:
		var stat_key := str(entry[1])
		var value_label := iv_value_labels.get(stat_key) as Label
		if value_label == null:
			continue
		if ivs.has(stat_key):
			value_label.text = str(int(ivs.get(stat_key)))
			has_values = true
		else:
			value_label.text = "–"
	iv_details_container.visible = has_values


func _set_evs(evs_value: Variant) -> void:
	if ev_value_label == null:
		return
	if not show_evs or not (evs_value is Dictionary):
		ev_value_label.visible = false
		return
	var evs: Dictionary = evs_value as Dictionary
	var parts: Array[String] = []
	for entry: Array in [
		["HP", "hp"],
		["Atk", "atk"],
		["Def", "def"],
		["SpA", "spa"],
		["SpD", "spd"],
		["Spe", "spe"],
	]:
		if evs.has(entry[1]) and int(evs.get(entry[1])) > 0:
			parts.append("%s %d" % [entry[0], int(evs.get(entry[1]))])
	ev_value_label.text = _t("battle.hover.evs", {
		"values": " · ".join(parts),
	})
	ev_value_label.visible = not parts.is_empty()


func _set_stat_label(
	label: Label,
	stats: Dictionary,
	stat_stages: Dictionary,
	stat_key: String,
	nature_modifiers: Dictionary = {},
	item_modifiers: Dictionary = {}
) -> void:
	var stage_value: int = int(stat_stages.get(stat_key, 0))
	label.text = _format_stat_value(stats, stat_stages, stat_key)
	if stage_value > 0:
		label.add_theme_color_override("font_color", STAT_BOOST_COLOR)
	elif stage_value < 0:
		label.add_theme_color_override("font_color", STAT_DROP_COLOR)
	elif str(nature_modifiers.get("up", "")) == stat_key:
		label.add_theme_color_override("font_color", STAT_BOOST_COLOR)
	elif str(nature_modifiers.get("down", "")) == stat_key:
		label.add_theme_color_override("font_color", NATURE_DROP_COLOR)
	elif item_modifiers.has(stat_key) and float(item_modifiers.get(stat_key, 1.0)) != 1.0:
		label.add_theme_color_override("font_color", STAT_BOOST_COLOR if float(item_modifiers[stat_key]) > 1.0 else STAT_DROP_COLOR)
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
		var fallback_name := str(move_dictionary.get(
			"name",
			move_dictionary.get("move", move_dictionary.get("id", ""))
		))
		var move_id := str(move_dictionary.get(
			"id",
			move_dictionary.get(
				"move",
				move_dictionary.get("moveId", move_dictionary.get("move_id", fallback_name))
			)
		))
		return _localized_content_name("moves", move_id, fallback_name)

	var move_name := str(move_data)
	return _localized_content_name("moves", move_name, move_name)


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


func _on_locale_changed(_locale: String) -> void:
	if localization_manager != null:
		localization_manager.call("localize_tree", self)
	if not current_pokemon_data.is_empty():
		_set_pokemon_data(current_pokemon_data)


func _format_value(value: String, fallback: String) -> String:
	var cleaned := value.strip_edges()
	if cleaned == "":
		return fallback

	var words: PackedStringArray = cleaned.replace("_", "-").split("-")
	for index in range(words.size()):
		words[index] = words[index].capitalize()

	return " ".join(words)


func _t(key: String, replacements: Dictionary = {}) -> String:
	if localization_manager != null:
		return str(localization_manager.call("text", key, replacements))
	return key
