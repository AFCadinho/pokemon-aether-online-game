extends SceneTree

const PROJECT_CONFIG := "res://project.godot"
const DIALOGUE_METADATA_SERVICE_SCRIPT := "res://scripts/services/dialogue_metadata_service.gd"
const NPC_DIALOGUE_SERVICE_SCRIPT := "res://scripts/services/npc_dialogue_service.gd"
const DIALOGUE_NPC_SCRIPT := "res://scripts/world/npcs/dialogue_npc.gd"
const TRAINER_NPC_SCRIPT := "res://scripts/world/npcs/trainer_npc.gd"

var failed := false


func _init() -> void:
	_check_service_is_autoloaded()
	_check_service_api()
	_check_service_normalization()
	_check_service_safe_missing_id()
	_check_service_locale_contract()
	_check_dialogue_npc_uses_dialogue_id_lookup()
	_check_dialogue_npc_fallback_behavior()
	_check_trainer_npc_uses_intro_dialogue_lookup()
	_check_trainer_npc_fallback_behavior()
	_check_trainer_battle_behavior_unchanged()

	quit(1 if failed else 0)


func _check_service_is_autoloaded() -> void:
	var text := _read_text(PROJECT_CONFIG)
	_check_true(
		text.contains("DialogueMetadataService=\"*res://scripts/services/dialogue_metadata_service.gd\""),
		"DialogueMetadataService is autoloaded"
	)
	_check_true(
		text.contains("NpcDialogueService=\"*res://scripts/services/npc_dialogue_service.gd\""),
		"NpcDialogueService is autoloaded"
	)


func _check_service_api() -> void:
	var text := _read_text(DIALOGUE_METADATA_SERVICE_SCRIPT)
	_check_true(text.contains("class_name DialogueMetadataServiceNode"), "DialogueMetadataService class exists")
	_check_true(text.contains("func get_dialogue(dialogue_id: String) -> Dictionary:"), "get_dialogue API exists")
	_check_true(text.contains("func get_lines(dialogue_id: String) -> Array[String]:"), "get_lines API exists")
	_check_true(text.contains("func has_dialogue(dialogue_id: String) -> bool:"), "has_dialogue API exists")
	var resolver_text := _read_text(NPC_DIALOGUE_SERVICE_SCRIPT)
	_check_true(
		resolver_text.contains("func resolve_default_dialogue(")
		and resolver_text.contains("func select_dialogue_reference(")
		and resolver_text.contains("func resolve_lines("),
		"NpcDialogueService exposes selection and resolution APIs"
	)


func _check_service_normalization() -> void:
	var text := _read_text(DIALOGUE_METADATA_SERVICE_SCRIPT)
	_check_true(text.contains("dialogue_metadata.get(\"dialogueId\", dialogue_metadata.get(\"dialogue_id\""), "dialogueId/dialogue_id normalization exists")
	_check_true(text.contains("\"dialogueLines\""), "dialogueLines normalization exists")
	_check_true(text.contains("\"dialogue_lines\""), "dialogue_lines normalization exists")
	_check_true(text.contains("\"speakerName\""), "speakerName normalization exists")


func _check_service_safe_missing_id() -> void:
	var text := _read_text(DIALOGUE_METADATA_SERVICE_SCRIPT)
	_check_true(text.contains("if normalized_dialogue_id.is_empty():"), "missing dialogue_id is handled")
	_check_true(text.contains("\"success\": false"), "missing/unknown dialogue returns failure payload")
	_check_true(text.contains("return []"), "get_lines fails safely to empty lines")


func _check_service_locale_contract() -> void:
	var text := _read_text(DIALOGUE_METADATA_SERVICE_SCRIPT)
	_check_true(text.contains("var cache_key := _get_cache_key(locale, normalized_dialogue_id)"), "dialogue cache is isolated by locale")
	_check_true(text.contains("GatewayApiConfig.get_accept_headers(locale)"), "dialogue request sends its resolved locale")
	_check_true(text.contains("func _get_http_locale() -> String:"), "dialogue service resolves the current HTTP locale")


