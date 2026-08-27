extends SceneTree

const GYM_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_gym.tscn"

const GYM_POKEMON := {
	"Entities/Pokemon/Staryu": {
		"id": "kanto_cerulean_city_gym_staryu_1",
		"species": "staryu",
		"level": 18,
		"position": Vector2(240, 304),
	},
	"Entities/Pokemon/Horsea": {
		"id": "kanto_cerulean_city_gym_horsea_1",
		"species": "horsea",
		"position": Vector2(336, 432),
	},
	"Entities/Pokemon/Shellder": {
		"id": "kanto_cerulean_city_gym_shellder_1",
		"species": "shellder",
		"position": Vector2(240, 752),
	},
	"Entities/Pokemon/Goldeen": {
		"id": "kanto_cerulean_city_gym_goldeen_1",
		"species": "goldeen",
		"position": Vector2(656, 880),
	},
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gym: Node = load(GYM_SCENE).instantiate()
	root.add_child(gym)
	await process_frame
	var collision := gym.find_map_tilemap_layer("Collision") as TileMapLayer
	var water := gym.find_map_tilemap_layer("Water") as TileMapLayer
	_check(collision != null, "Cerulean Gym exposes its collision layer")
	_check(water != null, "Cerulean Gym exposes its water layer")

	for node_path: String in GYM_POKEMON:
		var expected: Dictionary = GYM_POKEMON[node_path]
		var pokemon := gym.get_node_or_null(node_path) as Node2D
		_check(pokemon != null, "%s is placed in Cerulean Gym" % node_path)
		if pokemon == null:
			continue
		_check(str(pokemon.get("overworld_pokemon_id")) == expected.id, "%s uses its canonical content ID" % node_path)
		_check(str(pokemon.get("species_id")) == expected.species, "%s uses the intended species" % node_path)
		if expected.has("level"):
			_check(int(pokemon.get("level")) == expected.level, "%s uses its intended level" % node_path)
		_check(pokemon.position == expected.position, "%s occupies its designed pool position" % node_path)
		_check(str(pokemon.get("movement_behavior")) == "idle", "%s cannot wander onto land" % node_path)
		if collision != null and water != null:
			var collision_cell := collision.local_to_map(collision.to_local(pokemon.global_position))
			var water_cell := water.local_to_map(water.to_local(pokemon.global_position))
			_check(collision.get_cell_source_id(collision_cell) < 0, "%s does not block a walkway" % node_path)
			_check(water.get_cell_source_id(water_cell) >= 0, "%s stays inside a Gym pool" % node_path)

	gym.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
