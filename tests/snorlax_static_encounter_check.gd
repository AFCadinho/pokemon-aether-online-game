extends SceneTree

const Blocking := preload("res://scripts/world/map_character_blocking.gd")

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
	check(snorlax.blocked_tile_footprint == Vector2i(3, 3), "Three-by-three footprint")
	var collision := map.get_node("Tiles/Collision") as TileMapLayer
	var water := map.get_node("Tiles/Water") as TileMapLayer
	var origin: Vector2i = Vector2i(snorlax.position / 32.0) + snorlax.blocked_tile_offset
	var north := origin + Vector2i(1, -1)
	var south := origin + Vector2i(1, 3)
	var movement_map := Node2D.new()
	var entities := Node2D.new()
	entities.name = "Entities"
	movement_map.add_child(entities)
	var encounters := Node2D.new()
	encounters.name = "StaticEncounters"
	entities.add_child(encounters)
	var movement_snorlax := snorlax.duplicate()
	encounters.add_child(movement_snorlax)
	var movement_player: Node2D = (load("res://scripts/world/player.gd") as GDScript).new()
	movement_map.add_child(movement_player)
	# Exercise Player.can_move_to without entering the tree or sending HTTP requests.
	movement_player.map_layers_initialized = true
	movement_player.map_layers_owner = movement_map
	movement_player.resolved_map_cache = movement_map
	movement_player.collision_tilemap = collision
	movement_player.water_tilemap = water
	for y in range(origin.y, origin.y + 3):
		for x in range(origin.x, origin.x + 3):
			var tile := Vector2i(x, y)
			check(collision.get_cell_source_id(tile) == -1 and water.get_cell_source_id(tile) == -1, "Snorlax occupies walkable steiger tiles")
			check(snorlax.blocks_world_position(Vector2(tile) * 32 + Vector2(16, 16)), "Every footprint tile blocks")
			check(not movement_player.can_move_to(Vector2(tile) * 32 + Vector2(16, 16)), "Player cannot enter any sleeping Snorlax tile")
	check(movement_player.can_move_to(Vector2(north) * 32 + Vector2(16, 16)), "Approach remains clear")
	check(movement_player.can_move_to(Vector2(south) * 32 + Vector2(16, 16)), "South approach remains clear")
	check(not reachable(collision, water, movement_map, north, south), "Cannot walk around Snorlax anywhere on Route 12")
	snorlax._ensure_interaction_area()
	var player := TestPlayer.new()
	for offset in range(3):
		check_interaction_edge(snorlax, player, origin + Vector2i(offset, -1), Vector2.DOWN, "north")
		check_interaction_edge(snorlax, player, origin + Vector2i(offset, 3), Vector2.UP, "south")
		check_interaction_edge(snorlax, player, origin + Vector2i(-1, offset), Vector2.RIGHT, "west")
		check_interaction_edge(snorlax, player, origin + Vector2i(3, offset), Vector2.LEFT, "east")
	player.free()
	check(not snorlax.apply_status({"encounterId": "snorlax_celadon", "completed": true}), "Another encounter cannot hide Route 12 Snorlax")
	check(not movement_snorlax.apply_status({"encounterId": "snorlax_celadon", "completed": true}), "Another encounter cannot release the movement blocker")
	check(not movement_player.can_move_to(snorlax.position), "Route 12 remains blocked")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview="):
			write_preview(map, snorlax, arg.trim_prefix("--preview="))
	check(snorlax.apply_status({"encounterId": "snorlax_route_12", "completed": true}), "Own completion applies")
	check(not snorlax.visible and not snorlax.blocks_world_position(snorlax.position), "Completion removes artwork and collision together")
	check(movement_snorlax.apply_status({"encounterId": "snorlax_route_12", "completed": true}), "Own completion updates the movement blocker")
	for y in range(origin.y, origin.y + 3):
		for x in range(origin.x, origin.x + 3):
			check(movement_player.can_move_to(Vector2(x * 32 + 16, y * 32 + 16)), "Completed Snorlax tiles allow player movement")
	check(reachable(collision, water, movement_map, north, south), "Completed route is traversable")
	movement_map.free()
	map.free()
	if not failed:
		print("PASS Snorlax: nine blocked tiles, no land bypass, all interaction edges, independent IDs and completed passage")
	quit(1 if failed else 0)

func check_interaction_edge(snorlax: Node2D, player: TestPlayer, tile: Vector2i, direction: Vector2, edge: String) -> void:
	player.position = Vector2(tile) * 32 + Vector2(16, 16)
	player.last_direction = direction
	check(not snorlax.blocks_world_position(player.position), "%s adjacent tile lies outside the footprint" % edge)
	check(snorlax._is_player_facing_interactable(player), "Interaction at every %s edge tile" % edge)
	var shape := snorlax.get_node("InteractionArea/CollisionShape2D").shape as RectangleShape2D
	check(Rect2(-shape.size / 2, shape.size).has_point(player.position - snorlax.position), "%s edge falls inside the interaction area" % edge)

func reachable(collision: TileMapLayer, water: TileMapLayer, movement_map: Node2D, start: Vector2i, goal: Vector2i) -> bool:
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
			if Blocking.is_position_blocked_by_character(movement_map, Vector2(next) * 32 + Vector2(16, 16)):
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
