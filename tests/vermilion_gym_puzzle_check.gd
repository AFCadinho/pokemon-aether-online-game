extends SceneTree

const GYM := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_gym.tscn"
var failed := false

class TestPlayer extends Node2D:
	var last_direction := Vector2.UP

class TestDialogue extends Node:
	signal dialogue_finished
	var is_open := false
	var last_lines: Array[String] = []
	func start_dialogue(lines: Array[String], _speaker: String, _portrait: Texture2D, _show_portrait: bool) -> void:
		last_lines = lines
		dialogue_finished.emit.call_deferred()


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := root.get_node("GameState")
	var localization := root.get_node("LocalizationManager")
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host
	var dialogue_container := Node.new()
	dialogue_container.name = "DialogueBox"
	host.add_child(dialogue_container)
	var dialogue := TestDialogue.new()
	dialogue.name = "Box"
	dialogue_container.add_child(dialogue)
	var gym := _new_gym(host)
	game_state.current_map = gym
	var collision := gym.get_node("Tiles/Collision") as TileMapLayer
	var has_map_collision := not collision.get_used_cells().is_empty()
	var bins: Dictionary = {}
	var player := TestPlayer.new()
	host.add_child(player)
	for child: Node in gym.get_node("Entities/Interactables").get_children():
		if child.get("bin_coordinates") == null:
			continue
		bins[child.bin_coordinates] = child
		# Both positions within the single front tile support normal interaction.
		for dx in [-8, 8]:
			player.global_position = child.global_position + Vector2(dx, 32)
			_check(child._is_player_facing_interactable(player), "bin front supports facing interaction")
			_check(not child.blocks_world_position(player.global_position), "bin leaves its approach open")
			_check(not gym.is_position_blocked_by_character(child.global_position + Vector2(dx, 0)), "bins allow walking through their interaction footprint")
		player.last_direction = Vector2.DOWN
		_check(not child._is_player_facing_interactable(player), "bin ignores interaction while facing away")
		player.last_direction = Vector2.UP
	_check(bins.size() == 20, "all twenty visual bins are interactive")
	_check(gym.get_adjacent_bins(gym.first_switch).has(gym.second_switch), "visit selects cardinal neighbors")
	var lower := gym.get_node("Entities/Interactables/LowerElectricBarrier")
	var upper := gym.get_node("Entities/Interactables/UpperElectricBarrier")
	_check(lower.visible and upper.visible, "both electric barriers start visible")
	_check(_reachable(gym, Vector2i(11, 9)) == not has_map_collision, "only an intentionally empty map collision allows routes around barriers")
	_check_barrier_footprints(gym)
	_check(_reachable(gym, Vector2i(11, 15)) == not has_map_collision, "painted walls constrain access to the lower barrier")
	var entrance: Vector2 = gym.get_node("Spawns/FromVermilionCity").global_position
	for position: Vector2 in [Vector2(368, 304), Vector2(368, 432), Vector2(368, 496), Vector2(368, 528)]:
		_check(gym.get_safe_restored_player_position(position) == entrance, "new visit restores saved upper corridor positions at entrance")
	_check(gym.get_safe_restored_player_position(Vector2(368, 752)) == Vector2(368, 752), "restoring inside a nonblocking bin preserves the position")
	_check(gym.get_safe_restored_player_position(Vector2(368, 1008)) == Vector2(368, 1008), "normal saved puzzle-floor position stays unchanged")

	# Exercise every possible adjacent pair and every wrong second choice.
	for first: Vector2i in bins:
		for second: Vector2i in gym.get_adjacent_bins(first):
			_set_pair(gym, first, second)
			_check(gym.activate_bin(second) == "empty", "second cannot activate before first")
			for wrong: Vector2i in bins:
				if wrong == first or wrong == second:
					continue
				_check(gym.activate_bin(first) == "first", "first rearms after each failed attempt")
				_check(not lower.blocks_movement and upper.blocks_movement, "first opens only the lower barrier")
				_check(gym.activate_bin(first) == "first_active", "rechecking first does not fail")
				_check(gym.activate_bin(wrong) == "wrong", "incorrect second resets activation")
				_check(lower.blocks_movement and upper.blocks_movement, "wrong choice restores both barriers")
				_check(gym.first_switch == first and gym.second_switch == second, "failed guesses never reroll the pair")
			gym.activate_bin(first)
			_check(gym.activate_bin(second) == "solved", "adjacent second solves puzzle")
			_check(not lower.visible and not upper.visible, "success removes both electric effects")
			for bin: Vector2i in bins:
				_check(gym.activate_bin(bin) == "solved", "solved visit stays open when checking any bin")

	# Run actual WorldInteractable dialogue and locking, in every released locale.
	_set_pair(gym, Vector2i(2, 1), Vector2i(3, 1))
	_check_barrier_footprints(gym)
	var locale_before: String = localization.current_locale
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		localization.set_locale(locale)
		_set_pair(gym, Vector2i(2, 1), Vector2i(3, 1))
		for bin: Vector2i in [Vector2i(0, 0), Vector2i(2, 1), Vector2i(2, 1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, 1)]:
			await bins[bin]._start_manual_interaction(player)
			_check(not dialogue.last_lines.is_empty() and not dialogue.last_lines[0].begins_with("world."), "localized bin feedback: " + locale)
			_check(not game_state.is_overworld_input_locked(), "dialogue releases input lock")
		_check(gym.puzzle_solved, "actual bin interactions solve puzzle")
	localization.set_locale(locale_before)
	_check(_reachable(gym, Vector2i(11, 9)), "solved barriers allow walking to Lt. Surge")
	_check(gym.get_safe_restored_player_position(Vector2(368, 304)) == Vector2(368, 304), "active solved visit keeps its leader position")
	_set_pair(gym, Vector2i(2, 1), Vector2i(3, 1))
	gym.activate_bin(gym.first_switch)
	_check(_reachable(gym, Vector2i(11, 15)), "first allows walking into intermediate corridor")
	_check(_reachable(gym, Vector2i(11, 9)) == not has_map_collision, "upper barrier closes the painted corridor after first switch")
	_check(gym.is_position_blocked_by_character(Vector2(368, 432)), "upper barrier still blocks its own passage after first switch")
	_check(not gym.is_position_blocked_by_character(Vector2(368, 528)), "first switch removes lower barrier movement blocking")

	# A fresh map instance resets both activation and solution, including after success.
	gym.activate_bin(gym.second_switch)
	game_state.current_map = null
	gym.free()
	gym = _new_gym(host)
	game_state.current_map = gym
	_check(not gym.first_switch_active and not gym.puzzle_solved, "re-entry resets the visit")
	_check(gym.get_adjacent_bins(gym.first_switch).has(gym.second_switch), "re-entry selects a valid new pair")
	_check_barrier_footprints(gym)
	game_state.current_map = null
	await process_frame
	current_scene = null
	host.free()
	print("VERMILION_GYM_PUZZLE ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _new_gym(host: Node) -> Node2D:
	var gym := (load(GYM) as PackedScene).instantiate()
	# This test exercises local puzzle behavior without trainer metadata requests.
	for npc: Node in gym.get_node("Entities/NPCs").get_children():
		npc.free()
	host.add_child(gym)
	return gym


func _set_pair(gym: Node, first: Vector2i, second: Vector2i) -> void:
	gym.first_switch = first
	gym.second_switch = second
	gym.first_switch_active = false
	gym.puzzle_solved = false
	gym.puzzle_changed.emit()


func _reachable(gym: Node, target: Vector2i) -> bool:
	var collision := gym.get_node("Tiles/Collision") as TileMapLayer
	var start := Vector2i(11, 31)
	var visited := {start: true}
	var pending: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < pending.size():
		var cell := pending[cursor]
		cursor += 1
		if cell == target:
			return true
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := cell + direction
			if not Rect2i(0, 0, 24, 36).has_point(next) or visited.has(next):
				continue
			if collision.get_cell_source_id(next) != -1:
				continue
			if gym.is_position_blocked_by_character(gym.to_global(Vector2(next * 32 + Vector2i(16, 16)))):
				continue
			visited[next] = true
			pending.append(next)
	return false


func _check_barrier_footprints(gym: Node) -> void:
	for row in [13, 16]:
		for column in range(8, 15):
			var position := Vector2(column * 32 + 16, row * 32 + 16)
			_check(gym.is_position_blocked_by_character(position), "electric barriers block all passage cells even with empty map collision")


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL " + label)
