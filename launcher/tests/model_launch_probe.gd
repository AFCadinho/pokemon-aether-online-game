extends "res://scripts/launcher.gd"
## Loaded after autoload initialization; never launches an actual process.
var model_path := ""
var observed := ""
var result := 42

func _selected_model_catalog() -> String:
	return model_path

func _create_game_process_with_mods(_path: String) -> int:
	observed = OS.get_environment("POKEAETHER_MODEL_CATALOG")
	return result
