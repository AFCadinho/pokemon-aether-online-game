extends SceneTree

class TestPlayer extends Node2D:
	var last_direction := Vector2.DOWN
	func get_feet_position() -> Vector2:
		return global_position

var failed := false

func _init() -> void:
	call_deferred("run")

func run() -> void:
	check(load("res://scripts/world/world.gd") != null, "World battle integration compiles")
	var scene := load("res://scenes/overworld/kanto/routes/kanto_route_12.tscn") as PackedScene
	check(scene != null, "Route 12 loads")
	if scene == null:
		quit(1)
		return
	var map := scene.instantiate()
	var snorlax := map.get_node("Entities/StaticEncounters/Snorlax")
	check(snorlax.encounter_id == "snorlax_route_12", "Independent Route 12 ID")
	check(snorlax.blocked_tile_footprint == Vector2i(3, 2), "Three-wide footprint")
	var collision := map.get_node("Tiles/Collision") as TileMapLayer
	var water := map.get_node("Tiles/Water") as TileMapLayer
	for y in range(62, 64):
		for x in range(28, 31):
			var tile := Vector2i(x, y)
			check(collision.get_cell_source_id(tile) == -1 and water.get_cell_source_id(tile) == -1, "Snorlax occupies walkable steiger tiles")
			check(snorlax.blocks_world_position(Vector2(tile) * 32 + Vector2(16, 16)), "Every footprint tile blocks")
	check(not snorlax.blocks_world_position(Vector2(944, 1968)), "Approach remains clear")
	check(not reachable(collision, water, snorlax, Vector2i(29, 61), Vector2i(29, 64)), "Cannot walk around Snorlax anywhere on Route 12")
	var player := TestPlayer.new()
	for x in range(28, 31):
		player.position = Vector2(x * 32 + 16, 61 * 32 + 16)
		player.last_direction = Vector2.DOWN
		check(snorlax._is_player_facing_interactable(player), "Interaction at every north edge tile")
		player.position.y = 64 * 32 + 16
		player.last_direction = Vector2.UP
		check(snorlax._is_player_facing_interactable(player), "Interaction at every south edge tile")
	player.free()
	check(not snorlax.apply_status({"encounterId": "snorlax_celadon", "completed": true}), "Another encounter cannot hide Route 12 Snorlax")
	check(snorlax.blocks_world_position(Vector2(944, 2032)), "Route 12 remains blocked")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview="):
			write_preview(map, snorlax, arg.trim_prefix("--preview="))
	check(snorlax.apply_status({"encounterId": "snorlax_route_12", "completed": true}), "Own completion applies")
	check(not snorlax.visible and not snorlax.blocks_world_position(Vector2(944, 2032)), "Completion removes artwork and collision together")
	check(reachable(collision, water, snorlax, Vector2i(29, 61), Vector2i(29, 64)), "Completed route is traversable")
	map.free()
	if not failed:
		print("PASS Snorlax: six blocked tiles, no land bypass, both interaction edges, independent IDs and completed passage")
	quit(1 if failed else 0)

func reachable(collision: TileMapLayer, water: TileMapLayer, snorlax: Node2D, start: Vector2i, goal: Vector2i) -> bool:
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		if tile == goal:
			return true
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := tile + step
			if next.x < 0 or next.x >= 48 or next.y < 0 or next.y >= 125 or seen.has(next):
				continue
			seen[next] = true
			if collision.get_cell_source_id(next) != -1 or water.get_cell_source_id(next) != -1:
				continue
			if snorlax.blocks_world_position(Vector2(next) * 32 + Vector2(16, 16)):
				continue
			queue.append(next)
	return false

func write_preview(map: Node, snorlax: Node2D, output: String) -> void:
	# Export the real tile atlas pixels for a focused visual placement review.
	var crop := Rect2i(24 * 32, 57 * 32, 12 * 32, 12 * 32)
	var preview := Image.create(crop.size.x, crop.size.y, false, Image.FORMAT_RGBA8)
	for child: Node in map.get_node("Visual").get_children():
		if not child is TileMapLayer or not child.visible:
			continue
		var layer := child as TileMapLayer
		for cell: Vector2i in layer.get_used_cells():
			var dest := cell * 32 - crop.position + Vector2i(layer.position)
			if not Rect2i(Vector2i.ZERO, crop.size).intersects(Rect2i(dest, Vector2i(32, 32))):
				continue
			var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			if source == null:
				continue
			var pixels := source.texture.get_image()
			pixels.convert(Image.FORMAT_RGBA8)
			var region := source.get_tile_texture_region(layer.get_cell_atlas_coords(cell))
			preview.blend_rect(pixels, region, dest)
	var sprite := snorlax.get_node("Sprite2D") as Sprite2D
	var sprite_image := sprite.texture.get_image()
	sprite_image.convert(Image.FORMAT_RGBA8)
	sprite_image.resize(roundi(sprite_image.get_width() * sprite.scale.x), roundi(sprite_image.get_height() * sprite.scale.y), Image.INTERPOLATE_NEAREST)
	var dest := Vector2i(snorlax.position + sprite.position) - crop.position - sprite_image.get_size() / 2
	preview.blend_rect(sprite_image, Rect2i(Vector2i.ZERO, sprite_image.get_size()), dest)
	check(preview.save_png(output) == OK, "Placement preview exported")

func check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
