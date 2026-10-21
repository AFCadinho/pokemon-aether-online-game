extends SceneTree

const Gate := preload("res://scripts/world/interactables/pokemon_tower_spirit_gate.gd")
const TOWER := "res://scenes/overworld/kanto/towns/lavender_town/pokemon_tower.tscn"

class TestGate extends Gate:
	var accept := false
	var prompts := 0
	var challenges := 0
	var farewells := 0
	var refreshed_story: Dictionary = {}
	var refreshes := 0
	func _refresh_spirit_state() -> Dictionary:
		refreshes += 1
		if not refreshed_story.is_empty():
			StoryService.apply_story(refreshed_story)
		return {"success": true}
	func _ask_use_scope() -> bool:
		prompts += 1
		return accept
	func _run_spirit_hook(_phase_name: String, _hook: String, _player: Node2D) -> Dictionary:
		if _phase_name == "farewell":
			farewells += 1
			return {"success": true, "handled": true}
		challenges += 1
		return {"success": false, "handled": true, "status": "pending_battle"}

class FakeBox extends Node:
	signal dialogue_finished
	var lines_seen := 0
	var portraits: Array[Texture2D] = []
	func start_dialogue(_lines: Array[String], _speaker: String, _portrait: Texture2D = null, _show_portrait := false) -> void:
		lines_seen += 1
		portraits.append(_portrait)
		dialogue_finished.emit.call_deferred()

