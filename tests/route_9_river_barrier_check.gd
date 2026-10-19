extends SceneTree

const ROUTE := "res://scenes/overworld/kanto/routes/kanto_route_9.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := (load(ROUTE) as PackedScene).instantiate()
	root.add_child(map)
	var collision := map.get_node("Tiles/Collision") as TileMapLayer
	var water := map.get_node("Tiles/Water") as TileMapLayer
	var banks_closed := true
	for x in range(82,94):
		banks_closed = banks_closed and collision.get_cell_source_id(Vector2i(x,5)) != -1
		if x < 86 or x > 89:
			banks_closed = banks_closed and collision.get_cell_source_id(Vector2i(x,13)) != -1
	for y in range(6,14):
		banks_closed = banks_closed and collision.get_cell_source_id(Vector2i(81,y)) != -1
	_expect(banks_closed, "both river banks and the western bypass are blocked")
	var surf_open := true
	for x in range(86,90):
		for y in range(12,19):
			surf_open = surf_open and collision.get_cell_source_id(Vector2i(x,y)) == -1
	var river_open := true
	for x in range(82,94):
		for y in range(6,12):
			var cell := Vector2i(x,y)
			river_open = river_open and collision.get_cell_source_id(cell) == -1 and water.get_cell_source_id(cell) != -1
	_expect(surf_open and river_open, "Surf approach and the river passage to Route 10 remain open")
	var seen := {Vector2i(1,20): true}
	var queue: Array[Vector2i] = [Vector2i(1,20)]
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+delta
			if not Rect2i(0,0,94,48).has_point(next) or seen.has(next): continue
			if collision.get_cell_source_id(next) != -1 or water.get_cell_source_id(next) != -1: continue
			seen[next] = true
			queue.append(next)
	_expect(seen.has(Vector2i(92,20)) and seen.has(Vector2i(87,12)), "land route and Surf landing remain reachable from Cerulean")
	var visual: Node = map.get_node("Visual")
	var validator = load("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	_expect(validator.validate(visual,"res://generated/tiled_visuals/route_9/route_9.visual.tileset.tres").is_empty(), "updated visual atlas is valid")
	# The artist map is now 94 columns wide. Check the solid banks flanking
	# the landing instead of prescribing a historic number/layout of trees.
	var southern_banks_closed := true
	for x in [82,83,84,85,90,91,92,93]:
		for y in range(13,19):
			southern_banks_closed = southern_banks_closed and collision.get_cell_source_id(Vector2i(x,y)) != -1
	_expect(southern_banks_closed, "southern tree banks block walking around the Surf landing")
	_expect(water.get_cell_source_id(water.local_to_map(map.get_node("Spawns/FromRoute10River").position)) != -1,
		"Route 10 river arrival lies on the connected Surf passage")
	map.queue_free()
	await process_frame
	print("ROUTE_9_RIVER_BARRIERS ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _expect(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		failed = true
		push_error(message)
