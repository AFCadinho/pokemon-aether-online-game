extends SceneTree

const BASE := "res://scenes/overworld/kanto/towns/ss_anne/ss_anne_"
const PORT := "res://scenes/overworld/kanto/towns/vermilion_docks/vermilion_docks.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var maps: Dictionary = {}
	var validator = load("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	for floor in ["1f", "2f", "b1f", "3f"]:
		var path: String = BASE + floor + ".tscn"
		var map: Node = load(path).instantiate()
		maps[path] = map
		_check(map.map_id == "kanto_ss_anne_" + floor, "floor identity " + floor)
		for node_path in ["Entities/Players", "Entities/NPCs", "Entities/Pokemon", "Entities/Interactables", "Tiles/Collision", "Spawns", "Exits", "FloorVisibilityMask"]:
			_check(map.has_node(node_path), floor + " required node " + node_path)
		_check(map.get_node("Tiles/Collision").get_used_cells().is_empty(), floor + " collision left empty")
		_check(validator.validate(map.get_node("Visual"), "res://generated/tiled_visuals/ss_anne_" + floor + "/ss_anne_" + floor + ".visual.tileset.tres").is_empty(), floor + " atlas layout")
		var mask: Node = map.get_node("FloorVisibilityMask")
		_check(mask.follow_player_floor and mask.constrain_camera_to_active_floor, floor + " room masking and camera limits")
	maps[PORT] = load(PORT).instantiate()
	var total := 0
	for path in maps:
		var map: Node = maps[path]
		for exit_node in map.get_node("Exits").get_children():
			if not maps.has(exit_node.target_scene_path):
				continue
			total += 1
			var destination: Node = maps[exit_node.target_scene_path]
			var spawn: Node2D = destination.get_node_or_null("Spawns/" + exit_node.target_spawn_name)
			_check(spawn != null, str(exit_node.name) + " destination exists")
			if spawn == null:
				continue
			for target_exit in destination.get_node("Exits").get_children():
				_check(not target_exit.contains_world_position(spawn.position), str(exit_node.name) + " arrival avoids transition loops")
			if exit_node.target_scene_path == PORT:
				_check(not destination.is_water_tile_for_actor(spawn.position, null), "ship return is dry")
			else:
				var contained := false
				for region in destination.get_node("FloorVisibilityMask").floor_regions.values():
					contained = contained or region.has_point(spawn.position)
				_check(contained, str(exit_node.name) + " arrival inside visible room")
	_check(total == 50, "48 internal connections and two boarding directions")
	var skipper: Node = maps[PORT].get_node("Entities/NPCs/SSAnneSkipper")
	_check(skipper.guarded_transition_id == "kanto_vermilion_city__to_ss_anne", "skipper uses story boarding transition")
	_check(not skipper.requires_party_pokemon and skipper.guard_role == "attendant", "skipper stays visible and checks ticket")
	_check(maps[PORT].get_node("Exits/ToSSAnne").contains_world_position(Vector2(1424, 624)), "gangway boarding position")
	for map in maps.values():
		map.free()
	if not failed:
		print("SS_ANNE_SCENES PASS: 4 floors, 25 rooms, 50 transitions, empty collision and valid atlases")
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
