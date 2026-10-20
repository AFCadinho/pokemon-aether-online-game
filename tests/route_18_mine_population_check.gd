extends SceneTree
class EncounterSink extends Node:
	var requests: Array = []
	func start_triggered_wild_battle_for_area(area_id: String,method: String) -> void:
		requests.append([area_id,method])
var failed := false
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var mine := (load("res://scenes/overworld/kanto/caves/route_18_mine/route_18_mine.tscn") as PackedScene).instantiate()
	var state: Node = root.get_node("GameState")
	var previous: Node = state.current_map
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	player.map_layers_initialized = true
	player.map_layers_owner = mine
	player.resolved_map_cache = mine
	player.collision_tilemap = mine.get_node("Tiles/Collision")
	player.water_tilemap = mine.find_map_tilemap_layer("Water")
	mine.add_child(player)
	_check(mine.get_wild_encounter_area_id() == "kanto_route_18_mine" and mine.get_step_encounter_type() == "cave", "mine owns an independent cave encounter table")
	_check(is_equal_approx(mine.cave_encounter_chance,0.07), "per-step cave chance matches backend")
	state.current_map = mine
	_check(player.call("_is_cave_encounter_map"), "real player recognizes this interior as a wild cave")
	var sink := EncounterSink.new()
	root.add_child(sink)
	sink.add_to_group("world")
	mine.cave_encounter_chance = 1.0 # Force the random roll; keep real encounter resolution and routing.
	for mounted in [false,true]:
		player.land_mount_activity_active = mounted
		player.check_for_wild_encounter("cave",_point(Vector2i(20,7)))
	_check(sink.requests == [["kanto_route_18_mine","cave"],["kanto_route_18_mine","cave"]], "real walking/mounted encounter flow routes to the mine cave battle")
	mine.cave_encounter_chance = 0.07
	player.land_mount_activity_active = false
	sink.free()
	# Ready the actors without a live encounter metadata request; all checks run
	# before a frame/deferred metadata fetch and keep their real movement code.
	mine.encounter_area_id = ""
	root.add_child(mine)
	var npcs := mine.get_node("Entities/NPCs").get_children()
	var pokemon := mine.get_node("Entities/Pokemon").get_children()
	_check(npcs.size() == 2 and pokemon.size() == 7, "two dialogue explorers and seven ambient Pokemon")
	var actors: Array = npcs+pokemon
	var reserved := {}
	var species := {}
	for actor in actors:
		var cell := Vector2i(actor.position/32)
		var radius: int = 0 if actor.movement_behavior == "idle" else actor.movement_tiles
		var axis := Vector2i.RIGHT if actor.movement_behavior == "pace_horizontal" else Vector2i.DOWN
		_check(not actor.pickpocket_enabled and not actor.ambient_movement_ignores_map_collision, "ordinary dialogue/cry actors respect terrain")
		if actor.get_parent().name == "Pokemon":
			species[actor.species_id] = true
			_check(FollowerSpriteService.get_sprite_frames(actor.species_id,false) != null, "follower sprite exists: "+actor.species_id)
		else:
			_check(actor.get_script().resource_path.ends_with("dialogue_npc.gd") and actor.npc_sprite_frames != null and not actor.dialogue_id.is_empty(), "explorer has a talkable identity and artwork")
		for offset in range(-radius,radius+1):
			var tile := cell+axis*offset
			_check(Rect2i(0,0,42,32).has_point(tile) and player.collision_tilemap.get_cell_source_id(tile) == -1, "%s patrol stays on cave floor at %s" % [actor.name,tile])
			_check(not reserved.has(tile), "all actor patrols are disjoint")
			reserved[tile] = actor.name
			if offset != 0: _check(actor.call("_can_npc_move_to",_point(tile)), "real actor movement accepts its authored patrol")
	_check(species.size() == 7 and species.has("sandile") and species.has("gible"), "requested Ground species are visible in the mine")
	var start := Vector2i(mine.get_node("Spawns/FromRoute18").position/32)
	_check(not reserved.has(start) and not reserved.has(Vector2i(4,9)), "arrival and exit staircase stay clear")
	var reached := _reachable(player.collision_tilemap,reserved,start)
	_check(reached.has(Vector2i(4,9)), "return exit remains reachable with complete patrols reserved")
	for y in range(32):
		for x in range(42):
			var cell := Vector2i(x,y)
			if player.collision_tilemap.get_cell_source_id(cell) == -1 and not reserved.has(cell):
				_check(reached.has(cell), "every free floor tile stays connected with worst-case patrol occupancy")
	for cell: Vector2i in reserved:
		var accessible := false
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			accessible = accessible or reached.has(cell+direction)
		_check(accessible, "actor can be approached at every patrol stop: "+str(reserved[cell]))
	state.current_map = previous
	mine.free()
	if not failed: print("PASS Route 18 mine population: cave battle routing, seven Pokemon, two dialogue NPCs and clear circulation")
	quit(1 if failed else 0)
func _reachable(collision: TileMapLayer,reserved: Dictionary,start: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var seen := {start:true}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = cell+direction
			if not Rect2i(0,0,42,32).has_point(next) or seen.has(next) or reserved.has(next): continue
			if collision.get_cell_source_id(next) == -1:
				seen[next] = true
				queue.append(next)
	return seen
func _point(cell: Vector2i) -> Vector2:
	return Vector2(cell)*32+Vector2(16,16)
func _check(ok: bool,message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
