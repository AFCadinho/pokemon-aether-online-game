extends SceneTree

const ROUTES := {
	"res://scenes/overworld/kanto/routes/kanto_route_4.tscn": {
		"Entities/Pokemon/Sandshrew": ["kanto_route_4_sandshrew_1", "sandshrew", Vector2(912, 1424), "grass"],
		"Entities/Pokemon/Mankey": ["kanto_route_4_mankey_1", "mankey", Vector2(2256, 1392), "grass"],
		"Entities/Pokemon/Spearow": ["kanto_route_4_spearow_1", "spearow", Vector2(2960, 624), "grass"],
		"Entities/Pokemon/Tentacool": ["kanto_route_4_tentacool_1", "tentacool", Vector2(2832, 1008), "water"],
	},
	"res://scenes/overworld/kanto/routes/kanto_route_24.tscn": {
		"Entities/Pokemon/Abra": ["kanto_route_24_abra_1", "abra", Vector2(1296, 176), "grass"],
		"Entities/Pokemon/Oddish": ["kanto_route_24_oddish_1", "oddish", Vector2(848, 624), "grass"],
		"Entities/Pokemon/Squirtle": ["kanto_route_24_squirtle_1", "squirtle", Vector2(464, 1040), "grass"],
		"Entities/Pokemon/Magikarp": ["kanto_route_24_magikarp_1", "magikarp", Vector2(560, 1136), "water"],
	},
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene_path: String in ROUTES:
		var route := (load(scene_path) as PackedScene).instantiate()
		root.add_child(route)
		await process_frame
		var collision := route.get_node("Tiles/Collision") as TileMapLayer
		var tall_grass := route.get_node("Tiles/TallGrass") as TileMapLayer
		var water := route.get_node("Tiles/Water") as TileMapLayer

		for node_path: String in ROUTES[scene_path]:
			var expected: Array = ROUTES[scene_path][node_path]
			var pokemon := route.get_node_or_null(node_path) as Node2D
			_check(pokemon != null, "%s contains %s" % [scene_path, node_path])
			if pokemon == null:
				continue
			_check(str(pokemon.get("overworld_pokemon_id")) == expected[0], "%s uses its canonical content ID" % node_path)
			_check(str(pokemon.get("species_id")) == expected[1], "%s uses the intended species" % node_path)
			_check(pokemon.position == expected[2], "%s remains at its designed position" % node_path)
			_check(str(pokemon.get("movement_behavior")) == "idle", "%s cannot wander out of its habitat" % node_path)

			var collision_cell := collision.local_to_map(collision.to_local(pokemon.global_position))
			var grass_cell := tall_grass.local_to_map(tall_grass.to_local(pokemon.global_position))
			var water_cell := water.local_to_map(water.to_local(pokemon.global_position))
			if expected[3] == "grass":
				_check(collision.get_cell_source_id(collision_cell) < 0, "%s stands on walkable ground" % node_path)
				_check(tall_grass.get_cell_source_id(grass_cell) >= 0, "%s stands in local tall grass" % node_path)
				_check(water.get_cell_source_id(water_cell) < 0, "%s does not stand in water" % node_path)
			else:
				_check(water.get_cell_source_id(water_cell) >= 0, "%s stands in local water" % node_path)

		route.queue_free()
		await process_frame

	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
