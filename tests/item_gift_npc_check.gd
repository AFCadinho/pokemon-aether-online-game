extends SceneTree

const ITEM_GIFT_SCRIPT := "res://scripts/world/npcs/item_gift_npc.gd"
const ITEM_GIFT_SCENE := "res://scenes/npcs/item_gift_npc.tscn"
const PALLET_TOWN_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn"
const RIVALS_HOUSE_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/rivals_house.tscn"
const INVENTORY_SERVICE := "res://scripts/services/inventory_service.gd"
const FISHING_GURU_SCRIPT := "res://scripts/world/kanto/towns/pallet_town/fishing_guru.gd"

var failed := false


func _init() -> void:
	var script_source := FileAccess.get_file_as_string(ITEM_GIFT_SCRIPT)
	var scene_source := FileAccess.get_file_as_string(ITEM_GIFT_SCENE)
	var pallet_source := FileAccess.get_file_as_string(PALLET_TOWN_SCENE)
	var rivals_house_source := FileAccess.get_file_as_string(RIVALS_HOUSE_SCENE)
	var inventory_source := FileAccess.get_file_as_string(INVENTORY_SERVICE)
	var fishing_guru_source := FileAccess.get_file_as_string(FISHING_GURU_SCRIPT)

	_check_true(script_source.contains("extends DialogueNPC"), "item gift NPC extends DialogueNPC")
	_check_true(script_source.contains("claim_npc_item_reward"), "item gift NPC claims a server reward")
	_check_true(script_source.contains("already_received_dialogue_id"), "item gift NPC supports repeat dialogue")
	_check_true(scene_source.contains("res://scripts/world/npcs/item_gift_npc.gd"), "item gift scene uses its script")
	_check_true(inventory_source.contains('NPC_ITEM_REWARD_ENDPOINT := "/game/npc-rewards/%s/claim"'), "inventory service uses NPC reward endpoint")
	_check_true(pallet_source.contains('npc_id = "kanto_pallet_town_fishing_guru"'), "Pallet Town places the Fishing Guru")
	_check_true(pallet_source.contains('reward_id = "kanto_pallet_town_old_rod"'), "Fishing Guru grants the Old Rod reward")
	_check_true(pallet_source.contains('res://scripts/world/kanto/towns/pallet_town/fishing_guru.gd'), "Fishing Guru uses the lesson flow")
	_check_true(pallet_source.contains('interaction_id = "pallet_town_fishing_guru_lesson_complete"'), "Fishing Guru completes the return step through a story hook")
	_check_true(fishing_guru_source.contains('const QUEST_ID := "learn_to_fish"'), "Fishing Guru owns the fishing lesson quest flow")
	_check_true(fishing_guru_source.contains("_show_completed_help"), "Fishing Guru remains available as a permanent help NPC")
	_check_true(rivals_house_source.contains('npc_id = "kanto_rivals_house_daisy"'), "Rival's House places Daisy Oak")
	_check_true(rivals_house_source.contains('reward_id = "kanto_rivals_house_town_map"'), "Daisy grants the Town Map reward")

	quit(1 if failed else 0)


func _check_true(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
