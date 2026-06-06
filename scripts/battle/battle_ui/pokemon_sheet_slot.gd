extends VBoxContainer

signal pokemon_hovered(pokemon_data: Dictionary)
signal pokemon_unhovered

const NORMAL_ICON_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const FAINTED_ICON_MODULATE := Color(0.45, 0.45, 0.45, 0.75)

@onready var pokemon_icon: TextureRect = $PokemonIcon
@onready var hp_bar: ProgressBar = $HpBar

var current_pokemon_data: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	for child in get_children():
		if child is Control:
			var control: Control = child as Control
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_empty() -> void:
	visible = false
	current_pokemon_data = {}
	pokemon_icon.texture = null
	pokemon_icon.modulate = NORMAL_ICON_MODULATE
	hp_bar.value = 0

func set_pokemon_data(pokemon_data: Dictionary) -> void:
	visible = true
	current_pokemon_data = pokemon_data
	var condition: String = str(pokemon_data.get("condition", ""))
	var is_fainted: bool = condition.contains("fnt")

	var species: String = _get_species_from_data(pokemon_data)
	var icon: Texture2D = PokemonAssets.load_party_icon(species, _get_shiny_from_data(pokemon_data))

	if icon == null:
		icon = PokemonAssets.load_unknown_icon()

	pokemon_icon.texture = icon
	pokemon_icon.modulate = FAINTED_ICON_MODULATE if is_fainted else NORMAL_ICON_MODULATE

	var hp: int = _parse_current_hp(condition)
	var max_hp: int = _parse_max_hp(condition)

	hp_bar.max_value = max(max_hp, 1)
	hp_bar.value = clamp(hp, 0, hp_bar.max_value)

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

	return ident

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

func _parse_current_hp(condition: String) -> int:
	if condition.contains("/"):
		return int(condition.split("/")[0])

	return 0

func _parse_max_hp(condition: String) -> int:
	if condition.contains("/"):
		var right := str(condition.split("/")[1])
		return int(right.split(" ")[0])
	return 0

func _on_mouse_entered() -> void:
	if current_pokemon_data.is_empty():
		return

	pokemon_hovered.emit(current_pokemon_data)

func _on_mouse_exited() -> void:
	pokemon_unhovered.emit()
