extends SceneTree

const ROUTE_25_SCENE := "res://scenes/overworld/kanto/routes/route25/kanto_route_25.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var route := (load(ROUTE_25_SCENE) as PackedScene).instantiate()
	root.add_child(route)
	await process_frame

	_check(str(route.get("encounter_area_id")) == "kanto_route_25", "Route 25 requests its backend encounter table")
	_check(is_equal_approx(float(route.get("grass_encounter_chance")), 0.21), "Route 25 uses the intended grass encounter chance")

	var tall_grass := route.get_node_or_null("Tiles/TallGrass") as TileMapLayer
	var water := route.get_node_or_null("Tiles/Water") as TileMapLayer
	var visual_grass := route.get_node_or_null("Route25Visual/Grass") as TileMapLayer
	_check(tall_grass != null, "Route 25 exposes a tall-grass encounter mask")
	_check(water != null, "Route 25 exposes a water mask for Surf and fishing")
	_check(visual_grass != null, "Route 25 keeps its imported grass visuals")

	if tall_grass != null:
		_check(not tall_grass.visible, "Route 25 keeps its tall-grass mask invisible")
		_check(tall_grass.get_used_cells().size() == 46, "Route 25 marks all 46 tall-grass cells")
	if tall_grass != null and visual_grass != null:
		var marker_cells := tall_grass.get_used_cells()
		var visual_cells := visual_grass.get_used_cells()
		marker_cells.sort()
		visual_cells.sort()
		_check(marker_cells == visual_cells, "Route 25 grass encounters exactly match its grass visuals")

	if water != null:
		_check(not water.visible, "Route 25 keeps its water mask invisible")
		_check(water.get_used_cells().size() == 468, "Route 25 marks its complete water surface")
		_check(water.get_cell_source_id(Vector2i(47, 23)) >= 0, "Route 25 marks the western pond shore for fishing")
		_check(water.get_cell_source_id(Vector2i(48, 24)) >= 0, "Route 25 marks pond water for Surf")
		_check(water.get_cell_source_id(Vector2i(79, 49)) >= 0, "Route 25 marks the eastern sea for Surf and fishing")
		_check(water.get_cell_source_id(Vector2i(0, 0)) < 0, "Route 25 does not mark dry land as water")

	route.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
