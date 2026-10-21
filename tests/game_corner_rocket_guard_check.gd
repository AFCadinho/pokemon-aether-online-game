extends SceneTree

const CORNER := "res://scenes/overworld/kanto/towns/celadon_city/game_corner.tscn"
const QUEST := "investigate_celadon_game_corner"
const TRAINER := "kanto_celadon_game_corner_rocket_guard"
var failed := false
var story: Node
var state: Node


class PlayerProbe extends CharacterBody2D:
	var last_direction := Vector2.UP
	func get_feet_position() -> Vector2:
		return global_position
	func get_interaction_position() -> Vector2:
		return global_position
	func face_world_position(target: Vector2) -> void:
		last_direction = (target - global_position).normalized()


class WorldProbe extends Node2D:
	var battles: Array[Dictionary] = []
	func start_trainer_battle(metadata: Dictionary) -> Dictionary:
		battles.append(metadata.duplicate(true))
		return {"success": true, "battleId": "guard-fixture"}


class ProgressProbe extends Node:
	signal progress_invalidated
	func get_progress(_trainer_id: String) -> Dictionary:
		return {"success": true, "progress": {"state": "first_encounter"}}


class ApiProbe extends Node:
	var resolutions: Array[Dictionary] = []
	var completions: Array[Dictionary] = []
	var completed_story: Dictionary
	var fail_escape_ack := true
	func resolve_story_interaction(id: String, map_id: String, entity: String, trigger: String) -> Dictionary:
		resolutions.append({"id": id, "mapId": map_id, "entity": entity, "trigger": trigger})
		var service := get_node("/root/StoryService")
		var battle: bool = service.is_requirement_met("investigate_celadon_game_corner", "investigate_game_corner", "active")
		var escape: bool = service.is_requirement_met("investigate_celadon_game_corner", "watch_guard_flee", "active")
		var handled := battle if id.ends_with("confrontation") else escape
		var actions: Array = []
		if handled and battle:
			for dialogue: String in ["player_question", "guard_deflect", "player_push", "guard_found_out", "guard_challenge"]:
				actions.append({"type": "dialogue", "dialogueId": "kanto_game_corner_" + dialogue})
			actions.append({"type": "battle", "trainerId": "kanto_celadon_game_corner_rocket_guard"})
		elif handled:
			actions.append({"type": "dialogue", "dialogueId": "kanto_game_corner_guard_warn_boss"})
		return {"success": true, "interactionId": id, "handled": handled, "completionRequired": handled and escape,
			"revision": 21, "actions": actions}
	func complete_story_interaction(id: String, request: String, revision: int, map_id: String, entity: String, trigger: String) -> Dictionary:
		completions.append({"id": id, "request": request, "revision": revision, "mapId": map_id, "entity": entity, "trigger": trigger})
		if fail_escape_ack:
			fail_escape_ack = false
			return {"success": false, "status": 400, "error": "Fixture acknowledgement failure"}
		return {"success": true, "story": completed_story, "effects": []}


