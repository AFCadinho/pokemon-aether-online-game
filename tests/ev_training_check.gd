extends SceneTree

func _init() -> void:
	var scene_source := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn"
	)
	var map_script_source := FileAccess.get_file_as_string(
		"res://scripts/world/kanto/towns/viridian_city.gd"
	)
	var gate_source := FileAccess.get_file_as_string(
		"res://scripts/world/npcs/ev_training_gate_npc.gd"
	)
	var service_source := FileAccess.get_file_as_string(
		"res://scripts/services/ev_training_service.gd"
	)
	var expert_source := FileAccess.get_file_as_string(
		"res://scripts/world/kanto/towns/ev_training_expert_mateo.gd"
	)
	_assert(scene_source.contains("EVExpertMateo"), "EV expert Mateo is missing")
	_assert(scene_source.contains("EVAssistantRina"), "north EV assistant is missing")
	_assert(scene_source.contains("EVAssistantEli"), "south EV assistant is missing")
	_assert(scene_source.contains("kanto_viridian_city_ev_training"), "EV encounter region is missing")
	_assert(scene_source.contains("EVTrainingNorthInside"), "north teleport markers are missing")
	_assert(scene_source.contains("EVTrainingSouthInside"), "south teleport markers are missing")
	_assert(map_script_source.contains("_setup_ev_training_grass"), "EV grass mask setup is missing")
	for stat: String in ["hp", "atk", "def", "spa", "spd", "spe"]:
		_assert(gate_source.contains('"id": "%s"' % stat), "missing EV stat choice: %s" % stat)
	_assert(service_source.contains("/game/ev-training/session"), "EV session endpoint is missing")
	_assert(service_source.contains("/game/ev-training/tutorial/focus"), "EV tutorial focus endpoint is missing")
	_assert(expert_source.contains("allocate_training_evs"), "Mateo's EV allocation lesson is missing")
	print("EV training checks passed.")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
