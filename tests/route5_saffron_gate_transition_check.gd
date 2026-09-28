extends SceneTree

const CATALOG_PATH := "res://generated/world_access_catalog.json"

var failed := false


func _init() -> void:
	var payload_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	_expect(payload_value is Dictionary, "World access catalog is valid JSON")
	if not payload_value is Dictionary:
		quit(1)
		return

	var payload := payload_value as Dictionary
	var areas := payload.get("areas", {}) as Dictionary
	var transitions := payload.get("transitions", {}) as Dictionary
	var gate := areas.get("kanto_route_5_saffron_gate", {}) as Dictionary
	_expect(
		gate.get("scenePath", "")
			== "res://scenes/overworld/kanto/transition_buildings/route_5_saffron_gate.tscn",
		"Route 5–Saffron Gate uses the reusable indoor transition scene"
	)
	_expect(gate.get("areaType", "") == "transition", "Gate is catalogued as a transition")
	_expect(
		gate.get("spawnPoints", {}).has("from_north")
			and gate.get("spawnPoints", {}).has("from_south"),
		"Gate provides entry points from both sides"
	)

	_check_transition(
		transitions,
		"kanto_route_5__to_saffron_gate",
		"kanto_route_5",
		"kanto_route_5_saffron_gate",
		"FromNorth"
	)
	_check_transition(
		transitions,
		"kanto_route_5_saffron_gate__to_route5",
		"kanto_route_5_saffron_gate",
		"kanto_route_5",
		"FromSaffronNorth"
	)
	_check_transition(
		transitions,
		"kanto_saffron_city__to_route5_gate",
		"kanto_saffron_city",
		"kanto_route_5_saffron_gate",
		"FromSouth"
	)
	_check_transition(
		transitions,
		"kanto_route_5_saffron_gate__to_saffron_city",
		"kanto_route_5_saffron_gate",
		"kanto_saffron_city",
		"FromRoute5"
	)

	quit(1 if failed else 0)


func _check_transition(
	transitions: Dictionary,
	transition_id: String,
	source_map_id: String,
	destination_map_id: String,
	spawn_marker: String
) -> void:
	var transition_value: Variant = transitions.get(transition_id, null)
	_expect(transition_value is Dictionary, "Transition exists: %s" % transition_id)
	if not transition_value is Dictionary:
		return
	var transition := transition_value as Dictionary
	var destination := transition.get("destination", {}) as Dictionary
	_expect(
		transition.get("sourceMapId", "") == source_map_id
			and transition.get("destinationAreaId", "") == destination_map_id
			and destination.get("spawnMarker", "") == spawn_marker,
		"Transition endpoints and spawn are correct: %s" % transition_id
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failed = true
		push_error("FAIL: %s" % message)
