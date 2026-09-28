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
	for x in range(84,96):
		banks_closed = banks_closed and collision.get_cell_source_id(Vector2i(x,5)) != -1
		if x < 88 or x > 91:
			banks_closed = banks_closed and collision.get_cell_source_id(Vector2i(x,12)) != -1
	for y in range(6,14):
		banks_closed = banks_closed and collision.get_cell_source_id(Vector2i(83,y)) != -1
	_expect(banks_closed, "both river banks and the western bypass are blocked")
	var surf_open := true
	for x in range(88,92):
		for y in range(12,20):
			surf_open = surf_open and collision.get_cell_source_id(Vector2i(x,y)) == -1
	var river_open := true
	for x in range(85,96):
		for y in range(7,11):
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
			if not Rect2i(0,0,96,48).has_point(next) or seen.has(next): continue
			if collision.get_cell_source_id(next) != -1 or water.get_cell_source_id(next) != -1: continue
			seen[next] = true
			queue.append(next)
	_expect(seen.has(Vector2i(94,20)) and seen.has(Vector2i(89,12)), "land route and Surf landing remain reachable from Cerulean")
	var visual: Node = map.get_node("Visual")
	var validator = load("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	_expect(validator.validate(visual,"res://generated/tiled_visuals/route_9/route_9.visual.tileset.tres").is_empty(), "updated visual atlas is valid")
	var rails := visual.get_node("Objects") as TileMapLayer
	var crowns := visual.get_node("TreeTop") as TileMapLayer
	var trees_complete := true
	for x in [84,86,92,94]:
		for y in [11,13,15]:
			for dx in range(2):
				for dy in range(4):
					var layer := crowns if dy < 2 else visual.get_node("TreeBottom") as TileMapLayer
					trees_complete = trees_complete and layer.get_cell_source_id(Vector2i(x+dx,y+dy)) != -1
					trees_complete = trees_complete and collision.get_cell_source_id(Vector2i(x+dx,y+dy)) != -1
	_expect(trees_complete, "southern bank has twelve complete trees with blocking cells")
	var lower_rails_removed := true
	for x in range(84,96):
		lower_rails_removed = lower_rails_removed and rails.get_cell_source_id(Vector2i(x,12)) == -1
	_expect(lower_rails_removed and rails.get_cell_source_id(Vector2i(95,5)) != -1, "southern bank uses trees and northern barrier is preserved")
	map.queue_free()
	await process_frame
	print("ROUTE_9_RIVER_BARRIERS ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _expect(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		failed = true
		push_error(message)
