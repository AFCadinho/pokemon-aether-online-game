extends SceneTree

const GYM := "res://scenes/overworld/kanto/towns/celadon_city/celadon_gym.tscn"
const ERIKA := "kanto_celadon_gym_erika"
const QUEST := "challenge_celadon_gym"
const INQUIRY := "kanto_celadon_erika_rocket_inquiry"
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


class ProgressProbe extends Node:
	signal progress_invalidated
	func get_progress(_trainer_id: String) -> Dictionary:
		return {"success": true, "progress": {"state": "completed"}}


class ApiProbe extends Node:
	var resolutions: Array[Dictionary] = []
	var completions: Array[Dictionary] = []
	var completed_story: Dictionary
	func resolve_story_interaction(id: String, map_id: String, entity: String, trigger: String) -> Dictionary:
		resolutions.append({"id": id, "mapId": map_id, "entityId": entity, "trigger": trigger})
		return {"success": true, "interactionId": id, "handled": true, "completionRequired": true,
			"revision": 21, "actions": [
				{"type": "dialogue", "dialogueId": "kanto_celadon_player_ask_erika_rocket"},
				{"type": "dialogue", "dialogueId": "kanto_celadon_erika_game_corner_rumors"}]}
	func complete_story_interaction(id: String, request: String, revision: int, map_id: String, entity: String, trigger: String) -> Dictionary:
		completions.append({"id": id, "request": request, "revision": revision, "mapId": map_id, "entity": entity, "trigger": trigger})
		return {"success": true, "story": completed_story, "effects": []}


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
	api.set("completed_story", _story("ask_erika", true))
	var progress := root.get_node("TrainerProgressService")
	var progress_script: Script = progress.get_script()
	progress.set_script(ProgressProbe)
	_prime_content()
	story.apply_story(_story("challenge_erika"))
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	world.set_script(load("res://tests/fixtures/coop_return_world_probe.gd"))
	for child: Node in world.get_node("CurrentMap").get_children():
		child.free()
	world.get_node("Player").set_script(PlayerProbe)
	world.get_node("UIOverlay").free()
	world.get_node("ContentCreatorPhotoMode").free()
	var gym := (load(GYM) as PackedScene).instantiate()
	for child: Node in gym.get_node("Entities/NPCs").get_children():
		if child.name != "GymLeaderErika":
			child.free()
	for child: Node in gym.get_node("Entities/Interactables").get_children():
		child.free()
	world.get_node("CurrentMap").add_child(gym)
	state.current_map = gym
	root.add_child(world)
	current_scene = world
	var erika := gym.get_node("Entities/NPCs/GymLeaderErika") as Node2D
	var player := world.get_node("Player") as CharacterBody2D
	player.global_position = erika.global_position + Vector2(0, 32)
	var trigger := erika.get_node("RocketInquiry") as Area2D
	_check(trigger.get_node("StoryHook").get("interaction_id") == INQUIRY, "Automatic conversation binds Erika's canonical interaction")
	_check(erika.get_node("StoryHook").get("interaction_id") == INQUIRY + "_manual", "Erika also supports manual dialogue recovery")
	for _frame in range(5):
		await physics_frame
	_check(api.get("resolutions").is_empty(), "Standing at Erika before victory does not start the Rocket conversation")
	state.lock_overworld_input()
	story.apply_story(_story("ask_erika"))
	var box := world.get_node("DialogueBox/Box")
	var outro := {"done": false}
	_present_normal_outro(world, erika.get("mugshot"), outro)
	await process_frame
	_check(box.get("lines") == ["A wonderful battle! Please accept the Rainbow Badge."], "The normal trainer outro praises the battle first")
	_check(api.get("resolutions").is_empty(), "The interview waits while the normal outro owns input")
	box.call("hide_dialogue")
	for _frame in range(4):
		await process_frame
	_check(outro.done and api.get("resolutions").is_empty(), "Closing the battle reaction keeps the interview behind the remaining battle lock")
	state.unlock_overworld_input()
	await _wait_for_line(box, "What do you know about Team Rocket in Celadon?")
	_check(api.get("resolutions").size() == 1, "The question starts automatically after the ordinary outro unlocks")
	_check(box.get("npc_sprite").texture != erika.get("mugshot"), "The player's question uses the player's portrait")
	box.call("hide_dialogue")
	await _wait_for_line(box, "I heard rumors of suspicious activity at the Game Corner.")
	_check(box.get("npc_sprite").texture == erika.get("mugshot"), "Erika answers with her own trainer portrait")
	_check(api.get("completions").is_empty(), "The Game Corner quest waits until Erika's hint finishes")
	box.call("hide_dialogue")
	for _frame in range(8):
		await process_frame
	_check(api.get("completions").size() == 1, "The complete interview is acknowledged once")
	_check(story.is_requirement_met("investigate_celadon_game_corner", "investigate_game_corner", "active"), "The next main quest investigates the Game Corner")
	_check(not state.is_overworld_input_locked(), "Automatic conversation releases input")
	_check(not erika.get_node("QuestMarker").visible, "Erika's quest marker clears after the hint")
	# Recover an interrupted interview by speaking to the real trainer manually.
	trigger.set_process(false)
	story.apply_story(_story("ask_erika"))
	Input.action_press("interact")
	for _frame in range(4):
		await process_frame
	Input.action_release("interact")
	await _wait_for_line(box, "What do you know about Team Rocket in Celadon?")
	box.call("hide_dialogue")
	await _wait_for_line(box, "I heard rumors of suspicious activity at the Game Corner.")
	box.call("hide_dialogue")
	for _frame in range(8):
		await process_frame
	_check(api.get("resolutions").back().get("trigger") == "interact", "An interrupted saved interview can resume through manual NPC interaction")
	_check(api.get("completions").size() == 2 and not state.is_overworld_input_locked(), "Manual recovery completes the same interview and releases input")
	state.current_map = null
	current_scene = null
	world.queue_free()
	await process_frame
	api.set_script(api_script)
	progress.set_script(progress_script)
	story.reset_story()
	state.reset_gameplay_runtime_state()
	print("celadon_gym_story_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)


func _present_normal_outro(world: Node, portrait: Texture2D, state_result: Dictionary) -> void:
	await world.call("_show_trainer_outro_dialogue", "kanto_celadon_gym_erika_defeated", portrait)
	state_result.done = true


func _wait_for_line(box: Node, line: String) -> void:
	for _frame in range(60):
		if box.get("is_open") and box.get("lines") == [line]:
			return
		await process_frame
	_check(false, "Expected dialogue: " + line)


func _story(step: String, completed := false) -> Dictionary:
	return {"revision": 22 if completed else 21, "quests": [
		{"questId": QUEST, "storylineId": "kanto_main", "questType": "main", "definitionVersion": 1,
			"status": "completed" if completed else "active", "steps": [
				{"stepId": "challenge_erika", "status": "active" if step == "challenge_erika" else "completed"},
				{"stepId": "ask_erika", "status": "completed" if completed else "active" if step == "ask_erika" else "inactive"}]},
		{"questId": "investigate_celadon_game_corner", "storylineId": "kanto_main", "questType": "main", "definitionVersion": 1,
			"status": "active" if completed else "available", "steps": [{"stepId": "investigate_game_corner", "status": "active" if completed else "inactive"}]}]}


func _prime_content() -> void:
	var metadata := root.get_node("NpcMetadataService")
	var key: String = metadata.call("_get_cache_key", metadata.call("_get_http_locale"), ERIKA)
	metadata.npc_metadata_cache[key] = {"success": true, "metadata": {"id": ERIKA, "name": "Erika",
		"questMarkers": [{"questId": QUEST, "stepId": "challenge_erika", "statuses": ["active"]},
			{"questId": QUEST, "stepId": "ask_erika", "statuses": ["active"]}]}}
	var dialogues := root.get_node("DialogueMetadataService")
	for entry: Array in [
		["kanto_celadon_gym_erika_defeated", "A wonderful battle! Please accept the Rainbow Badge.", "Erika", "npc"],
		["kanto_celadon_player_ask_erika_rocket", "What do you know about Team Rocket in Celadon?", "Player", "player"],
		["kanto_celadon_erika_game_corner_rumors", "I heard rumors of suspicious activity at the Game Corner.", "Erika", "npc"]]:
		key = dialogues.call("_get_cache_key", dialogues.call("_get_http_locale"), entry[0])
		dialogues.dialogue_metadata_cache[key] = {"success": true, "metadata": {
			"id": entry[0], "dialogueId": entry[0], "lines": [entry[1]], "speakerName": entry[2], "speakerRole": entry[3]}}


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
