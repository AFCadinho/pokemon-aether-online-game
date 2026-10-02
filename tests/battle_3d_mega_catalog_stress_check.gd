extends "res://tests/battle_3d_legendary_stress_check.gd"
## Same three arena rounds, 20ms p95 gate and prepared observation intervals for the Mega cohort.

func _ready_pair(species: String, left_shiny: bool, right_shiny: bool) -> void:
	await super._ready_pair(species, left_shiny, right_shiny)
	# Attribute a slow aggregate round without changing its observation interval.
	var prepared := frame_samples.slice(maxi(0, frame_samples.size() - 120))
	prepared.sort()
	print("MEGA_PREPARED_P95 ", JSON.stringify({"species": species,
		"left_shiny": left_shiny, "arena": root.get_node("SettingsManager").battle_3d_arena,
		"frames": prepared.size(), "p95_ms": prepared[int(prepared.size() * .95)]}))
