extends SceneTree

const ROUTE_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_6.tscn"
const POKEMON_PATHS: Array[String] = [
	"Entities/Pokemon/Pidgey",
	"Entities/Pokemon/Meowth",
	"Entities/Pokemon/Oddish",
	"Entities/Pokemon/Bellsprout",
	"Entities/Pokemon/Pidgey2",
]

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var route := (load(ROUTE_SCENE) as PackedScene).instantiate()
	root.add_child(route)
	await process_frame

	var speeds: Dictionary = {}
	var waits: Dictionary = {}
	for relative_path: String in POKEMON_PATHS:
		var pokemon := route.get_node_or_null(relative_path) as Node
		_check(pokemon != null, "%s exists" % relative_path)
		if pokemon == null:
			continue

		var wait_seconds := float(pokemon.get("movement_wait_seconds"))
		var jitter_seconds := float(pokemon.get("movement_wait_jitter_seconds"))
		var speed_pixels := float(pokemon.get("movement_speed_pixels"))
		_check(jitter_seconds > 0.0, "%s has randomized pauses" % relative_path)
		speeds[speed_pixels] = true
		waits[wait_seconds] = true

		var observed_delays: Dictionary = {}
		for _sample: int in range(8):
			var scheduled_at := Time.get_ticks_msec()
			pokemon.call("_schedule_next_npc_movement_step")
			var delay_msec := int(pokemon.get("movement_next_step_at_msec")) - scheduled_at
			var minimum_msec := int(maxf(wait_seconds - jitter_seconds, 0.0) * 1000.0) - 2
			var maximum_msec := int((wait_seconds + jitter_seconds) * 1000.0) + 2
			_check(
				delay_msec >= minimum_msec and delay_msec <= maximum_msec,
				"%s pause stays inside its randomized range" % relative_path
			)
			observed_delays[delay_msec] = true
		_check(observed_delays.size() > 1, "%s receives different pauses over time" % relative_path)

	_check(speeds.size() == POKEMON_PATHS.size(), "Route 6 Pokémon use different movement speeds")
	_check(waits.size() == POKEMON_PATHS.size(), "Route 6 Pokémon use different base pauses")
	route.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL %s" % message)