class DialogueProbe extends Node:
	signal dialogue_finished
	var is_open := false
	var turns: Array[Dictionary] = []
	func start_dialogue(lines: Array, speaker := "", portrait: Texture2D = null, _show_portrait := true) -> void:
		is_open = true
		turns.append({"lines": lines.duplicate(), "speaker": speaker, "portrait": portrait})
		_finish.call_deferred()
	func _finish() -> void:
		await get_tree().process_frame
		is_open = false
		dialogue_finished.emit()


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	story = root.get_node("StoryService")
	state = root.get_node("GameState")
	state.reset_gameplay_runtime_state()
	root.get_node("CoopService").set_process(false)
	var api := root.get_node("PlayerGameStateService")
	var api_script: Script = api.get_script()
	api.set_script(ApiProbe)
	api.set("completed_story", _story("watch_guard_flee", true))
	var progress := root.get_node("TrainerProgressService")
	var progress_script: Script = progress.get_script()
	progress.set_script(ProgressProbe)
	_prime_content()
	story.apply_story(_story("inactive"))
	var map := (load(CORNER) as PackedScene).instantiate()
	# Isolate the guard: map exits remain covered by server transition tests.
	for exit_node: Node in map.get_node("Exits").get_children():
		exit_node.free()
	state.current_map = map
	root.add_child(map)
	current_scene = map
	var world := WorldProbe.new()
	world.add_to_group("world")
	root.add_child(world)
	var layer := Node.new()
	layer.name = "DialogueBox"
	map.add_child(layer)
	var box := DialogueProbe.new()
	box.name = "Box"
	layer.add_child(box)
	var guard := map.get_node("Entities/NPCs/StairAttendant") as Node2D
	var origin := guard.position
	var player := PlayerProbe.new()
	player.name = "Player"
	player.add_to_group("player")
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 16)
	shape.shape = rectangle
	player.add_child(shape)
	map.get_node("Entities/Players").add_child(player)
	player.global_position = guard.global_position + Vector2(0, 32)
	player.z_as_relative = false
	player.z_index = floori(player.global_position.y)
	for _frame in range(4):
		await physics_frame
	_check(guard.get("portrait_id") == "showdown_worker_gen6", "Before Erika the guard looks like an ordinary attendant")
	_check(not guard.get_node("RematchMarker").visible, "The disguise has no trainer challenge marker")
	for offset: Vector2 in [Vector2.ZERO, Vector2(32, 0), Vector2(64, 0)]:
		_check(map.is_position_blocked_by_character(guard.global_position + offset), "The attendant blocks the approach and both stair tiles")
	await _press_interact()
	_check(world.battles.is_empty() and box.turns.back().lines == ["Nothing to see here. Staff only."], "Before the story prerequisite he sends the player away")
	story.apply_story(_story("investigate_game_corner"))
	await _press_interact()
	_check(world.battles.size() == 1, "The confrontation starts exactly one normal trainer battle")
	_check(box.turns.size() == 6, "The confrontation follows both player questions and all three guard turns")
	_check(box.turns[4].portrait.resource_path.ends_with("worker-gen6.png"), "Found out is spoken while he is still disguised")
	_check(box.turns[5].portrait.resource_path.ends_with("rainbowrocketgrunt.png"), "The threat uses his revealed Rocket portrait")
	_check(guard.get("portrait_id") == "showdown_rainbowrocketgrunt", "The overworld guard has changed into a Rocket Grunt")
	_check(guard.get("sprite").sprite_frames.get_frame_count("walk_right") == 4, "The revealed grunt has four walking frames for his escape")
	if not world.battles.is_empty():
		_check(world.battles[0].get("_battle_mugshot") == guard.get("mugshot"), "Battle staging uses the revealed portrait")
		_check(world.battles[0].get("_battle_sprite_frames") == guard.get("sprite").sprite_frames, "Battle staging uses the revealed overworld frames")
	_check(api.get("completions").is_empty(), "Client dialogue cannot acknowledge a battle victory")
	guard.call("abort_story_sequence")
	state.unlock_input()
	_check(not guard.is_gate_open() and guard.position == origin, "An aborted or lost confrontation restores the blocked staging")
	state.lock_overworld_input()
	story.apply_story(_story("watch_guard_flee"))
	for _frame in range(4):
		await physics_frame
	_check(api.get("completions").is_empty(), "The escape waits while the normal battle outro owns input")
	state.unlock_overworld_input()
	for _frame in range(55):
		await physics_frame
	_check(api.get("completions").size() == 1, "The guard warns the boss and flees only after a trusted win")
	_check(guard.visible and guard.position == origin, "Failed escape ACK restores the same Rocket guard for a safe retry")
	_check(guard.is_gate_open() and not state.is_overworld_input_locked(), "The earned victory remains open and failure releases input")
	await _press_interact(50)
	_check(api.get("completions").size() == 2, "Manual interaction resumes the saved escape without a second battle")
	_check(not guard.visible and world.battles.size() == 1, "Successful escape removes the guard without repeating his reward")
	_check(story.is_requirement_met("confront_team_rocket_boss", "confront_boss", "active"), "The new objective confronts Team Rocket's boss about Pokémon Tower")
	_check(not state.is_overworld_input_locked(), "Completing the escape releases input")
	state.current_map = null
	current_scene = null
	map.queue_free()
	world.queue_free()
	await process_frame
	api.set_script(api_script)
	progress.set_script(progress_script)
	story.reset_story()
	state.reset_gameplay_runtime_state()
	print("game_corner_rocket_guard_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)


func _press_interact(frames := 30) -> void:
	Input.action_press("interact")
	for _frame in range(3):
		await physics_frame
	Input.action_release("interact")
	for _frame in range(frames):
		await physics_frame


func _story(step: String, completed := false) -> Dictionary:
	return {"revision": 22 if completed else 21, "quests": [
		{"questId": QUEST, "questType": "main", "definitionVersion": 2, "status": "completed" if completed else "available" if step == "inactive" else "active", "steps": [
			{"stepId": "investigate_game_corner", "status": "completed" if completed or step == "watch_guard_flee" else "active" if step == "investigate_game_corner" else "inactive"},
			{"stepId": "watch_guard_flee", "status": "completed" if completed else "active" if step == "watch_guard_flee" else "inactive"}]},
		{"questId": "confront_team_rocket_boss", "questType": "main", "definitionVersion": 1, "status": "active" if completed else "available", "steps": [
			{"stepId": "confront_boss", "status": "active" if completed else "inactive"}]}]}


func _prime_content() -> void:
	var metadata := root.get_node("NpcMetadataService")
	var key: String = metadata.call("_get_cache_key", metadata.call("_get_http_locale"), "kanto_game_corner_attendant")
	metadata.npc_metadata_cache[key] = {"success": true, "metadata": {"id": "kanto_game_corner_attendant", "dialogueId": "kanto_game_corner_guard_blocked", "questMarkers": [
		{"questId": QUEST, "stepId": "investigate_game_corner", "statuses": ["active"]},
		{"questId": QUEST, "stepId": "watch_guard_flee", "statuses": ["active"]}]}}
	root.get_node("TrainerMetadataService").trainer_metadata_cache[TRAINER] = {"success": true, "metadata": {"id": TRAINER, "name": "Team Rocket Grunt", "trainer_class": "team_rocket"}}
	var dialogues := root.get_node("DialogueMetadataService")
	for entry: Array in [["guard_blocked", "Nothing to see here. Staff only."], ["player_question", "What is downstairs?"],
		["guard_deflect", "Only storage rooms."], ["player_push", "Then I will take a look."],
		["guard_found_out", "So, we have been found out."], ["guard_challenge", "I cannot let you leave!"],
		["guard_warn_boss", "I have to warn the boss!"]]:
		var id := "kanto_game_corner_" + str(entry[0])
		key = dialogues.call("_get_cache_key", dialogues.call("_get_http_locale"), id)
		var is_player: bool = str(entry[0]).begins_with("player")
		dialogues.dialogue_metadata_cache[key] = {"success": true, "metadata": {"id": id, "dialogueId": id,
			"speakerName": "Player" if is_player else "Attendant", "speakerRole": "player" if is_player else "npc", "lines": [entry[1]]}}


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
