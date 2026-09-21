extends Node
## Test-build main scene only; no login, world or network battle is entered.
func _ready() -> void:
	assert(not OS.has_feature("editor") and not OS.get_environment("POKEAETHER_E2E_DATA_HOME").is_empty())
	get_tree().set_script(load("res://tests/launcher_model_process_child.gd"))
	queue_free()
