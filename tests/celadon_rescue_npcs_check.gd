extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/celadon_city/celadon_city.tscn"
const QUEST := "celadon_rocket_trio"
const MIRA := "kanto_celadon_city_mira"
const EEVEE := "kanto_celadon_city_mira_eevee"
var failures := 0
var story: Node
var game_state: Node


class PlayerProbe extends CharacterBody2D:
	var last_direction := Vector2.UP
	func get_feet_position() -> Vector2:
		return global_position
	func get_interaction_position() -> Vector2:
		return global_position
	func face_world_position(target: Vector2) -> void:
		last_direction = (target - global_position).normalized()


class DialogueProbe extends Node:
	signal dialogue_finished
	var is_open := false
	var lines: Array = []
	var speakers: Array[String] = []
	func start_dialogue(new_lines: Array, speaker := "", _portrait: Texture2D = null, _show_portrait := true) -> void:
		is_open = true
		lines.append(new_lines.duplicate())
		speakers.append(speaker)
		_finish.call_deferred()
	func _finish() -> void:
		await get_tree().process_frame
		is_open = false
		dialogue_finished.emit()


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	story = root.get_node("StoryService")
	game_state = root.get_node("GameState")
	_prime_metadata()
	story.apply_story(_story("spot_trio"))
	var map := (load(CITY) as PackedScene).instantiate()
	# Keep the real map and rescue actors, without unrelated residents or triggers.
	for container: String in ["Entities/NPCs", "Entities/Pokemon"]:
		for child: Node in map.get_node(container).get_children():
			if child.name not in ["Mira", "MirasEevee"]:
				child.get_parent().remove_child(child)
				child.free()
	var trio := map.get_node("Story/RocketTrio")
	for child: Node in trio.get_children():
		if child is Area2D:
			trio.remove_child(child)
			child.free()
	game_state.current_map = map
	root.add_child(map)
	current_scene = map
	var layer := Node.new()
	layer.name = "DialogueBox"
	map.add_child(layer)
	var dialogue := DialogueProbe.new()
	dialogue.name = "Box"
	layer.add_child(dialogue)
	var mira := map.get_node("Entities/NPCs/Mira") as Node2D
	var eevee := map.get_node("Entities/Pokemon/MirasEevee") as Node2D
	await process_frame
	_check(not mira.visible and not eevee.visible, "Rescue actors stay hidden before the Route 7 sighting")
	_check(not map.is_position_blocked_by_character(mira.global_position), "Hidden Mira does not block the map")
	_check(not map.is_position_blocked_by_character(eevee.global_position), "Hidden Eevee does not block the map")
	story.apply_story(_story("defeat_trio"))
	await process_frame
	_check(mira.visible and eevee.visible, "Both rescue actors appear when the trio reaches Celadon")
	_check(map.is_position_blocked_by_character(mira.global_position), "Mira participates in real map character collision")
	_check(map.is_position_blocked_by_character(eevee.global_position), "Eevee participates in real map character collision")
	_check(trio.get_node(trio.get("victim_path")) == mira, "Cutscene references the same interactable Mira")
	_check(trio.get_node(trio.get("victim_pokemon_path")) == eevee, "Cutscene animates the same interactable Eevee")
	var player := PlayerProbe.new()
	player.name = "Player"
	player.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 16)
	shape.shape = rectangle
	player.add_child(shape)
	map.get_node("Entities/Players").add_child(player)
	player.global_position = mira.global_position + Vector2(0, 32)
	game_state.unlock_input()
	await _press_interact()
	_check(dialogue.lines.size() == 1 and dialogue.lines.back() == ["Help Eevee."], "Manual interaction asks for help before the rescue")
	var prepared: Dictionary = await trio.call("prepare_story_sequence")
	_check(prepared.get("success", false), "Real rescue actors support cutscene preparation")
	_check(mira.get("facing_direction") == Vector2.LEFT and eevee.get("facing_direction") == Vector2.LEFT, "Mira and Eevee face the thieves again after speaking with the player")
	trio.call("abort_story_sequence")
	story.apply_story(_story("watch_trio_flee", true))
	await process_frame
	_check(mira.visible and eevee.visible, "Mira and Eevee remain after Team Rocket leaves")
	_check(map.is_position_blocked_by_character(mira.global_position), "Mira remains solid after the escape")
	_check(map.is_position_blocked_by_character(eevee.global_position), "Eevee remains solid after the escape")
	await _press_interact()
	_check(dialogue.lines.size() == 2 and dialogue.lines.back() == ["Thank you for saving Eevee."], "Manual interaction selects Mira's thank-you after the escape")
	player.global_position = eevee.global_position + Vector2(0, 32)
	player.last_direction = Vector2.UP
	await _press_interact()
	_check(dialogue.lines.size() == 3 and dialogue.lines.back() == ["Vee!"], "Manual interaction opens Eevee's normal Pokémon cry dialogue")
	_check(not game_state.is_overworld_input_locked(), "Manual interactions release the overworld input lock")
	game_state.current_map = null
	current_scene = null
	map.queue_free()
	await process_frame
	story.reset_story()
	print("celadon_rescue_npcs_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures else 0)


func _press_interact() -> void:
	# Actual physics proximity and input dispatch, rather than calling NPC dialogue directly.
	for _frame in range(3):
		await physics_frame
	Input.action_press("interact")
	for _frame in range(3):
		await process_frame
	Input.action_release("interact")
	for _frame in range(8):
		await process_frame


func _prime_metadata() -> void:
	var npc := root.get_node("NpcMetadataService")
	var key: String = npc.call("_get_cache_key", npc.call("_get_http_locale"), MIRA)
	npc.npc_metadata_cache[key] = {"success": true, "metadata": {
		"id": MIRA, "name": "Trainer Mira", "dialogueId": "kanto_celadon_mira_needs_help",
		"dialogueVariants": [{"requiredQuestId": QUEST, "requiredQuestStatus": "completed",
			"dialogueId": "kanto_celadon_mira_after_rescue"}]}}
	var pokemon := root.get_node("OverworldPokemonMetadataService")
	pokemon.overworld_pokemon_metadata_cache[EEVEE] = {"success": true, "metadata": {
		"id": EEVEE, "speciesId": "eevee", "name": "Eevee", "level": 20,
		"dialogueId": "kanto_celadon_city_eevee_cry"}}
	var dialogue := root.get_node("DialogueMetadataService")
	for id: String in ["kanto_celadon_mira_needs_help", "kanto_celadon_mira_after_rescue", "kanto_celadon_city_eevee_cry"]:
		var line := "Help Eevee." if id.ends_with("needs_help") else "Thank you for saving Eevee." if id.ends_with("after_rescue") else "Vee!"
		key = dialogue.call("_get_cache_key", dialogue.call("_get_http_locale"), id)
		dialogue.dialogue_metadata_cache[key] = {"success": true, "metadata": {
			"id": id, "dialogueId": id, "speakerName": "Eevee" if id.ends_with("cry") else "Trainer Mira", "lines": [line]}}


func _story(active_step: String, completed := false) -> Dictionary:
	var steps: Array = []
	var passed := true
	for id: String in ["spot_trio", "defeat_trio", "watch_trio_flee"]:
		var status := "completed" if passed else "inactive"
		if id == active_step:
			status = "active"
			passed = false
		steps.append({"stepId": id, "status": "completed" if completed else status})
	return {"revision": 20, "quests": [{"questId": QUEST, "storylineId": "kanto_main", "definitionVersion": 2,
		"status": "completed" if completed else "active", "steps": steps}]}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
