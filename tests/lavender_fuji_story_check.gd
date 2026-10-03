extends SceneTree

class FakeHost extends Node:
	var calls := 0
	func show_dialogue(_lines: Array[String], _speaker: String) -> bool:
		calls += 1
		return true

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
