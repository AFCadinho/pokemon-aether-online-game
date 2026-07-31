extends SceneTree

const BASE_NPC_SCRIPT := "res://scripts/world/npcs/base_npc.gd"
const NPC_METADATA_SERVICE_SCRIPT := "res://scripts/services/npc_metadata_service.gd"
const DIALOGUE_NPC_SCRIPT := "res://scripts/world/npcs/dialogue_npc.gd"
const TRAINER_NPC_SCRIPT := "res://scripts/world/npcs/trainer_npc.gd"
const GATE_NPC_SCRIPT := "res://scripts/world/npcs/gate_npc.gd"
const HEAL_NPC_SCRIPT := "res://scripts/world/npcs/heal_npc.gd"
const ROUTE_1_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_1.tscn"

var failed := false


func _init() -> void:
	_check_base_npc_exports_dialogue_id()
	_check_base_npc_exports_definition_id()
	_check_scene_defined_dialogue_id_is_allowed()
	_check_metadata_populates_dialogue_id()
	_check_metadata_preserves_scene_dialogue_id_without_override()
	_check_scene_display_name_overrides_metadata_name()
	_check_npc_metadata_service_normalizes_dialogue_id()
	_check_npc_metadata_locale_contract()
	_check_base_npc_movement_behavior()
	_check_existing_npc_behavior_entrypoints()

	quit(1 if failed else 0)


func _check_base_npc_exports_dialogue_id() -> void:
	var text := _read_text(BASE_NPC_SCRIPT)
	_check_true(
		text.contains("## Exceptional scene-specific override.")
		and text.contains("@export var dialogue_id := \"\""),
		"BaseNPC documents dialogue_id as an explicit override"
	)
	_check_true(
		text.contains("@export var dialogue_id := \"\""),
		"BaseNPC preserves legacy dialogue_id serialization order"
	)


func _check_base_npc_exports_definition_id() -> void:
	var text := _read_text(BASE_NPC_SCRIPT)
	_check_true(text.contains("@export var npc_definition_id := \"\""), "BaseNPC exports npc_definition_id")
	_check_true(
		text.contains("func _get_npc_metadata_id() -> String:"),
		"BaseNPC resolves a shared NPC definition id"
	)
	_check_true(
		text.contains("return npc_id.strip_edges()"),
		"BaseNPC falls back to the placed npc_id"
	)


func _check_scene_defined_dialogue_id_is_allowed() -> void:
	var text := _read_text(ROUTE_1_SCENE)
	_check_true(
		not text.contains("dialogue_id = \"kanto_route_1_alder_intro\""),
		"Alder resolves normal dialogue from NPC metadata"
	)


func _check_metadata_populates_dialogue_id() -> void:
	var text := _read_text(BASE_NPC_SCRIPT)
	_check_true(
		text.contains("metadata_dialogue_id = str(")
		and text.contains("metadata.get(\"dialogueId\", metadata.get(\"dialogue_id\", \"\"))"),
		"BaseNPC reads dialogueId/dialogue_id from metadata"
	)
	_check_true(
		not text.contains("dialogue_id = metadata_dialogue_id"),
		"metadata dialogueId does not overwrite a scene compatibility field"
	)


func _check_metadata_preserves_scene_dialogue_id_without_override() -> void:
	var text := _read_text(BASE_NPC_SCRIPT)
	_check_true(
		text.contains("func _get_dialogue_override_id() -> String:")
		and text.contains("return dialogue_id.strip_edges()"),
		"BaseNPC exposes the intentional scene override to new runtime logic"
	)


func _check_scene_display_name_overrides_metadata_name() -> void:
	var text := _read_text(BASE_NPC_SCRIPT)
	_check_true(
		text.contains("display_name.strip_edges().is_empty() or display_name == metadata_display_name"),
		"scene display_name overrides backend metadata name"
	)


func _check_npc_metadata_service_normalizes_dialogue_id() -> void:
	var text := _read_text(NPC_METADATA_SERVICE_SCRIPT)
	_check_true(
		text.contains("npc_metadata[\"dialogueId\"] = str(npc_metadata.get(\"dialogueId\", npc_metadata.get(\"dialogue_id\", \"\")))"),
		"NPC metadata normalizes dialogueId and accepts dialogue_id fallback"
	)
	_check_true(
		text.contains("npc_metadata[\"successDialogueId\"]"),
		"NPC metadata normalizes healer dialogue IDs"
	)
	_check_true(
		text.contains("npc_metadata[\"openingDialogueId\"]")
		and text.contains("npc_metadata[\"marketId\"]")
		and text.contains("npc_metadata[\"marketMode\"]"),
		"NPC metadata normalizes market attendant fields"
	)


func _check_npc_metadata_locale_contract() -> void:
	var service_text := _read_text(NPC_METADATA_SERVICE_SCRIPT)
	_check_true(service_text.contains("var cache_key := _get_cache_key(locale, normalized_npc_id)"), "NPC metadata cache is isolated by locale")
	_check_true(service_text.contains("GatewayApiConfig.get_accept_headers(locale)"), "NPC metadata request sends its resolved locale")

	var base_npc_text := _read_text(BASE_NPC_SCRIPT)
	_check_true(base_npc_text.contains("LocalizationManager.locale_changed.connect(_on_locale_changed)"), "NPCs observe runtime locale changes")
	_check_true(base_npc_text.contains("func _on_locale_changed(_locale: String) -> void:"), "NPCs reset metadata state after a locale change")


