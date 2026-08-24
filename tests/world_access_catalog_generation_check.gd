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
		areas.has("aether_clash_lobby")
			and (areas.get("aether_clash_lobby", {}) as Dictionary)
				.get("spawnPoints", {})
				.has("guild_arrival"),
		"Aether Clash Lobby and its Guild arrival point are registered"
	)
	_expect(
		(areas.get("aether_clash_lobby", {}) as Dictionary).get("sceneAliases", [])
			== ["uid://is25lssna4ae"],
		"Aether Clash Lobby exposes its scene UID independently of the local cache"
	)
	_expect(
		(areas.get("aether_clash_lobby", {}) as Dictionary).get("areaType", "")
			== "exterior",
		"Aether Clash Lobby is categorized as an exterior map"
	)
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
	_expect(
		(areas.get("kanto_pewter_city", {}) as Dictionary)
			.get("spawnPoints", {})
			.get("from_pokecenter", {})
			.get("label", "") == "Pokémon Center",
		"Staff destinations use the place name instead of From Pokecenter"
	)
	_expect(
		(areas.get("kanto_pallet_town", {}) as Dictionary)
			.get("spawnPoints", {})
			.get("from_players_house", {})
			.get("label", "") == "Player's House",
		"Staff destinations humanize possessive place names"
	)
	var labels_avoid_directional_prefixes := true
	for area_value: Variant in areas.values():
		if not area_value is Dictionary:
			continue
		var points_value: Variant = (area_value as Dictionary).get("spawnPoints", {})
		if not points_value is Dictionary:
			continue
		for point_value: Variant in (points_value as Dictionary).values():
			if not point_value is Dictionary:
				continue
			var point_label := str((point_value as Dictionary).get("label", "")).to_lower()
			if point_label.begins_with("from ") or point_label.begins_with("to "):
				labels_avoid_directional_prefixes = false
	_expect(
		labels_avoid_directional_prefixes,
		"Staff destination labels never expose technical From or To prefixes"
	)
	var unsafe_staff_points: Array[String] = []
	for area_id_value: Variant in areas:
		var area_id := str(area_id_value)
		var area_value: Variant = areas.get(area_id, {})
		if not area_value is Dictionary:
			continue
		var spawn_points_value: Variant = area_value.get("spawnPoints", {})
		if not spawn_points_value is Dictionary:
			continue
		for point_id_value: Variant in spawn_points_value:
			var point_id := str(point_id_value)
			var point_value: Variant = spawn_points_value.get(point_id, {})
			if not point_value is Dictionary or not bool(point_value.get(
				"safeForStaffTeleport", false
			)):
				unsafe_staff_points.append("%s:%s" % [area_id, point_id])
	unsafe_staff_points.sort()
	_expect(
		unsafe_staff_points == [
			"aether_clash_battle_royale_preview:jail",
			"aether_clash_battle_royale_preview:preview",
			"aether_clash_duel_preview:preview",
			"aether_clash_waiting_area_preview:preview",
		],
		"Only isolated Aether Clash previews are excluded from safe player teleports"
	)
	_expect(areas.has("kanto_route_2_gate"), "Inherited transition building is registered")
	_expect(
		areas.has("kanto_pewter_city_gym")
			and not bool((areas.get("kanto_pewter_city_gym", {}) as Dictionary).get("accessOnly", false))
			and (areas.get("kanto_pewter_city_gym", {}) as Dictionary).get("scenePath", "")
			== "res://scenes/overworld/kanto/towns/pewter_city/pewter_gym.tscn"
			and (areas.get("kanto_pewter_city_gym", {}) as Dictionary).get("defaultMode", "") == "open",
		"Pewter Gym is registered as an open scene-backed area"
	)
	_expect(
		bool((areas.get("kanto_pewter_city_museum", {}) as Dictionary).get("accessOnly", false)),
		"Future Pewter Museum remains an open access-only area"
	)
	_expect(
		not bool((areas.get("kanto_pewter_city_house_1", {}) as Dictionary).get("accessOnly", false))
			and (areas.get("kanto_pewter_city_house_1", {}) as Dictionary).get("scenePath", "")
			== "res://scenes/overworld/kanto/towns/pewter_city/house1.tscn"
			and (areas.get("kanto_pewter_city_house_1", {}) as Dictionary).get("defaultMode", "")
			== "open"
			and not bool((areas.get("kanto_pewter_city_house_2", {}) as Dictionary).get("accessOnly", false))
			and (areas.get("kanto_pewter_city_house_2", {}) as Dictionary).get("scenePath", "")
			== "res://scenes/overworld/kanto/towns/pewter_city/house2.tscn"
			and (areas.get("kanto_pewter_city_house_2", {}) as Dictionary).get("defaultMode", "")
			== "open",
		"Pewter houses are registered as open scene-backed areas"
	)
	_expect(
		transitions.has("kanto_pewter_city__to_house_1")
			and transitions.has("kanto_pewter_city__to_house_2")
			and transitions.has("kanto_pewter_city_house_1__to_pewter_city")
			and transitions.has("kanto_pewter_city_house_2__to_pewter_city"),
		"Pewter houses expose connected entrance and exit transitions"
	)
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
		transitions.has("kanto_viridian_city__to_route_1")
			and transitions.has("kanto_viridian_city__to_route_2")
			and transitions.has("kanto_viridian_city__to_route_22")
			and transitions.has("kanto_route_22__to_viridian_city"),
		"Viridian City exposes guarded route transitions including Route 22"
	)
	var route_22_points := (
		(areas.get("kanto_route_22", {}) as Dictionary).get("spawnPoints", {}) as Dictionary
	)
	_expect(
		route_22_points.has("victory_road_post")
			and (route_22_points.get("victory_road_post", {}) as Dictionary).get(
				"spawnMarker", ""
			) == "FromVictoryRoadPost",
		"Route 22 exposes the Victory Road Post staff destination"
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
