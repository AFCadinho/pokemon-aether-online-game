extends SceneTree

const ROUTE_25_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_25.tscn"
const BILLS_HOUSE_SCENE := "res://scenes/overworld/kanto/routes/bills_house.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var route_25 := await _instantiate_map(ROUTE_25_SCENE)
	var bills_house := await _instantiate_map(BILLS_HOUSE_SCENE)

	_check_transition(
		route_25,
		"Exits/ToBillsHouse",
		BILLS_HOUSE_SCENE,
		"FromRoute25",
		"kanto_route_25__to_bills_house"
	)
	_check_transition(
		bills_house,
		"Exits/ToRoute25",
		ROUTE_25_SCENE,
		"FromBillsHouse",
		"kanto_route_25_bills_house__to_route_25"
	)
	_check(route_25.get_node_or_null("Spawns/FromBillsHouse") is Marker2D, "Route 25 has Bill's House return spawn")
	_check(bills_house.get_node_or_null("Spawns/FromRoute25") is Marker2D, "Bill's House has its Route 25 arrival spawn")

	var visual := bills_house.get_node_or_null("BillsHouseVisual")
	_check(visual != null, "Bill's House instantiates its imported visual")
	if visual != null:
		var visual_map := visual.get_meta("tiled_visual_map", {}) as Dictionary
		_check(visual_map.get("width") == 25, "Bill's House preserves the 25-tile visual width")
		_check(visual_map.get("height") == 20, "Bill's House preserves the 20-tile visual height")
		for layer_name: String in ["Ground", "GroundDetail", "Objects", "ObjectsTop"]:
			_check(visual.get_node_or_null(layer_name) is TileMapLayer, "Bill's House preserves its %s layer" % layer_name)

	var collision := bills_house.find_map_tilemap_layer("Collision") as TileMapLayer
	_check(collision != null, "Bill's House has a collision layer ready for editing")
	_check(collision != null and collision.get_used_cells().is_empty(), "Bill's House collision layer is intentionally empty")

	var catalog_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	var catalog := catalog_value as Dictionary if catalog_value is Dictionary else {}
	var areas := catalog.get("areas", {}) as Dictionary
	var transitions := catalog.get("transitions", {}) as Dictionary
	_check(areas.has("kanto_route_25_bills_house"), "World access catalog includes Bill's House")
	_check(transitions.has("kanto_route_25__to_bills_house"), "World access catalog includes the entrance transition")
	_check(transitions.has("kanto_route_25_bills_house__to_route_25"), "World access catalog includes the return transition")

	route_25.queue_free()
	bills_house.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _instantiate_map(scene_path: String) -> Node:
	var packed := load(scene_path) as PackedScene
	_check(packed != null, "%s loads" % scene_path.get_file())
	if packed == null:
		return Node.new()
	var map := packed.instantiate()
	root.add_child(map)
	await process_frame
	return map


func _check_transition(map: Node, path: String, target_scene: String, target_spawn: String, transition_id: String) -> void:
	var exit := map.get_node_or_null(path)
	_check(exit != null, "%s has %s" % [map.name, path])
	if exit == null:
		return
	_check(exit.target_scene_path == target_scene, "%s targets the reciprocal scene" % path)
	_check(exit.target_spawn_name == target_spawn, "%s targets the reciprocal spawn" % path)
	_check(exit.transition_id == transition_id, "%s has a stable transition ID" % path)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
