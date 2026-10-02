extends SceneTree

const TOWN := "res://scenes/overworld/kanto/towns/lavender_town/lavender_town.tscn"
const HOUSE := "res://scenes/overworld/kanto/towns/lavender_town/mr_fuji_house.tscn"
const ROUTE := "res://scenes/overworld/kanto/routes/kanto_route_10.tscn"
const AtlasValidator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var town := (load(TOWN) as PackedScene).instantiate()
	var house := (load(HOUSE) as PackedScene).instantiate()
	var route := (load(ROUTE) as PackedScene).instantiate()
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
	_check_connection(town, "ToMrFujiHouse", house, HOUSE)
	_check_connection(house, "ToOutside", town, TOWN)
	_check(house.get("map_id") == "kanto_lavender_town_mr_fuji_house"
		and house.get("world_access_group_id") == town.get("map_id"), "Fuji house belongs to Lavender Town")
	_check(house.get("lighting_profile") == "indoor" and house.get("weather_profile") == "disabled"
		and house.get("music_profile_id") == "kanto.lavender_town", "House uses indoor lighting and Lavender music")
	var house_collision := house.get_node("Tiles/Collision") as TileMapLayer
	_check(house_collision.tile_set != null and house_collision.get_used_cells().is_empty(),
		"House has an editable empty collision layer for the map author")
	var house_visual := house.get_node("Visual")
	var house_metadata: Dictionary = house_visual.get_meta("tiled_visual_map")
	_check(house_metadata.get("width") == 26 and house_metadata.get("height") == 24,
		"Fuji house preserves the artist map dimensions")
	_check(AtlasValidator.new().validate(house_visual,
		"res://generated/tiled_visuals/lavender_mr_fuji_house/lavender_mr_fuji_house.visual.tileset.tres").is_empty(),
		"Fuji house uses valid compact atlases")
	_check(house.get_node("Spawns/FromLavenderTown").position == Vector2(400, 592),
		"Interior arrival uses the TMX arrival tile")
	_check(town.get_node("Spawns/FromMrFujiHouse").position == Vector2(1296, 880),
		"Return arrival is in front of the northeast purple roof house")
	for route_number in [8, 12]:
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
	_check(bool(record.get("success", false)) and (record.get("exits", []) as Array).size() == 3,
		"Catalog builder registers Route 10, Pokémon Center and Fuji house exits")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_check(not catalog.areas.has("kanto_lavender_town_north"), "Removed north map is absent from staff catalog")
	_check(not ResourceLoader.exists("res://scenes/overworld/kanto/routes/connections/lavender_town_north.tscn"),
		"Removed north scene cannot be loaded")
	_check(catalog.areas.has("kanto_lavender_town_mr_fuji_house")
		and catalog.transitions.has("kanto_lavender_town__to_mr_fuji_house")
		and catalog.transitions.has("kanto_lavender_town_mr_fuji_house__to_outside"),
		"Catalog registers the house and both authorized transitions")
	house.free()
	town.free()
	route.free()
	quit(1 if failures > 0 else 0)


func _check_connection(source: Node, exit_name: String, destination: Node, destination_path: String) -> void:
	var exit := source.get_node("Exits/" + exit_name) as Area2D
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
