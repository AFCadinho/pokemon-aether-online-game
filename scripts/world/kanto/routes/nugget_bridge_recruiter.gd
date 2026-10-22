@tool
extends NuggetBridgeTrainer

class_name NuggetBridgeRecruiter

const REWARD_ID := "kanto_route_24_nugget_bridge_big_nugget"
const COMPLETED_DIALOGUE_ID := "kanto_route_24_rocket_recruiter_completed"
const PRIZE_DIALOGUE_ID := "kanto_route_24_rocket_recruiter_prize"
const PITCH_DIALOGUE_ID := "kanto_route_24_rocket_recruiter_pitch"
const REFUSAL_DIALOGUE_ID := "kanto_route_24_rocket_recruiter_refusal"
const CHALLENGE_DIALOGUE_ID := "kanto_route_24_rocket_recruiter_intro"

@export var rocket_sprite_frames: SpriteFrames

var revealed := false
var recruiter_progress_verified := false
var recruiter_progress_response: Dictionary = {}


func supports_trainer_rematches() -> bool:
	return false


func _refresh_rematch_marker() -> void:
	super._refresh_rematch_marker()
	if rematch_marker != null:
		rematch_marker.visible = false


func _request_recruiter_progress() -> Dictionary:
	return await TrainerProgressService.get_progress(trainer_id)


func _claim_bridge_reward() -> Dictionary:
	return await InventoryService.claim_npc_item_reward(REWARD_ID)


func _load_trainer_progress() -> void:
	if trainer_progress_request_active:
		while trainer_progress_request_active:
			await get_tree().process_frame
		return
	trainer_progress_request_active = true
	recruiter_progress_response = await _request_recruiter_progress()
	trainer_progress_request_active = false
	recruiter_progress_verified = bool(recruiter_progress_response.get("success", false))
	if recruiter_progress_verified:
		_apply_trainer_progress(recruiter_progress_response.get("progress", {}) as Dictionary, STATE_FIRST_ENCOUNTER)
	else:
		# Unknown progress must not replay this one-time prize and Rocket reveal.
		# Keep manual interaction available so the player can retry the lookup.
		auto_trigger_failed = true
		trainer_progress_loaded = true
	_refresh_rematch_marker()
	_configure_vision_area()


func _apply_trainer_progress(progress: Dictionary, fallback_state: String) -> void:
	super._apply_trainer_progress(progress, fallback_state)
	recruiter_progress_verified = true
	if trainer_progress_state != STATE_FIRST_ENCOUNTER:
		_reveal_team_rocket()


func _show_post_battle_dialogue() -> void:
	_reveal_team_rocket()
	await _show_catalogue_dialogue(
		COMPLETED_DIALOGUE_ID,
		["You beat me. You earned that Big Nugget fair and square.", "A shame you won't work for Team Rocket. You could have gone far with us."],
		"Team Rocket Recruiter"
	)


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
	await _load_trainer_progress()
	if not recruiter_progress_verified:
		_release_failed_battle_start()
		await GameErrorDialogService.show_response(recruiter_progress_response)
		_recover_overworld_after_failed_battle_start()
		return
	if trainer_progress_state != STATE_FIRST_ENCOUNTER:
		_release_failed_battle_start()
		await _show_post_battle_dialogue()
		_recover_overworld_after_failed_battle_start()
		return
	var reward_result: Dictionary = await _claim_bridge_reward()
	if not bool(reward_result.get("success", false)):
		await _show_reward_failure(reward_result)
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
		await _show_catalogue_dialogue(REFUSAL_DIALOGUE_ID, ["No?"], "You")
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
		_release_failed_battle_start()
		await GameErrorDialogService.show_response(metadata_response)
		_recover_overworld_after_failed_battle_start()
		return
	var trainer_metadata := metadata_response.get("metadata", {}) as Dictionary
	trainer_metadata["_is_rematch"] = false
	var battle_result: Dictionary = await start_trainer_battle(trainer_metadata)
	if not bool(battle_result.get("success", false)):
		_release_failed_battle_start()
		await GameErrorDialogService.show_response(battle_result, "backend.error.trainer_battle_start")
		_recover_overworld_after_failed_battle_start()


func _show_reward_failure(reward_result: Dictionary) -> void:
	_release_failed_battle_start()
	await GameErrorDialogService.show_response(reward_result, "backend.error.reward_claim")
	_recover_overworld_after_failed_battle_start()


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
