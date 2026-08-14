extends SceneTree

const ITEM_GIFT_NPC_SCENE_PATH := "res://scenes/npcs/item_gift_npc.tscn"
const FISHING_GURU_SCRIPT_PATH := "res://scripts/world/kanto/towns/pallet_town/fishing_guru.gd"
const DIALOGUE_BOX_SCENE_PATH := "res://scripts/ui/dialogue_box.tscn"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var test_scene := Node2D.new()
	test_scene.name = "FishingGuruOfferTest"
	root.add_child(test_scene)
	current_scene = test_scene

	var dialogue_layer := (load(DIALOGUE_BOX_SCENE_PATH) as PackedScene).instantiate()
	test_scene.add_child(dialogue_layer)
	var dialogue_box := dialogue_layer.get_node("Box")

	var guru := (load(ITEM_GIFT_NPC_SCENE_PATH) as PackedScene).instantiate()
	guru.set_script(load(FISHING_GURU_SCRIPT_PATH))
	guru.set("npc_id", "")
	var introduction_lines: Array[String] = ["Let me teach you how to fish."]
	guru.set("dialogue_lines", introduction_lines)
	test_scene.add_child(guru)
	await process_frame
	guru.call("_apply_npc_metadata", {
		"offeredQuestId": "learn_to_fish",
		"offeredQuestRequiredQuestId": "oaks_parcel",
		"offeredQuestRequiredQuestStepId": "return_to_oak",
		"offeredQuestRequiredQuestStatus": "completed",
		"requiredQuestId": "learn_to_fish",
		"requiredQuestStepId": "receive_old_rod",
		"requiredQuestStatus": "active",
	})
	root.get_node("StoryService").call("apply_story", _available_fishing_story())

	guru.call("interact_with_player", null)
	await process_frame
	_expect(dialogue_box.get("quest_offer_open") == true, "Fishing Guru opens the Fishing side-quest choice directly")
	_expect(
		str((dialogue_box.get("offered_quest") as Dictionary).get("questId", "")) == "learn_to_fish",
		"Fishing Guru offers learn_to_fish"
	)

	dialogue_box.call("_finish_quest_offer", false)
	root.get_node("StoryService").call("apply_story", _available_fishing_story(false))
	guru.call("interact_with_player", null)
	await process_frame
	_expect(dialogue_box.get("is_open") == true, "Fishing Guru still talks before Oak's Parcel is complete")
	_expect(dialogue_box.get("quest_offer_open") == false, "Fishing quest choice stays locked before Oak's Parcel")
	dialogue_box.call("hide_dialogue")
	await process_frame
	test_scene.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _available_fishing_story(parcel_completed := true) -> Dictionary:
	var parcel_status := "completed" if parcel_completed else "active"
	return {
		"revision": 7,
		"quests": [{
			"questId": "oaks_parcel",
			"storylineId": "kanto_main",
			"definitionVersion": 1,
			"questType": "main",
			"status": parcel_status,
			"steps": [{"stepId": "return_to_oak", "status": parcel_status}],
		}, {
			"questId": "learn_to_fish",
			"storylineId": "kanto_main",
			"definitionVersion": 3,
			"questType": "side",
			"status": "available",
			"titleKey": "story.kanto.learn_to_fish.title",
			"summaryKey": "story.kanto.learn_to_fish.summary",
			"rewardPreviews": [],
			"steps": [{
				"stepId": "receive_old_rod",
				"status": "inactive",
				"objectiveKey": "story.kanto.learn_to_fish.receive_old_rod",
			}],
		}],
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
