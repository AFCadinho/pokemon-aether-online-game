extends SceneTree

const ITEM_FOUND_SOUND := "res://assets/audio/sfx/overworld/item_found.ogg"
const ITEM_RECEIVED_SOUND := "res://assets/audio/sfx/overworld/item_received.ogg"
const NPC_SHOP_PURCHASE_SOUND := "res://assets/audio/sfx/overworld/npc_shop_purchase.ogg"
const SFX_MANAGER := "res://scripts/services/sfx_manager.gd"
const INVENTORY_SERVICE := "res://scripts/services/inventory_service.gd"
const ITEM_GIFT_NPC := "res://scripts/world/npcs/item_gift_npc.gd"
const MARKET_ATTENDANT_NPC := "res://scripts/world/npcs/market_attendant_npc.gd"
const ROOK_NPC := "res://scripts/world/kanto/towns/thieving_mentor_rook.gd"
const KENJI_NPC := "res://scripts/world/kanto/towns/pewter_city/karate_master_kenji.gd"
const FISHING_GURU_NPC := "res://scripts/world/kanto/towns/pallet_town/fishing_guru.gd"
const MATEO_NPC := "res://scripts/world/kanto/towns/ev_training_expert_mateo.gd"
const GIDEON_NPC := "res://scripts/world/kanto/towns/catching_mentor_gideon.gd"
const DADINHO_NPC := "res://scripts/world/kanto/routes/dadinho_training_npc.gd"
const NUGGET_BRIDGE_NPC := "res://scripts/world/kanto/routes/nugget_bridge_recruiter.gd"
const BILLS_MACHINE_NPC := "res://scripts/world/kanto/routes/bills_house_machine.gd"
const ROUTE_25_DATE_NPC := "res://scripts/world/kanto/routes/route_25_misty_date_npc.gd"
const DAILY_SMASHABLE_ROCK := "res://scripts/world/interactables/daily_smashable_rock.gd"
const UI_OVERLAY := "res://scripts/ui/ui_overlay.gd"
const OAK_SCRIPT := "res://scripts/world/kanto/towns/pallet_town/oak.gd"
const WORLD_SCRIPT := "res://scripts/world/world.gd"

var failed := false


