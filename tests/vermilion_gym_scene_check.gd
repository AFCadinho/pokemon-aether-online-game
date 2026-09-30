extends SceneTree

const GYM := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_gym.tscn"
const CITY := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var gym := (load(GYM) as PackedScene).instantiate()
	var city := (load(CITY) as PackedScene).instantiate()
	_check(gym.map_id == "kanto_vermilion_city_gym", "gym identity")
	_check(gym.lighting_profile == "indoor" and gym.weather_profile == "disabled" and gym.music_profile_id == "gym.interior", "gym environment")
	for path: String in ["Entities/Players", "Entities/NPCs", "Entities/Pokemon", "Entities/Interactables", "Spawns/FromVermilionCity", "Exits/ToVermilionCity", "FloorVisibilityMask/Top", "FloorVisibilityMask/Bottom", "FloorVisibilityMask/Left", "FloorVisibilityMask/Right"]:
		_check(gym.has_node(path), "required node " + path)
	var collision := gym.get_node("Tiles/Collision") as TileMapLayer
	_check(collision.get_used_cells().is_empty(), "terrain collision remains empty for manual authoring")
	_check(collision.tile_set != null and collision.tile_set.tile_size == Vector2i(32, 32), "collision marker tileset is ready to paint")
	var visual := gym.get_node("Visual")
	_check(visual.get_meta("tiled_visual_map").width == 24 and visual.get_meta("tiled_visual_map").height == 36, "TMX dimensions preserved")
	for name: String in ["Ground", "GroundDetail", "Objects", "ObjectsTop"]:
		_check(visual.has_node(name), "TMX layer " + name)
	var validator = load("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	_check(validator.validate(visual, "res://generated/tiled_visuals/vermilion_gym/vermilion_gym.visual.tileset.tres").is_empty(), "imported atlas is valid")
	var leader := gym.get_node("Entities/NPCs/GymLeaderLtSurge")
	_check(leader.trainer_id == "kanto_alpha_gym_lt_surge" and leader.npc_profile.badge_id == "thunder", "existing Lt. Surge trainer and Thunder Badge profile")
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
