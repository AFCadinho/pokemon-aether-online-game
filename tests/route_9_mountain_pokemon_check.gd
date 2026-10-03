extends SceneTree

const EXPECTED_POKEMON := {
	"Gligar": ["kanto_route_9_mountain_gligar_1", "gligar", Vector2(480, 400)],
	"Nosepass": ["kanto_route_9_mountain_nosepass_1", "nosepass", Vector2(1120, 400)],
	"Shieldon": ["kanto_route_9_mountain_shieldon_1", "shieldon", Vector2(1760, 400)],
	"Carbink": ["kanto_route_9_mountain_carbink_1", "carbink", Vector2(2240, 400)],
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := (load("res://scenes/overworld/kanto/routes/kanto_route_9.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	var mountain := map.get_node("Entities/Pokemon/MountainPokemon")
	var collision := map.get_node("Tiles/Collision") as TileMapLayer
	var grass := map.get_node("Tiles/TallGrass") as TileMapLayer
	var water := map.get_node("Tiles/Water") as TileMapLayer
	_check(mountain.get_child_count() == EXPECTED_POKEMON.size(), "Route 9 has four mountain Pokemon")
	var pokemon_ids: Dictionary = {}
	for node_name: String in EXPECTED_POKEMON:
		var expected: Array = EXPECTED_POKEMON[node_name]
		var pokemon := mountain.get_node_or_null(node_name) as Node2D
		_check(pokemon != null, "%s exists on Route 9's mountain" % node_name)
		if pokemon == null:
			continue
		var pokemon_id := str(pokemon.get("overworld_pokemon_id"))
		_check(pokemon_id == expected[0], "%s has its mountain content ID" % node_name)
		_check(not pokemon_ids.has(pokemon_id), "%s uses a unique content ID" % node_name)
		pokemon_ids[pokemon_id] = true
		_check(str(pokemon.get("species_id")) == expected[1], "%s uses its intended species" % node_name)
		_check(pokemon.position == expected[2], "%s is placed on the north mountain" % node_name)
		_check(str(pokemon.get("movement_behavior")) == "pace_horizontal", "%s patrols its ledge horizontally" % node_name)
		_check(int(pokemon.get("movement_tiles")) == 1, "%s uses a one-tile patrol" % node_name)
		_check(FollowerSpriteService.get_sprite_frames(expected[1], false) != null, "%s follower sprite resolves" % node_name)
		var center := collision.local_to_map(collision.to_local(pokemon.global_position))
		for offset in range(-1, 2):
			var cell: Vector2i = center + Vector2i.RIGHT * offset
			_check(collision.get_cell_source_id(cell) < 0, "%s patrol stays on open mountain ground" % node_name)
			_check(grass.get_cell_source_id(cell) < 0, "%s patrol stays outside wild grass" % node_name)
			_check(water.get_cell_source_id(cell) < 0, "%s patrol stays out of water" % node_name)
		_check(_land_component_size(center, Rect2i(0, 0, 96, 48), collision, water) == 264, "%s remains on the isolated mountain" % node_name)
	map.queue_free()
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
