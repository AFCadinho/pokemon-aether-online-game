extends "res://tests/catalog_batch_01_candidate_stress_check.gd"
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
func _run() -> void:
	var directory := OS.get_environment("POKEAETHER_FORM_BUNDLE_WORK")
	assert(directory.is_absolute_path())
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("runtime-fixture.json")))
	Registry.DATA.data.models.merge(fixture.models, true)
	Registry.DATA.data.profiles.merge(fixture.profiles, true)
	await super._run()
