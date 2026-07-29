extends Button

signal selected
signal pokemon_hovered(pokemon_data: Dictionary, slot_rect: Rect2)
signal pokemon_unhovered

const FAINTED_BACKGROUND := Color("#30343c")
const FAINTED_BORDER := Color("#626a76")
const ACTIVE_BACKGROUND := Color("#0a315f")
const ACTIVE_BORDER := Color("#62d7ff")
const PARTY_BACKGROUND := Color("#081321f2")
const PARTY_BORDER := Color("#315070")
const ICON_PARTY_BORDER := Color("#223b55")
const NORMAL_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const FAINTED_MODULATE := Color(0.62, 0.62, 0.62, 1.0)
const ICON_FAINTED_MODULATE := Color(0.38, 0.38, 0.38, 0.84)
const POISON_STATUS_TEXTURE: Texture2D = preload("res://assets/battles/status/poisoned.png")
const POISON_STATUS_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const TOXIC_STATUS_MODULATE := Color("#8c58ff")
const NAME_FONT_SIZE := 14
const LONG_NAME_FONT_SIZE := 12
const VERY_LONG_NAME_FONT_SIZE := 11

@export var compact_mode := false
@export var icon_only_mode := false

@onready var margin_container: MarginContainer = $MarginContainer
@onready var slot_row: HBoxContainer = $MarginContainer/HBoxContainer
@onready var pokemon_icon: TextureRect = $MarginContainer/HBoxContainer/PokemonIcon
@onready var icon_status_badge: Label = %IconStatusBadge
@onready var details_column: VBoxContainer = $MarginContainer/HBoxContainer/VBoxContainer
@onready var name_row: HBoxContainer = $MarginContainer/HBoxContainer/VBoxContainer/NameRow
@onready var shiny_badge: Label = $MarginContainer/HBoxContainer/VBoxContainer/NameRow/ShinyBadge
@onready var name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/NameRow/NameLabel
@onready var bottom_row: HBoxContainer = $MarginContainer/HBoxContainer/VBoxContainer/BottomRowContainer
@onready var hp_bar: ProgressBar = $MarginContainer/HBoxContainer/VBoxContainer/BottomRowContainer/HPBar
@onready var status_icon: TextureRect = $MarginContainer/HBoxContainer/VBoxContainer/BottomRowContainer/StatusIcon

var current_pokemon_data: Dictionary = {}
var localization_manager: Node

func _ready() -> void:
	localization_manager = get_tree().root.get_node_or_null("LocalizationManager")
	if localization_manager != null and not localization_manager.locale_changed.is_connected(_on_locale_changed):
		localization_manager.locale_changed.connect(_on_locale_changed)
	_apply_slot_layout()
	_ignore_child_mouse_input(self)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func _apply_slot_layout() -> void:
	if icon_only_mode:
		custom_minimum_size = Vector2(52.0, 52.0)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		margin_container.add_theme_constant_override("margin_left", 2)
		margin_container.add_theme_constant_override("margin_top", 2)
		margin_container.add_theme_constant_override("margin_right", 2)
		margin_container.add_theme_constant_override("margin_bottom", 2)
		pokemon_icon.custom_minimum_size = Vector2(46.0, 46.0)
		details_column.visible = false
		return
	if not compact_mode:
		return

	custom_minimum_size = Vector2(120.0, 62.0)
	size_flags_vertical = Control.SIZE_FILL
	margin_container.add_theme_constant_override("margin_left", 4)
	margin_container.add_theme_constant_override("margin_top", 5)
	margin_container.add_theme_constant_override("margin_right", 4)
	margin_container.add_theme_constant_override("margin_bottom", 5)
	slot_row.add_theme_constant_override("separation", 3)
	pokemon_icon.custom_minimum_size = Vector2(42.0, 46.0)
	details_column.custom_minimum_size = Vector2(76.0, 46.0)
	details_column.add_theme_constant_override("separation", 2)
	name_row.custom_minimum_size = Vector2(0.0, 23.0)
	shiny_badge.custom_minimum_size = Vector2(10.0, 16.0)
	shiny_badge.add_theme_font_size_override("font_size", 12)
	name_label.custom_minimum_size = Vector2(54.0, 21.0)
	bottom_row.custom_minimum_size = Vector2(0.0, 18.0)
	hp_bar.custom_minimum_size = Vector2(50.0, 18.0)
	hp_bar.add_theme_font_size_override("font_size", 12)
	status_icon.custom_minimum_size = Vector2(18.0, 18.0)
	status_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

