extends DialogueNPC

const GARY_QUEST_ID := "gary_starter_battle"
const GARY_STEP_ID := "battle_gary"
const SELECTED_DIALOGUE_ID := "kanto_oaks_lab_gary_selected_starter"
const CHALLENGE_DIALOGUE_ID := "kanto_oaks_lab_gary_challenge"
const AFTER_BATTLE_DIALOGUE_ID := "kanto_oaks_lab_gary_after_battle"
const PATH_DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]

var starter_sequence_running := false


func _ready() -> void:
	super._ready()
	_sync_persisted_starter_choice.call_deferred()


func interact_with_player(player: Node2D) -> void:
	if starter_sequence_running:
		return
	if _is_gary_battle_active():
		var options: Dictionary = await PlayerPartyStateService.get_starter_options()
		if not bool(options.get("success", false)):
			await GameErrorDialogService.show_response(options)
			return
		call_deferred(
			"begin_starter_sequence",
			player,
			str(options.get("rivalStarterSpeciesId", "")),
			str(options.get("rivalStarterSpeciesName", "")),
			str(options.get("rivalTrainerId", ""))
		)
		return
	if _is_gary_battle_completed():
		await _show_catalogue_dialogue(AFTER_BATTLE_DIALOGUE_ID)
		return
	await show_dialogue()


func begin_starter_sequence(
	player: Node2D,
	rival_species_id: String,
	rival_species_name: String,
	rival_trainer_id: String
) -> void:
	if starter_sequence_running:
		return
	var species_id := rival_species_id.strip_edges().to_lower()
	var species_name := rival_species_name.strip_edges()
	var trainer_id := rival_trainer_id.strip_edges()
	if species_id.is_empty() or species_name.is_empty() or trainer_id.is_empty():
		var options: Dictionary = await PlayerPartyStateService.get_starter_options()
		if bool(options.get("success", false)):
			species_id = str(options.get("rivalStarterSpeciesId", "")).strip_edges().to_lower()
			species_name = str(options.get("rivalStarterSpeciesName", "")).strip_edges()
			trainer_id = str(options.get("rivalTrainerId", "")).strip_edges()
	if player == null or species_id.is_empty() or species_name.is_empty() or trainer_id.is_empty():
		await GameErrorDialogService.show_report_to_staff_message()
		return

	starter_sequence_running = true
	GameState.lock_overworld_input()
	var selected_ball := _starter_ball_for_species(species_id)
	if selected_ball == null:
		starter_sequence_running = false
		GameState.unlock_overworld_input()
		await GameErrorDialogService.show_report_to_staff_message()
		return

	if selected_ball.visible:
		var reached_ball := await _walk_to_world_position(
			selected_ball.call("get_selection_stand_position") as Vector2
		)
		if not reached_ball:
			starter_sequence_running = false
			GameState.unlock_overworld_input()
			await GameErrorDialogService.show_report_to_staff_message()
			return
		face_world_position(selected_ball.global_position)
		await _show_catalogue_dialogue(SELECTED_DIALOGUE_ID, {"pokemon": species_name})
		selected_ball.call("set_claimed", true)

	if not await _walk_next_to_player(player):
		starter_sequence_running = false
		GameState.unlock_overworld_input()
		await GameErrorDialogService.show_report_to_staff_message()
		return
	face_world_position(_get_body_feet_position(player))
	if player.has_method("face_world_position"):
		player.face_world_position(get_feet_position())
	await _show_catalogue_dialogue(CHALLENGE_DIALOGUE_ID)

	var metadata_response: Dictionary = await TrainerMetadataService.get_trainer_metadata(trainer_id)
	if not bool(metadata_response.get("success", false)):
		starter_sequence_running = false
		GameState.unlock_overworld_input()
		await GameErrorDialogService.show_response(metadata_response)
		return
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("start_trainer_battle"):
		starter_sequence_running = false
		GameState.unlock_overworld_input()
		await GameErrorDialogService.show_report_to_staff_message()
		return
	var battle_result: Dictionary = await world.call(
		"start_trainer_battle",
		(metadata_response.get("metadata", {}) as Dictionary).duplicate(true)
	)
	starter_sequence_running = false
	if not bool(battle_result.get("success", false)):
		GameState.unlock_overworld_input()
		await GameErrorDialogService.show_response(
			battle_result,
			"backend.error.trainer_battle_start"
		)


