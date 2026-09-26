extends SceneTree
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
func _init() -> void:
	assert(Arenas.validate("bogus")=="classic")
	assert(Arenas.validate_selection("bogus")=="auto")
	for pair in [["grass","forest"],["water","sea"],["cave","cave"],["pvp_stadium","stadium"],["unknown","forest"]]:
		assert(Arenas.resolve("auto",StringName(pair[0]))==pair[1])
		assert(Arenas.resolve("cave",StringName(pair[0]))=="cave")
	# The same location selects calm terrain for wild encounters and its
	# authored map scene for trainer battles. This includes gym interiors and
	# fishing/surfing on maps with a shoreline variant.
	for pair in [["route_1", "forest"], ["route_2", "forest"], ["route_3", "forest"], ["route_4", "forest"], ["route_22", "forest"], ["route_24", "forest"], ["pallet_town", "forest"], ["viridian_city", "forest"], ["pewter_city", "forest"], ["cerulean_city", "forest"], ["route_25", "forest"], ["route_1_water", "sea"], ["route_24_water", "sea"], ["pallet_town_water", "sea"], ["viridian_city_water", "sea"], ["pewter_city_gym", "cave"], ["cerulean_city_gym", "sea"]]:
		assert(Arenas.resolve("auto", StringName(pair[0]), "wild") == pair[1], pair[0])
		assert(Arenas.resolve("auto", StringName(pair[0]), "trainer") == pair[0], pair[0])
	assert(Arenas.resolve("auto", &"cave", "wild") == "cave")
	assert(Arenas.resolve("auto", &"pvp_stadium", "pvp") == "stadium")
	assert(Arenas.resolve("cave", &"route_1", "wild") == "cave", "review overrides still work")
	var resolver = preload("res://scripts/battle/battle_environment_resolver.gd")
	for context in [{"battle_kind":"pvp"},{"battle_kind":"wild","map_id":"aether_clash_lobby"},{"battle_kind":"trainer","explicit_environment_id":"pvp_stadium"}]:
		assert(Arenas.resolve("auto",resolver.resolve(context))=="stadium")
	for id in Arenas.IDS:
		assert(Arenas.validate(id)==id)
		var entry := Arenas.definition(id)
		assert(entry.scope == ("map" if (id in ["pallet_town", "pallet_town_water", "viridian_city", "viridian_city_water", "pewter_city"] or id.ends_with("_gym") or id.begins_with("route_") or id.begins_with("cerulean_city")) else "generic"))
		if id != "classic":
			assert(ResourceLoader.exists("res://scripts/battle/arenas/" + entry.builder))
		if entry.scope == "map":
			assert(entry.map_id == "kanto_" + id.trim_suffix("_water"))
		assert((Arenas.camera_home(id) - Arenas.battle_origin(id)).is_equal_approx(Vector3(2.5, 5, 16) if id == "stadium" else Vector3(4, 5.5, 12)))
		assert((Arenas.camera_target(id) - Arenas.battle_origin(id)).is_equal_approx(Vector3(0, 2.8, 0) if id == "stadium" else Vector3(0, 1.3, 0)))
	assert(Arenas.CAMERA_FOV == 48.0)
	assert(Arenas.spawn(0) == Vector3(-2.8, 0, 1.5))
	assert(Arenas.spawn(1) == Vector3(2.8, 0, -1.5))
	assert(Arenas.spawn(0)!=Arenas.spawn(1))
	assert(not Arenas.prepare_forest("").is_empty())
	assert(not ClassDB.class_exists("Terrain3D"),"Ordinary client startup must not load the native forest addon")
	print("BATTLE_ARENA_CONTRACT_OK")
	quit()
