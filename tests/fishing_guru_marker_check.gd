extends SceneTree

const DIALOGUE_NPC_SCENE_PATH := "res://scenes/npcs/dialogue_npc.tscn"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var story_service := get_root().get_node("StoryService")
	story_service.reset_story()
	var dialogue_npc_scene := load(DIALOGUE_NPC_SCENE_PATH) as PackedScene
	_expect(dialogue_npc_scene != null, "Dialogue NPC scene loads for the Fishing Guru marker contract")
	if dialogue_npc_scene == null:
		quit(1)
		return
	var guru := dialogue_npc_scene.instantiate()
	get_root().add_child(guru)
	await process_frame
	guru.call("_apply_npc_metadata", {
		"questMarkers": [{
			"questId": "learn_to_fish",
			"statuses": ["available"],
			"visibilityQuestId": "oaks_parcel",
			"visibilityQuestStepId": "return_to_oak",
			"visibilityQuestStatus": "completed",
		}],
	})

	story_service.apply_story(_story_with_parcel_status("active"))
	await process_frame
	guru.call("_refresh_quest_marker")
	var marker := guru.get("quest_marker") as PanelContainer
	_expect(marker != null and not marker.visible, "Fishing marker stays hidden before Oak's Parcel is complete")

	story_service.apply_story(_story_with_parcel_status("completed"))
	await process_frame
	guru.call("_refresh_quest_marker")
	var marker_label := guru.get("quest_marker_label") as Label
	_expect(marker != null and marker.visible, "Fishing marker appears after Oak's Parcel is complete")
	_expect(marker_label != null and marker_label.text == "✦", "Fishing offer uses the side-quest marker")

	guru.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _story_with_parcel_status(parcel_status: String) -> Dictionary:
	return {
		"revision": 1 if parcel_status == "active" else 2,
		"quests": [{
			"questId": "oaks_parcel",
			"storylineId": "kanto_main",
			"definitionVersion": 1,
			"questType": "main",
			"status": parcel_status,
			"steps": [{
				"stepId": "return_to_oak",
				"status": parcel_status,
			}],
		}, {
			"questId": "learn_to_fish",
			"storylineId": "kanto_main",
			"definitionVersion": 2,
			"questType": "side",
			"status": "available",
			"steps": [{
				"stepId": "receive_old_rod",
				"status": "inactive",
			}],
		}],
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
