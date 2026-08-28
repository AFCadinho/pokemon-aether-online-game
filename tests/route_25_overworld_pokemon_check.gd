extends SceneTree

const ROUTE_SCENE := "res://scenes/overworld/kanto/routes/route25/kanto_route_25.tscn"
const BOUNDS := Rect2i(0, 0, 80, 50)
const LOCAL_POKEMON := {
	"Entities/Pokemon/Meowth": ["kanto_route_25_meowth_1", "meowth", Vector2(848, 400), "pace_horizontal", "grass"],
	"Entities/Pokemon/Venonat": ["kanto_route_25_venonat_1", "venonat", Vector2(1136, 592), "pace_vertical", "grass"],
	"Entities/Pokemon/Squirtle": ["kanto_route_25_squirtle_1", "squirtle", Vector2(1136, 912), "pace_horizontal", "grass"],
	"Entities/Pokemon/Poliwag": ["kanto_route_25_poliwag_1", "poliwag", Vector2(2256, 1040), "pace_horizontal", "water"],
}
const MOUNTAIN_POKEMON := {
	"Entities/Pokemon/MountainPokemon/Nacli": ["kanto_route_25_mountain_nacli_1", "nacli", Vector2(1104, 112), 598],
	"Entities/Pokemon/MountainPokemon/Noibat": ["kanto_route_25_mountain_noibat_1", "noibat", Vector2(2192, 112), 598],
	"Entities/Pokemon/MountainPokemon/Gligar": ["kanto_route_25_mountain_gligar_1", "gligar", Vector2(336, 1296), 409],
	"Entities/Pokemon/MountainPokemon/Pawniard": ["kanto_route_25_mountain_pawniard_1", "pawniard", Vector2(1328, 1456), 409],
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var route := (load(ROUTE_SCENE) as PackedScene).instantiate()
	# Trainer readiness requests are unrelated to this layout check.
	var npcs := route.get_node("Entities/NPCs")
	for npc: Node in npcs.get_children():
		npcs.remove_child(npc)
		npc.free()
	root.add_child(route)
	await process_frame

	var collision := route.get_node("Tiles/Collision") as TileMapLayer
	var tall_grass := route.get_node("Tiles/TallGrass") as TileMapLayer
	var water := route.get_node("Tiles/Water") as TileMapLayer

	for node_path: String in LOCAL_POKEMON:
		var expected: Array = LOCAL_POKEMON[node_path]
		var pokemon := route.get_node_or_null(node_path) as Node2D
		_check(pokemon != null, "Route 25 contains %s" % node_path)
		if pokemon == null:
			continue
		_check(str(pokemon.get("overworld_pokemon_id")) == expected[0], "%s uses its canonical content ID" % node_path)
		_check(str(pokemon.get("species_id")) == expected[1], "%s uses a species from Route 25's encounter ecology" % node_path)
		_check(pokemon.position == expected[2], "%s remains at its designed position" % node_path)
		_check(str(pokemon.get("movement_behavior")) == expected[3], "%s patrols along its terrain" % node_path)
		_check(int(pokemon.get("movement_tiles")) == 1, "%s uses a short one-tile patrol" % node_path)
		var center_cell := collision.local_to_map(collision.to_local(pokemon.global_position))
		var axis := Vector2i.RIGHT if expected[3] == "pace_horizontal" else Vector2i.DOWN
		for offset in range(-1, 2):
			var patrol_cell: Vector2i = center_cell + axis * offset
			if expected[4] == "grass":
				_check(tall_grass.get_cell_source_id(patrol_cell) >= 0, "%s patrol remains in tall grass" % node_path)
			else:
				_check(water.get_cell_source_id(patrol_cell) >= 0, "%s patrol remains in water" % node_path)

	for node_path: String in MOUNTAIN_POKEMON:
		var expected: Array = MOUNTAIN_POKEMON[node_path]
		var pokemon := route.get_node_or_null(node_path) as Node2D
		_check(pokemon != null, "Route 25 contains %s" % node_path)
		if pokemon == null:
			continue
		_check(str(pokemon.get("overworld_pokemon_id")) == expected[0], "%s uses its canonical content ID" % node_path)
		_check(str(pokemon.get("species_id")) == expected[1], "%s uses its intended mountain species" % node_path)
		_check(pokemon.position == expected[2], "%s remains at its designed mountain position" % node_path)
		_check(str(pokemon.get("movement_behavior")) == "pace_horizontal", "%s patrols along its ledge" % node_path)
		_check(int(pokemon.get("movement_tiles")) == 1, "%s uses a short one-tile patrol" % node_path)
		var center_cell := collision.local_to_map(collision.to_local(pokemon.global_position))
		for offset in range(-1, 2):
			var patrol_cell: Vector2i = center_cell + Vector2i.RIGHT * offset
			_check(collision.get_cell_source_id(patrol_cell) < 0, "%s patrol remains on open ledge ground" % node_path)
			_check(tall_grass.get_cell_source_id(patrol_cell) < 0, "%s patrol remains outside wild grass" % node_path)
			_check(water.get_cell_source_id(patrol_cell) < 0, "%s patrol remains outside water" % node_path)
		var component_size := _land_component_size(center_cell, collision, water)
		_check(
			component_size == expected[3],
			"%s stands on its isolated mountain landmass (expected %d cells, found %d)" % [node_path, expected[3], component_size],
		)

	route.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _land_component_size(start: Vector2i, collision: TileMapLayer, water: TileMapLayer) -> int:
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if not BOUNDS.has_point(neighbor) or visited.has(neighbor):
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
