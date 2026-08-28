extends SceneTree

const ROUTES := {
	"res://scenes/overworld/kanto/routes/kanto_route_4.tscn": {
		"Entities/Pokemon/Sandshrew": ["kanto_route_4_sandshrew_1", "sandshrew", Vector2(1744, 624), "ground", "pace_horizontal"],
		"Entities/Pokemon/Mankey": ["kanto_route_4_mankey_1", "mankey", Vector2(2512, 1328), "ground", "pace_horizontal"],
		"Entities/Pokemon/Spearow": ["kanto_route_4_spearow_1", "spearow", Vector2(2992, 656), "grass", "pace_horizontal"],
		"Entities/Pokemon/Tentacool": ["kanto_route_4_tentacool_1", "tentacool", Vector2(2896, 1040), "water", "pace_horizontal"],
	},
	"res://scenes/overworld/kanto/routes/kanto_route_24.tscn": {
		"Entities/Pokemon/Abra": ["kanto_route_24_abra_1", "abra", Vector2(1296, 176), "grass", "pace_horizontal"],
		"Entities/Pokemon/Oddish": ["kanto_route_24_oddish_1", "oddish", Vector2(880, 592), "grass", "pace_horizontal"],
		"Entities/Pokemon/Squirtle": ["kanto_route_24_squirtle_1", "squirtle", Vector2(432, 1168), "grass", "pace_vertical"],
		"Entities/Pokemon/Magikarp": ["kanto_route_24_magikarp_1", "magikarp", Vector2(496, 1296), "water", "pace_vertical"],
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
			_check(str(pokemon.get("movement_behavior")) == expected[4], "%s uses its designed patrol axis" % node_path)
			_check(int(pokemon.get("movement_tiles")) == 1, "%s uses a short one-tile patrol" % node_path)

			var center_cell := collision.local_to_map(collision.to_local(pokemon.global_position))
			var axis := Vector2i.RIGHT if expected[4] == "pace_horizontal" else Vector2i.DOWN
			for offset in range(-1, 2):
				var patrol_cell: Vector2i = center_cell + axis * offset
				if expected[3] == "grass":
					_check(collision.get_cell_source_id(patrol_cell) < 0, "%s patrol remains on walkable ground" % node_path)
					_check(tall_grass.get_cell_source_id(patrol_cell) >= 0, "%s patrol remains in local tall grass" % node_path)
					_check(water.get_cell_source_id(patrol_cell) < 0, "%s patrol remains outside water" % node_path)
				elif expected[3] == "water":
					_check(water.get_cell_source_id(patrol_cell) >= 0, "%s patrol remains in local water" % node_path)
				else:
					_check(collision.get_cell_source_id(patrol_cell) < 0, "%s patrol remains on walkable ground" % node_path)
					_check(water.get_cell_source_id(patrol_cell) < 0, "%s patrol remains outside water" % node_path)

		route.queue_free()
		await process_frame

	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
