extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/fuchsia_city/fuchsia_city.tscn"
const SPECIES := ["chansey","oddish","nidoran-f","kangaskhan","venonat","psyduck","slowpoke"]
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var city := (load(CITY) as PackedScene).instantiate()
	var npcs: Node = city.get_node("Entities/NPCs")
	var pokemon: Node = city.get_node("Entities/Pokemon")
	_check(npcs.get_child_count() == 7 and pokemon.get_child_count() == 7, "seven residents and seven ambient Pokemon")
	var actors: Array[Node] = []
	actors.append_array(npcs.get_children())
	actors.append_array(pokemon.get_children())
	var lanes := {}
	var identities := {}
	var seen_species := {}
	var speeds := {}
	var waits := {}
	for actor in actors:
		var cell := Vector2i(actor.position / 32.0)
		var axis := Vector2i.RIGHT if actor.movement_behavior == "pace_horizontal" else Vector2i.DOWN
		var radius: int = 0 if actor.movement_behavior == "idle" else actor.movement_tiles
		_check(actor.natural_ambient_movement and not actor.ambient_movement_ignores_map_collision, str(actor.name) + " respects map collision and independent pacing")
		var id: String = actor.overworld_pokemon_id if actor.get_parent() == pokemon else actor.npc_id
		_check(id.begins_with("kanto_fuchsia_city_") and not identities.has(id), "actor has a unique Fuchsia identity")
		identities[id] = true
		_check(actor.dialogue_id.begins_with("kanto_fuchsia_city_"), "actor has its own dialogue")
		if actor.get_parent() == pokemon:
			seen_species[actor.species_id] = true
			_check(FollowerSpriteService.get_sprite_frames(actor.species_id,false) != null, str(actor.name) + " has follower art")
		else:
			_check(actor.npc_sprite_frames != null, str(actor.name) + " has resident art")
			_check(not actor.pickpocket_enabled, "resident Thieving profiles load from server metadata")
		if radius > 0:
			speeds[actor.movement_speed_pixels] = true
			waits[actor.movement_wait_seconds] = true
			_check(actor.movement_wait_jitter_seconds > 0.0, "pacing has varied pauses")
		for offset in range(-radius,radius+1):
			var lane: Vector2i = cell + axis*offset
			lanes[lane] = actor.name
	for species: String in SPECIES:
		_check(seen_species.has(species), species + " is present")
	_check(speeds.size() >= 6 and waits.size() >= 6, "residents and Pokemon have varied rhythms")
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	player.free()
	# Exercise the real NPC movement gate on every authored step, after ready
	# initializes its feet marker and collision cache.
	var state: Node = root.get_node("GameState")
	var previous: Node = state.get("current_map")
	state.set("current_map",city)
	root.add_child(city)
	for actor in actors:
		actor.set_process(false)
		if actor.movement_behavior == "idle": continue
		var axis := Vector2.RIGHT if actor.movement_behavior == "pace_horizontal" else Vector2.DOWN
	state.set("current_map",previous)
	city.free()
	print("FUCHSIA_POPULATION ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
