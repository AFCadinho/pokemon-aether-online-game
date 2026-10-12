extends "res://tests/elemental_move_forms_check.gd"
const Batch = preload("res://scripts/battle/battle_ui/elemental_batch_effect_3d.gd")

func _test_moves() -> Array:
	return Batch.Profiles.DATA.keys()

func _test_renderer() -> Script:
	return Batch

func _piece_budget() -> int:
	return 48
