extends SceneTree

const ITEM_GIFT_NPC_SCENE_PATH := "res://scenes/npcs/item_gift_npc.tscn"
const CHAIRMAN_SCRIPT_PATH := (
	"res://scripts/world/kanto/towns/pokemon_fan_club_chairman.gd"
)
const DIALOGUE_BOX_SCENE_PATH := "res://scripts/ui/dialogue_box.tscn"
const BIKE_STORE_SCENE_PATH := (
	"res://scenes/overworld/kanto/towns/cerulean_city/bike_store.tscn"
)

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var test_scene := Node2D.new()
	test_scene.name = "PokemonFanClubChairmanTest"
	root.add_child(test_scene)
	current_scene = test_scene

	var dialogue_layer := (load(DIALOGUE_BOX_SCENE_PATH) as PackedScene).instantiate()
	test_scene.add_child(dialogue_layer)
	var dialogue_box := dialogue_layer.get_node("Box")

	var chairman := (load(ITEM_GIFT_NPC_SCENE_PATH) as PackedScene).instantiate()
	chairman.set_script(load(CHAIRMAN_SCRIPT_PATH))
	chairman.set("npc_id", "")
	chairman.set("display_name", "Pokemon Fan Club Chairman")
	test_scene.add_child(chairman)
	await process_frame

	chairman.call("_apply_npc_metadata", {
		"offeredQuestId": "pokemon_fan_club_chairman",
		"rewardId": "kanto_pokemon_fan_club_bike_voucher",
		"rewardItemId": "bike-voucher",
		"introDialogueId": "chairman_intro",
		"notNowDialogueId": "chairman_not_now",
		"storyDialogueId": "chairman_story",
	})
	_expect(
		str(chairman.get("reward_id")) == "kanto_pokemon_fan_club_bike_voucher",
		"Chairman loads the authoritative Bike Voucher reward"
	)
	_expect(
		str(chairman.get("story_dialogue_id")) == "chairman_story",
		"Chairman loads his interactive story dialogue"
	)
	chairman.set("intro_dialogue_id", "")
	chairman.set("not_now_dialogue_id", "")
	chairman.set("story_dialogue_id", "")

	root.get_node("StoryService").call("apply_story", _chairman_story("available"))
	chairman.call("interact_with_player", null)
	await process_frame
	_expect(
		bool(dialogue_box.get("quest_offer_open")),
		"Chairman opens the side-quest summary before any story dialogue"
	)
	_expect(
		str((dialogue_box.get("offered_quest") as Dictionary).get("questId", ""))
		== "pokemon_fan_club_chairman",
		"Chairman offers the location-independent quest id"
	)
	dialogue_box.call("_finish_quest_offer", false)
	await process_frame
	_expect(
		str(root.get_node("StoryService").call(
			"get_quest",
			"pokemon_fan_club_chairman"
		).get("status", "")) == "available",
		"Declining leaves the Chairman's quest available"
	)

	root.get_node("StoryService").call("apply_story", _chairman_story("active"))
	chairman.call("interact_with_player", null)
	await process_frame
	_expect(bool(dialogue_box.get("is_open")), "Active quest starts with the Chairman's introduction")
	dialogue_box.call("hide_dialogue")
	var choice_root: Node = null
	for _frame: int in range(30):
		choice_root = chairman.find_child("MentorTopicMenu", true, false)
		if choice_root != null:
			break
		await process_frame
	_expect(choice_root != null, "Chairman opens the follow-up dialogue choice")
	if choice_root != null:
		var buttons := choice_root.find_children("*", "Button", true, false)
		_expect(buttons.size() == 2, "Dialogue choice shows only Not now and Tell me more")
		if buttons.size() == 2:
			(buttons[0] as Button).pressed.emit()
			await process_frame
			_expect(
				bool(dialogue_box.get("is_open")),
				"Not now closes the choice without abandoning the active quest"
			)
			dialogue_box.call("hide_dialogue")

	var bike_store_source := FileAccess.get_file_as_string(BIKE_STORE_SCENE_PATH)
	_expect(
		bike_store_source.contains('npc_id = "kanto_pokemon_fan_club_chairman"'),
		"Cerulean Bike Shop temporarily places the Chairman"
	)
	_expect(
		bike_store_source.contains("preload_quest_markers = true"),
		"Chairman's side-quest marker is preloaded above him"
	)
	var bike_store := (load(BIKE_STORE_SCENE_PATH) as PackedScene).instantiate()
	test_scene.add_child(bike_store)
	await process_frame
	var placed_chairman := bike_store.get_node_or_null(
		"Entities/NPCs/PokemonFanClubChairman"
	) as Node2D
	var collision := bike_store.get_node_or_null("Tiles/Collision") as TileMapLayer
	_expect(placed_chairman != null, "Bike Shop scene contains the Chairman actor")
	if placed_chairman != null and collision != null:
		var chairman_tile := collision.local_to_map(
			collision.to_local(placed_chairman.global_position)
		)
		_expect(
			collision.get_cell_source_id(chairman_tile) == -1,
			"Chairman stands on a walkable Bike Shop tile"
		)
	bike_store.queue_free()

	test_scene.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _chairman_story(status: String) -> Dictionary:
	var step_status := "active" if status == "active" else "inactive"
	return {
		"revision": 12,
		"quests": [{
			"questId": "pokemon_fan_club_chairman",
			"storylineId": "kanto_main",
			"definitionVersion": 1,
			"questType": "side",
			"status": status,
			"titleKey": "story.kanto.pokemon_fan_club_chairman.title",
			"summaryKey": "story.kanto.pokemon_fan_club_chairman.summary",
			"rewardPreviews": [{
				"type": "item",
				"itemId": "bike-voucher",
				"quantity": 1,
			}],
			"steps": [{
				"stepId": "listen_to_chairman",
				"status": step_status,
				"objectiveKey": (
					"story.kanto.pokemon_fan_club_chairman.listen_to_chairman"
				),
			}],
		}],
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
