extends SceneTree

const TRAINER_NPC_SCRIPT := "res://scripts/world/npcs/trainer_npc.gd"
const TRAINER_METADATA_SERVICE_SCRIPT := "res://scripts/services/trainer_metadata_service.gd"
const TRAINER_PROGRESS_SERVICE_SCRIPT := "res://scripts/services/trainer_progress_service.gd"
const BATTLE_API_CLIENT_SCRIPT := "res://scripts/battle/battle_api/battle_api_client.gd"

var failed := false


func _init() -> void:
	_check_trainer_metadata_normalizes_dialogue_ids()
	_check_post_battle_dialogue_contract()
	_check_fallback_order()
	_check_missing_dialogue_id_falls_back_safely()
	_check_existing_dialogue_before_battle_still_works()
	_check_battle_start_behavior_is_unchanged()
	_check_rematch_state_contract()

	quit(1 if failed else 0)


func _check_trainer_metadata_normalizes_dialogue_ids() -> void:
	var text := _read_text(TRAINER_METADATA_SERVICE_SCRIPT)
	_check_true(text.contains("trainer_metadata[\"dialogueId\"]"), "TrainerMetadataService normalizes dialogueId")
	_check_true(text.contains("trainer_metadata[\"introDialogueId\"]"), "TrainerMetadataService normalizes introDialogueId")
	_check_true(text.contains("trainer_metadata[\"battleIntroDialogueId\"]"), "TrainerMetadataService normalizes battleIntroDialogueId")
	_check_true(text.contains("trainer_metadata.get(\"dialogue_id\""), "TrainerMetadataService accepts dialogue_id")
	_check_true(text.contains("trainer_metadata.get(\"intro_dialogue_id\""), "TrainerMetadataService accepts intro_dialogue_id")
	_check_true(text.contains("trainer_metadata.get(\"battle_intro_dialogue_id\""), "TrainerMetadataService accepts battle_intro_dialogue_id")
	_check_true(text.contains('trainer_metadata["battle_banter"]'), "TrainerMetadataService preserves structured battle banter")
	_check_true(text.contains('trainer_metadata["battle_voice"]'), "TrainerMetadataService preserves structured battle voice profiles")


func _check_post_battle_dialogue_contract() -> void:
	var metadata_text := _read_text(TRAINER_METADATA_SERVICE_SCRIPT)
	var world_text := _read_text("res://scripts/world/world.gd")
	_check_true(metadata_text.contains('trainer_metadata["outroDialogueId"]'), "TrainerMetadataService normalizes outroDialogueId")
	_check_true(metadata_text.contains('trainer_metadata["rematchDialogueId"]'), "TrainerMetadataService normalizes rematchDialogueId")
	_check_true(world_text.contains("await _show_trainer_outro_dialogue"), "trainer wins present configured outro dialogue")
	_check_true(world_text.contains("keep_locked_for_outro"), "overworld remains locked until trainer outro dialogue finishes")
	var trainer_text := _read_text(TRAINER_NPC_SCRIPT)
	_check_true(trainer_text.contains("NpcDialogueService.resolve_dialogue("), "trainer dialogue resolves localized lines and speaker names")
	_check_true(trainer_text.contains('metadata.get("outroDialogueId"'), "repeat interactions resolve the localized defeated dialogue")
	_check_true(trainer_text.contains("resolved_battle_dialogue_speaker_name"), "trainer intro uses the localized speaker name")


func _check_fallback_order() -> void:
	var text := _read_text(TRAINER_NPC_SCRIPT)
	var configured_index := text.find("var configured_dialogue_id := _get_dialogue_override_id()")
	var metadata_index := text.find("var metadata_dialogue_id := _get_intro_dialogue_id_from_trainer_metadata(trainer_metadata)")
	var fallback_index := text.find("return _get_dialogue_lines_from_trainer_metadata(trainer_metadata)")
	_check_true(configured_index != -1, "TrainerNPC reads the explicit dialogue override")
	_check_true(metadata_index > configured_index, "TrainerNPC checks trainer metadata dialogue id after the scene override")
	_check_true(fallback_index > metadata_index, "TrainerNPC falls back to dialogue_before_battle last")


