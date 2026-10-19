extends SceneTree

const SpinTiles := preload("res://scripts/world/spin_tile_movement.gd")
const LAYER_NAMES := ["SpinUp", "SpinDown", "SpinLeft", "SpinRight", "SpinStop"]
var failed := false

class PuzzleMap extends Node2D:
	var blocked_npc := Vector2.INF
	var blocked_actor := Vector2.INF
	var blocked_barrier := Vector2.INF

	func is_position_blocked_by_character(world_position: Vector2) -> bool:
		return world_position == blocked_npc

	func is_world_actor_step_blocked(_from: Vector2, to: Vector2) -> bool:
		return to == blocked_actor

	func is_world_barrier_step_blocked(_from: Vector2, to: Vector2) -> bool:
		return to == blocked_barrier


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = root.get_node("GameState")
	game.unlock_input()
	var map := _make_map()
	root.add_child(map)
	game.current_map = map
	var player: Node2D = load("res://scenes/player.tscn").instantiate()
	player.set_script(load("res://tests/fixtures/spin_tile_player.gd"))
	map.add_child(player)
	player.teleport_within_current_map(_at(map, Vector2i.ZERO))
	var tiles := map.get_node("Tiles/Logic")
	_paint(tiles, "SpinRight", Vector2i(1, 0))
	_paint(tiles, "SpinDown", Vector2i(4, 0))
	_paint(tiles, "SpinLeft", Vector2i(4, 3))
	_paint(tiles, "SpinUp", Vector2i(2, 3))
	_paint(tiles, "SpinStop", Vector2i(2, 1))
	_check(player._try_start_move(Vector2.RIGHT), "normal walking enters the first arrow")
	Input.action_press("move_left")
	player.buffered_direction = Vector2.LEFT
	var poses: Dictionary = {}
	var saw_forced_movement := false
	for frame in range(200):
		player._process(0.03)
		if player.spin_tiles.active:
			poses[str(player.master_appearance_sprite.animation)] = true
			_check(not player._can_accept_movement_input(), "manual movement is blocked during sliding")
			if player.is_moving:
				saw_forced_movement = true
				_check(is_equal_approx(player.get_network_movement_state().duration, SpinTiles.TILE_DURATION), "sliding uses normal network movement with fixed duration")
		if player.completed_steps >= 11 and not player.is_moving and not player.spin_tiles.active:
			break
	Input.action_release("move_left")
	_check(saw_forced_movement and poses.size() == 4, "the layered character turns through all four facing directions")
	_check(player.global_position == _at(map, Vector2i(2, 1)), "arrows redirect over ordinary floor and stop exactly on yellow")
	_check(player.completed_steps == 11, "each forced tile emits the normal completed-step signal")
	_check(not game.is_overworld_input_locked() and player._can_accept_movement_input(), "yellow returns normal control without consuming held input")
	_check(player.buffered_direction == Vector2.ZERO, "old buffered input is cleared")
	_check(str(player.master_appearance_sprite.animation).ends_with("up"), "stopping restores the final travel facing")

	_clear_layers(tiles)
	_paint(tiles, "SpinRight", Vector2i(1, 0))
	_paint(tiles, "SpinStop", Vector2i(5, 0))
	player.teleport_within_current_map(_at(map, Vector2i(1, 0)))
	player._process(0.03)
	_check(player.spin_tiles.active, "loading or teleporting onto an arrow starts the puzzle")
	var story_path: Array[String] = ["right"]
	_check(not player.can_story_move_path(story_path), "story paths cannot take over an active slide")
	game.acquire_overworld_input_lock(&"spin_test_story")
	_tick(player, 20)
	_check(player.global_position == _at(map, Vector2i(2, 0)) and not player.is_moving, "an external lock pauses the slide at the next tile boundary")
	_check(game.overworld_input_lock_owners.has(&"spin_test_story"), "the slide preserves external input-lock ownership")
	game.release_overworld_input_lock(&"spin_test_story")
	_run_until_stopped(player)
	_check(player.global_position == _at(map, Vector2i(5, 0)), "the slide resumes after the external lock ends")

	for blocker in ["npc", "actor", "barrier", "collision", "ledge", "direction"]:
		map.blocked_npc = Vector2.INF
		map.blocked_actor = Vector2.INF
		map.blocked_barrier = Vector2.INF
		for name in ["Collision", "LedgeRight", "BlockRight"]:
			tiles.get_node(name).clear()
		var next := _at(map, Vector2i(2, 0))
		match blocker:
			"npc": map.blocked_npc = next
			"actor": map.blocked_actor = next
			"barrier": map.blocked_barrier = next
			"collision": _paint(tiles, "Collision", Vector2i(2, 0))
			"ledge": _paint(tiles, "LedgeRight", Vector2i(2, 0))
			"direction": _paint(tiles, "BlockRight", Vector2i(1, 0))
		player.teleport_within_current_map(_at(map, Vector2i(1, 0)))
		_tick(player, 8)
		_check(player.global_position == _at(map, Vector2i(1, 0)) and not player.spin_tiles.active, "%s safely stops a slide without crossing the blocker" % blocker)
		_check(not game.is_overworld_input_locked(), "%s releases slide input control" % blocker)
	# A blocked arrow can trigger again after stepping off and returning.
	tiles.get_node("BlockRight").clear()
	player._try_start_move(Vector2.DOWN)
	_tick(player, 9)
	player._try_start_move(Vector2.UP)
	_run_until_stopped(player)
	_check(player.global_position == _at(map, Vector2i(5, 0)), "leaving and revisiting an arrow reactivates it")

	_clear_layers(tiles)
	_paint(tiles, "SpinRight", Vector2i(1, 0))
	_paint(tiles, "SpinDown", Vector2i(2, 0))
	_paint(tiles, "SpinLeft", Vector2i(2, 1))
	_paint(tiles, "SpinUp", Vector2i(1, 1))
	player.teleport_within_current_map(_at(map, Vector2i(1, 0)))
	_run_until_stopped(player)
	_check(not player.spin_tiles.active and not game.is_overworld_input_locked(), "a closed arrow loop returns control instead of trapping the player")

	_clear_layers(tiles)
	_paint(tiles, "SpinRight", Vector2i(1, 0))
	_paint(tiles, "SpinStop", Vector2i(3, 0))
	player.teleport_within_current_map(_at(map, Vector2i(1, 0)))
	player.exit_position = _at(map, Vector2i(2, 0))
	_run_until_stopped(player)
	_check(player.global_position == player.exit_position and not game.is_overworld_input_locked(), "map exits end sliding and release its lock")
	player.exit_position = Vector2.INF
	player.teleport_within_current_map(_at(map, Vector2i(1, 0)))
	player._process(0.03)
	game.acquire_overworld_input_lock(&"spin_test_story")
	player.reset_movement_state()
	_check(not player.spin_tiles.active and game.overworld_input_lock_owners.has(&"spin_test_story"), "reset clears sliding while retaining unrelated locks")
	game.release_overworld_input_lock(&"spin_test_story")
	player.teleport_within_current_map(_at(map, Vector2i(1, 0)))
	player._process(0.03)
	player.teleport_within_current_map(_at(map, Vector2i(0, 0)))
	_check(not player.spin_tiles.active and not game.is_overworld_input_locked(), "teleport cancels old slide direction and lock")
	for name: String in LAYER_NAMES:
		_check(not tiles.get_node(name).visible and not tiles.get_node(name).collision_enabled, "%s is a hidden, nonblocking runtime marker" % name)

	_paint(tiles, "SpinStop", Vector2i(1, 0))
	player.teleport_within_current_map(_at(map, Vector2i(1, 0)))
	player._process(0.03)
	_check(not player.spin_tiles.active and not player.is_moving, "a stop marker has priority over an overlapping arrow")
	tiles.get_node("SpinStop").erase_cell(Vector2i(1, 0))
	player.teleport_within_current_map(_at(map, Vector2i(1, 0)))
	player._process(0.03)
	player.reset_movement_state()
	var second := _make_map()
	second.name = "OrdinaryMap"
	root.add_child(second)
	map.remove_child(player)
	second.add_child(player)
	game.current_map = second
	player.teleport_within_current_map(_at(second, Vector2i.ZERO))
	player._process(0.03)
	_check(not player.spin_tiles.active and player.spin_tiles.map_owner == second, "changing maps discards the previous puzzle state and marker cache")
	_check(player._try_start_move(Vector2.UP), "ordinary movement stays available on a map without painted arrows")
	_tick(player, 9)
	_check(player.global_position == _at(second, Vector2i(0, -1)), "ordinary walking still completes a normal tile")
	second.remove_child(player)
	map.add_child(player)
	game.current_map = map
	second.free()
	player.teleport_within_current_map(_at(map, Vector2i(1, 0)))
	player._process(0.03)
	player.free()
	_check(not game.is_overworld_input_locked(), "removing the player releases the slide lock")
	map.free()
	game.current_map = null
	for floor in range(1, 5):
		var scene: Node = load("res://scenes/overworld/kanto/towns/celadon_city/rocket_hideout_b%sf.tscn" % floor).instantiate()
		for name: String in LAYER_NAMES:
			var layer := scene.get_node_or_null("Tiles/" + name) as TileMapLayer
			_check(layer != null and layer.tile_set != null, "B%sF has an authored %s marker layer" % [floor, name])
		scene.free()
	print("spin_tile_movement_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)


func _make_map() -> PuzzleMap:
	var map := PuzzleMap.new()
	map.name = "SpinPuzzle"
	map.position = Vector2(96, 64)
	var tiles := Node2D.new()
	tiles.name = "Tiles"
	tiles.position = Vector2(64, 32)
	map.add_child(tiles)
	var logic := Node2D.new()
	logic.name = "Logic"
	tiles.add_child(logic)
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.YELLOW)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.texture_region_size = Vector2i(32, 32)
	atlas.create_tile(Vector2i.ZERO)
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	tileset.add_source(atlas, 7)
	for name: String in LAYER_NAMES + ["Collision", "LedgeRight", "BlockRight"]:
		var layer := TileMapLayer.new()
		layer.name = name
		layer.tile_set = tileset
		logic.add_child(layer)
	return map


func _at(map: Node2D, cell: Vector2i) -> Vector2:
	return map.get_node("Tiles").to_global(Vector2(cell) * 32 + Vector2(16, 16))


func _paint(tiles: Node, layer_name: String, cell: Vector2i) -> void:
	tiles.get_node(layer_name).set_cell(cell, 7, Vector2i.ZERO)


func _clear_layers(tiles: Node) -> void:
	for layer: TileMapLayer in tiles.get_children():
		layer.clear()


func _tick(player: Node, frames: int) -> void:
	for frame in range(frames):
		player._process(0.03)


func _run_until_stopped(player: Node) -> void:
	for frame in range(200):
		player._process(0.03)
		if not player.is_moving and not player.spin_tiles.active:
			return
	_check(false, "the slide finishes within the bounded test path")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
