extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	var scene_source := FileAccess.get_file_as_string(OVERLAY_SCENE_PATH)
	var script_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check_contains(scene_source, '[node name="WildPokemonButton"', "location bar has a wild Pokémon button")
	_check_contains(scene_source, 'tooltip_text = "ui.navigation.wild_pokemon"', "wild Pokémon button has a localized tooltip")
	_check_contains(script_source, "func _get_current_encounter_area_id()", "overlay resolves the current encounter area")
	_check_contains(script_source, "EncounterMetadataService.get_encounter_area_metadata(area_id)", "popup loads encounter metadata")
	_check_contains(script_source, "func _render_wild_pokemon_metadata", "popup renders encounter metadata")
	_check_contains(script_source, "PokemonAssets.load_party_icon(species, false)", "popup renders Pokémon icons")
	_check_contains(script_source, '"ui.wild.level_range"', "popup renders localized encounter level ranges")
	_check_contains(script_source, "func _create_wild_pokemon_rarity_badge", "popup renders rarity badges")
	_check_contains(script_source, "func _create_encounter_time_badge", "popup renders day, night, or any badges")
	_check_contains(script_source, 'entry.get("timeOfDay", "any")', "popup reads encounter time metadata")
	_check_contains(script_source, 'location.get("timeOfDay", "any")', "Pokédex locations read encounter time metadata")
	_check_contains(script_source, '"ui.encounter.time.%s"', "encounter time labels are localized")
	_check_contains(script_source, "PokedexService.is_species_owned(species, false)", "owned wild species show their Pokédex Poké Ball")
	_check_contains(script_source, "func _animate_wild_pokemon_button()", "radar button has hover feedback")

	quit(1 if failed else 0)


func _check_contains(source: String, expected: String, label: String) -> void:
	if source.contains(expected):
		return

	failed = true
	push_error(label)