func _init() -> void:
	var found_stream := load(ITEM_FOUND_SOUND) as AudioStream
	var received_stream := load(ITEM_RECEIVED_SOUND) as AudioStream
	var npc_shop_purchase_stream := load(NPC_SHOP_PURCHASE_SOUND) as AudioStream
	var sfx_source := FileAccess.get_file_as_string(SFX_MANAGER)
	var inventory_source := FileAccess.get_file_as_string(INVENTORY_SERVICE)
	var item_gift_source := FileAccess.get_file_as_string(ITEM_GIFT_NPC)
	var market_attendant_source := FileAccess.get_file_as_string(MARKET_ATTENDANT_NPC)
	var rook_source := FileAccess.get_file_as_string(ROOK_NPC)
	var kenji_source := FileAccess.get_file_as_string(KENJI_NPC)
	var fishing_guru_source := FileAccess.get_file_as_string(FISHING_GURU_NPC)
	var mateo_source := FileAccess.get_file_as_string(MATEO_NPC)
	var gideon_source := FileAccess.get_file_as_string(GIDEON_NPC)
	var dadinho_source := FileAccess.get_file_as_string(DADINHO_NPC)
	var nugget_bridge_source := FileAccess.get_file_as_string(NUGGET_BRIDGE_NPC)
	var bills_machine_source := FileAccess.get_file_as_string(BILLS_MACHINE_NPC)
	var route_25_date_source := FileAccess.get_file_as_string(ROUTE_25_DATE_NPC)
	var daily_smashable_rock_source := FileAccess.get_file_as_string(DAILY_SMASHABLE_ROCK)
	var overlay_source := FileAccess.get_file_as_string(UI_OVERLAY)
	var oak_source := FileAccess.get_file_as_string(OAK_SCRIPT)
	var world_source := FileAccess.get_file_as_string(WORLD_SCRIPT)

	_check(found_stream != null, "trimmed item-found OGG loads as an audio stream")
	_check(received_stream != null, "trimmed item-received OGG loads as an audio stream")
	_check(npc_shop_purchase_stream != null, "converted NPC shop purchase OGG loads as an audio stream")
	_check(
		sfx_source.contains('"item_found"')
		and sfx_source.contains('"path": "%s"' % ITEM_FOUND_SOUND),
		"SfxManager registers the item-found jingle"
	)
	_check(
		sfx_source.contains('"item_received"')
		and sfx_source.contains('"path": "%s"' % ITEM_RECEIVED_SOUND),
		"SfxManager registers the item-received jingle"
	)
	_check(
		sfx_source.contains('"npc_shop_purchase"')
		and sfx_source.contains('"path": "%s"' % NPC_SHOP_PURCHASE_SOUND),
		"SfxManager registers the NPC shop purchase sound"
	)
	_check(
		not inventory_source.contains('SfxManager.play("item_received")'),
		"the inventory service leaves reward-jingle timing to the dialogue owner"
	)
	_check_received_sound_after(item_gift_source, "success_dialogue_id", "generic item gifts")
	_check_received_sound_after(market_attendant_source, "quest_reward_received_dialogue_id", "Market quest rewards")
	_check_received_item_popup_after(market_attendant_source, "quest_reward_received_dialogue_id", "Market quest rewards")
	_check_received_item_popup_after(rook_source, "quest_reward_received_dialogue_id", "Rook's quest reward")
	_check_received_item_popup_after(kenji_source, "quest_reward_received_dialogue_id", "Rock Smash quest reward")
	_check_received_item_popup_after(fishing_guru_source, "quest_reward_received_dialogue_id", "Fishing quest reward")
	_check_received_sound_after(mateo_source, "quest_reward_received_dialogue_id", "Mateo's quest reward")
	_check_received_item_popup_after(mateo_source, "quest_reward_received_dialogue_id", "Mateo's quest reward")
	_check_received_sound_after(gideon_source, "quest_reward_received_dialogue_id", "Gideon's quest reward")
	_check_received_item_popup_after(gideon_source, "quest_reward_received_dialogue_id", "Gideon's quest reward")
	_check_received_sound_after(dadinho_source, "quest_reward_received_dialogue_id", "Dadinho's quest reward")
	_check_received_item_popup_after(dadinho_source, "quest_reward_received_dialogue_id", "Dadinho's quest reward")
	_check_received_item_popup_after(nugget_bridge_source, "PRIZE_DIALOGUE_ID", "Nugget Bridge reward")
	_check_received_item_popup_after(bills_machine_source, "_present_ticket_reward", "Bill's reward")
	var milk_message_index := route_25_date_source.find('LocalizationManager.text("ui.world.reward.story_item"')
	var milk_sound_index := route_25_date_source.find('SfxManager.play("item_received")', milk_message_index)
	_check(
		milk_message_index >= 0 and milk_sound_index > milk_message_index,
		"Moomoo Milk shows its System message before the received-item jingle"
	)
	_check_received_sound_after(oak_source, "quest_turn_in_completed_dialogue_id", "Oak's Pokedex reward")
	var trainer_outro_index := world_source.find("await _show_trainer_outro_dialogue")
	var trainer_popup_index := world_source.find("_notify_story_reward_items(", trainer_outro_index)
	var trainer_sound_index := world_source.find('SfxManager.play("item_received")', trainer_popup_index)
	_check(
		trainer_outro_index >= 0
		and trainer_popup_index > trainer_outro_index
		and trainer_sound_index > trainer_popup_index,
		"trainer item reward popup and sound follow the outro dialogue together"
	)
	var rock_popup_index := daily_smashable_rock_source.find('"add_item_reward_notification"')
	var rock_sound_index := daily_smashable_rock_source.find('SfxManager.play("item_received")')
	_check(
		rock_popup_index >= 0
		and rock_sound_index > rock_popup_index,
		"Rock Smash rewards show an item popup before the received-item sound"
	)
	_check(
		daily_smashable_rock_source.contains('"add_money_reward_notification", money_awarded')
		and daily_smashable_rock_source.contains('var item_reward_awarded := false')
		and daily_smashable_rock_source.contains('if item_reward_awarded:'),
		"Rock Smash money rewards show a popup while money-only rewards stay silent"
	)
	_check(
		world_source.contains('InventoryService.apply_inventory_state(reward_result.get("inventory", {}))'),
		"trainer battle item rewards immediately refresh the local Bag"
	)
	var bundle_message_index := overlay_source.find('LocalizationManager.text("ui.bag.message.box_opened"')
	var found_sound_index := overlay_source.find('SfxManager.play("item_found")', bundle_message_index)
	_check(
		bundle_message_index >= 0 and found_sound_index > bundle_message_index,
		"item bundles show their result before playing the item-found jingle"
	)
	_check(
		overlay_source.contains("if granted_count > 0:")
		and overlay_source.contains('SfxManager.play("item_found")'),
		"discovering items in a bundle plays the item-found jingle"
	)
	var market_purchase_index := overlay_source.find("func _on_market_buy_pressed")
	var market_purchase_success_index := overlay_source.find(
		'if not bool(result.get("success", false)):',
		market_purchase_index
	)
	var market_purchase_sound_index := overlay_source.find(
		'SfxManager.play("npc_shop_purchase")',
		market_purchase_success_index
	)
	_check(
		market_purchase_index >= 0
		and market_purchase_success_index > market_purchase_index
		and market_purchase_sound_index > market_purchase_success_index,
		"successful NPC item purchases play the dedicated shop sound"
	)
	_check(
		world_source.contains("func _notify_wild_item_drop_awards")
		and world_source.contains('LocalizationManager.text("ui.world.reward.wild_item_drop"')
		and world_source.contains('"add_item_reward_notification", item_id, quantity'),
		"wild Mega Stone drops show a localized item notification"
	)
	_check(
		world_source.contains("func _notify_wild_currency_drop_awards")
		and world_source.contains('LocalizationManager.text("ui.world.reward.wild_aetherite_drop"')
		and world_source.contains('"add_currency_reward_notification", currency_id, amount'),
		"wild Aetherite drops show a localized currency notification"
	)
	_check(
		world_source.contains('var item_reward_awarded := false')
		and world_source.contains('item_reward_awarded = _notify_story_reward_items(')
		and not world_source.contains('"playItemReceivedSfx"'),
		"trainer reward sound is limited to item rewards"
	)

	quit(1 if failed else 0)


func _check_received_sound_after(source: String, dialogue_marker: String, label: String) -> void:
	var sound_index := source.find('SfxManager.play("item_received")')
	var dialogue_index := source.rfind(dialogue_marker, sound_index)
	var dialogue_call_index := source.rfind("await show_dialogue", dialogue_index)
	_check(
		dialogue_call_index >= 0 and dialogue_index > dialogue_call_index and sound_index > dialogue_index,
		"%s plays the received-item jingle after its reward dialogue" % label
	)


func _check_received_item_popup_after(source: String, dialogue_marker: String, label: String) -> void:
	var popup_index := source.find("InventoryService.notify_claimed_item_reward")
	var dialogue_index := source.rfind("await show_dialogue", popup_index)
	if dialogue_index < 0:
		dialogue_index = source.rfind("await _show_catalogue_dialogue", popup_index)
	if dialogue_marker.begins_with("_"):
		dialogue_index = popup_index - 1
	_check(
		popup_index >= 0 and dialogue_index >= 0 and popup_index > dialogue_index,
		"%s shows an item reward popup after its reward dialogue" % label
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
