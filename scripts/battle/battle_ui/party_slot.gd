extends Button

signal selected

const FAINTED_BACKGROUND := Color("#30343c")
const FAINTED_BORDER := Color("#626a76")
const NORMAL_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const FAINTED_MODULATE := Color(0.62, 0.62, 0.62, 1.0)
const POISON_STATUS_TEXTURE: Texture2D = preload("res://assets/battles/status/poisoned.png")
const POISON_STATUS_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const TOXIC_STATUS_MODULATE := Color("#8c58ff")

@onready var pokemon_icon: TextureRect = $MarginContainer/HBoxContainer/PokemonIcon
@onready var name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var hp_bar: ProgressBar = $MarginContainer/HBoxContainer/VBoxContainer/BottomRowContainer/HPBar
@onready var status_icon: TextureRect = $MarginContainer/HBoxContainer/VBoxContainer/BottomRowContainer/StatusIcon

func _ready() -> void:
	_ignore_child_mouse_input(self)
	pressed.connect(_on_pressed)

func _ignore_child_mouse_input(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE


		_ignore_child_mouse_input(child)

func set_pokemon(pokemon: Pokemon) -> void:
	var is_fainted := pokemon.current_hp <= 0
	_apply_slot_style(pokemon.species, is_fainted)

	visible = true
	disabled = is_fainted
	modulate = FAINTED_MODULATE if is_fainted else NORMAL_MODULATE

	name_label.text = pokemon.species
	hp_bar.max_value = max(pokemon.max_hp, 1)
	hp_bar.value = clamp(pokemon.current_hp, 0, pokemon.max_hp)
	pokemon_icon.texture = PokemonAssets.load_party_icon(pokemon.species, pokemon.shiny)
	_set_status_icon("")

func set_pokemon_data(pokemon_data: Dictionary) -> void:
	var species := _get_species_from_data(pokemon_data)
	var condition: String = str(pokemon_data.get("condition", ""))
	var hp_data := _parse_condition(condition)
	var is_active := bool(pokemon_data.get("active", false))
	var is_fainted := bool(hp_data.get("fainted", false))

	_apply_slot_style(species, is_fainted)

	visible = true
	disabled = is_active or is_fainted
	modulate = FAINTED_MODULATE if is_fainted else NORMAL_MODULATE

	name_label.text = species

	hp_bar.max_value = max(int(hp_data.get("max_hp", 1)), 1)
	hp_bar.value = clamp(int(hp_data.get("current_hp", 0)), 0, int(hp_bar.max_value))
	pokemon_icon.texture = PokemonAssets.load_party_icon(species, _get_shiny_from_data(pokemon_data))
	_set_status_icon(_parse_status(condition))

func _get_species_from_data(pokemon_data: Dictionary) -> String:
	var display_species := str(pokemon_data.get("displaySpecies", ""))
	if display_species != "":
		return display_species

	var details := str(pokemon_data.get("details", ""))
	if details != "":
		return str(details.split(",")[0]).strip_edges()

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

func _parse_condition(condition: String) -> Dictionary:
	var result := {
		"current_hp": 0,
		"max_hp": 1,
		"fainted": false,
	}

	if condition.contains("fnt"):
		result["fainted"] = true

	if condition.contains("/"):
		var parts := condition.split("/")
		result["current_hp"] = int(parts[0])
		result["max_hp"] = max(int(str(parts[1]).split(" ")[0]), 1)

	return result

func _parse_status(condition: String) -> String:
	var parts: PackedStringArray = condition.split(" ")
	for part in parts:
		var status: String = str(part).strip_edges().to_lower()
		match status:
			"psn", "tox", "brn", "par", "slp", "frz":
				return status

	return ""

func _set_status_icon(status: String) -> void:
	status_icon.texture = _get_status_texture(status)
	status_icon.visible = status_icon.texture != null
	status_icon.tooltip_text = _get_status_tooltip(status) if status_icon.visible else ""
	status_icon.modulate = _get_status_modulate(status) if status_icon.visible else NORMAL_MODULATE

func _get_status_texture(status: String) -> Texture2D:
	match status.strip_edges().to_lower():
		"psn", "tox":
			return POISON_STATUS_TEXTURE

	return null

func _get_status_tooltip(status: String) -> String:
	match status.strip_edges().to_lower():
		"psn":
			return "Poisoned"
		"tox":
			return "Badly poisoned"
		"brn":
			return "Burned"
		"par":
			return "Paralyzed"
		"slp":
			return "Asleep"
		"frz":
			return "Frozen"

	return ""

func _get_status_modulate(status: String) -> Color:
	match status.strip_edges().to_lower():
		"tox":
			return TOXIC_STATUS_MODULATE

	return POISON_STATUS_MODULATE

func set_empty() -> void:
	visible = true
	disabled = true
	modulate = NORMAL_MODULATE

	name_label.text = ""
	hp_bar.value = 0
	pokemon_icon.texture = null
	_set_status_icon("")

	remove_theme_stylebox_override("normal")
	remove_theme_stylebox_override("hover")
	remove_theme_stylebox_override("pressed")
	remove_theme_stylebox_override("disabled")

func _apply_slot_style(species: String, is_fainted: bool) -> void:
	if is_fainted:
		_set_color(FAINTED_BACKGROUND, FAINTED_BORDER)
		return

	var types := PokemonFactory.get_species_types(species)
	if types.is_empty():
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("hover")
		remove_theme_stylebox_override("pressed")
		remove_theme_stylebox_override("disabled")
		return

	var primary_type := str(types[0])
	_set_color(TypeColors.get_slot_background(primary_type), TypeColors.get_slot_border(primary_type))

func _set_color(background: Color, border: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = background
	normal.border_color = border
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1

	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = background.lightened(0.08)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = background.darkened(0.08)

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("disabled", normal)

func _on_pressed() -> void:
	if disabled:
		return
	selected.emit()
