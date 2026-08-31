extends SceneTree

const ITEM_FOUND_SOUND := "res://assets/audio/sfx/overworld/item_found.ogg"
const ITEM_RECEIVED_SOUND := "res://assets/audio/sfx/overworld/item_received.ogg"
const SFX_MANAGER := "res://scripts/services/sfx_manager.gd"
const INVENTORY_SERVICE := "res://scripts/services/inventory_service.gd"
const ITEM_GIFT_NPC := "res://scripts/world/npcs/item_gift_npc.gd"
const MARKET_ATTENDANT_NPC := "res://scripts/world/npcs/market_attendant_npc.gd"
const MATEO_NPC := "res://scripts/world/kanto/towns/ev_training_expert_mateo.gd"
const GIDEON_NPC := "res://scripts/world/kanto/towns/catching_mentor_gideon.gd"
const DADINHO_NPC := "res://scripts/world/kanto/routes/dadinho_training_npc.gd"
const ROUTE_25_DATE_NPC := "res://scripts/world/kanto/routes/route_25_misty_date_npc.gd"
const UI_OVERLAY := "res://scripts/ui/ui_overlay.gd"
const OAK_SCRIPT := "res://scripts/world/kanto/towns/pallet_town/oak.gd"
const WORLD_SCRIPT := "res://scripts/world/world.gd"

var failed := false


func _init() -> void:
	var found_stream := load(ITEM_FOUND_SOUND) as AudioStream
	var received_stream := load(ITEM_RECEIVED_SOUND) as AudioStream
	var sfx_source := FileAccess.get_file_as_string(SFX_MANAGER)
	var inventory_source := FileAccess.get_file_as_string(INVENTORY_SERVICE)
	var item_gift_source := FileAccess.get_file_as_string(ITEM_GIFT_NPC)
	var market_attendant_source := FileAccess.get_file_as_string(MARKET_ATTENDANT_NPC)
	var mateo_source := FileAccess.get_file_as_string(MATEO_NPC)
	var gideon_source := FileAccess.get_file_as_string(GIDEON_NPC)
	var dadinho_source := FileAccess.get_file_as_string(DADINHO_NPC)
	var route_25_date_source := FileAccess.get_file_as_string(ROUTE_25_DATE_NPC)
	var overlay_source := FileAccess.get_file_as_string(UI_OVERLAY)
	var oak_source := FileAccess.get_file_as_string(OAK_SCRIPT)
	var world_source := FileAccess.get_file_as_string(WORLD_SCRIPT)

	_check(found_stream != null, "trimmed item-found OGG loads as an audio stream")
	_check(received_stream != null, "trimmed item-received OGG loads as an audio stream")
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
		not inventory_source.contains('SfxManager.play("item_received")'),
		"the inventory service leaves reward-jingle timing to the dialogue owner"
	)
	_check_received_sound_after(item_gift_source, "success_dialogue_id", "generic item gifts")
	_check_received_sound_after(market_attendant_source, "quest_reward_received_dialogue_id", "Market quest rewards")
	_check_received_sound_after(mateo_source, "quest_reward_received_dialogue_id", "Mateo's quest reward")
	_check_received_sound_after(gideon_source, "quest_reward_received_dialogue_id", "Gideon's quest reward")
	_check_received_sound_after(dadinho_source, "quest_reward_received_dialogue_id", "Dadinho's quest reward")
	var milk_message_index := route_25_date_source.find('LocalizationManager.text("ui.world.reward.story_item"')
	var milk_sound_index := route_25_date_source.find('SfxManager.play("item_received")', milk_message_index)
	_check(
		milk_message_index >= 0 and milk_sound_index > milk_message_index,
		"Moomoo Milk shows its System message before the received-item jingle"
	)
	_check_received_sound_after(oak_source, "quest_turn_in_completed_dialogue_id", "Oak's Pokedex reward")
	var brock_outro_index := world_source.find("await _show_trainer_outro_dialogue")
	var brock_sound_index := world_source.find('SfxManager.play("item_received")', brock_outro_index)
	_check(
		brock_outro_index >= 0
		and brock_sound_index > brock_outro_index
		and world_source.contains('trainer_reward_result.get("playItemReceivedSfx", false)'),
		"a newly earned Gym Badge plays the received-item jingle after the Leader's reward dialogue"
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
	_check(
		world_source.contains("func _notify_wild_item_drop_awards")
		and world_source.contains('LocalizationManager.text("ui.world.reward.wild_item_drop"')
		and world_source.contains('"add_item_reward_notification", item_id, quantity'),
		"wild Mega Stone drops show a localized item notification"
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


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