func _ignore_child_mouse_input(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE


		_ignore_child_mouse_input(child)

func set_pokemon(pokemon: Pokemon) -> void:
	current_pokemon_data = pokemon.to_battle_dict()
	var is_fainted := pokemon.current_hp <= 0
	var is_active := bool(current_pokemon_data.get("active", false))
	_apply_slot_style(pokemon.species, is_fainted, is_active, pokemon.types)

	visible = true
	disabled = is_active or is_fainted
	modulate = FAINTED_MODULATE if is_fainted and not icon_only_mode else NORMAL_MODULATE
	tooltip_text = _t("battle.party.active") if is_active else ""

	_set_species_name(pokemon.species, pokemon.shiny)
	hp_bar.max_value = max(pokemon.max_hp, 1)
	hp_bar.value = clamp(pokemon.current_hp, 0, pokemon.max_hp)
	pokemon_icon.texture = PokemonAssets.load_party_icon(pokemon.species, pokemon.shiny)
	_set_status_icon("")
	_apply_icon_only_condition_badge("", is_fainted)

func set_pokemon_data(pokemon_data: Dictionary) -> void:
	current_pokemon_data = pokemon_data.duplicate(true)
	var species := _get_species_from_data(pokemon_data)
	var types := _get_types_from_data(pokemon_data)
	var is_active := bool(pokemon_data.get("active", false))
	var max_hp: int = _get_max_hp_from_data(pokemon_data)
	var current_hp: int = _get_current_hp_from_data(pokemon_data, max_hp)
	var is_fainted := _get_fainted_from_data(pokemon_data, current_hp)

	_apply_slot_style(species, is_fainted, is_active, types)

	visible = true
	disabled = is_active or is_fainted
	modulate = FAINTED_MODULATE if is_fainted and not icon_only_mode else NORMAL_MODULATE
	tooltip_text = _t("battle.party.active") if is_active else ""

	var is_shiny := _get_shiny_from_data(pokemon_data)
	_set_species_name(species, is_shiny)

	hp_bar.max_value = max_hp
	hp_bar.value = clamp(current_hp, 0, int(hp_bar.max_value))
	pokemon_icon.texture = PokemonAssets.load_party_icon(species, is_shiny)
	var status := str(pokemon_data.get("status", ""))
	_set_status_icon(status)
	_apply_icon_only_condition_badge(status, is_fainted)

func _get_species_from_data(pokemon_data: Dictionary) -> String:
	var display_species := str(pokemon_data.get("displaySpecies", ""))
	if display_species != "":
		return display_species

	var species := str(pokemon_data.get("species", ""))
	if species != "":
		return species

	var ident := str(pokemon_data.get("ident", ""))
	if ident.contains(": "):
		return str(ident.split(": ")[1]).strip_edges()

	return ""

func _get_shiny_from_data(pokemon_data: Dictionary) -> bool:
	for key in ["shiny", "isShiny", "is_shiny"]:
		if not pokemon_data.has(key):
			continue

		var value: Variant = pokemon_data.get(key)
		if value is bool:
			return bool(value)

		var text_value: String = str(value).strip_edges().to_lower()
		match text_value:
			"true", "yes", "1", "y":
				return true
			"false", "no", "0", "n":
				return false

	return false

func _get_types_from_data(pokemon_data: Dictionary) -> Array:
	var types: Array = []
	var types_value: Variant = pokemon_data.get("types", [])
	if not (types_value is Array):
		return types

	for type_name in types_value:
		types.append(str(type_name))

	return types

func _get_max_hp_from_data(pokemon_data: Dictionary) -> int:
	for key in ["maxHp", "max_hp"]:
		if pokemon_data.has(key):
			return max(int(pokemon_data.get(key)), 1)

	var stats_value: Variant = pokemon_data.get("stats", {})
	if stats_value is Dictionary:
		var stats: Dictionary = stats_value as Dictionary
		if stats.has("hp"):
			return max(int(stats.get("hp")), 1)

	return 1

func _get_current_hp_from_data(pokemon_data: Dictionary, max_hp: int) -> int:
	for key in ["hp", "currentHp", "current_hp"]:
		if pokemon_data.has(key):
			return clamp(int(pokemon_data.get(key)), 0, max_hp)

	var condition := str(pokemon_data.get("condition", "")).strip_edges().to_lower()
	if condition == "0 fnt" or condition.ends_with(" fnt"):
		return 0
	if condition.contains("/"):
		var hp_parts := condition.split("/")
		if hp_parts.size() >= 2:
			return clamp(int(hp_parts[0]), 0, max_hp)

	return max_hp

func _get_fainted_from_data(pokemon_data: Dictionary, current_hp: int) -> bool:
	if bool(pokemon_data.get("fainted", false)):
		return true

	var condition := str(pokemon_data.get("condition", "")).strip_edges().to_lower()
	if condition == "0 fnt" or condition.ends_with(" fnt"):
		return true

	return pokemon_data.has("hp") and current_hp <= 0

func _set_status_icon(status: String) -> void:
	status_icon.texture = _get_status_texture(status)
	status_icon.visible = status_icon.texture != null
	status_icon.tooltip_text = _get_status_tooltip(status) if status_icon.visible else ""
	status_icon.modulate = _get_status_modulate(status) if status_icon.visible else NORMAL_MODULATE

func _apply_icon_only_condition_badge(status: String, is_fainted: bool) -> void:
	# self_modulate darkens only the Pokemon silhouette. Using modulate here also
	# darkens the child FNT badge, making white text and its red pill nearly black.
	pokemon_icon.self_modulate = ICON_FAINTED_MODULATE if icon_only_mode and is_fainted else NORMAL_MODULATE
	if not icon_only_mode:
		icon_status_badge.visible = false
		return

	var normalized_status := status.strip_edges().to_lower()
	icon_status_badge.text = (
		_t("battle.status.compact.fainted")
		if is_fainted
		else _get_compact_status_text(normalized_status)
	)
	icon_status_badge.visible = is_fainted or icon_status_badge.text != ""
	icon_status_badge.self_modulate = NORMAL_MODULATE
	if not icon_status_badge.visible:
		return

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = _get_condition_badge_color("fnt" if is_fainted else normalized_status)
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.border_color = Color("#fff1f4") if is_fainted else Color("#e8f4ff")
	badge_style.corner_radius_top_left = 3
	badge_style.corner_radius_top_right = 3
	badge_style.corner_radius_bottom_left = 3
	badge_style.corner_radius_bottom_right = 3
	icon_status_badge.add_theme_stylebox_override("normal", badge_style)

func _get_compact_status_text(status: String) -> String:
	match status:
		"brn": return _t("battle.status.compact.burn")
		"par": return _t("battle.status.compact.paralysis")
		"slp": return _t("battle.status.compact.sleep")
		"frz": return _t("battle.status.compact.freeze")
		"psn": return _t("battle.status.compact.poison")
		"tox": return _t("battle.status.compact.toxic")
	return ""

func _get_condition_badge_color(status: String) -> Color:
	match status:
		"fnt": return Color("#e64262")
		"brn": return Color("#c94f24")
		"par": return Color("#b58a16")
		"slp": return Color("#6f63b6")
		"frz": return Color("#3a94ba")
		"psn", "tox": return Color("#8c45a8")
	return Color("#263247")

func _get_status_texture(status: String) -> Texture2D:
	match status.strip_edges().to_lower():
		"psn", "tox":
			return POISON_STATUS_TEXTURE

	return null

func _get_status_tooltip(status: String) -> String:
	match status.strip_edges().to_lower():
		"psn":
			return _t("pokemon.status.poisoned")
		"tox":
			return _t("pokemon.status.badly_poisoned")
		"brn":
			return _t("pokemon.status.burned")
		"par":
			return _t("pokemon.status.paralyzed")
		"slp":
			return _t("pokemon.status.asleep")
		"frz":
			return _t("pokemon.status.frozen")

	return ""

func _get_status_modulate(status: String) -> Color:
	match status.strip_edges().to_lower():
		"tox":
			return TOXIC_STATUS_MODULATE

	return POISON_STATUS_MODULATE

func set_empty() -> void:
	current_pokemon_data = {}
	# Battlefield icon rails should only occupy space for actual team members.
	# Interactive switch rows keep their empty positions for stable navigation.
	visible = not icon_only_mode
	disabled = true
	modulate = NORMAL_MODULATE

	name_label.text = ""
	name_label.add_theme_font_size_override("font_size", _get_name_font_size(""))
	shiny_badge.text = ""
	shiny_badge.tooltip_text = ""
	hp_bar.value = 0
	pokemon_icon.texture = null
	pokemon_icon.self_modulate = NORMAL_MODULATE
	icon_status_badge.visible = false
	icon_status_badge.text = ""
	_set_status_icon("")
	tooltip_text = ""

	remove_theme_stylebox_override("normal")
	remove_theme_stylebox_override("hover")
	remove_theme_stylebox_override("pressed")
	remove_theme_stylebox_override("disabled")

func _apply_slot_style(species: String, is_fainted: bool, is_active: bool, types: Array = []) -> void:
	if is_fainted:
		_set_color(FAINTED_BACKGROUND, FAINTED_BORDER, false)
		return

	if is_active:
		_set_color(ACTIVE_BACKGROUND, ACTIVE_BORDER, true)
		return

	_set_color(PARTY_BACKGROUND, ICON_PARTY_BORDER if icon_only_mode else PARTY_BORDER, false)

func _set_color(background: Color, border: Color, is_active: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = background
	normal.border_color = border
	var border_width := 2 if is_active else 1
	normal.border_width_left = border_width
	normal.border_width_top = border_width
	normal.border_width_right = border_width
	normal.border_width_bottom = border_width

	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.shadow_color = Color(0.38431373, 0.84313726, 1, 0.3) if is_active else Color(0, 0, 0, 0.22)
	normal.shadow_size = 10 if is_active else 6
	normal.shadow_offset = Vector2(0, 3) if is_active else Vector2(0, 2)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = background.lightened(0.1 if icon_only_mode else 0.08)
	hover.border_color = ACTIVE_BORDER if icon_only_mode else border.lightened(0.18)
	hover.shadow_color = Color(0.38431373, 0.84313726, 1, 0.2) if icon_only_mode else Color(0.40784314, 0.6156863, 0.9019608, 0.18)
	hover.shadow_size = 10
	hover.shadow_offset = Vector2(0, 3)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = background.darkened(0.08)

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("disabled", normal)

func _set_species_name(species: String, is_shiny: bool) -> void:
	name_label.text = species
	name_label.add_theme_font_size_override("font_size", _get_name_font_size(species))
	shiny_badge.text = "S" if is_shiny else ""
	shiny_badge.tooltip_text = _t("ui.party.shiny") if is_shiny else ""

func _get_name_font_size(species: String) -> int:
	var compact_name := species.replace(" ", "")
	if compact_mode:
		if compact_name.length() >= 11:
			return 10
		if compact_name.length() >= 9:
			return 11
		return 12
	if compact_name.length() >= 11:
		return VERY_LONG_NAME_FONT_SIZE
	if compact_name.length() >= 9:
		return LONG_NAME_FONT_SIZE

	return NAME_FONT_SIZE

func _on_pressed() -> void:
	if disabled:
		return
	selected.emit()

func _on_mouse_entered() -> void:
	if current_pokemon_data.is_empty():
		return

	pokemon_hovered.emit(current_pokemon_data, Rect2(global_position, size))

func _on_mouse_exited() -> void:
	pokemon_unhovered.emit()


func _on_locale_changed(_locale: String) -> void:
	if not current_pokemon_data.is_empty():
		set_pokemon_data(current_pokemon_data)


func _t(key: String, replacements: Dictionary = {}) -> String:
	if localization_manager != null:
		return str(localization_manager.call("text", key, replacements))
	return key
