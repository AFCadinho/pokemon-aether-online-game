extends SceneTree

const ITEM_GIFT_NPC_SCENE_PATH := "res://scenes/npcs/item_gift_npc.tscn"
const FISHING_GURU_SCRIPT_PATH := "res://scripts/world/kanto/towns/pallet_town/fishing_guru.gd"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var story_service := get_root().get_node("StoryService")
	story_service.reset_story()
	var item_gift_npc_scene := load(ITEM_GIFT_NPC_SCENE_PATH) as PackedScene
	_expect(item_gift_npc_scene != null, "ItemGiftNPC scene loads for the Fishing Guru marker contract")
	if item_gift_npc_scene == null:
		quit(1)
		return
	var guru := item_gift_npc_scene.instantiate()
	guru.set_script(load(FISHING_GURU_SCRIPT_PATH))
	guru.set("npc_id", "")
	get_root().add_child(guru)
	await process_frame
	# Existing accounts can already own an Old Rod. That must not suppress the
	# offer marker before the lesson quest has been accepted. The Guru keeps an
	# explicit marker fallback so cached or delayed NPC metadata cannot hide it.
	guru.set("reward_resolved", true)

	story_service.apply_story(_story_with_parcel_status("active"))
	await process_frame
	guru.call("_refresh_quest_marker")
	var marker := guru.get_node_or_null("QuestMarker") as PanelContainer
	_expect(marker == null or not marker.visible, "Fishing marker stays hidden before Oak's Parcel is complete")

	story_service.apply_story(_story_with_parcel_status("completed"))
	await process_frame
	guru.call("_refresh_quest_marker")
	marker = guru.get_node_or_null("QuestMarker") as PanelContainer
	var marker_label := marker.get_node_or_null("Icon") as Label if marker != null else null
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
