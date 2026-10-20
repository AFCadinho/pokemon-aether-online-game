extends SceneTree

const CITY := "res://scenes/overworld/kanto/routes/kanto_route_16_east.tscn"
const WATER_SPECIES := ["magikarp","goldeen","poliwag"]
const SPECIES := ["vulpix","spearow","rattata","ponyta","raticate","doduo","magikarp","goldeen","poliwag"]
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var city := (load(CITY) as PackedScene).instantiate()
	var collision: TileMapLayer = city.get_node("Tiles/Collision")
	var water: TileMapLayer = city.get_node("Tiles/Water")
	var npcs: Node = city.get_node("Entities/NPCs")
	var pokemon: Node = city.get_node("Entities/Pokemon")
	_check(npcs.get_child_count() == 5 and pokemon.get_child_count() == 9, "five travelers and nine ambient Pokemon")
	var actors: Array[Node] = []
	actors.append_array(npcs.get_children())
	actors.append_array(pokemon.get_children())
	var water_lanes := {}
	var lanes := {}
	var identities := {}
	var seen_species := {}
	var speeds := {}
	var waits := {}
	for actor in actors:
		var water_actor: bool = actor.get_parent() == pokemon and WATER_SPECIES.has(actor.species_id)
		var cell := Vector2i(actor.position / 32.0)
		var axis := Vector2i.RIGHT if actor.movement_behavior == "pace_horizontal" else Vector2i.DOWN
		var radius: int = 0 if actor.movement_behavior == "idle" else actor.movement_tiles
		_check(actor.natural_ambient_movement and not actor.ambient_movement_ignores_map_collision, str(actor.name) + " respects map collision and independent pacing")
		var id: String = actor.overworld_pokemon_id if actor.get_parent() == pokemon else actor.npc_id
		_check(id.begins_with("kanto_route_16_east_") and not identities.has(id), "actor has a unique Route 16 identity")
		identities[id] = true
		_check(actor.dialogue_id.begins_with("kanto_route_16_east_"), "actor has its own dialogue")
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
			_check(Rect2i(0,0,52,57).has_point(lane), "lane stays inside the map")
			_check(collision.get_cell_source_id(lane) == -1, "%s stays clear of obstacles at %s" % [actor.name,lane])
			_check((water.get_cell_source_id(lane) != -1) == water_actor, "%s stays in its land or water habitat at %s" % [actor.name,lane])
			if water_actor: water_lanes[lane] = true
			_check(not lanes.has(lane), "%s has a separate lane at %s" % [actor.name,lane])
			lanes[lane] = actor.name
			for exit_node in city.get_node("Exits").get_children():
				_check(not exit_node.contains_world_position(Vector2(lane)*32+Vector2(16,16)), "all doorway triggers stay free")
	for species: String in SPECIES:
		_check(seen_species.has(species), species + " is present")
	_check(speeds.size() >= 6 and waits.size() >= 6, "residents and Pokemon have varied rhythms")
	var start := Vector2i(city.get_node("Spawns/FromCeladonCity").position / 32.0)
	var snorlax: Node = city.get_node("Entities/StaticEncounters/Snorlax")
	var reserved := lanes.duplicate()
	for x in range(17,20):
		for y in range(29,32):
			var tile := Vector2i(x,y)
			_check(not lanes.has(tile), "ambient patrols stay outside Snorlax")
			reserved[tile] = "Snorlax"
	var reached := _reachable(collision,water,reserved,start)
	# The western gate becomes connected after the independent Snorlax encounter.
	var reached_open := _reachable(collision,water,lanes,start)
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	for spawn in city.get_node("Spawns").get_children():
		_check(reached_open.has(Vector2i(spawn.position/32.0)), "arrival connects after Snorlax with every complete patrol lane reserved: " + spawn.name)
	for lane: Vector2i in lanes:
		if water_lanes.has(lane): continue # Decorative swimmers are visible from shore.
		var approachable := false
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			approachable = approachable or reached.has(lane + direction)
		_check(approachable, "actor can be approached at every patrol stop: " + str(lanes[lane]))
	# Check actual player-shape overlap: the Center trigger ends exactly at
	# the entering grid center, while the player's upper body enters it.
	for exit_node in city.get_node("Exits").get_children():
		var accessible := false
		for cell: Vector2i in reached_open:
			accessible = accessible or player.overlaps_exit_at(exit_node,Vector2(cell)*32+Vector2(16,16))
		_check(accessible, "every exit remains reachable with complete patrol lanes reserved: " + exit_node.name)
	player.free()
	# Exercise the real NPC movement gate on every authored step, after ready
	# initializes its feet marker and collision cache.
	var state: Node = root.get_node("GameState")
	var previous: Node = state.get("current_map")
	state.set("current_map",city)
	snorlax.set_script(load("res://tests/fixtures/snorlax_encounter_probe.gd"))
	city.encounter_area_id = "" # Keep the offline movement check free of metadata HTTP.
	root.add_child(city)
	for actor in actors:
		actor.set_process(false)
		if actor.movement_behavior == "idle": continue
		var axis := Vector2.RIGHT if actor.movement_behavior == "pace_horizontal" else Vector2.DOWN
		for offset in range(-actor.movement_tiles,actor.movement_tiles+1):
			if offset == 0: continue
			_check(actor.call("_can_npc_move_to",actor.global_position+axis*32*offset), "runtime actor can take its authored step: " + actor.name)
	state.set("current_map",previous)
	city.free()
	print("ROUTE16_POPULATION ", "FAIL" if failed else "PASS")
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
			if not Rect2i(0,0,52,57).has_point(next) or reached.has(next) or reserved.has(next): continue
			if collision.get_cell_source_id(next) == -1 and water.get_cell_source_id(next) == -1:
				reached[next] = true
				pending.append(next)
	return reached

func _check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
