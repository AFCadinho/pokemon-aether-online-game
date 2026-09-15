extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/browser-misty-scope.json"))
	var failures := 0
	for id: String in scope.additionalVisualDirectories:
		var map: Node = load("res://generated/tiled_visuals/%s/%s.visual.tscn" % [id, id]).instantiate()
		for child in map.get_children():
			if not child is TileMapLayer:
				continue
			var layer := child as TileMapLayer
			for index in range(layer.tile_set.get_source_count()):
				var source := layer.tile_set.get_source(layer.tile_set.get_source_id(index)) as TileSetAtlasSource
				if source.texture.get_width() > 4096 or source.texture.get_height() > 4096:
					push_error("Oversized browser atlas: " + source.texture.resource_path)
					failures += 1
			for cell in layer.get_used_cells():
				var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
				if not source.has_tile(layer.get_cell_atlas_coords(cell)):
					push_error("Invalid atlas cell in " + id)
					failures += 1
		map.free()
	var world: Node = load("res://scenes/world.tscn").instantiate()
	world.call("_discard_web_placeholder_map")
	if world.call("_has_active_world_map"):
		push_error("Browser placeholder must not qualify for autosave")
		failures += 1
	if world.get_node("Player").process_mode != Node.PROCESS_MODE_DISABLED:
		push_error("Browser player must wait for the canonical map")
		failures += 1
	if world.get_node("CurrentMap").get_child_count() != 0 or world.get_node_or_null("Player") == null:
		push_error("Browser placeholder cleanup must preserve the player")
		failures += 1
	world.free()
	print("web_misty_tiles_probe: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