func _check_base_npc_movement_behavior() -> void:
	var text := _read_text(BASE_NPC_SCRIPT)
	_check_true(
		text.contains("@export_enum(\"idle\", \"pace_horizontal\", \"pace_vertical\") var movement_behavior := \"idle\""),
		"BaseNPC exports NPC movement behavior"
	)
	_check_true(text.contains("@export_range(1, 12, 1) var movement_tiles := 3"), "BaseNPC exports movement tile range")
	_check_true(text.contains("func _process_npc_movement() -> void:"), "BaseNPC processes NPC movement")
	_check_true(text.contains("func _can_npc_move_to(world_position: Vector2) -> bool:"), "BaseNPC checks movement collision")
	_check_true(text.contains("MapCharacterBlocking.is_position_blocked_by_character"), "BaseNPC respects character blocking")
	_check_true(text.contains("collision_tilemap.get_cell_source_id(tile_position)"), "BaseNPC respects collision tilemap")
	_check_true(
		text.contains("_copy_missing_animations(source_sprite_frames, generated_sprite_frames)")
		and text.contains("func _copy_missing_animations(source: SpriteFrames, target: SpriteFrames) -> void:"),
		"BaseNPC preserves custom animations while generating directional frames"
	)


func _check_existing_npc_behavior_entrypoints() -> void:
	var dialogue_text := _read_text(DIALOGUE_NPC_SCRIPT)
	_check_true(dialogue_text.contains("extends BaseNPC"), "DialogueNPC still extends BaseNPC")
	_check_true(dialogue_text.contains("_ready_base_npc()"), "DialogueNPC still initializes BaseNPC")
	_check_true(
		dialogue_text.contains("NpcDialogueService.resolve_default_dialogue("),
		"DialogueNPC delegates default dialogue selection to NpcDialogueService"
	)

	var trainer_text := _read_text(TRAINER_NPC_SCRIPT)
	_check_true(trainer_text.contains("extends BaseNPC"), "TrainerNPC still extends BaseNPC")
	_check_true(trainer_text.contains("TrainerMetadataService.get_trainer_metadata(trainer_id)"), "TrainerNPC still uses trainer_id metadata")
	_check_true(trainer_text.contains("func show_intro_dialogue()"), "TrainerNPC intro dialogue entrypoint remains")
	_check_true(trainer_text.contains("func start_trainer_battle"), "TrainerNPC battle entrypoint remains")

	var gate_text := _read_text(GATE_NPC_SCRIPT)
	_check_true(gate_text.contains("extends DialogueNPC"), "GateNPC still extends DialogueNPC")
	_check_true(gate_text.contains("func show_gate_dialogue()"), "GateNPC dialogue entrypoint remains")
	_check_true(gate_text.contains("func _load_gate_metadata()"), "GateNPC metadata loading remains")
	_check_true(gate_text.contains("blockedDialogueId"), "GateNPC supports blockedDialogueId")
	_check_true(
		gate_text.contains("NpcDialogueService.resolve_lines("),
		"GateNPC uses the central dialogue resolver"
	)

	var heal_text := _read_text(HEAL_NPC_SCRIPT)
	_check_true(heal_text.contains("extends DialogueNPC"), "HealNPC still extends DialogueNPC")
	_check_true(heal_text.contains("func interact_with_player"), "HealNPC interaction entrypoint remains")
	_check_true(
		heal_text.contains("await _play_heal_animation(_get_player_party().size())")
		and heal_text.contains("@export var heal_animation_name := &\"heal_down\""),
		"HealNPC plays heal_down after a changed party heal"
	)
	_check_true(
		heal_text.contains("signal heal_sequence_started(duration_seconds: float, pokemon_count: int)")
		and heal_text.contains("heal_sequence_started.emit(duration_seconds, clampi(pokemon_count, 0, 6))"),
		"HealNPC announces party size with its visual heal sequence"
	)
	_check_true(
		heal_text.contains("func _get_animation_duration_seconds(animation_name: StringName) -> float:"),
		"HealNPC limits looping heal animations to one cycle"
	)
	_check_true(
		not heal_text.contains("await show_dialogue(await _resolve_dialogue_lines(success_dialogue_id, success_dialogue_lines))"),
		"HealNPC uses the system message without a duplicate success dialogue"
	)
	_check_true(heal_text.contains("func _load_npc_metadata_if_needed()"), "HealNPC metadata loading remains")
	_check_true(
		heal_text.contains("NpcDialogueService.resolve_lines("),
		"HealNPC uses the central dialogue resolver"
	)
	_check_true(heal_text.contains("successDialogueId"), "HealNPC supports successDialogueId")


func _read_text(path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _check_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		print("PASS %s" % message)
		return

	failed = true
	push_error("FAIL %s expected=%s actual=%s" % [message, str(expected), str(actual)])


func _check_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return

	failed = true
	push_error("FAIL %s" % message)
