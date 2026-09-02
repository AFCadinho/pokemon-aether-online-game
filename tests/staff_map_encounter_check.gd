extends SceneTree

var failed := false

func _init() -> void:
	var overlay := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	var scene := FileAccess.get_file_as_string("res://scenes/interface/ui_overlay.tscn")
	var world := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var api := FileAccess.get_file_as_string("res://scripts/battle/battle_api/battle_api_client.gd")

	_check(scene.contains('[node name="EncounterMode" type="OptionButton"'), "staff encounter popup has a mode selector")
	_check(scene.contains('[node name="EncounterMethod" type="OptionButton"'), "staff encounter popup has a method selector")
	_check(scene.contains('[node name="EncounterSpecies" type="OptionButton"'), "staff encounter popup has a species selector")
	_check(overlay.contains("func _handle_start_map_encounter_command()"), "staff UI starts selected map encounters")
	_check(overlay.contains("EncounterMetadataService.get_encounter_area_metadata"), "staff UI reads current-map encounter metadata")
	_check(world.contains("forced_species_id: String = \"\""), "world forwards an optional staff-selected species")
	_check(api.contains('payload["forcedSpeciesId"]'), "battle API sends a selected species only when requested")
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL " + message)
