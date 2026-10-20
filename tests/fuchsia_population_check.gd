extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/fuchsia_city/fuchsia_city.tscn"
const SPECIES := ["chansey","oddish","nidoran-f","kangaskhan","venonat","psyduck","slowpoke"]
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var city := (load(CITY) as PackedScene).instantiate()
	var collision: TileMapLayer = city.get_node("Tiles/Collision")
	var water: TileMapLayer = city.get_node("Tiles/Water")
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
			_check(not actor.pickpocket_enabled, "residents have no unsolicited thieving interaction")
		if radius > 0:
			speeds[actor.movement_speed_pixels] = true
			waits[actor.movement_wait_seconds] = true
			_check(actor.movement_wait_jitter_seconds > 0.0, "pacing has varied pauses")
		for offset in range(-radius,radius+1):
			var lane: Vector2i = cell + axis*offset
			_check(Rect2i(0,0,72,50).has_point(lane), "lane stays inside the map")
			_check(collision.get_cell_source_id(lane) == -1 and water.get_cell_source_id(lane) == -1, "%s has dry, clear ground at %s" % [actor.name,lane])
			_check(not lanes.has(lane), "%s has a separate lane at %s" % [actor.name,lane])
			lanes[lane] = actor.name
			for exit_node in city.get_node("Exits").get_children():
				_check(not exit_node.contains_world_position(Vector2(lane)*32+Vector2(16,16)), "all doorway triggers stay free")
	for species: String in SPECIES:
		_check(seen_species.has(species), species + " is present")
	_check(speeds.size() >= 6 and waits.size() >= 6, "residents and Pokemon have varied rhythms")
	var start := Vector2i(city.get_node("Spawns/FromRoute15Gate").position / 32.0)
	var reached := _reachable(collision,water,lanes,start)
	for spawn in city.get_node("Spawns").get_children():
		_check(reached.has(Vector2i(spawn.position/32.0)), "arrival remains connected with every complete patrol lane reserved: " + spawn.name)
	for lane: Vector2i in lanes:
		var approachable := false
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			approachable = approachable or reached.has(lane + direction)
		_check(approachable, "actor can be approached at every patrol stop: " + str(lanes[lane]))
	for exit_node in city.get_node("Exits").get_children():
		var covered := 0
		for cell: Vector2i in reached:
			if exit_node.contains_world_position(Vector2(cell)*32+Vector2(16,16)):
				covered += 1
		_check(covered > 0, "exit remains reachable: " + exit_node.name)
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
		for sign_value in [-1,1]:
			_check(actor.call("_can_npc_move_to",actor.global_position+axis*32*sign_value), "runtime actor can take its authored step: " + actor.name)
	state.set("current_map",previous)
	city.free()
	print("FUCHSIA_POPULATION ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _reachable(collision: TileMapLayer,water: TileMapLayer,reserved: Dictionary,start: Vector2i) -> Dictionary:
	var pending: Array[Vector2i] = [start]
	var reached := {start:true}
	var cursor := 0
	while cursor < pending.size():
		var cell := pending[cursor]
		cursor += 1
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = cell + direction
			if not Rect2i(0,0,72,50).has_point(next) or reached.has(next) or reserved.has(next): continue
			if collision.get_cell_source_id(next) == -1 and water.get_cell_source_id(next) == -1:
				reached[next] = true
				pending.append(next)
	return reached

func _check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
