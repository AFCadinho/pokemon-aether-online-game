extends SceneTree

const NPC_SCENE := "res://scenes/npcs/dialogue_npc.tscn"
const POKEMON_SCENE := "res://scenes/npcs/overworld_pokemon.tscn"
var failed := false
var actors: Array[Node2D] = []

class MovementState extends Node:
	var current_map: Node
	var locked := false
	func is_overworld_input_locked() -> bool:
		return locked


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var state := MovementState.new()
	root.add_child(state)
	var speeds := {}
	var starts := {}
	for index in range(12):
		var actor := _spawn_actor(NPC_SCENE if index % 2 == 0 else POKEMON_SCENE, index)
		actor.set("GameState", state)
		var speed: float = actor.call("_get_ambient_movement_speed")
		_check(speed >= 32.0 and speed <= 48.0, "Ambient speed stays within 20 percent of its authored speed")
		_check(actor.get("movement_speed_pixels") == 40.0, "Authored speed remains available for scripted story movement")
		speeds[snappedf(speed, 0.01)] = true
		starts[actor.get("movement_next_step_at_msec")] = true
		# Seed pause sampling so variation checks are reproducible.
		actor.get("_ambient_movement_rng").seed = index + 100
		var pauses := {}
		for sample in range(12):
			actor.call("_schedule_next_npc_movement_step")
			var pause: float = actor.get("_movement_pause_seconds")
			_check(pause >= 0.4 and pause <= 1.8, "Placements without timing settings receive bounded random pauses")
			pauses[snappedf(pause, 0.001)] = true
		_check(pauses.size() > 1, "One actor receives different pauses over time")
	_check(speeds.size() > 6 and starts.size() > 6, "Identically configured NPCs and Pokémon start independently and walk at different speeds")

	var actor := actors[0]
	# Input locks, nearby players and conversations must not release the entire crowd together.
	state.locked = true
	for resident in actors:
		resident.set("movement_next_step_at_msec", 0)
		await resident.call("_process_npc_movement")
		_check(not resident.get("is_npc_moving"), "Input lock prevents ambient movement")
	state.locked = false
	starts.clear()
	for resident in actors:
		await resident.call("_process_npc_movement")
		var deadline: int = resident.get("movement_next_step_at_msec")
		_check(deadline > Time.get_ticks_msec(), "Resuming movement schedules a fresh future start")
		_check(not resident.get("is_npc_moving"), "Actor waits after the shared lock is released")
		starts[deadline] = true
	_check(starts.size() > 6, "A shared lock does not synchronize the crowd on resume")
	actor.set("player_nearby", true)
	actor.set("movement_next_step_at_msec", 0)
	await actor.call("_process_npc_movement")
	actor.set("player_nearby", false)
	await actor.call("_process_npc_movement")
	_check(actor.get("movement_next_step_at_msec") > Time.get_ticks_msec(), "Leaving an interaction gives the resident a new pause")

	# An opt-out retains deliberate fixed/continuous pacing, and idle services never wander.
	var fixed := _spawn_actor(NPC_SCENE, 20, false)
	fixed.set("GameState", state)
	_check(fixed.call("_get_ambient_movement_speed") == 40.0, "Fixed cadence opt-out preserves exact speed")
	fixed.call("_schedule_next_npc_movement_step")
	_check(fixed.get("_movement_pause_seconds") == 0.0, "Fixed cadence opt-out preserves zero waits")
	fixed.set("movement_behavior", "idle")
	var fixed_position := fixed.position
	await fixed.call("_process_npc_movement")
	_check(fixed.position == fixed_position and not fixed.get("is_npc_moving"), "Idle actors stay anchored")

	# Execute a real tween and verify the tile reservation, final alignment and rest animation.
	var pokemon := actors[1]
	pokemon.set("movement_direction_sign", 1)
	var origin := pokemon.position
	await pokemon.call("_try_step_npc_movement")
	_check(pokemon.position == origin + Vector2(32, 0), "Natural pacing still completes exactly one grid tile")
	_check(pokemon.get("movement_reserved_tile") == Vector2i.ZERO and not pokemon.get("is_npc_moving"), "Completed step releases the reserved tile")
	_check(not (pokemon.get_node("Look/AnimatedSprite2D") as AnimatedSprite2D).is_playing(), "Pokémon stops its walking animation during its random pause")
	var edge_position := pokemon.position
	await pokemon.call("_try_step_npc_movement")
	_check(pokemon.position == edge_position and pokemon.get("movement_direction_sign") == -1, "Patrol reverses at its authored boundary without drifting")
	await pokemon.call("_try_step_npc_movement")
	_check(pokemon.position == origin, "Patrol returns to its original grid tile")
	var continuous := _spawn_actor(POKEMON_SCENE, 21, false)
	continuous.set("GameState", state)
	continuous.set("movement_tiles", 2)
	await continuous.call("_try_step_npc_movement")
	_check((continuous.get_node("Look/AnimatedSprite2D") as AnimatedSprite2D).is_playing(), "Explicit continuous pacing retains its walking animation between steps")

	for resident in actors:
		resident.free()
	state.free()
	print("natural_ambient_movement_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)


func _spawn_actor(scene_path: String, index: int, natural := true) -> Node2D:
	var actor := (load(scene_path) as PackedScene).instantiate() as Node2D
	actor.name = "AmbientTestActor%d" % index
	actor.position = Vector2(16 + index * 128, 16)
	actor.set("movement_behavior", "pace_horizontal")
	actor.set("movement_tiles", 1)
	actor.set("movement_speed_pixels", 40.0)
	actor.set("movement_wait_seconds", 0.0)
	actor.set("movement_wait_jitter_seconds", 0.0)
	actor.set("natural_ambient_movement", natural)
	actor.get("_ambient_movement_rng").seed = index + 42
	actor.set_process(false)
	root.add_child(actor)
	actors.append(actor)
	return actor


func _check(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		push_error(description)