func _check_dialogue_npc_uses_dialogue_id_lookup() -> void:
	var text := _read_text(DIALOGUE_NPC_SCRIPT)
	_check_true(text.contains("func _get_dialogue_metadata_lines() -> Array[String]:"), "DialogueNPC has dialogue metadata resolver")
	_check_true(text.contains("NpcDialogueService.resolve_default_dialogue("), "DialogueNPC uses the central NPC resolver")
	_check_true(text.contains("metadata_dialogue_id"), "DialogueNPC prefers NPC metadata dialogue")
	_check_true(
		text.contains('result.get("speakerName", "")')
		and text.contains("resolved_dialogue_speaker_name"),
		"DialogueNPC uses the localized dialogue speaker name"
	)
	_check_true(
		text.contains('metadata.get("offeredQuestId", "")')
		and text.contains('call_group("ui_overlay", "open_quest_offer"'),
		"DialogueNPC opens a catalog-configured available side-quest offer"
	)


func _check_dialogue_npc_fallback_behavior() -> void:
	var text := _read_text(DIALOGUE_NPC_SCRIPT)
	_check_true(text.contains("await super.show_dialogue(lines, resolved_speaker_name)"), "DialogueNPC keeps explicit lines fallback")
	_check_true(text.contains("await super.show_dialogue(dialogue_metadata_lines, resolved_speaker_name)"), "DialogueNPC passes resolved lines to BaseNPC")
	_check_true(text.contains("resolved_dialogue_speaker_name"), "DialogueNPC keeps the resolved speaker fallback")


func _check_trainer_npc_uses_intro_dialogue_lookup() -> void:
	var text := _read_text(TRAINER_NPC_SCRIPT)
	_check_true(text.contains("func _resolve_intro_dialogue_lines(trainer_metadata: Dictionary) -> Array[String]:"), "TrainerNPC resolves intro dialogue")
	_check_true(text.contains("var configured_dialogue_id := _get_dialogue_override_id()"), "TrainerNPC prefers an explicit scene override")
	_check_true(text.contains("func _get_intro_dialogue_id_from_trainer_metadata(trainer_metadata: Dictionary) -> String:"), "TrainerNPC supports trainer metadata dialogue id")
	_check_true(text.contains("NpcDialogueService.resolve_lines("), "TrainerNPC uses NpcDialogueService for intro dialogue")


func _check_trainer_npc_fallback_behavior() -> void:
	var text := _read_text(TRAINER_NPC_SCRIPT)
	_check_true(text.contains("return _get_dialogue_lines_from_trainer_metadata(trainer_metadata)"), "TrainerNPC falls back to dialogue_before_battle")
	_check_true(text.contains("dialogue_before_battle"), "TrainerNPC still supports dialogue_before_battle")
	_check_true(text.contains("\"battleIntroDialogueId\""), "TrainerNPC supports battleIntroDialogueId")
	_check_true(text.contains("\"battle_intro_dialogue_id\""), "TrainerNPC supports battle_intro_dialogue_id")
	_check_true(text.contains("\"introDialogueId\""), "TrainerNPC supports introDialogueId")
	_check_true(text.contains("\"intro_dialogue_id\""), "TrainerNPC supports intro_dialogue_id")
	_check_true(text.contains("\"dialogueId\""), "TrainerNPC supports dialogueId")
	_check_true(text.contains("\"dialogue_id\""), "TrainerNPC supports dialogue_id")


func _check_trainer_battle_behavior_unchanged() -> void:
	var text := _read_text(TRAINER_NPC_SCRIPT)
	_check_true(text.contains("TrainerMetadataService.get_trainer_metadata(trainer_id)"), "TrainerNPC still uses trainer metadata by trainer_id")
	_check_true(text.contains("await start_trainer_battle(trainer_metadata)"), "TrainerNPC still starts battle after intro dialogue")
	_check_true(text.contains("func start_trainer_battle(trainer_metadata: Dictionary) -> Dictionary:"), "TrainerNPC returns structured battle start errors")


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
