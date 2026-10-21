extends SceneTree
var failed := false
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var anchors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/coop_trainer_anchors.json")).entries
	var state: Node = root.get_node("GameState")
	var previous: Node = state.current_map
	for number in [16,17,18]:
		var map := (load("res://scenes/overworld/kanto/routes/kanto_route_%s.tscn" % number) as PackedScene).instantiate()
		state.current_map = map
		map.encounter_area_id = ""
		root.add_child(map)
		var collision: TileMapLayer = map.get_node("Tiles/Collision")
		var water: TileMapLayer = map.get_node("Tiles/Water")
		var occupied := {}
		var actors: Array[Node] = []
		actors.append_array(map.get_node("Entities/NPCs").get_children())
		actors.append_array(map.get_node("Entities/Pokemon").get_children())
		_check(map.get_node("Entities/NPCs").get_child_count() == {16:6,17:10,18:4}[number], "complete route trainer roster and mine attendant")
		_check(map.get_node("Entities/Pokemon").get_child_count() == {16:5,17:6,18:5}[number], "ambient route population")
		for actor in actors:
			actor.feet_marker = actor.get_node("FeetMarker")
			var cell := Vector2i(actor.position/32)
			var radius: int = 0 if actor.movement_behavior == "idle" else actor.movement_tiles
			var axis := Vector2i.RIGHT if actor.movement_behavior == "pace_horizontal" else Vector2i.DOWN
			for offset in range(-radius,radius+1):
				var lane := cell+axis*offset
				if offset != 0 and collision.get_cell_source_id(lane) != -1:
					continue
				occupied[lane] = actor.name
			for spawn in map.get_node("Spawns").get_children():
				_check(not occupied.has(Vector2i(spawn.position/32)), "arrival remains clear")
			if actor.get_parent().name == "NPCs":
				if not actor.has_method("supports_trainer_rematches"):
					_check(number == 18 and actor.npc_id == "kanto_route_18_mine_foreman_niels", "additional NPC is the mine foreman")
					continue
				_check(actor.npc_id == actor.trainer_id and anchors.has(actor.trainer_id), "trainer has registered co-op identity")
				var entry: Dictionary = anchors.get(actor.trainer_id,{})
				_check(entry.get("mapId") == map.map_id and entry.get("position") == {"x":actor.position.x,"y":actor.position.y}, "authoritative anchor matches placed trainer")
				_check(actor.sight_range_tiles == 2 and actor.mugshot != null, "trainer has battle portrait and bounded sight")
				if number < 18:
					_check(actor.display_name.begins_with("Biker ") and actor.npc_sprite_frames.resource_path.ends_with("biker_frames.tres"), "Cycling Road uses only real Biker sprites")
					for direction in ["down","up","left","right"]:
						_check(actor.npc_sprite_frames.has_animation("walk_"+direction) and actor.npc_sprite_frames.has_animation("idle_"+direction), "Biker has directional approach and idle animations")
			else:
				_check(FollowerSpriteService.get_sprite_frames(actor.species_id,false) != null, "ambient species has follower artwork")
		var items := map.get_node("Entities/Interactables").get_children()
		_check(items.size() == (5 if number == 17 else 0), "only canonical Route 17 ground rewards are added")
		for item in items:
			_check(item.z_index > map.get_node("Visual/Ground").z_index and not item.z_as_relative, "pickup remains visible above the authored ground")
			var cell := Vector2i(item.position/32)
			occupied[cell] = item.name
		var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
		player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
		player.map_layers_initialized = true
		player.map_layers_owner = map
		player.resolved_map_cache = map
		player.collision_tilemap = collision
		player.water_tilemap = water
		for actor in actors:
			var radius: int = 0 if actor.movement_behavior == "idle" else actor.movement_tiles
			var axis := Vector2i.RIGHT if actor.movement_behavior == "pace_horizontal" else Vector2i.DOWN
			for offset in range(-radius,radius+1):
				var cell := Vector2i(actor.position/32)+axis*offset
				if collision.get_cell_source_id(cell) != -1: continue
				if offset == 0: _check(not player.can_move_to(_point(cell)), "real player respects actor blocking")
		player.free()
		map.free()
	state.current_map = previous
	if not failed: print("PASS Cycling Road population: 19 trainers, 16 Pokemon, five pickups, clear travel and platform escape")
	quit(1 if failed else 0)
func _approachable(reached: Dictionary,cell: Vector2i) -> bool:
	for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		if reached.has(cell+direction): return true
	return false
func _point(cell: Vector2i) -> Vector2:
	return Vector2(cell)*32+Vector2(16,16)
func _check(ok: bool,message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
