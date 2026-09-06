@tool
extends ItemGiftNPC

class_name PokemonFanClubChairman

const QUEST_ID := "pokemon_fan_club_chairman"
const LISTEN_STEP_ID := "listen_to_chairman"
const TELL_MORE_CHOICE := "tell_more"
const MENTOR_TOPIC_MENU := preload("res://scripts/ui/mentor_topic_menu.gd")

@export var intro_dialogue_id := ""
@export var not_now_dialogue_id := ""
@export var story_dialogue_id := ""

const INTRO_FALLBACK_LINES: Array[String] = [
	"My beloved Rapidash is magnificent, and that is only the beginning!",
]
const NOT_NOW_FALLBACK_LINES: Array[String] = [
	"Come back whenever you would like to hear the rest.",
]
const STORY_FALLBACK_LINES: Array[String] = [
	"Rapidash is elegant, loyal, swift, and gentle. I could talk about it all day!",
]


func interact_with_player(player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await _show_report_to_staff_message()
		return

	var quest := StoryService.get_quest(QUEST_ID)
	var quest_status := str(quest.get("status", "")).strip_edges().to_lower()
	if quest_status == "available":
		if await _show_available_quest_offer(display_name):
			await interact_with_player(player)
		return
	if StoryService.is_requirement_met(QUEST_ID, LISTEN_STEP_ID, "active"):
		await _offer_full_story()
		return
	if quest_status == "completed":
		await show_dialogue(await _resolve_dialogue_lines(
			already_received_dialogue_id,
			already_received_dialogue_lines
		))
		return
	await show_dialogue()


func _offer_full_story() -> void:
	await show_dialogue(await _resolve_dialogue_lines(
		intro_dialogue_id,
		INTRO_FALLBACK_LINES
	))
	var choice := await _choose_story_response()
	if choice != TELL_MORE_CHOICE:
		await show_dialogue(await _resolve_dialogue_lines(
			not_now_dialogue_id,
			NOT_NOW_FALLBACK_LINES
		))
		return
	await show_dialogue(await _resolve_dialogue_lines(
		story_dialogue_id,
		STORY_FALLBACK_LINES
	))
	await _claim_bike_voucher()


func _choose_story_response() -> String:
	var menu := MENTOR_TOPIC_MENU.new()
	add_child(menu)
	var choice: String = await menu.choose_topic(
		LocalizationManager.text("npc.pokemon_fan_club_chairman.choice.title"),
		LocalizationManager.text("npc.pokemon_fan_club_chairman.choice.prompt"),
		[
			{
				"id": "not_now",
				"label": LocalizationManager.text(
					"npc.pokemon_fan_club_chairman.choice.not_now"
				),
			},
			{
				"id": TELL_MORE_CHOICE,
				"label": LocalizationManager.text(
					"npc.pokemon_fan_club_chairman.choice.tell_more"
				),
			},
		],
		LocalizationManager.text("npc.pokemon_fan_club_chairman.choice.eyebrow"),
		"",
		1,
		true,
		false
	)
	menu.queue_free()
	return choice


func _claim_bike_voucher() -> void:
	if reward_id.is_empty():
		await _show_report_to_staff_message()
		return
	var result: Dictionary = await InventoryService.claim_npc_item_reward(reward_id)
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result, "backend.error.reward_claim")
		return
	if not bool(result.get("storyRefreshSuccess", false)):
		push_warning("PokemonFanClubChairman: voucher succeeded but story refresh failed locally.")
	await show_dialogue(await _resolve_dialogue_lines(
		success_dialogue_id,
		success_dialogue_lines
	))
	if bool(result.get("claimed", false)):
		InventoryService.notify_claimed_item_reward(result)
		get_tree().call_group(
			"ui_overlay",
			"add_system_message",
			LocalizationManager.text("ui.quest.completed_reward", {
				"quest": LocalizationManager.text(
					"story.kanto.pokemon_fan_club_chairman.title"
				),
				"reward": ItemLocalization.display_name("bike-voucher"),
			})
		)
		SfxManager.play("item_received")


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)
	intro_dialogue_id = _metadata_dialogue_value(
		metadata,
		"introDialogueId",
		intro_dialogue_id
	)
	not_now_dialogue_id = _metadata_dialogue_value(
		metadata,
		"notNowDialogueId",
		not_now_dialogue_id
	)
	story_dialogue_id = _metadata_dialogue_value(
		metadata,
		"storyDialogueId",
		story_dialogue_id
	)


func _metadata_dialogue_value(metadata: Dictionary, key: String, fallback: String) -> String:
	var value := str(metadata.get(key, "")).strip_edges()
	return value if not value.is_empty() else fallback
