extends SceneTree

const ROUTES := {
	"res://scenes/overworld/kanto/routes/kanto_route_4.tscn": {
		"bounds": Rect2i(0, 0, 101, 50),
		"pokemon": {
			"Entities/Pokemon/MountainPokemon/Rookidee": ["kanto_route_4_mountain_rookidee_1", "rookidee", Vector2(1136, 112), 302],
			"Entities/Pokemon/MountainPokemon/Aron": ["kanto_route_4_mountain_aron_1", "aron", Vector2(1616, 112), 302],
			"Entities/Pokemon/MountainPokemon/Drilbur": ["kanto_route_4_mountain_drilbur_1", "drilbur", Vector2(2224, 112), 302],
			"Entities/Pokemon/MountainPokemon/Rockruff": ["kanto_route_4_mountain_rockruff_1", "rockruff", Vector2(2832, 112), 302],
		},
	},
	"res://scenes/overworld/kanto/routes/kanto_route_24.tscn": {
		"bounds": Rect2i(0, 0, 45, 60),
		"pokemon": {
			"Entities/Pokemon/MountainPokemon/Corvisquire": ["kanto_route_24_mountain_corvisquire_1", "corvisquire", Vector2(176, 400), 268],
			"Entities/Pokemon/MountainPokemon/Mudbray": ["kanto_route_24_mountain_mudbray_1", "mudbray", Vector2(176, 1264), 268],
			"Entities/Pokemon/MountainPokemon/Rolycoly": ["kanto_route_24_mountain_rolycoly_1", "rolycoly", Vector2(1296, 656), 295],
			"Entities/Pokemon/MountainPokemon/Tinkatink": ["kanto_route_24_mountain_tinkatink_1", "tinkatink", Vector2(1136, 1520), 295],
		},
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
		var route_data: Dictionary = ROUTES[scene_path]

		for node_path: String in route_data.pokemon:
			var expected: Array = route_data.pokemon[node_path]
			var pokemon := route.get_node_or_null(node_path) as Node2D
			_check(pokemon != null, "%s contains %s" % [scene_path, node_path])
			if pokemon == null:
				continue
			_check(str(pokemon.get("overworld_pokemon_id")) == expected[0], "%s uses its canonical content ID" % node_path)
			_check(str(pokemon.get("species_id")) == expected[1], "%s uses the intended later-generation species" % node_path)
			_check(pokemon.position == expected[2], "%s remains at its designed mountain position" % node_path)
			_check(str(pokemon.get("movement_behavior")) == "idle", "%s cannot wander off its ledge" % node_path)

			var collision_cell := collision.local_to_map(collision.to_local(pokemon.global_position))
			var grass_cell := tall_grass.local_to_map(tall_grass.to_local(pokemon.global_position))
			var water_cell := water.local_to_map(water.to_local(pokemon.global_position))
			_check(collision.get_cell_source_id(collision_cell) < 0, "%s stands on open ledge ground" % node_path)
			_check(tall_grass.get_cell_source_id(grass_cell) < 0, "%s stands outside the wild grass habitat" % node_path)
			_check(water.get_cell_source_id(water_cell) < 0, "%s stands outside water" % node_path)
			_check(
				_land_component_size(collision_cell, route_data.bounds, collision, water) == expected[3],
				"%s stands on its isolated mountain landmass" % node_path,
			)

		route.queue_free()
		await process_frame

	quit(1 if failed else 0)


func _land_component_size(start: Vector2i, bounds: Rect2i, collision: TileMapLayer, water: TileMapLayer) -> int:
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if not bounds.has_point(neighbor) or visited.has(neighbor):
				continue
			if collision.get_cell_source_id(neighbor) >= 0 or water.get_cell_source_id(neighbor) >= 0:
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	return visited.size()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
