extends DialogueNPC

const PARCEL_QUEST_ID := "oaks_parcel"
const SELECTED_DIALOGUE_ID := "kanto_oaks_lab_gary_selected_starter"
const STARTER_DEPARTURE_DIALOGUE_ID := "kanto_oaks_lab_gary_starter_departure"
const PARCEL_WAITING_DIALOGUE_ID := "kanto_oaks_lab_gary_parcel_waiting"
const ROUTE_22_DEPARTURE_DIALOGUE_ID := "kanto_oaks_lab_gary_route_22_departure"
const PATH_DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]

var starter_sequence_running := false
var parcel_departure_running := false
var starter_already_claimed := false


func _ready() -> void:
	super._ready()
	var story_service := get_node_or_null("/root/StoryService")
	if story_service != null and not story_service.story_changed.is_connected(_on_gary_story_changed):
		story_service.story_changed.connect(_on_gary_story_changed)
	_sync_persisted_starter_choice.call_deferred()


func interact_with_player(player: Node2D) -> void:
	if starter_sequence_running or parcel_departure_running:
		return
	if _is_parcel_return_active():
		await _show_catalogue_dialogue(PARCEL_WAITING_DIALOGUE_ID)
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
	if species_id.is_empty() or species_name.is_empty():
		var options: Dictionary = await PlayerPartyStateService.get_starter_options()
		if bool(options.get("success", false)):
			species_id = str(options.get("rivalStarterSpeciesId", "")).strip_edges().to_lower()
			species_name = str(options.get("rivalStarterSpeciesName", "")).strip_edges()
	if player == null or species_id.is_empty() or species_name.is_empty():
		await GameErrorDialogService.show_report_to_staff_message()
		return

	starter_sequence_running = true
	_set_story_presence(true)
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

	var reached_player := await _walk_next_to_player(player)
	if not reached_player:
		push_warning(
			"Oak's Lab Gary could not reach a tile beside the player; "
			+ "continuing the challenge from the starter table."
		)
	face_world_position(_get_body_feet_position(player))
	if player.has_method("face_world_position"):
		player.face_world_position(get_feet_position())
	await _show_catalogue_dialogue(STARTER_DEPARTURE_DIALOGUE_ID)
	starter_sequence_running = false
	_set_story_presence(false)
	GameState.unlock_overworld_input()


func _sync_persisted_starter_choice() -> void:
	var options: Dictionary = await PlayerPartyStateService.get_starter_options()
	if not bool(options.get("success", false)):
		return
	starter_already_claimed = bool(options.get("alreadyClaimed", false))
	if not starter_already_claimed:
		_set_story_presence(true)
		return
	if GameState.current_map == null:
		await get_tree().process_frame
	var selected_ball := _starter_ball_for_species(
		str(options.get("rivalStarterSpeciesId", ""))
	)
	if selected_ball != null:
		selected_ball.call("set_claimed", true)
	_sync_story_presence()


func play_parcel_return_departure(player: Node2D) -> void:
	if parcel_departure_running:
		return
	parcel_departure_running = true
	_set_story_presence(true)
	face_world_position(_get_body_feet_position(player))
	if player != null and player.has_method("face_world_position"):
		player.face_world_position(get_feet_position())
	await _show_catalogue_dialogue(ROUTE_22_DEPARTURE_DIALOGUE_ID)
	parcel_departure_running = false
	_set_story_presence(false)


func _on_gary_story_changed(_revision: int) -> void:
	_sync_story_presence()


func _sync_story_presence() -> void:
	if starter_sequence_running or parcel_departure_running:
		return
	var parcel_quest := StoryService.get_quest(PARCEL_QUEST_ID)
	var parcel_status := str(parcel_quest.get("status", "")).strip_edges().to_lower()
	if parcel_status == "active":
		_set_story_presence(_is_parcel_return_active())
		return
	if parcel_status == "completed":
		_set_story_presence(false)
		return
	if not starter_already_claimed:
		_set_story_presence(true)
		return
	_set_story_presence(false)


func _set_story_presence(is_present: bool) -> void:
	visible = is_present
	if nameplate != null:
		nameplate.visible = is_present and not display_name.strip_edges().is_empty()
	if not is_present and quest_marker != null:
		quest_marker.visible = false
	if interaction_area != null:
		interaction_area.set_deferred("monitoring", is_present)
		interaction_area.set_deferred("monitorable", is_present)


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


func _is_parcel_return_active() -> bool:
	var quest := StoryService.get_quest(PARCEL_QUEST_ID)
	if str(quest.get("status", "")) != "active":
		return false
	for value: Variant in quest.get("steps", []):
		if value is Dictionary:
			var step := value as Dictionary
			if str(step.get("stepId", "")) == "return_to_oak":
				return str(step.get("status", "")) == "active"
	return false
