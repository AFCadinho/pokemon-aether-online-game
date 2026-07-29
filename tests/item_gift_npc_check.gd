extends SceneTree

const ITEM_GIFT_SCRIPT := "res://scripts/world/npcs/item_gift_npc.gd"
const ITEM_GIFT_SCENE := "res://scenes/npcs/item_gift_npc.tscn"
const PALLET_TOWN_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn"
const INVENTORY_SERVICE := "res://scripts/services/inventory_service.gd"

var failed := false


func _init() -> void:
	var script_source := FileAccess.get_file_as_string(ITEM_GIFT_SCRIPT)
	var scene_source := FileAccess.get_file_as_string(ITEM_GIFT_SCENE)
	var pallet_source := FileAccess.get_file_as_string(PALLET_TOWN_SCENE)
	var inventory_source := FileAccess.get_file_as_string(INVENTORY_SERVICE)

	_check_true(script_source.contains("extends DialogueNPC"), "item gift NPC extends DialogueNPC")
	_check_true(script_source.contains("claim_npc_item_reward"), "item gift NPC claims a server reward")
	_check_true(script_source.contains("already_received_dialogue_id"), "item gift NPC supports repeat dialogue")
	_check_true(scene_source.contains("res://scripts/world/npcs/item_gift_npc.gd"), "item gift scene uses its script")
	_check_true(inventory_source.contains('NPC_ITEM_REWARD_ENDPOINT := "/game/npc-rewards/%s/claim"'), "inventory service uses NPC reward endpoint")
	_check_true(pallet_source.contains('npc_id = "kanto_pallet_town_fishing_guru"'), "Pallet Town places the Fishing Guru")
	_check_true(pallet_source.contains('reward_id = "kanto_pallet_town_old_rod"'), "Fishing Guru grants the Old Rod reward")

	quit(1 if failed else 0)


func _check_true(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
