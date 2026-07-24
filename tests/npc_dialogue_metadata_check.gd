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
	_check_base_npc_movement_behavior()
	_check_existing_npc_behavior_entrypoints()

	quit(1 if failed else 0)


func _check_base_npc_exports_dialogue_id() -> void:
	var text := _read_text(BASE_NPC_SCRIPT)
	_check_true(text.contains("@export var dialogue_id := \"\""), "BaseNPC exports dialogue_id")


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
		text.contains("dialogue_id = \"kanto_route_1_alder_intro\""),
		"placed NPC can define dialogue_id in scene"
	)


func _check_metadata_populates_dialogue_id() -> void:
	var text := _read_text(BASE_NPC_SCRIPT)
	_check_true(
		text.contains("var metadata_dialogue_id := str(metadata.get(\"dialogueId\", metadata.get(\"dialogue_id\", \"\"))).strip_edges()"),
		"BaseNPC reads dialogueId/dialogue_id from metadata"
	)
	_check_true(
		text.contains("dialogue_id = metadata_dialogue_id"),
		"metadata dialogueId populates BaseNPC.dialogue_id"
	)


func _check_metadata_preserves_scene_dialogue_id_without_override() -> void:
	var text := _read_text(BASE_NPC_SCRIPT)
	_check_true(
		text.contains("if not metadata_dialogue_id.is_empty():\n\t\tdialogue_id = metadata_dialogue_id"),
		"scene dialogue_id is preserved when metadata has no dialogueId"
	)


func _check_scene_display_name_overrides_metadata_name() -> void:
	var text := _read_text(BASE_NPC_SCRIPT)
	_check_true(
		text.contains("if display_name.strip_edges().is_empty() and not metadata_name.is_empty():"),
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
		and text.contains("npc_metadata[\"marketId\"]"),
		"NPC metadata normalizes market attendant fields"
	)


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


func _check_existing_npc_behavior_entrypoints() -> void:
	var dialogue_text := _read_text(DIALOGUE_NPC_SCRIPT)
	_check_true(dialogue_text.contains("extends BaseNPC"), "DialogueNPC still extends BaseNPC")
	_check_true(dialogue_text.contains("_ready_base_npc()"), "DialogueNPC still initializes BaseNPC")

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
	_check_true(gate_text.contains("func _resolve_dialogue_lines(dialogue_reference_id: String, fallback_lines: Array[String]) -> Array[String]:"), "GateNPC resolves dialogue IDs with inline fallback")

	var heal_text := _read_text(HEAL_NPC_SCRIPT)
	_check_true(heal_text.contains("extends DialogueNPC"), "HealNPC still extends DialogueNPC")
	_check_true(heal_text.contains("func interact_with_player"), "HealNPC interaction entrypoint remains")
	_check_true(heal_text.contains("func _load_npc_metadata_if_needed()"), "HealNPC metadata loading remains")
	_check_true(heal_text.contains("func _resolve_dialogue_lines(dialogue_reference_id: String, fallback_lines: Array[String]) -> Array[String]:"), "HealNPC resolves dialogue IDs with inline fallback")
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
