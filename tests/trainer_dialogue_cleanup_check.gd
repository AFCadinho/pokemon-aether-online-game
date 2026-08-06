extends SceneTree

const TRAINER_NPC_SCRIPT := "res://scripts/world/npcs/trainer_npc.gd"
const TRAINER_METADATA_SERVICE_SCRIPT := "res://scripts/services/trainer_metadata_service.gd"

var failed := false


func _init() -> void:
	_check_trainer_metadata_normalizes_dialogue_ids()
	_check_post_battle_dialogue_contract()
	_check_fallback_order()
	_check_missing_dialogue_id_falls_back_safely()
	_check_existing_dialogue_before_battle_still_works()
	_check_battle_start_behavior_is_unchanged()

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


func _check_post_battle_dialogue_contract() -> void:
	var metadata_text := _read_text(TRAINER_METADATA_SERVICE_SCRIPT)
	var world_text := _read_text("res://scripts/world/world.gd")
	_check_true(metadata_text.contains('trainer_metadata["outroDialogueId"]'), "TrainerMetadataService normalizes outroDialogueId")
	_check_true(world_text.contains("await _show_trainer_outro_dialogue"), "trainer wins present configured outro dialogue")
	_check_true(world_text.contains("keep_locked_for_outro"), "overworld remains locked until trainer outro dialogue finishes")


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
		text.contains("NpcDialogueService.resolve_lines("),
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
	_check_true(text.contains("await start_trainer_battle(trainer_metadata)"), "TrainerNPC still starts battle after dialogue")


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
