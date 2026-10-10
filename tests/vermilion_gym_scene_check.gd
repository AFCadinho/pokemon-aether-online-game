extends SceneTree

const GYM := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_gym.tscn"
const CITY := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var gym := (load(GYM) as PackedScene).instantiate()
	var city := (load(CITY) as PackedScene).instantiate()
	root.add_child(gym)
	await process_frame
	_check(gym.map_id == "kanto_vermilion_city_gym", "gym identity")
	_check(gym.lighting_profile == "indoor" and gym.weather_profile == "disabled" and gym.music_profile_id == "gym.interior", "gym environment")
	for path: String in ["Entities/Players", "Entities/NPCs", "Entities/Pokemon", "Entities/Interactables", "Spawns/FromVermilionCity", "Exits/ToVermilionCity", "FloorVisibilityMask/Top", "FloorVisibilityMask/Bottom", "FloorVisibilityMask/Left", "FloorVisibilityMask/Right"]:
		_check(gym.has_node(path), "required node " + path)
	var collision := gym.get_node("Tiles/Collision") as TileMapLayer
	_check(collision.get_used_cells().is_empty() or (collision.tile_set != null and collision.tile_set.tile_size == Vector2i(32, 32)), "collision layer can remain empty for map authoring or use the 32px marker tileset")
	var visual := gym.get_node("Visual")
	_check(visual.get_meta("tiled_visual_map").width == 24 and visual.get_meta("tiled_visual_map").height == 36, "TMX dimensions preserved")
	for name: String in ["Ground", "GroundDetail", "Objects", "ObjectsTop"]:
		_check(visual.has_node(name), "TMX layer " + name)
	var validator = load("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	_check(validator.validate(visual, "res://generated/tiled_visuals/vermilion_gym/vermilion_gym.visual.tileset.tres").is_empty(), "imported atlas is valid")
	var leader := gym.get_node("Entities/NPCs/GymLeaderLtSurge")
	_check(leader.trainer_id == "kanto_alpha_gym_lt_surge" and leader.npc_profile.badge_id == "thunder", "existing Lt. Surge trainer and Thunder Badge profile")
	_check_leader_podium(gym, leader, collision)
	_check(gym.get_node("Entities/NPCs/GymGuide").npc_id == "kanto_vermilion_city_gym_guide", "guide uses dedicated dialogue metadata")
	_check_trainers(gym)
	var entrance := city.get_node("Exits/ToGym")
	var exit := gym.get_node("Exits/ToVermilionCity")
	_check(entrance.target_scene_path == GYM and entrance.target_spawn_name == "FromVermilionCity", "city entrance")
	_check(exit.target_scene_path == CITY and exit.target_spawn_name == "FromGym", "city return")
	_check(not exit.contains_world_position(gym.get_node("Spawns/FromVermilionCity").position), "arrival avoids immediate exit")
	_check(not entrance.contains_world_position(city.get_node("Spawns/FromGym").position), "return avoids immediate re-entry")
	_check(city.get_node("Tiles/Collision").get_cell_source_id(Vector2i(14, 41)) == -1, "city return tile is walkable")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_check(catalog.areas.has(gym.map_id), "gym registered in world catalog")
	_check(catalog.transitions.has("kanto_vermilion_city__to_gym") and catalog.transitions.has("kanto_vermilion_city_gym__to_outside"), "both transitions registered")
	gym.free()
	city.free()
	print("VERMILION_GYM_SCENE ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL " + label)

func _check_leader_podium(gym: Node, leader: Node2D, collision: TileMapLayer) -> void:
	var ground := gym.get_node("Visual/Ground") as TileMapLayer
	var detail := gym.get_node("Visual/GroundDetail") as TileMapLayer
	var has_map_collision := not collision.get_used_cells().is_empty()
	var podium := Rect2i(10, 8, 3, 3)
	var center := podium.position + podium.size / 2
	_check(leader.position == ground.map_to_local(center), "Lt. Surge stands on the exact center tile of the podium")
	_check(leader.position == Vector2(podium.position * 32) + Vector2(podium.size * 32) / 2.0, "podium visual center matches the actor grid")
	var carpet_cells := 0
	for x in range(10, 14):
		for y in range(8, 12):
			var cell := Vector2i(x, y)
			if detail.get_cell_source_id(cell) != -1:
				carpet_cells += 1
				_check(podium.has_point(cell), "carpet has no extra row or column outside the centered podium")
	_check(carpet_cells == 9, "complete three-by-three podium")
	_check(not gym.has_node("Visual/Arena Trim"), "puzzle floor has no surrounding rails")
	var bin_tops := gym.get_node("Visual/ObjectsTop") as TileMapLayer
	var bin_bottoms := gym.get_node("Visual/Objects") as TileMapLayer
	var bin_nodes := gym.get_node("Entities/Interactables")
	var reachable := _reachable_walkable_cells(gym, collision)
	var bin_count := 0
	for bin: Node2D in bin_nodes.get_children():
		if not bin.name.begins_with("Bin"):
			continue
		bin_count += 1
		var bin_coordinates: Vector2i = bin.get("bin_coordinates")
		var visual_origin := Vector2i(5 + bin_coordinates.x * 3, 18 + bin_coordinates.y * 2)
		_check(bin_tops.get_cell_atlas_coords(visual_origin) == Vector2i(0, 2) and bin_bottoms.get_cell_atlas_coords(visual_origin + Vector2i(0, 1)) == Vector2i(1, 2), "%s has a complete visual bin split across authored object layers" % bin.name)
		var expected_spawn := Vector2((float(visual_origin.x) + 0.5) * 32.0, (float(visual_origin.y) + 1.5) * 32.0)
		_check(bin.position == expected_spawn, "%s gameplay spawn aligns with its visual bin" % bin.name)
		var footprint_origin: Vector2i = Vector2i(floori(bin.position.x / 32.0), floori(bin.position.y / 32.0)) + bin.blocked_tile_offset
		var footprint: Vector2i = bin.blocked_tile_footprint
		_check(footprint_origin == visual_origin and footprint == Vector2i(1, 2), "%s interaction footprint matches its visual tiles" % bin.name)
		_check(not bin.blocks_movement, "%s has no movement collision" % bin.name)
		var x := footprint_origin.x
		var y := footprint_origin.y
		var access_cells: Array[Vector2i] = []
		for dx in range(footprint.x):
			access_cells.append(Vector2i(x + dx, y - 1))
			access_cells.append(Vector2i(x + dx, y + footprint.y))
		for dy in range(footprint.y):
			access_cells.append(Vector2i(x - 1, y + dy))
			access_cells.append(Vector2i(x + footprint.x, y + dy))
		for cell: Vector2i in access_cells:
			var world_position := Vector2(cell * 32) + Vector2(16, 16)
			_check(collision.get_cell_source_id(cell) == -1, "%s has clear floor beside its footprint" % bin.name)
			_check(not gym.is_position_blocked_by_character(world_position), "%s approach tile is not occupied" % bin.name)
			_check(reachable.has(cell), "%s approach tile is reachable from the entrance" % bin.name)
	_check(bin_count == 20, "all twenty bins have aligned Godot interactables")
	var platform := gym.get_node("Visual/Leader Platform") as TileMapLayer
	_check(platform.get_used_rect() == Rect2i(8, 12, 7, 1), "complete raised stage front")
	for x in range(8, 15):
		var cell := Vector2i(x, 12)
		_check(platform.get_cell_source_id(cell) != -1, "no gap in the stage fascia or stairs")
		if has_map_collision:
			_check((collision.get_cell_source_id(cell) == -1) == (x >= 10 and x <= 12), "stage access passes through the stairs only")
	for y in range(center.y, 18):
		_check(collision.get_cell_source_id(Vector2i(center.x, y)) == -1, "leader tile and straight approach are walkable")
	for x in [8, 9, 13, 14]:
		for y in range(8, 12):
			if has_map_collision:
				_check(collision.get_cell_source_id(Vector2i(x, y)) != -1, "complete column footprint blocks movement")
	var emblem := gym.get_node("Visual/Gym Emblem") as TileMapLayer
	_check(emblem.position.x + float(emblem.get_used_rect().position.x * 32) + float(emblem.get_used_rect().size.x * 16) == leader.position.x, "emblem shares the leader centerline")

func _reachable_walkable_cells(gym: Node, collision: TileMapLayer) -> Dictionary:
	var spawn := gym.get_node("Spawns/FromVermilionCity") as Marker2D
	var start := collision.local_to_map(collision.to_local(spawn.global_position))
	var reachable: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := current + direction
			if next.x < 0 or next.x >= 24 or next.y < 0 or next.y >= 36 or reachable.has(next):
				continue
			if collision.get_cell_source_id(next) != -1:
				continue
			var world_position := collision.to_global(collision.map_to_local(next))
			if gym.is_position_blocked_by_character(world_position):
				continue
			reachable[next] = true
			queue.append(next)
	return reachable


func _check_trainers(gym: Node) -> void:
	var expected := {
		"WorkerDax": "kanto_vermilion_city_gym_worker_dax",
		"ScientistMira": "kanto_vermilion_city_gym_scientist_mira",
		"GentlemanEdwin": "kanto_vermilion_city_gym_gentleman_edwin",
	}
	var ground := gym.get_node("Visual/Ground") as TileMapLayer
	var floor_cell := Vector2i(11, 20)
	var floor_source := ground.get_cell_source_id(floor_cell)
	var floor_atlas := ground.get_cell_atlas_coords(floor_cell)
	var occupied: Dictionary = {}
	for npc: Node2D in gym.get_node("Entities/NPCs").get_children():
		var cell := ground.local_to_map(npc.position)
		_check(not occupied.has(cell), str(npc.name) + " has a separate tile")
		occupied[cell] = true
	_check(gym.get_node("Entities/NPCs").get_child_count() == 5, "three trainers supplement Lt. Surge and guide")
	for name: String in expected:
		var trainer := gym.get_node("Entities/NPCs/" + name)
		_check(trainer.trainer_id == expected[name] and trainer.npc_id == expected[name], name + " uses its canonical trainer identity")
		_check(trainer.scene_file_path == "res://scenes/npcs/trainer_npc.tscn", name + " uses battle trainer interaction")
		_check(trainer.npc_sprite_frames != null, name + " has character sprites")
		var cell := ground.local_to_map(trainer.position)
		for step in range(trainer.sight_range_tiles + 1):
			var lane: Vector2i = cell + Vector2i(trainer.facing_direction) * step
			_check(ground.get_cell_source_id(lane) == floor_source and ground.get_cell_atlas_coords(lane) == floor_atlas, name + " approach stays on the visual floor")
			if step > 0:
				_check(not occupied.has(lane), name + " approach avoids another NPC")
