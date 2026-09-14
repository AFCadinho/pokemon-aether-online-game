extends SceneTree

const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

func _init() -> void:
	var arena := load("res://scenes/overworld/aether_clash/aether_clash_duel.tscn").instantiate() as Node2D
	var collision := arena.get_node("Tiles/Collision") as TileMapLayer
	var red := arena.get_node("Spawns/Guild2ArenaSpawn") as Marker2D
	var staging := Rect2(red.position - Vector2(112, 112), Vector2(224, 224))
	var start := Vector2i((red.position - Vector2(0, 128)) / 32)
	var queue: Array[Vector2i] = [start]
	var reachable := {start: true}
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		for direction: Vector2i in DIRECTIONS:
			var neighbor := tile + direction
			var point := Vector2(neighbor * 32) + Vector2(16, 16)
			if neighbor.x < 1 or neighbor.x > 64 or neighbor.y < 81 or neighbor.y > 157:
				continue
			if reachable.has(neighbor) or collision.get_cell_source_id(neighbor) != -1 or staging.has_point(point):
				continue
			# Avoid directional ledges rather than assume they are bidirectional.
			if (arena.get_node("Tiles/BlockDirection/BlockUp") as TileMapLayer).get_cell_source_id(neighbor) != -1:
				continue
			if (arena.get_node("Tiles/BlockDirection/BlockDown") as TileMapLayer).get_cell_source_id(neighbor) != -1:
				continue
			reachable[neighbor] = true
			queue.append(neighbor)
	var candidates: Array = []
	for y in range(140, 83, -2):
		for x in range(4, 64, 2):
			var tile := Vector2i(x, y)
			var clear := reachable.has(tile)
			for direction: Vector2i in DIRECTIONS:
				clear = clear and reachable.has(tile + direction)
			if clear:
				candidates.append([x * 32 + 16, y * 32 + 16])
	if OS.get_cmdline_user_args().has("--generate"):
		print("ANCHORS_JSON=", JSON.stringify({"version": 1, "side": "challenged", "positions": candidates.slice(0, 200)}))
		print("CANDIDATE_COUNT=", candidates.size())
		arena.free()
		quit(0 if candidates.size() >= 200 else 1)
		return
	var manifest_path := ProjectSettings.globalize_path("res://").path_join("../backend/account-service/data/aether_clash_bot_anchors.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var positions: Array = manifest.get("positions", [])
	var valid: bool = positions.size() == 200 and manifest.get("side") == "challenged" and collision.get_cell_source_id(start) == -1
	var seen := {}
	for position: Array in positions:
		if position.size() != 2:
			valid = false
			continue
		var normalized: Array = [int(position[0]), int(position[1])]
		valid = valid and position[0] == normalized[0] and position[1] == normalized[1] and candidates.has(normalized) and not seen.has(str(normalized))
		seen[str(normalized)] = true
	arena.free()
	if not valid:
		push_error("Bot anchor manifest must contain 200 distinct reachable, clear tiles outside staging in the challenged half")
	else:
		print("PASS 200 bot anchors are reachable from the red exit, outside staging, with four clear adjacent tiles")
	quit(0 if valid else 1)
