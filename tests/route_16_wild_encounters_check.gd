extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Inspect off-tree: neither map metadata nor Snorlax may contact a live server.
	var map := (load("res://scenes/overworld/kanto/routes/kanto_route_16_east.tscn") as PackedScene).instantiate()
	_check(map.get_wild_encounter_area_id() == "kanto_route_16_east", "wild battles use the current map identity")
	_check(is_equal_approx(map.grass_encounter_chance, 0.21), "grass chance matches server table")
	_check(map.get_step_encounter_type().is_empty(), "ordinary paths have no whole-map encounters")
	var grass: TileMapLayer = map.get_node("Tiles/TallGrass")
	var visual: TileMapLayer = map.get_node("Visual/Grass")
	_check(not grass.get_used_cells().is_empty(), "encounter grass exists")
	_check(grass.get_used_cells().size() == visual.get_used_cells().size(), "every visible grass cell has encounters")
	for cell in grass.get_used_cells():
		_check(visual.get_cell_source_id(cell) != -1, "encounters are limited to visible grass at " + str(cell))
	for spawn in map.get_node("Spawns").get_children():
		_check(grass.get_cell_source_id(Vector2i(spawn.position / 32.0)) == -1, "arrival is outside encounter grass")
	var snorlax: Node = map.get_node("Entities/StaticEncounters/Snorlax")
	_check(snorlax.encounter_id == "snorlax_route_16" and snorlax.encounter_area_id == map.encounter_area_id, "flute encounter retains its independent identity")
	map.free()
	if not failed:
		print("PASS Route 16 East: wild grass coverage, area, chance and separate Snorlax")
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
