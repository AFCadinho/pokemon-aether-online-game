extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn"
const MOVING_POKEMON_PATHS: Array[String] = [
	"Entities/Pokemon/Pidgey",
	"Entities/Pokemon/Meowth",
	"Entities/Pokemon/Pikachu",
	"Entities/Pokemon/Machop",
	"Entities/Pokemon/Krabby",
	"Entities/Pokemon/Psyduck",
]

const MOVING_NPC_NAMES: Array[String] = [
	"VisitorIris", "FanClubHugo", "ElderElsie", "WorkerOwen", "AceTrainerSienna",
	"TrainerFelix", "ChildToby", "HarborWorkerBram", "RetiredSailorAbel", "PicnickerJune",
]

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := (load(CITY_SCENE) as PackedScene).instantiate()
	# Inspect the routines without letting their real-time processes move the fixtures.
	for group_name: String in ["NPCs", "Pokemon"]:
		for actor: Node in city.get_node("Entities/" + group_name).get_children():
			actor.set_process(false)
	root.add_child(city)
	await process_frame

	var speeds: Dictionary = {}
	var paths := MOVING_POKEMON_PATHS.duplicate()
	for npc_name in MOVING_NPC_NAMES:
		paths.append("Entities/NPCs/" + npc_name)
	var waits: Dictionary = {}
	for relative_path: String in paths:
		var pokemon := city.get_node_or_null(relative_path) as Node
		_check(pokemon != null, "%s exists" % relative_path)
		if pokemon == null:
			continue

		var wait_seconds := float(pokemon.get("movement_wait_seconds"))
		var jitter_seconds := float(pokemon.get("movement_wait_jitter_seconds"))
		_check(jitter_seconds > 0.0, "%s has randomized pauses" % relative_path)
		waits[wait_seconds] = true
		speeds[float(pokemon.get("movement_speed_pixels"))] = true
		_check(pokemon.get("natural_ambient_movement"), "%s uses independent ambient timing" % relative_path)
		_check(pokemon.get("movement_behavior") != "idle", "%s has a walking routine" % relative_path)
		var axis := Vector2i.RIGHT if pokemon.get("movement_behavior") == "pace_horizontal" else Vector2i.DOWN
		var tile := Vector2i((pokemon as Node2D).position / 32.0)
		for step in [-1, 0, 1]:
			var candidate: Vector2i = tile + axis * step
			var point := Vector2(candidate * 32 + Vector2i(16, 16))
			_check(not city.is_water_tile_for_actor(point, pokemon), "%s patrol stays on dry land" % relative_path)
			for exit_node: Node2D in city.get_node("Exits").get_children():
				_check(not exit_node.contains_world_position(point), "%s patrol stays clear of map exits" % relative_path)
			for marker: Node2D in city.get_node("Spawns").get_children():
				_check(Vector2i(marker.position / 32.0) != candidate, "%s patrol leaves arrivals clear" % relative_path)

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

	_check(speeds.size() >= 10 and waits.size() >= 12, "Vermilion residents and Pokémon have varied walking speeds and pauses")
	for service_name: String in ["GuildRegistrarNPC", "TransitKeeperNPC"]:
		_check(city.get_node("Entities/NPCs/" + service_name).get("movement_behavior") == "idle", "%s stays at its service point" % service_name)
	city.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL %s" % message)