var failures := 0
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var state := root.get_node("GameState")
	var story := root.get_node("StoryService")
	var auth := root.get_node("AuthService")
	var inventory := root.get_node("InventoryService")
	var dialogue := root.get_node("DialogueMetadataService")
	var old_story: Dictionary = story.get_story()
	var old_user: Dictionary = auth.current_user.duplicate(true)
	var old_items: Array = inventory.cached_inventory_items.duplicate(true)
	var old_owner: int = inventory.cached_inventory_user_id
	auth.current_user = {"id": 8003}
	inventory.cached_inventory_user_id = 8003
	inventory.cached_inventory_items = [{"itemId": "silph-scope", "quantity": 1}]
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var holder := Node.new()
	holder.name = "DialogueBox"
	world.add_child(holder)
	var box := FakeBox.new()
	box.name = "Box"
	holder.add_child(box)
	var gate := TestGate.new()
	gate.position = Vector2(2224, 1360)
	world.add_child(gate)
	var player := Node2D.new()
	player.name = "Player"
	world.add_child(player)
	var locale: String = dialogue.call("_get_http_locale")
	var key: String = dialogue.call("_get_cache_key", locale, "kanto_pokemon_tower_spirit_warning")
	dialogue.dialogue_metadata_cache[key] = {"success": true, "metadata": {"id": "kanto_pokemon_tower_spirit_warning", "dialogueId": "kanto_pokemon_tower_spirit_warning", "speakerName": "???", "lines": ["Go away…"]}}
	story.apply_story({"revision": 0, "quests": [
		{"questId": "confront_team_rocket_boss", "status": "active", "steps": [
			{"stepId": "confront_boss", "status": "completed"}, {"stepId": "return_to_tower", "status": "active"}]},
		{"questId": "calm_pokemon_tower_spirit", "status": "available", "steps": [{"stepId": "battle_marowak", "status": "inactive"}]},
	]})
	_check(not gate.can_reveal_spirit(), "A stale return objective initially blocks the reveal despite the owned Scope")
	gate.refreshed_story = _battle_story()
	await gate._start_manual_interaction(player)
	_check(gate.refreshes == 1 and gate.prompts == 1 and box.lines_seen == 1, "Interaction refreshes stale progress before dialogue and offers the owned Scope immediately")
	gate.refreshed_story = {}
	gate.prompts = 0
	box.lines_seen = 0
	box.portraits.clear()
	_check(gate.can_reveal_spirit() and not gate.is_passage_open(), "Scope plus Giovanni and the active Tower objective allow revealing, never bypassing")
	await gate._start_manual_interaction(player)
	_check(gate.prompts == 1 and gate.challenges == 0 and not gate.is_passage_open(), "No leaves the stair blocked and starts no battle")
	_check(not state.is_overworld_input_locked(), "Declining restores player input")
	gate.accept = true
	await gate._start_manual_interaction(player)
	_check(gate.challenges == 1 and box.lines_seen == 2, "Yes hands off once after the original ghost warning")
	_check(state.is_overworld_input_locked(), "Battle handoff preserves the world's input lock")
	state.unlock_overworld_input()
	story.apply_story({"revision": 2, "quests": [{"questId": "calm_pokemon_tower_spirit", "status": "active", "steps": [{"stepId": "battle_marowak", "status": "completed"}, {"stepId": "farewell_marowak", "status": "active"}]}]})
	gate.player_nearby = true
	gate.nearby_player = player
	await process_frame
	await process_frame
	_check(gate.farewells == 1 and not state.is_overworld_input_locked(), "A confirmed win or reconnect resumes the farewell once input is free")
	gate.player_nearby = false
	story.apply_story(_battle_story())
	# Exercise the real presentation hooks without HTTP or a live battle.
	gate._phase = "battle"
	await gate.prepare_story_sequence()
	_check((gate._actors.Marowak as AnimatedSprite2D).visible, "Scope light reveals the existing Marowak overworld sprite")
	_check((gate._actors.Marowak as AnimatedSprite2D).sprite_frames.has_animation("idle_right"), "Marowak uses the directional follower sheet")
	gate.abort_story_sequence()
	_check(not (gate._actors.Marowak as AnimatedSprite2D).visible, "An interrupted reveal resets safely")
	gate._phase = "farewell"
	await gate.prepare_story_sequence()
	_check((gate._actors.Reina as AnimatedSprite2D).visible and (gate._actors.Cubone as AnimatedSprite2D).visible, "Reina and Cubone arrive for the farewell")
	for line: String in ["Reina arrives", "Cubone cries", "Reina promises", "Marowak finds peace", "Rescue Fuji"]:
		await gate.show_dialogue([line], "")
	_check(not (gate._actors.Marowak as AnimatedSprite2D).visible and not (gate._actors.Cubone as AnimatedSprite2D).visible and not (gate._actors.Reina as AnimatedSprite2D).visible, "Marowak fades away and Reina takes Cubone home")
	_check(box.portraits[2] != null and box.portraits[3] != null, "Reina and Cubone use their existing dialogue portraits")
	gate.abort_story_sequence()
	# Authored actors must not walk through collision on their short entrance.
	var tower := (load(TOWER) as PackedScene).instantiate()
	# Both visitors approach along the open room below the stair passage.
	var placed := tower.get_node("Entities/Interactables/RestlessSpirit")
	_check(placed.get_node("MarowakChallenge").interaction_id == "kanto_pokemon_tower_marowak_challenge", "The placed gate has the canonical battle hook")
	_check(placed.get_node("MarowakFarewell").interaction_id == "kanto_pokemon_tower_marowak_farewell", "The placed gate has the resumable farewell hook")
	tower.free()
	dialogue.dialogue_metadata_cache.erase(key)
	story.apply_story(old_story)
	auth.current_user = old_user
	inventory.cached_inventory_items = old_items
	inventory.cached_inventory_user_id = old_owner
	world.queue_free()
	await process_frame
	print("tower_marowak_story_check: ", "FAIL" if failures else "PASS")
	quit(1 if failures else 0)
func _battle_story() -> Dictionary:
	return {"revision": 1, "quests": [
		{"questId": "confront_team_rocket_boss", "status": "completed", "steps": [{"stepId": "confront_boss", "status": "completed"}]},
		{"questId": "calm_pokemon_tower_spirit", "status": "active", "steps": [{"stepId": "battle_marowak", "status": "active"}, {"stepId": "farewell_marowak", "status": "inactive"}]},
	]}
func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		push_error(label)
