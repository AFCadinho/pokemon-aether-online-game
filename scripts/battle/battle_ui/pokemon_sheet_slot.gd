extends VBoxContainer

const NORMAL_ICON_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const FAINTED_ICON_MODULATE := Color(0.45, 0.45, 0.45, 0.75)

@onready var pokemon_icon: TextureRect = $PokemonIcon
@onready var hp_bar: ProgressBar = $HpBar

func set_empty() -> void:
	visible = false
	pokemon_icon.texture = null
	pokemon_icon.modulate = NORMAL_ICON_MODULATE
	hp_bar.value = 0

func set_pokemon_data(pokemon_data: Dictionary) -> void:
	visible = true
	var condition := str(pokemon_data.get("condition", ""))
	var is_fainted := condition.contains("fnt")

	var species := _get_species_from_ident(str(pokemon_data.get("ident", "")))
	var icon := PokemonAssets.load_party_icon(species)

	if icon == null:
		icon = PokemonAssets.load_unknown_icon()

	pokemon_icon.texture = icon
	pokemon_icon.modulate = FAINTED_ICON_MODULATE if is_fainted else NORMAL_ICON_MODULATE

	var hp := _parse_current_hp(condition)
	var max_hp := _parse_max_hp(condition)

	hp_bar.max_value = max(max_hp, 1)
	hp_bar.value = clamp(hp, 0, hp_bar.max_value)

func _get_species_from_ident(ident: String) -> String:
	if ident.contains(": "):
		return str(ident.split(": ")[1]).strip_edges()

	return ident

func _parse_current_hp(condition: String) -> int:
	if condition.contains("/"):
		return int(condition.split("/")[0])

	return 0

func _parse_max_hp(condition: String) -> int:
	if condition.contains("/"):
		var right := str(condition.split("/")[1])
		return int(right.split(" ")[0])
	return 0
