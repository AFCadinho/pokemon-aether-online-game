extends "res://tests/thundershock_preview.gd"
func _start() -> void:
	electric_script = preload("res://scripts/battle/battle_ui/thunderbolt_move_effect_3d.gd")
	electric_name = "Thunderbolt"
	electric_index = 6
	await super._start()
