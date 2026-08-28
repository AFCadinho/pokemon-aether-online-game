extends SceneTree

const ROUTE_25_SCENE := "res://scenes/overworld/kanto/routes/route25/kanto_route_25.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string(ROUTE_25_SCENE)
	_check(
		source.contains("generated/tiled_visuals/route_25/route_25.visual.tscn"),
		"Route 25 references its imported visual"
	)
	_check(not source.contains("generated/tiled_visuals/open_field/"), "Route 25 removes the placeholder visual")

	var packed := load(ROUTE_25_SCENE) as PackedScene
	_check(packed != null, "Route 25 scene loads")
	if packed == null:
		quit(1)
		return

	var route_25 := packed.instantiate()
	root.add_child(route_25)
	await process_frame
	_check(route_25.get("map_size") == Vector2i(80, 50), "Route 25 uses its 80-by-50-tile map boundary")

	var visual := route_25.get_node_or_null("Route25Visual")
	_check(visual != null, "Route 25 instantiates its imported visual")
	if visual != null:
		var visual_map := visual.get_meta("tiled_visual_map", {}) as Dictionary
		_check(visual_map.get("width") == 80, "Route 25 preserves the 80-tile visual width")
		_check(visual_map.get("height") == 50, "Route 25 preserves the 50-tile visual height")
		_check(visual_map.get("tile_width") == 32, "Route 25 preserves the 32-pixel tile width")
		_check(visual_map.get("tile_height") == 32, "Route 25 preserves the 32-pixel tile height")
		for layer_name: String in ["Ground", "Grass", "GroundDetail", "Objects", "Doors", "ObjectsTop"]:
			_check(visual.get_node_or_null(layer_name) is TileMapLayer, "Route 25 preserves its %s layer" % layer_name)
		var objects_top := visual.get_node_or_null("ObjectsTop") as TileMapLayer
		_check(objects_top != null and objects_top.z_index > 2000, "Route 25 foreground objects render above characters")

	var collision := route_25.find_map_tilemap_layer("Collision") as TileMapLayer
	_check(collision != null, "Route 25 retains gameplay collision")

	route_25.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