func _check_missing_dialogue_id_falls_back_safely() -> void:
	var text := _read_text(TRAINER_NPC_SCRIPT)
	_check_true(text.contains("if not configured_lines.is_empty():"), "TrainerNPC only uses configured dialogue lookup when lines exist")
	_check_true(text.contains("if not metadata_lines.is_empty():"), "TrainerNPC only uses metadata dialogue lookup when lines exist")
	_check_true(
		text.contains("NpcDialogueService.resolve_dialogue("),
		"TrainerNPC delegates empty dialogue lookup handling to the central resolver"
	)


func _check_existing_dialogue_before_battle_still_works() -> void:
	var text := _read_text(TRAINER_NPC_SCRIPT)
	_check_true(text.contains("func _get_dialogue_lines_from_trainer_metadata(trainer_metadata: Dictionary) -> Array[String]:"), "TrainerNPC keeps dialogue_before_battle helper")
	_check_true(text.contains("trainer_metadata.get(\"dialogue_before_battle\", [])"), "TrainerNPC still reads dialogue_before_battle")


func _check_battle_start_behavior_is_unchanged() -> void:
	var text := _read_text(TRAINER_NPC_SCRIPT)
	_check_true(text.contains("dialogue_box.start_dialogue(dialogue_lines, speaker_name, mugshot)"), "TrainerNPC still starts intro dialogue in dialogue box")
	_check_true(text.contains("await dialogue_box.dialogue_finished"), "TrainerNPC still waits for intro dialogue")
	_check_true(text.contains("await start_trainer_battle(battle_metadata)"), "TrainerNPC still starts battle after dialogue")


func _check_rematch_state_contract() -> void:
	var trainer_text := _read_text(TRAINER_NPC_SCRIPT)
	var gym_text := _read_text("res://scripts/world/npcs/gym_leader_npc.gd")
	var world_text := _read_text("res://scripts/world/world.gd")
	var progress_service_text := _read_text(TRAINER_PROGRESS_SERVICE_SCRIPT)
	var battle_api_text := _read_text(BATTLE_API_CLIENT_SCRIPT)
	_check_true(trainer_text.contains('const STATE_READY := "ready"'), "TrainerNPC has an explicit rematch-ready state")
	_check_true(trainer_text.contains('const STATE_SLEEPING := "sleeping"'), "TrainerNPC has an explicit daily sleeping state")
	_check_true(not trainer_text.contains("TrainerProgressService.begin_rematch(trainer_id)"), "rematches do not reserve a cooldown before battle")
	_check_true(trainer_text.contains('rematch_marker_sleep_label.text = "Zzz"'), "spent rematches display a sleeping marker")
	_check_true(trainer_text.contains('add_theme_font_size_override("font_size", 22)'), "sleeping marker remains readable at overworld scale")
	_check_true(trainer_text.contains('_sleeping_marker_style()'), "sleeping marker has a dedicated high-contrast badge")
	_check_true(trainer_text.contains('res://assets/ui/icons/trainer_challenge.png'), "ready rematches display the battle-challenge emblem")
	_check_true(trainer_text.contains("_update_rematch_marker_animation()"), "the ready challenge emblem has active movement")
	_check_true(gym_text.contains("func supports_trainer_rematches() -> bool:\n\treturn false"), "Gym Leaders explicitly opt out of rematches")
	_check_true(trainer_text.contains('battle_metadata["_is_rematch"]'), "trainer battle metadata distinguishes rematches")
	_check_true(world_text.contains("and not trainer_is_rematch"), "rematches do not replay unique outro dialogue")
	_check_true(progress_service_text.contains('TRAINER_REMATCH_ENDPOINT := "/game/trainers/%s/rematch"'), "rematches use the account-service rematch route")
	_check_true(battle_api_text.contains('"isRematch": is_rematch'), "trainer battle requests identify rematches for server scaling")
	_check_true(world_text.contains("active_trainer_is_rematch\n\t)"), "world forwards rematch identity to the battle API")


func _read_text(path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _check_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return

	failed = true
	push_error("FAIL %s" % message)
