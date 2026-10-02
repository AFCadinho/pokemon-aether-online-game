extends SceneTree

const MAPS := {
	"res://scenes/overworld/kanto/routes/kanto_route_9.tscn": {
		"Entities/Pokemon/Spearow": ["kanto_route_9_spearow_1", "spearow", Vector2(1136, 656), "grass", Vector2i.DOWN],
		"Entities/Pokemon/Sandshrew": ["kanto_route_9_sandshrew_1", "sandshrew", Vector2(1872, 1008), "grass", Vector2i.DOWN],
	},
	"res://scenes/overworld/kanto/routes/kanto_route_10.tscn": {
		"Entities/Pokemon/Voltorb": ["kanto_route_10_voltorb_1", "voltorb", Vector2(848, 496), "grass", Vector2i.DOWN],
		"Entities/Pokemon/Ekans": ["kanto_route_10_ekans_1", "ekans", Vector2(1104, 2576), "grass", Vector2i.DOWN],
	},
	"res://scenes/overworld/kanto/caves/rock_tunnel/1f.tscn": {
		"Entities/Pokemon/Geodude": ["kanto_rock_tunnel_1f_geodude_1", "geodude", Vector2(656, 336), "cave", Vector2i.DOWN],
		"Entities/Pokemon/Zubat": ["kanto_rock_tunnel_1f_zubat_1", "zubat", Vector2(1936, 848), "cave", Vector2i.DOWN],
	},
	"res://scenes/overworld/kanto/caves/rock_tunnel/b1f.tscn": {
		"Entities/Pokemon/Cubone": ["kanto_rock_tunnel_b1f_cubone_1", "cubone", Vector2(1712, 848), "cave", Vector2i.DOWN],
		"Entities/Pokemon/Onix": ["kanto_rock_tunnel_b1f_onix_1", "onix", Vector2(2032, 848), "cave", Vector2i.DOWN],
	},
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene_path: String in MAPS:
		var packed := load(scene_path) as PackedScene
		_check(packed != null, "%s loads" % scene_path)
		if packed == null:
			continue
		var map := packed.instantiate()
		root.add_child(map)
		await process_frame
		var collision := map.get_node("Tiles/Collision") as TileMapLayer
		var grass := map.get_node_or_null("Tiles/TallGrass") as TileMapLayer
		var cave_ground := map.get_node_or_null("Visual/Ground") as TileMapLayer
		var water := map.get_node("Tiles/Water") as TileMapLayer
		for node_path: String in MAPS[scene_path]:
			var expected: Array = MAPS[scene_path][node_path]
			var pokemon := map.get_node_or_null(node_path) as Node2D
			_check(pokemon != null, "%s exists" % node_path)
			if pokemon == null:
				continue
			_check(str(pokemon.get("overworld_pokemon_id")) == expected[0], "%s has its content ID" % node_path)
			_check(str(pokemon.get("species_id")) == expected[1], "%s has its intended species" % node_path)
			_check(pokemon.position == expected[2], "%s is placed at the selected habitat" % node_path)
			_check(str(pokemon.get("movement_behavior")) == "pace_vertical", "%s uses its short vertical patrol" % node_path)
			var terrain: TileMapLayer = grass if expected[3] == "grass" else cave_ground
			_check(terrain != null, "%s has its habitat layer" % node_path)
			if terrain == null:
				continue
			var center := collision.local_to_map(collision.to_local(pokemon.global_position))
			for offset in range(-1, 2):
				var cell: Vector2i = center + expected[4] * offset
				_check(terrain.get_cell_source_id(cell) >= 0, "%s patrol remains in its habitat" % node_path)
				_check(collision.get_cell_source_id(cell) < 0, "%s patrol remains walkable" % node_path)
				_check(water.get_cell_source_id(cell) < 0, "%s patrol avoids water" % node_path)
		map.queue_free()
		await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
