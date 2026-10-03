extends SceneTree

const ROUTE_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_9.tscn"
const MOVING_POKEMON_PATHS: Array[String] = [
	"Entities/Pokemon/Spearow",
	"Entities/Pokemon/Sandshrew",
	"Entities/Pokemon/Rattata",
	"Entities/Pokemon/Ekans",
	"Entities/Pokemon/MountainPokemon/Gligar",
	"Entities/Pokemon/MountainPokemon/Nosepass",
	"Entities/Pokemon/MountainPokemon/Shieldon",
	"Entities/Pokemon/MountainPokemon/Carbink",
]

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var route := (load(ROUTE_SCENE) as PackedScene).instantiate()
	root.add_child(route)
	await process_frame

	var waits: Dictionary = {}
	var speeds: Dictionary = {}
	for relative_path: String in MOVING_POKEMON_PATHS:
		var pokemon := route.get_node_or_null(relative_path) as Node
		_check(pokemon != null, "%s exists" % relative_path)
		if pokemon == null:
			continue

		var wait_seconds := float(pokemon.get("movement_wait_seconds"))
		var jitter_seconds := float(pokemon.get("movement_wait_jitter_seconds"))
		var speed_pixels := float(pokemon.get("movement_speed_pixels"))
		_check(jitter_seconds > 0.0, "%s has randomized pauses" % relative_path)
		waits[wait_seconds] = true
		speeds[speed_pixels] = true

		var observed_delays: Dictionary = {}
		for _sample: int in range(8):
			var scheduled_at := Time.get_ticks_msec()
			pokemon.call("_schedule_next_npc_movement_step")
			var delay_msec := int(pokemon.get("movement_next_step_at_msec")) - scheduled_at
			var minimum_msec := int(maxf(wait_seconds - jitter_seconds, 0.0) * 1000.0) - 2
			var maximum_msec := int((wait_seconds + jitter_seconds) * 1000.0) + 2
			_check(delay_msec >= minimum_msec and delay_msec <= maximum_msec, "%s pause stays inside its randomized range" % relative_path)
			observed_delays[delay_msec] = true
		_check(observed_delays.size() > 1, "%s receives different pauses over time" % relative_path)

	_check(waits.size() == MOVING_POKEMON_PATHS.size(), "Route 9 Pokémon use distinct base pauses")
	_check(speeds.size() == MOVING_POKEMON_PATHS.size(), "Route 9 Pokémon use distinct movement speeds")
	route.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL %s" % message)
