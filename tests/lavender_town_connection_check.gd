extends SceneTree

const TOWN := "res://scenes/overworld/kanto/towns/lavender_town/lavender_town.tscn"
const NORTH := "res://scenes/overworld/kanto/routes/connections/lavender_town_north.tscn"
const ROUTE := "res://scenes/overworld/kanto/routes/kanto_route_10.tscn"
const AtlasValidator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var town := (load(TOWN) as PackedScene).instantiate()
	var north := (load(NORTH) as PackedScene).instantiate()
	var route := (load(ROUTE) as PackedScene).instantiate()
	_check(town.get("map_id") == "kanto_lavender_town", "Lavender Town has its own map identity")
	_check(town.has_node("Entities/Players") and town.has_node("Entities/NPCs")
		and town.has_node("Entities/Interactables"), "Town supports players, NPCs and interactables")
	var collision := town.get_node("Tiles/Collision") as TileMapLayer
	_check(collision.tile_set != null and collision.get_used_cells().is_empty(),
		"Collision tileset is ready without painting any blocking cells")
	var visual := town.get_node("Visual")
	var metadata: Dictionary = visual.get_meta("tiled_visual_map")
	_check(metadata.get("width") == 50 and metadata.get("height") == 50,
		"Artist visual preserves its 50 by 50 tiles")
	_check(str(visual.get_meta("tiled_source_path")).ends_with("/Lavander Town.tmx"),
		"Town uses the requested artist TMX")
	var atlas_errors: Array[String] = AtlasValidator.new().validate(
		visual, "res://generated/tiled_visuals/lavender_town/lavender_town.visual.tileset.tres")
	_check(atlas_errors.is_empty(), "New visual meets compact lossless atlas contract: %s" % [atlas_errors])
	_check_connection(route, "ToLavenderNorth", north, NORTH)
	_check_connection(north, "ToLavenderTown", town, TOWN)
	_check_connection(town, "ToRoute10", north, NORTH)
	_check_connection(north, "ToRoute10", route, ROUTE)
	town.free()
	north.free()
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
