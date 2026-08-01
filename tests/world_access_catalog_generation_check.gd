extends SceneTree

const CATALOG_PATH := "res://generated/world_access_catalog.json"

var failed := false


func _init() -> void:
	var payload_value: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(CATALOG_PATH)
	)
	_expect(payload_value is Dictionary, "Generated world access catalog is valid JSON")
	if not payload_value is Dictionary:
		quit(1)
		return

	var payload := payload_value as Dictionary
	var areas_value: Variant = payload.get("areas", {})
	var transitions_value: Variant = payload.get("transitions", {})
	_expect(payload.get("schemaVersion") == 3, "Catalog schema version is supported")
	_expect(areas_value is Dictionary, "Catalog exposes an area dictionary")
	_expect(transitions_value is Dictionary, "Catalog exposes a transition dictionary")
	if not areas_value is Dictionary or not transitions_value is Dictionary:
		quit(1)
		return

	var areas := areas_value as Dictionary
	var transitions := transitions_value as Dictionary
	_expect(areas.size() >= 13, "All current overworld maps are registered")
	_expect(transitions.size() >= 28, "All configured map exits are registered")
	_expect(areas.has("kanto_pallet_town"), "Pallet Town is registered")
	_expect(
		areas.has("kanto_pewter_city_pokemon_center"),
		"Inherited Pokémon Center scene metadata is registered"
	)
	_expect(
		areas.has("kanto_viridian_city_pokemon_center"),
		"Viridian City Pokémon Center scene metadata is registered"
	)
	var viridian_center := areas.get("kanto_viridian_city_pokemon_center", {}) as Dictionary
	var viridian_center_points := viridian_center.get("spawnPoints", {}) as Dictionary
	_expect(
		viridian_center_points.has("from_outside")
			and viridian_center_points.has("heal_npc"),
		"Inherited Pokémon Center spawn points are part of the canonical catalog"
	)
	var viridian_city := areas.get("kanto_viridian_city", {}) as Dictionary
	var viridian_points := viridian_city.get("spawnPoints", {}) as Dictionary
	_expect(
		bool((viridian_points.get("route_1_entrance", {}) as Dictionary).get(
			"safeForStaffTeleport", false
		))
			and not bool((viridian_points.get("from_pokecenter", {}) as Dictionary).get(
				"safeForStaffTeleport", true
			)),
		"Staff-safe destinations are explicit and fail closed"
	)
	_expect(areas.has("kanto_route_2_gate"), "Inherited transition building is registered")
	_expect(
		(areas.get("kanto_oaks_lab", {}) as Dictionary).get("locationGroupId", "")
			== "kanto_pallet_town",
		"Oak's Lab is grouped under Pallet Town"
	)
	_expect(
		(areas.get("kanto_route_2_gate", {}) as Dictionary).get("areaType", "")
			== "transition",
		"Route 2 Gate is categorized as a transition map"
	)
	_expect(
		transitions.has("route_1_to_viridian_city"),
		"Stable Route 1 to Viridian transition is retained"
	)
	_expect(
		transitions.has("kanto_viridian_city__to_pokecenter")
			and transitions.has("kanto_viridian_city_pokemon_center__to_outside"),
		"Viridian City Pokémon Center has connected entrance and exit transitions"
	)

	for transition_id: Variant in transitions:
		var transition_value: Variant = transitions[transition_id]
		if not transition_value is Dictionary:
			_expect(false, "Transition %s is a dictionary" % str(transition_id))
			continue
		var transition := transition_value as Dictionary
		_expect(
			areas.has(str(transition.get("sourceMapId", ""))),
			"Transition %s has a registered source" % str(transition_id)
		)
		_expect(
			areas.has(str(transition.get("destinationAreaId", ""))),
			"Transition %s has a registered destination" % str(transition_id)
		)

	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s" % message)
