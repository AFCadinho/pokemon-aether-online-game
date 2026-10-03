extends SceneTree

class FakeHost extends Node:
	var calls := 0
	func show_dialogue(_lines: Array[String], _speaker: String) -> bool:
		calls += 1
		return true

class FakeAutoHook extends Node:
	var calls := 0
	var lock_observed := false
	var trigger_seen := ""
	func is_configured() -> bool:
		return true
	func try_handle_interaction(_host: Node, _player: Node2D, trigger: String) -> Dictionary:
		calls += 1
		trigger_seen = trigger
		lock_observed = get_node("/root/GameState").is_overworld_input_locked()
		return {"success": true, "status": "completed"}

class FakeBox extends Node:
	signal dialogue_finished
	var speaker := ""
	var portrait: Texture2D
	func start_dialogue(_lines: Array[String], name_value: String, image: Texture2D, _visible: bool) -> void:
		speaker = name_value
		portrait = image
		dialogue_finished.emit.call_deferred()

var failed := false
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var house := load("res://scenes/overworld/kanto/towns/lavender_town/mr_fuji_house.tscn").instantiate() as Node2D
	var helper := house.get_node("Entities/NPCs/FujiHelper")
	var cubone := house.get_node("Entities/Pokemon/Cubone")
	_check(helper.npc_definition_id == "trainer_class_lass", "Fuji’s helper uses the girl profile")
	_check(helper.npc_sprite_frames.resource_path.ends_with("lass_frames.tres"), "Helper has the matching overworld sprite")
	_check(helper.get_node("StoryHook").interaction_id == "kanto_lavender_fuji_helper_request", "Helper advances the main quest")
	_check(cubone.species_id == "cubone", "Cubone lives in Fuji’s house")
	_check(cubone.overworld_pokemon_id == "kanto_lavender_fuji_house_cubone_1", "Cubone has its own dialogue metadata")
	for actor: Node2D in [helper, cubone]:
		_check_walkable(house, actor)
		_check(actor.position.distance_to(house.get_node("Spawns/FromLavenderTown").position) > 96, "House actor leaves the entrance clear")
	var tower := load("res://scenes/overworld/kanto/towns/lavender_town/pokemon_tower.tscn").instantiate() as Node2D
	var gary := tower.get_node("Entities/NPCs/GaryOak")
	_check(gary.npc_definition_id == "trainer_class_blue", "Gary uses his own portrait profile")
	_check(gary.npc_sprite_frames.resource_path.ends_with("blue_frames.tres"), "Gary uses his own overworld sprite")
	_check(gary.visibility_required_quest_step_id == "speak_to_fuji_helper", "Gary appears after the helper conversation")
	_check(gary.visibility_hidden_quest_id == "investigate_pokemon_tower" and gary.defer_story_hide_until_reload, "Gary disappears on refresh after the battle advice")
	_check(tower.get_node("FloorVisibilityMask").floor_regions[&"floor_2"].has_point(gary.position), "Gary stands on Tower 2F")
	_check(gary.get_node("StoryHook").interaction_id == "kanto_pokemon_tower_gary_challenge", "Gary starts the Tower story battle")
	var auto := tower.get_node("StoryTriggers/GaryChallenge") as Area2D
	_check(auto.get_node(auto.story_host_path) == gary, "Automatic challenge uses Gary as its dialogue and battle host")
	_check(auto.required_quest_id == "investigate_pokemon_tower" and auto.required_step_id == "battle_gary", "Automatic challenge only watches the Gary quest step")
	_check(auto.get_node("StoryHook").interaction_id == "kanto_pokemon_tower_gary_auto_challenge", "Automatic challenge uses the server area-entry binding")
	var shape := auto.get_node("CollisionShape2D") as CollisionShape2D
	var bounds := Rect2(auto.position - shape.shape.size / 2, shape.shape.size)
	_check(auto.position.x == gary.position.x - 32, "Gary stops the player one tile past his position toward 3F")
	var arrival: Vector2 = tower.get_node("Spawns/Floor2From1").position
	_check(not bounds.grow(16).has_point(arrival), "Arriving on 2F does not challenge the player")
	_check(not bounds.has_point(tower.get_node("FloorTransitions/Floor2To1").position), "The return stair remains outside Gary's trigger")
	_check(_route_exists(tower, arrival, tower.get_node("FloorTransitions/Floor2To3").position, Rect2()), "There is a walkable route across 2F")
	_check(not _route_exists(tower, arrival, tower.get_node("FloorTransitions/Floor2To3").position, bounds), "Every route to 3F passes Gary's trigger")
	# Mount the shared battle presenter without the DialogueNPC startup requests.
	var battle_host := (load("res://scenes/npcs/dialogue_npc.tscn") as PackedScene).instantiate() as Node2D
	battle_host.set_script(load("res://scripts/world/npcs/base_npc.gd"))
	for key: String in ["npc_id", "npc_definition_id", "portrait_id", "battle_sprite_id", "npc_sprite_frames"]:
		battle_host.set(key, gary.get(key))
	root.add_child(battle_host)
	var battle_metadata: Dictionary = battle_host.call("build_battle_trainer_metadata", {"id": "kanto_pokemon_tower_gary_bulbasaur"})
	battle_host.queue_free()
	_check(battle_metadata.get("_battle_sprite_id") == "showdown_blue_lgpe", "Gary uses a trainer sprite in battle")
	var story_service := root.get_node("StoryService")
	var revision := int(story_service.get_story().get("revision", 0))
	for state: Dictionary in [
		{"status": "active", "helper": "active", "visible": false},
		{"status": "active", "helper": "completed", "visible": true},
		{"status": "completed", "helper": "completed", "visible": false},
	]:
		revision += 1
		story_service.apply_story({"revision": revision, "quests": [{
			"questId": "investigate_pokemon_tower", "status": state.status,
			"steps": [{"stepId": "speak_to_fuji_helper", "status": state.helper}],
		}]})
		_check(gary.call("_is_story_visibility_active") == state.visible,
			"Gary visibility follows Reina and battle completion: " + str(state))
	_check_walkable(tower, gary)
	for spawn: Node2D in tower.get_node("Spawns").get_children():
		_check(gary.position.distance_to(spawn.position) > 96, "Gary leaves tower spawns clear")
	# Exercise the production runner: player questions use the save name/portrait,
	# rather than borrowing the resident’s portrait through the NPC host.
	var world := Node.new()
	root.add_child(world)
	current_scene = world
	var holder := Node.new()
	holder.name = "DialogueBox"
	world.add_child(holder)
	var box := FakeBox.new()
	box.name = "Box"
	holder.add_child(box)
	var host := FakeHost.new()
	world.add_child(host)
	var runner := load("res://scripts/services/story_sequence_runner.gd").new() as Node
	world.add_child(runner)
	var save := root.get_node("PlayerSave")
	var original_name: String = save.player_name
	save.player_name = "Lavender Tester"
	var service := root.get_node("DialogueMetadataService")
	var locale: String = service.call("_get_http_locale")
	var key: String = service.call("_get_cache_key", locale, "player_question")
	service.dialogue_metadata_cache[key] = {"success": true, "metadata": {"id": "player_question", "dialogueId": "player_question", "speakerRole": "player", "lines": ["What happened?"]}}
	var response: Dictionary = await runner._run_dialogue({"dialogueId": "player_question"}, host)
	_check(response.get("success", false) and box.speaker == "Lavender Tester", "Player question uses the saved player name")
	_check(box.portrait != null and host.calls == 0, "Player question uses a player portrait")
	service.dialogue_metadata_cache.erase(key)
	save.player_name = original_name
	# Exercise the configured trigger's input stop without NPC/network requests.
	auto.get_parent().remove_child(auto)
	world.add_child(auto)
	auto.story_host_path = auto.get_path_to(host)
	auto.get_node("StoryHook").free()
	var auto_hook := FakeAutoHook.new()
	auto.add_child(auto_hook)
	var player := Node2D.new()
	player.name = "Player"
	world.add_child(player)
	story_service.apply_story({"quests": [{"questId": "investigate_pokemon_tower", "status": "active", "steps": [{"stepId": "battle_gary", "status": "active"}]}]})
	await auto._on_body_entered(player)
	_check(auto_hook.calls == 1 and auto_hook.lock_observed and auto_hook.trigger_seen == "area_enter", "Passing Gary toward 3F locks movement and starts his challenge")
	story_service.apply_story({"quests": [{"questId": "investigate_pokemon_tower", "status": "completed", "steps": [{"stepId": "battle_gary", "status": "completed"}]}]})
	await auto._on_body_entered(player)
	_check(auto_hook.calls == 1 and not root.get_node("GameState").is_overworld_input_locked(), "Returning after victory does not stop or challenge the player again")
	# Keep only Gary's base presentation, avoiding live NPC metadata requests.
	for holder_path in ["Entities/NPCs", "Entities/Pokemon"]:
		for actor in tower.get_node(holder_path).get_children():
			if actor != gary:
				actor.free()
	var visibility_config: Dictionary = {}
	for config_key in ["npc_id", "visibility_required_quest_id", "visibility_required_quest_step_id", "visibility_required_quest_status", "visibility_hidden_quest_id", "visibility_hidden_quest_step_id", "visibility_hidden_quest_status", "defer_story_hide_until_reload"]:
		visibility_config[config_key] = gary.get(config_key)
	gary.set_script(load("res://scripts/world/npcs/base_npc.gd"))
	for config_key in visibility_config:
		gary.set(config_key, visibility_config[config_key])
	gary.preload_quest_markers = false
	var mask := tower.get_node("FloorVisibilityMask")
	mask.follow_player_floor = false
	world.add_child(tower)
	story_service.apply_story({"quests": [{"questId": "investigate_pokemon_tower", "status": "active", "steps": [{"stepId": "speak_to_fuji_helper", "status": "completed"}, {"stepId": "battle_gary", "status": "active"}]}]})
	gary._ready_base_npc()
	mask.show_floor(&"floor_2")
	_check(gary.visible, "Gary is present before victory")
	mask.show_floor(&"floor_1")
	await process_frame
	_check(gary.visible, "Leaving before victory does not remove Gary")
	mask.show_floor(&"floor_2")
	story_service.apply_story({"quests": [{"questId": "investigate_pokemon_tower", "status": "completed", "steps": [{"stepId": "speak_to_fuji_helper", "status": "completed"}, {"stepId": "battle_gary", "status": "completed"}]}]})
	_check(gary.visible, "Gary stays for his advice after victory")
	mask.show_floor(&"floor_2")
	_check(gary.visible, "Reapplying the same floor does not interrupt Gary's advice")
	mask.show_floor(&"floor_3")
	await process_frame
	_check(not gary.visible and not gary.story_visibility_active and not gary.interaction_area.monitoring, "Leaving 2F after victory hides Gary and disables interaction")
	mask.show_floor(&"floor_2")
	_check(not gary.visible, "Gary remains absent when returning to 2F")
	gary.visible = true
	gary._apply_story_visibility()
	_check(not gary.visible, "A map reload also hides defeated Gary")
	house.free()
	tower.free()
	world.queue_free()
	print("lavender_fuji_story_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
func _check_walkable(map: Node, actor: Node2D) -> void:
	var collision := map.get_node("Tiles/Collision") as TileMapLayer
	_check(collision.get_cell_source_id(collision.local_to_map(actor.position)) == -1, actor.name + " stands on a walkable tile")
func _check(value: bool, label: String) -> void:
	if value:
		print("PASS ", label)
	else:
		failed = true
		push_error(label)

func _route_exists(tower: Node, start: Vector2, goal: Vector2, excluded: Rect2) -> bool:
	var collision := tower.get_node("Tiles/Collision") as TileMapLayer
	var floor_bounds: Rect2 = tower.get_node("FloorVisibilityMask").floor_regions[&"floor_2"]
	var target := Vector2i(floor(goal / 32))
	var queue: Array[Vector2i] = [Vector2i(floor(start / 32))]
	var seen: Dictionary = {}
	while not queue.is_empty():
		var tile := queue.pop_front() as Vector2i
		if seen.has(tile):
			continue
		seen[tile] = true
		var point := Vector2(tile) * 32 + Vector2(16, 16)
		if not floor_bounds.has_point(point) or collision.get_cell_source_id(tile) >= 0 or excluded.has_point(point):
			continue
		if tile == target:
			return true
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			queue.append(tile + direction)
	return false
