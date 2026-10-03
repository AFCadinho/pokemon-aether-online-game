extends SceneTree

const TOWN := "res://scenes/overworld/kanto/towns/lavender_town/lavender_town.tscn"
const HOUSE := "res://scenes/overworld/kanto/towns/lavender_town/mr_fuji_house.tscn"
const HOUSE3 := "res://scenes/overworld/kanto/towns/lavender_town/house3.tscn"
const HOUSE2 := "res://scenes/overworld/kanto/towns/lavender_town/house2.tscn"
const HOUSE1 := "res://scenes/overworld/kanto/towns/lavender_town/house1.tscn"
const ROUTE := "res://scenes/overworld/kanto/routes/kanto_route_10.tscn"
const ROUTE8 := "res://scenes/overworld/kanto/routes/kanto_route_8.tscn"
const AtlasValidator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var town := (load(TOWN) as PackedScene).instantiate()
	var house := (load(HOUSE) as PackedScene).instantiate()
	var house3 := (load(HOUSE3) as PackedScene).instantiate()
	var house2 := (load(HOUSE2) as PackedScene).instantiate()
	var house1 := (load(HOUSE1) as PackedScene).instantiate()
	var route := (load(ROUTE) as PackedScene).instantiate()
	var route8 := (load(ROUTE8) as PackedScene).instantiate()
	_check(town.get("map_id") == "kanto_lavender_town", "Lavender Town has its own map identity")
	_check(town.has_node("Entities/Players") and town.has_node("Entities/NPCs")
		and town.has_node("Entities/Interactables"), "Town supports players, NPCs and interactables")
	var collision := town.get_node("Tiles/Collision") as TileMapLayer
	_check(collision.tile_set != null,
		"Town retains its editable collision layer")
	var visual := town.get_node("Visual")
	var metadata: Dictionary = visual.get_meta("tiled_visual_map")
	_check(metadata.get("width") == 50 and metadata.get("height") == 50,
		"Artist visual preserves its 50 by 50 tiles")
	_check(str(visual.get_meta("tiled_source_path")).ends_with("/Lavander Town.tmx"),
		"Town uses the requested artist TMX")
	var atlas_errors: Array[String] = AtlasValidator.new().validate(
		visual, "res://generated/tiled_visuals/lavender_town/lavender_town.visual.tileset.tres")
	_check(atlas_errors.is_empty(), "New visual meets compact lossless atlas contract: %s" % [atlas_errors])
	_check_connection(route, "ToLavenderTown", town, TOWN)
	_check_connection(town, "ToRoute10", route, ROUTE)
	_check_connection(town, "ToRoute8", route8, ROUTE8)
	_check_connection(route8, "ToLavenderTown", town, TOWN)
	_check_connection(town, "ToMrFujiHouse", house, HOUSE)
	_check_connection(house, "ToOutside", town, TOWN)
	_check(house.get("map_id") == "kanto_lavender_town_mr_fuji_house"
		and house.get("world_access_group_id") == town.get("map_id"), "Fuji house belongs to Lavender Town")
	_check(house.get("lighting_profile") == "indoor" and house.get("weather_profile") == "disabled"
		and house.get("music_profile_id") == "kanto.lavender_town", "House uses indoor lighting and Lavender music")
	var house_collision := house.get_node("Tiles/Collision") as TileMapLayer
	_check(house_collision.tile_set != null,
		"Fuji house retains its editable collision layer")
	var house_visual := house.get_node("Visual")
	var house_metadata: Dictionary = house_visual.get_meta("tiled_visual_map")
	_check(house_metadata.get("width") == 26 and house_metadata.get("height") == 24,
		"Fuji house preserves the artist map dimensions")
	_check(AtlasValidator.new().validate(house_visual,
		"res://generated/tiled_visuals/lavender_mr_fuji_house/lavender_mr_fuji_house.visual.tileset.tres").is_empty(),
		"Fuji house uses valid compact atlases")
	_check(house.get_node("Spawns/FromLavenderTown").position == Vector2(400, 592),
		"Interior arrival uses the TMX arrival tile")
	_check(town.get_node("Spawns/FromMrFujiHouse").position == Vector2(272, 1040),
		"Fuji return arrival matches the relocated southwest house")
	_check_connection(town, "ToHouse3", house3, HOUSE3)
	_check_connection(house3, "ToOutside", town, TOWN)
	_check(house3.get("map_id") == "kanto_lavender_town_house_3"
		and house3.get("world_access_group_id") == town.get("map_id"), "House 3 belongs to Lavender Town")
	var house3_visual := house3.get_node("Visual")
	var house3_metadata: Dictionary = house3_visual.get_meta("tiled_visual_map")
	_check(house3_metadata.get("width") == 20 and house3_metadata.get("height") == 20
		and str(house3_visual.get_meta("tiled_source_path")).ends_with("/PokeAether House Template Blue.tmx"),
		"House 3 preserves the requested blue artist template")
	_check(AtlasValidator.new().validate(house3_visual,
		"res://generated/tiled_visuals/lavender_house_3/lavender_house_3.visual.tileset.tres").is_empty(),
		"House 3 uses valid compact atlases")
	var house3_collision := house3.get_node("Tiles/Collision") as TileMapLayer
	_check(house3_collision.tile_set != null and house3_collision.get_used_cells().is_empty(),
		"House 3 collision stays empty and editable")
	_check(house3.get_node("Spawns/FromLavenderTown").position == Vector2(304, 464)
		and town.get_node("Spawns/FromHouse3").position == Vector2(1328, 1200),
		"House 3 arrivals align with the interior entrance and southeast exterior door")
	_check(house3.get("lighting_profile") == "indoor" and house3.get("weather_profile") == "disabled"
		and house3.get("music_profile_id") == "kanto.lavender_town", "House 3 uses indoor lighting and Lavender music")
	_check_connection(town, "ToHouse2", house2, HOUSE2)
	_check_connection(house2, "ToOutside", town, TOWN)
	_check(house2.get("map_id") == "kanto_lavender_town_house_2"
		and house2.get("world_access_group_id") == town.get("map_id"), "House 2 belongs to Lavender Town")
	var house2_visual := house2.get_node("Visual")
	var house2_metadata: Dictionary = house2_visual.get_meta("tiled_visual_map")
	_check(house2_metadata.get("width") == 20 and house2_metadata.get("height") == 20
		and str(house2_visual.get_meta("tiled_source_path")).ends_with("/Lavender House 1 - Mauve.tmx"),
		"House 2 preserves the requested Mauve artist template")
	_check(AtlasValidator.new().validate(house2_visual,
		"res://generated/tiled_visuals/lavender_house_2/lavender_house_2.visual.tileset.tres").is_empty(),
		"House 2 uses valid compact atlases")
	var house2_collision := house2.get_node("Tiles/Collision") as TileMapLayer
	_check(house2_collision.tile_set != null and house2_collision.get_used_cells().is_empty(),
		"House 2 collision stays empty and editable")
	_check(house2.get_node("Spawns/FromLavenderTown").position == Vector2(304, 464)
		and town.get_node("Spawns/FromHouse2").position == Vector2(432, 1040),
		"House 2 arrivals align with the interior entrance and southwest exterior door")
	_check(collision.get_cell_source_id(Vector2i(13, 31)) == -1
		and collision.get_cell_source_id(Vector2i(13, 32)) == -1,
		"House 2 exterior door and return tile are traversable")
	_check(house2.get("lighting_profile") == "indoor" and house2.get("weather_profile") == "disabled"
		and house2.get("music_profile_id") == "kanto.lavender_town", "House 2 uses indoor lighting and Lavender music")
	_check_connection(town, "ToHouse1", house1, HOUSE1)
	_check_connection(house1, "ToOutside", town, TOWN)
	_check(house1.get("map_id") == "kanto_lavender_town_house_1"
		and house1.get("world_access_group_id") == town.get("map_id"), "House 1 belongs to Lavender Town")
	var house1_visual := house1.get_node("Visual")
	var house1_metadata: Dictionary = house1_visual.get_meta("tiled_visual_map")
	_check(house1_metadata.get("width") == 26 and house1_metadata.get("height") == 24
		and str(house1_visual.get_meta("tiled_source_path")).ends_with("/Lavender Home.tmx"),
		"House 1 preserves the requested Lavender Home artist visual")
	_check(AtlasValidator.new().validate(house1_visual,
		"res://generated/tiled_visuals/lavender_house_1/lavender_house_1.visual.tileset.tres").is_empty(),
		"House 1 uses valid compact atlases")
	var house1_collision := house1.get_node("Tiles/Collision") as TileMapLayer
	_check(house1_collision.tile_set != null and house1_collision.get_used_cells().is_empty(),
		"House 1 collision stays empty and editable")
	_check(house1.get_node("Spawns/FromLavenderTown").position == Vector2(400, 592)
		and town.get_node("Spawns/FromHouse1").position == Vector2(1296, 880),
		"House 1 arrivals align with the interior entrance and northeast exterior door")
	_check(collision.get_cell_source_id(Vector2i(40, 26)) == -1
		and collision.get_cell_source_id(Vector2i(40, 27)) == -1,
		"House 1 exterior door and return tile are traversable")
	_check(house1.get("lighting_profile") == "indoor" and house1.get("weather_profile") == "disabled"
		and house1.get("music_profile_id") == "kanto.lavender_town", "House 1 uses indoor lighting and Lavender music")
	for route_number in [12]:
		var planned_exit := town.get_node("Exits/ToRoute%d" % route_number) as Area2D
		var planned_shape := planned_exit.get_node("CollisionShape2D") as CollisionShape2D
		_check(not planned_exit.monitoring and planned_shape.disabled,
			"Future Route %d exit cannot trigger during gameplay" % route_number)
		_check(str(planned_exit.get("target_scene_path")).is_empty()
			and str(planned_exit.get("target_spawn_name")).is_empty(),
			"Future Route %d exit has no dangling scene or spawn reference" % route_number)
		var arrival := town.get_node("Spawns/FromRoute%d" % route_number) as Marker2D
		var rectangle := planned_shape.shape as RectangleShape2D
		var bounds := Rect2(planned_exit.position - rectangle.size / 2, rectangle.size)
		_check(not bounds.has_point(arrival.position),
			"Future Route %d spawn arrives inside town, outside its exit" % route_number)
	var builder := load("res://tools/world_access_catalog_builder.gd").new() as RefCounted
	var record: Dictionary = builder.call("_load_scene_record", TOWN, {})
	_check(bool(record.get("success", false)) and (record.get("exits", []) as Array).size() == 8,
		"Catalog builder registers Route 8, Route 10 and all six indoor exits")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_check(catalog.transitions.has("kanto_lavender_town__to_route8")
		and catalog.transitions.has("kanto_route_8__to_lavender_town"),
		"Catalog registers both authorized Route 8 transitions")
	_check(not catalog.areas.has("kanto_lavender_town_north"), "Removed north map is absent from staff catalog")
	_check(not ResourceLoader.exists("res://scenes/overworld/kanto/routes/connections/lavender_town_north.tscn"),
		"Removed north scene cannot be loaded")
	_check(catalog.areas.has("kanto_lavender_town_mr_fuji_house")
		and catalog.transitions.has("kanto_lavender_town__to_mr_fuji_house")
		and catalog.transitions.has("kanto_lavender_town_mr_fuji_house__to_outside"),
		"Catalog registers the house and both authorized transitions")
	_check(catalog.areas.has("kanto_lavender_town_house_3")
		and catalog.transitions.has("kanto_lavender_town__to_house_3")
		and catalog.transitions.has("kanto_lavender_town_house_3__to_outside"),
		"Catalog registers House 3 and both authorized transitions")
	_check(catalog.areas.has("kanto_lavender_town_house_2")
		and catalog.transitions.has("kanto_lavender_town__to_house_2")
		and catalog.transitions.has("kanto_lavender_town_house_2__to_outside"),
		"Catalog registers House 2 and both authorized transitions")
	_check(catalog.areas.has("kanto_lavender_town_house_1")
		and catalog.transitions.has("kanto_lavender_town__to_house_1")
		and catalog.transitions.has("kanto_lavender_town_house_1__to_outside"),
		"Catalog registers House 1 and both authorized transitions")
	house1.free()
	house2.free()
	house3.free()
	house.free()
	town.free()
	route.free()
	route8.free()
	quit(1 if failures > 0 else 0)


func _check_connection(source: Node, exit_name: String, destination: Node, destination_path: String) -> void:
	var exit := source.get_node("Exits/" + exit_name) as Area2D
	_check(exit.monitoring and not (exit.get_node("CollisionShape2D") as CollisionShape2D).disabled,
		"%s has an enabled walking trigger" % exit_name)
	_check(exit.get("target_scene_path") == destination_path, "%s points to the correct scene" % exit_name)
	_check(exit.is_connected("body_entered", Callable(exit, "_on_body_entered")),
		"%s responds to walking into the exit" % exit_name)
	var spawn := destination.get_node("Spawns/" + str(exit.get("target_spawn_name"))) as Marker2D
	_check(spawn != null, "%s has a destination spawn" % exit_name)
	for destination_exit: Node2D in destination.get_node("Exits").get_children():
		var shape := destination_exit.get_node("CollisionShape2D") as CollisionShape2D
		var rectangle := shape.shape as RectangleShape2D
		if rectangle != null:
			var bounds := Rect2(destination_exit.position + shape.position - rectangle.size / 2, rectangle.size)
			_check(not bounds.has_point(spawn.position), "%s arrives outside %s to avoid immediate return" % [exit_name, destination_exit.name])


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)
