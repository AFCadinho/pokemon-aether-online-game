extends "res://tests/elemental_move_forms_preview.gd"
const Profiles = preload("res://scripts/battle/battle_ui/elemental_batch_profiles_3d.gd")

func _preview_moves() -> Array:
	var selected := OS.get_environment("POKEAETHER_TEST_MOVES").split(",",false)
	return Array(selected) if not selected.is_empty() else Profiles.DATA.keys()
