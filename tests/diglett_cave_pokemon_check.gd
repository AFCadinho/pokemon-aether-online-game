extends SceneTree

const CAVE_SCENE := "res://scenes/overworld/kanto/caves/diglett_cave/tunnel.tscn"
const EXPECTED_POKEMON: Dictionary = {
	"Diglett1": {"id": "kanto_diglett_cave_tunnel_diglett_1", "species": "diglett"},
	"Diglett2": {"id": "kanto_diglett_cave_tunnel_diglett_2", "species": "diglett"},
	"Diglett3": {"id": "kanto_diglett_cave_tunnel_diglett_3", "species": "diglett"},
	"Dugtrio": {"id": "kanto_diglett_cave_tunnel_dugtrio_1", "species": "dugtrio"},
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cave := (load(CAVE_SCENE) as PackedScene).instantiate()
	var pokemon_nodes: Array[Node] = cave.get_node("Entities/Pokemon").get_children()
	var waits: Dictionary = {}
	var speeds: Dictionary = {}
	var actual_ids := {}
	for pokemon_name: String in EXPECTED_POKEMON:
		var pokemon := cave.get_node_or_null("Entities/Pokemon/" + pokemon_name) as Node2D
		_check(pokemon != null, "%s is present in Diglett Cave" % pokemon_name)
		if pokemon == null:
			continue
		var expected: Dictionary = EXPECTED_POKEMON[pokemon_name]
		var pokemon_id := str(pokemon.get("overworld_pokemon_id"))
		_check(pokemon_id == str(expected["id"]), "%s has a unique metadata ID" % pokemon_name)
		_check(str(pokemon.get("species_id")) == str(expected["species"]), "%s species matches its metadata ID" % pokemon_name)
		_check(float(pokemon.get("movement_wait_jitter_seconds")) > 0.0, "%s has randomized pauses" % pokemon_name)
		waits[float(pokemon.get("movement_wait_seconds"))] = true
		speeds[float(pokemon.get("movement_speed_pixels"))] = true
		actual_ids[pokemon_id] = true

		var movement_behavior := str(pokemon.get("movement_behavior"))

	_check(pokemon_nodes.size() == EXPECTED_POKEMON.size(), "Only the intended cave Pokémon are placed")
	_check(actual_ids.size() == EXPECTED_POKEMON.size(), "Cave Pokémon metadata IDs are unique")
	_check(waits.size() == EXPECTED_POKEMON.size(), "Cave Pokémon use distinct base pauses")
	_check(speeds.size() == EXPECTED_POKEMON.size(), "Cave Pokémon use distinct walking speeds")
	if not failed:
		print("PASS Diglett Cave: Diglett and Dugtrio placements, metadata IDs and varied pacing")
	cave.free()
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL %s" % message)
