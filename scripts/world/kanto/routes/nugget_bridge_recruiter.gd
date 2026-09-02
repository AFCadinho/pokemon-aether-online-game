@tool
extends NuggetBridgeTrainer

class_name NuggetBridgeRecruiter

const REWARD_ID := "kanto_route_24_nugget_bridge_big_nugget"
const PRIZE_DIALOGUE_ID := "kanto_route_24_rocket_recruiter_prize"
const PITCH_DIALOGUE_ID := "kanto_route_24_rocket_recruiter_pitch"
const REFUSAL_DIALOGUE_ID := "kanto_route_24_rocket_recruiter_refusal"
const CHALLENGE_DIALOGUE_ID := "kanto_route_24_rocket_recruiter_intro"

@export var rocket_sprite_frames: SpriteFrames

var revealed := false


func supports_trainer_rematches() -> bool:
	return false


func _refresh_rematch_marker() -> void:
	super._refresh_rematch_marker()
	if rematch_marker != null:
		rematch_marker.visible = false


func _load_trainer_progress() -> void:
	await super._load_trainer_progress()
	if trainer_progress_state != STATE_FIRST_ENCOUNTER:
		_reveal_team_rocket()


func interact_with_player(_player: Node2D) -> void:
	if trainer_progress_state != STATE_FIRST_ENCOUNTER:
		await _show_post_battle_dialogue()
		return
	if not _claim_battle_interaction():
		return
	triggered = true
	await _run_recruitment_sequence()


func show_intro_dialogue() -> void:
	await _run_recruitment_sequence()


func _run_recruitment_sequence() -> void:
	var reward_result: Dictionary = await InventoryService.claim_npc_item_reward(REWARD_ID)
	if not bool(reward_result.get("success", false)):
		battle_in_progress = false
		triggered = false
		_refresh_rematch_marker()
		await GameErrorDialogService.show_response(
			reward_result,
			"backend.error.reward_claim"
		)
		return

	var first_claim := bool(reward_result.get("claimed", false))
	if first_claim:
		await _show_catalogue_dialogue(
			PRIZE_DIALOGUE_ID,
			["Congratulations! You cleared the Big Nugget Challenge. Here is your prize!"],
			"Bridge Attendant"
		)
		get_tree().call_group(
			"ui_overlay",
			"add_system_message",
			LocalizationManager.text("ui.world.reward.story_item", {
				"item": ItemLocalization.display_name("big-nugget"),
				"quantity": 1,
			})
		)
		InventoryService.notify_claimed_item_reward(reward_result)
		SfxManager.play("item_received")

		await _show_catalogue_dialogue(
			PITCH_DIALOGUE_ID,
			["You have real potential. I recruit for Team Rocket. Will you join us?"],
			"Bridge Attendant"
		)
		await _show_catalogue_dialogue(REFUSAL_DIALOGUE_ID, ["No."], "You")
		_reveal_team_rocket()
	elif not revealed:
		_reveal_team_rocket()
	await _show_catalogue_dialogue(
		CHALLENGE_DIALOGUE_ID,
		["Fine! Now that I have revealed myself, I cannot let you leave!"],
		display_name
	)

	var metadata_response: Dictionary = await TrainerMetadataService.get_trainer_metadata(trainer_id)
	if not bool(metadata_response.get("success", false)):
		battle_in_progress = false
		triggered = false
		_refresh_rematch_marker()
		await GameErrorDialogService.show_response(metadata_response)
		return
	var trainer_metadata := metadata_response.get("metadata", {}) as Dictionary
	trainer_metadata["_is_rematch"] = false
	var battle_result: Dictionary = await start_trainer_battle(trainer_metadata)
	if not bool(battle_result.get("success", false)):
		battle_in_progress = false
		triggered = false
		_refresh_rematch_marker()


func _reveal_team_rocket() -> void:
	if revealed:
		return
	revealed = true
	display_name = "Team Rocket Recruiter"
	npc_definition_id = "trainer_class_rocket_grunt"
	portrait_id = ""
	if rocket_sprite_frames != null:
		npc_sprite_frames = rocket_sprite_frames
		if sprite != null:
			sprite.sprite_frames = _get_directional_sprite_frames(rocket_sprite_frames)
			_set_idle_frame(_get_cardinal_direction(facing_direction))
	_resolve_catalog_mugshot()
	_sync_nameplate()


func _show_catalogue_dialogue(
	dialogue_id: String,
	fallback_lines: Array[String],
	fallback_speaker: String
) -> void:
	var result := await NpcDialogueService.resolve_dialogue(
		dialogue_id,
		fallback_lines,
		"NuggetBridgeRecruiter"
	)
	var lines := _string_array(result.get("lines", fallback_lines))
	var speaker_name := str(result.get("speakerName", fallback_speaker)).strip_edges()
	if speaker_name.is_empty():
		speaker_name = fallback_speaker
	await show_dialogue(lines, speaker_name)
