extends SceneTree

var failed := false

func _init() -> void:
	var overlay := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	var scene := FileAccess.get_file_as_string("res://scenes/interface/ui_overlay.tscn")
	var world := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var api := FileAccess.get_file_as_string("res://scripts/battle/battle_api/battle_api_client.gd")

	_check(scene.contains('[node name="EncounterModeTabs" type="HBoxContainer"'), "staff encounter popup has visible encounter tabs")
	_check(scene.contains('[node name="FreeModeButton" type="Button"'), "staff encounter popup has a free Pokémon tab")
	_check(scene.contains('[node name="MapModeButton" type="Button"'), "staff encounter popup has a map encounter tab")
	_check(scene.contains('[node name="EncounterMethod" type="OptionButton"'), "staff encounter popup has a method selector")
	_check(scene.contains('[node name="EncounterSpecies" type="OptionButton"'), "staff encounter popup has a species selector")
	_check(overlay.contains("func _handle_start_map_encounter_command()"), "staff UI starts selected map encounters")
	_check(overlay.contains("EncounterMetadataService.get_encounter_area_metadata"), "staff UI reads current-map encounter metadata")
	_check(overlay.contains("func _apply_staff_encounter_tab_style"), "staff encounter tabs use the custom UI style")
	_check(overlay.contains("_apply_developer_dropdown_style(dev_encounter_method)"), "method selector uses the custom dropdown style")
	_check(overlay.contains("PokemonAssets.load_party_icon(species, false)"), "species selector uses Pokémon HOME icons")
	_check(world.contains("forced_species_id: String = \"\""), "world forwards an optional staff-selected species")
	_check(api.contains('payload["forcedSpeciesId"]'), "battle API sends a selected species only when requested")
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL " + message)
