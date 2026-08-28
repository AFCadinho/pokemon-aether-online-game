extends SceneTree

const ROUTES := {
	"res://scenes/overworld/kanto/routes/kanto_route_4.tscn": {
		"bounds": Rect2i(0, 0, 101, 50),
		"pokemon": {
			"Entities/Pokemon/MountainPokemon/Rookidee": ["kanto_route_4_mountain_rookidee_1", "rookidee", Vector2(464, 656), 0, "pace_horizontal", true],
			"Entities/Pokemon/MountainPokemon/Aron": ["kanto_route_4_mountain_aron_1", "aron", Vector2(1488, 176), 302, "pace_horizontal", false],
			"Entities/Pokemon/MountainPokemon/Drilbur": ["kanto_route_4_mountain_drilbur_1", "drilbur", Vector2(2288, 176), 302, "pace_horizontal", false],
			"Entities/Pokemon/MountainPokemon/Rockruff": ["kanto_route_4_mountain_rockruff_1", "rockruff", Vector2(2864, 176), 302, "pace_horizontal", false],
		},
	},
	"res://scenes/overworld/kanto/routes/kanto_route_24.tscn": {
		"bounds": Rect2i(0, 0, 45, 60),
		"pokemon": {
			"Entities/Pokemon/MountainPokemon/Corvisquire": ["kanto_route_24_mountain_corvisquire_1", "corvisquire", Vector2(176, 336), 268, "pace_horizontal", false],
			"Entities/Pokemon/MountainPokemon/Mudbray": ["kanto_route_24_mountain_mudbray_1", "mudbray", Vector2(144, 1264), 268, "pace_vertical", false],
			"Entities/Pokemon/MountainPokemon/Rolycoly": ["kanto_route_24_mountain_rolycoly_1", "rolycoly", Vector2(1360, 688), 295, "pace_horizontal", false],
			"Entities/Pokemon/MountainPokemon/Tinkatink": ["kanto_route_24_mountain_tinkatink_1", "tinkatink", Vector2(1392, 1168), 7, "pace_vertical", false],
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
			_check(str(pokemon.get("movement_behavior")) == expected[4], "%s moves along its designed ledge axis" % node_path)
			_check(int(pokemon.get("movement_tiles")) == 1, "%s uses a short one-tile patrol" % node_path)
			_check(bool(pokemon.get("ambient_movement_ignores_map_collision")) == expected[5], "%s uses the intended collision policy" % node_path)

			var center_cell := collision.local_to_map(collision.to_local(pokemon.global_position))
			var axis := Vector2i.RIGHT if expected[4] == "pace_horizontal" else Vector2i.DOWN
			for offset in range(-1, 2):
				var patrol_cell: Vector2i = center_cell + axis * offset
				_check(tall_grass.get_cell_source_id(patrol_cell) < 0, "%s patrol remains outside wild grass" % node_path)
				_check(water.get_cell_source_id(patrol_cell) < 0, "%s patrol remains outside water" % node_path)
				if expected[5]:
					_check(collision.get_cell_source_id(patrol_cell) >= 0, "%s flight remains over the marked cliff" % node_path)
				else:
					_check(collision.get_cell_source_id(patrol_cell) < 0, "%s patrol remains on open ledge ground" % node_path)
			if not expected[5]:
				_check(
					_land_component_size(center_cell, route_data.bounds, collision, water) == expected[3],
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