func _sync_persisted_starter_choice() -> void:
	var options: Dictionary = await PlayerPartyStateService.get_starter_options()
	if not bool(options.get("success", false)) or not bool(options.get("alreadyClaimed", false)):
		return
	if GameState.current_map == null:
		await get_tree().process_frame
	var selected_ball := _starter_ball_for_species(
		str(options.get("rivalStarterSpeciesId", ""))
	)
	if selected_ball != null:
		selected_ball.call("set_claimed", true)


func _starter_ball_for_species(species_id: String) -> Node2D:
	var current_map: Node = GameState.current_map
	if current_map == null:
		return null
	for node: Node in current_map.find_children("*", "", true, false):
		if node.has_method("matches_species") and bool(node.call("matches_species", species_id)):
			return node as Node2D
	return null


func _walk_next_to_player(player: Node2D) -> bool:
	var player_tile := _to_tile(_get_body_target_feet_position(player))
	var best_path: Array[String] = []
	for offset: Vector2i in PATH_DIRECTIONS:
		var candidate_tile := player_tile + offset
		if not _can_story_npc_move_to(_tile_to_world(candidate_tile)):
			continue
		var candidate_path := _find_story_path(candidate_tile)
		if candidate_path.is_empty() and candidate_tile != _to_tile(get_feet_position()):
			continue
		if best_path.is_empty() or candidate_path.size() < best_path.size():
			best_path = candidate_path
	if best_path.is_empty():
		return _to_tile(get_feet_position()).distance_squared_to(player_tile) == 1
	return await story_move_path(best_path)


func _walk_to_world_position(world_position: Vector2) -> bool:
	var target_tile := _to_tile(world_position)
	if target_tile == _to_tile(get_feet_position()):
		return true
	var path := _find_story_path(target_tile)
	if path.is_empty():
		return false
	return await story_move_path(path)


func _find_story_path(target_tile: Vector2i) -> Array[String]:
	var start_tile := _to_tile(get_feet_position())
	if start_tile == target_tile:
		return []
	var frontier: Array[Vector2i] = [start_tile]
	var previous: Dictionary = {start_tile: start_tile}
	var previous_direction: Dictionary = {}
	var cursor := 0
	while cursor < frontier.size() and frontier.size() <= 512:
		var current_tile := frontier[cursor]
		cursor += 1
		for offset: Vector2i in PATH_DIRECTIONS:
			var next_tile := current_tile + offset
			if previous.has(next_tile):
				continue
			if next_tile != target_tile and not _can_story_npc_move_to(_tile_to_world(next_tile)):
				continue
			if next_tile == target_tile and not _can_story_npc_move_to(_tile_to_world(next_tile)):
				continue
			previous[next_tile] = current_tile
			previous_direction[next_tile] = _direction_name(offset)
			if next_tile == target_tile:
				return _reconstruct_path(start_tile, target_tile, previous, previous_direction)
			frontier.append(next_tile)
	return []


func _reconstruct_path(
	start_tile: Vector2i,
	target_tile: Vector2i,
	previous: Dictionary,
	previous_direction: Dictionary
) -> Array[String]:
	var reversed: Array[String] = []
	var current_tile := target_tile
	while current_tile != start_tile:
		reversed.append(str(previous_direction.get(current_tile, "")))
		current_tile = previous[current_tile] as Vector2i
	reversed.reverse()
	if reversed.size() > MAX_STORY_PATH_STEPS:
		return []
	return reversed


func _direction_name(direction: Vector2i) -> String:
	match direction:
		Vector2i.UP:
			return "up"
		Vector2i.DOWN:
			return "down"
		Vector2i.LEFT:
			return "left"
		Vector2i.RIGHT:
			return "right"
	return ""


func _show_catalogue_dialogue(dialogue_id: String, replacements: Dictionary = {}) -> void:
	var lines: Array[String] = await DialogueMetadataService.get_lines(dialogue_id)
	var formatted: Array[String] = []
	for line: String in lines:
		var text := line
		for key: Variant in replacements:
			text = text.replace("{%s}" % str(key), str(replacements[key]))
		formatted.append(text)
	await show_dialogue(formatted, display_name)


func _is_gary_battle_active() -> bool:
	var quest := StoryService.get_quest(GARY_QUEST_ID)
	if str(quest.get("status", "")) != "active":
		return false
	for value: Variant in quest.get("steps", []):
		if value is Dictionary:
			var step := value as Dictionary
			if str(step.get("stepId", "")) == GARY_STEP_ID:
				return str(step.get("status", "")) == "active"
	return false


func _is_gary_battle_completed() -> bool:
	return str(StoryService.get_quest(GARY_QUEST_ID).get("status", "")) == "completed"
