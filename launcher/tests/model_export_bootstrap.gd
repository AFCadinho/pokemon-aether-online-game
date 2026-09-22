extends Node
## Test-build main scene only; never added to ordinary launcher startup.
func _ready() -> void:
	assert(not OS.has_feature("editor") and not OS.get_environment("POKEAETHER_E2E_DATA_HOME").is_empty())
	get_tree().set_script(load("res://tests/model_process_check.gd"))
	queue_free()
