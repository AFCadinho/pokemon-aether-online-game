extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn"
const HOUSE_DIRECTORY := "res://scenes/overworld/kanto/towns/vermilion_city/"
const TEMPLATE := "res://scenes/overworld/kanto/reusable_interiors/house/vermilion_house_template.tscn"
const VISUAL := "res://generated/tiled_visuals/vermilion_house_template/vermilion_house_template.visual.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var city := (load(CITY) as PackedScene).instantiate()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	var validator = load("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	var doors: Array[Vector2i] = [Vector2i(19, 13), Vector2i(20, 27), Vector2i(36, 36)]
	for number in range(1, 4):
		var house_path := HOUSE_DIRECTORY + "house%d.tscn" % number
		var house := (load(house_path) as PackedScene).instantiate()
		var map_id := "kanto_vermilion_city_house_%d" % number
		_check(house.map_id == map_id and house.world_access_group_id == "kanto_vermilion_city", "house %d identity" % number)
		_check(house.lighting_profile == "indoor" and house.weather_profile == "disabled", "indoor environment")
		_check(house.get_node("Visual").scene_file_path == VISUAL, "shared visual")
		_check((load(house_path) as PackedScene).get_state().get_base_scene_state().get_path() == TEMPLATE, "inherited house template")
		_check(validator.validate(house.get_node("Visual"), VISUAL.replace(".tscn", ".tileset.tres")).is_empty(), "portable compact atlas")
		var metadata: Dictionary = house.get_node("Visual").get_meta("tiled_visual_map")
		_check(metadata.width == 20 and metadata.height == 20, "original TMX dimensions")
		for path: String in ["Entities/Players", "Entities/NPCs", "Entities/Pokemon", "Entities/Interactables", "Tiles/Collision", "FloorVisibilityMask/Top", "FloorVisibilityMask/Bottom", "FloorVisibilityMask/Left", "FloorVisibilityMask/Right"]:
			_check(house.has_node(path), "required node " + path)
		var collision := house.get_node("Tiles/Collision") as TileMapLayer
		var ground := house.get_node("Visual/Ground") as TileMapLayer
		var start := collision.local_to_map(house.get_node("Spawns/FromOutside").position)
		_check(start == Vector2i(9, 14) and collision.get_cell_source_id(start) == -1, "authored arrival tile is free")
		_check(not collision.get_used_cells().is_empty(), "furniture and room bounds have collision")
		var reached: Dictionary = {}
		var pending: Array[Vector2i] = [start]
		while not pending.is_empty():
			var cell: Vector2i = pending.pop_back()
			if reached.has(cell) or collision.get_cell_source_id(cell) != -1 or cell.x < 0 or cell.y < 0 or cell.x >= 20 or cell.y >= 20:
				continue
			reached[cell] = true
			_check(ground.get_cell_source_id(cell) != -1, "walkable cells have a visual")
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				pending.append(cell + direction)
		for y in range(20):
			for x in range(20):
				var cell := Vector2i(x, y)
				if collision.get_cell_source_id(cell) == -1:
					_check(reached.has(cell), "all free floor is reachable")
		if number == 1:
			var guru := house.get_node("Entities/NPCs/FishingGuru")
			_check(guru.npc_id == "kanto_pallet_town_fishing_guru" and guru.reward_id == "kanto_pallet_town_old_rod", "Guru retains his quest and reward identity")
			_check(guru.get_script().resource_path == "res://scripts/world/kanto/towns/pallet_town/fishing_guru.gd" and guru.preload_quest_markers, "Guru retains lesson, help and quest marker behavior")
			_check(guru.npc_sprite_frames != null and guru.mugshot != null, "Guru keeps his sprites and portrait")
			var guru_cell := collision.local_to_map(guru.position)
			_check(collision.get_cell_source_id(guru_cell) == -1 and reached.has(guru_cell + Vector2i.DOWN), "Guru stands on free floor and is reachable from the entrance")
			_check(guru_cell != start, "Guru does not occupy the arrival tile")
		var entrance := city.get_node("Exits/ToHouse%d" % number)
		var exit := house.get_node("Exits/ToOutside")
		_check(entrance.target_scene_path == house_path and entrance.target_spawn_name == "FromOutside", "city doorway destination")
		_check(exit.target_scene_path == CITY and exit.target_spawn_name == "FromHouse%d" % number, "house return destination")
		_check(not exit.contains_world_position(house.get_node("Spawns/FromOutside").position), "arrival avoids immediate exit")
		var return_position: Vector2 = city.get_node("Spawns/FromHouse%d" % number).position
		_check(not entrance.contains_world_position(return_position), "return avoids immediate re-entry")
		_check(entrance.position == Vector2(doors[number - 1] * 32) + Vector2(16,16), "entrance uses the correct exterior door")
		for step in range(3):
			_check(city.get_node("Tiles/Collision").get_cell_source_id(doors[number - 1] + Vector2i(0, step)) == -1, "doorway and return path are walkable")
		for container in ["Entities/NPCs", "Entities/Pokemon"]:
			for actor: Node2D in city.get_node(container).get_children():
				_check(actor.position != return_position and actor.position != entrance.position, "city actor does not occupy a doorway or arrival")
		_check(catalog.areas.has(map_id), "house registered in world catalog")
		_check(catalog.transitions.has(entrance.transition_id) and catalog.transitions.has(exit.transition_id), "both transitions registered")
		house.free()
	city.free()
	print("VERMILION_HOUSES ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL " + label)
