extends "res://scripts/launcher.gd"
## Loaded after autoload initialization; exercises catalog selection without spawning.
var received_catalog := ""
var received_index := ""


func _create_game_process_with_mods(_path: String) -> int:
	received_catalog = OS.get_environment("POKEAETHER_MODEL_CATALOG")
	received_index = OS.get_environment("POKEAETHER_MODEL_INDEX")
	return 42
