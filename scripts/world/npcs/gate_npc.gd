@tool
extends DialogueNPC

class_name GateNPC

const LEGACY_IN_PROGRESS_ACCESS_PERMISSION := "world:areas:access-in-progress"

@export var gate_id := "route_1"
@export var guarded_transition_id := ""
@export var requires_party_pokemon := true
@export var requires_staff_role := false
@export var blocked_dialogue_lines: Array[String] = [
	"It's dangerous to go that way without a Pokemon.",
]
@export var staff_blocked_dialogue_lines: Array[String] = [
	"This area is not available during the alpha.",
]
@export var allowed_dialogue_lines: Array[String] = []
@export var blocked_dialogue_id := ""
@export var staff_blocked_dialogue_id := ""
@export var allowed_dialogue_id := ""

var transition_access: Dictionary = {}


func _ready() -> void:
	_ready_base_npc()
	if Engine.is_editor_hint():
		return
	if not guarded_transition_id.strip_edges().is_empty():
		add_to_group("world_transition_denial_presenters")
		Callable(self, "_refresh_transition_access").call_deferred()
	Callable(self, "_load_gate_metadata").call_deferred()


func is_gate_open() -> bool:
	if requires_party_pokemon and PlayerSave.party.is_empty():
		return false

	if not guarded_transition_id.strip_edges().is_empty():
		return bool(transition_access.get("allowed", false))

	if requires_staff_role and not _current_player_has_legacy_gate_permission():
		return false

	return true


func on_route_gate_blocked(player: Node2D) -> void:
	GameState.lock_overworld_input()
	_face_body(player)
	if player.has_method("face_world_position"):
		player.face_world_position(get_feet_position())

	await show_gate_dialogue()
	_set_idle_frame(_get_cardinal_direction(facing_direction))
	GameState.unlock_overworld_input()


func interact_with_player(_player: Node2D) -> void:
	await show_gate_dialogue()


func show_gate_dialogue() -> void:
	var metadata_response: Dictionary = await _load_gate_metadata()
	if not metadata_response.get("success", false):
		await GameErrorDialogService.show_report_to_staff_message()
		return

	if (
		not guarded_transition_id.strip_edges().is_empty()
		and not (requires_party_pokemon and PlayerSave.party.is_empty())
	):
		var access_response := await _refresh_transition_access(true)
		if not bool(access_response.get("success", false)):
			await GameErrorDialogService.show_report_to_staff_message()
			return
		if not bool(transition_access.get("allowed", false)):
			await _show_transition_denied_dialogue(transition_access)
			return

	var lines: Array[String] = await _get_blocked_dialogue_lines()
	if is_gate_open():
		lines = await _resolve_dialogue_lines(allowed_dialogue_id, allowed_dialogue_lines)

	if not lines.is_empty():
		await show_dialogue(lines)


func handles_world_transition(candidate_transition_id: String) -> bool:
	return (
		not guarded_transition_id.strip_edges().is_empty()
		and guarded_transition_id.strip_edges() == candidate_transition_id.strip_edges()
	)


func present_world_transition_denied(access: Dictionary, player: Node2D) -> void:
	transition_access = access.duplicate(true)
	GameState.lock_overworld_input()
	_face_body(player)
	if player.has_method("face_world_position"):
		player.face_world_position(get_feet_position())
	await _show_transition_denied_dialogue(transition_access)
	_set_idle_frame(_get_cardinal_direction(facing_direction))
	GameState.unlock_overworld_input()


func _load_gate_metadata() -> Dictionary:
	var response: Dictionary = await _load_npc_metadata()
	if not response.get("success", false):
		return response

	var metadata: Dictionary = response.get("metadata", {})
	if metadata.is_empty():
		return response

	requires_party_pokemon = bool(metadata.get("requiresPartyPokemon", requires_party_pokemon))
	requires_staff_role = bool(metadata.get("requiresStaffRole", requires_staff_role))

	var metadata_blocked_dialogue: Array[String] = _get_string_array(
		metadata.get("blockedDialogue", blocked_dialogue_lines)
	)
	if not metadata_blocked_dialogue.is_empty():
		blocked_dialogue_lines = metadata_blocked_dialogue
	blocked_dialogue_id = _get_metadata_dialogue_id(metadata, "blockedDialogueId", "blocked_dialogue_id", blocked_dialogue_id)

	var metadata_staff_blocked_dialogue: Array[String] = _get_string_array(
		metadata.get("staffBlockedDialogue", staff_blocked_dialogue_lines)
	)
	if not metadata_staff_blocked_dialogue.is_empty():
		staff_blocked_dialogue_lines = metadata_staff_blocked_dialogue
	staff_blocked_dialogue_id = _get_metadata_dialogue_id(metadata, "staffBlockedDialogueId", "staff_blocked_dialogue_id", staff_blocked_dialogue_id)

	var metadata_allowed_dialogue: Array[String] = _get_string_array(
		metadata.get("allowedDialogue", allowed_dialogue_lines)
	)
	allowed_dialogue_lines = metadata_allowed_dialogue
	allowed_dialogue_id = _get_metadata_dialogue_id(metadata, "allowedDialogueId", "allowed_dialogue_id", allowed_dialogue_id)
	return response


func _get_blocked_dialogue_lines() -> Array[String]:
	if requires_party_pokemon and PlayerSave.party.is_empty():
		return await _resolve_dialogue_lines(blocked_dialogue_id, blocked_dialogue_lines)

	if requires_staff_role and not _current_player_has_legacy_gate_permission():
		return await _resolve_dialogue_lines(staff_blocked_dialogue_id, staff_blocked_dialogue_lines)

	return await _resolve_dialogue_lines(blocked_dialogue_id, blocked_dialogue_lines)


func _get_metadata_dialogue_id(metadata: Dictionary, camel_key: String, snake_key: String, current_value: String) -> String:
	var metadata_dialogue_id := str(metadata.get(camel_key, metadata.get(snake_key, ""))).strip_edges()
	if metadata_dialogue_id.is_empty():
		return current_value
	return metadata_dialogue_id


func _resolve_dialogue_lines(dialogue_reference_id: String, fallback_lines: Array[String]) -> Array[String]:
	return await NpcDialogueService.resolve_lines(
		dialogue_reference_id,
		fallback_lines,
		"GateNPC"
	)


func _refresh_transition_access(force_refresh := false) -> Dictionary:
	var response: Dictionary = await WorldTransitionService.get_transition_access(
		guarded_transition_id,
		force_refresh
	)
	if bool(response.get("success", false)):
		var access_value: Variant = response.get("access", {})
		transition_access = access_value as Dictionary if access_value is Dictionary else {}
	return response


func _show_transition_denied_dialogue(access: Dictionary) -> void:
	var dialogue_reference_id := str(access.get("dialogueId", "")).strip_edges()
	var lines := await _resolve_dialogue_lines(
		dialogue_reference_id,
		staff_blocked_dialogue_lines
	)
	if not lines.is_empty():
		await show_dialogue(lines)


func _current_player_has_legacy_gate_permission() -> bool:
	var permissions_value: Variant = AuthService.current_user.get("permissions", [])
	if not permissions_value is Array:
		return false
	for permission_value: Variant in permissions_value as Array:
		if str(permission_value).strip_edges().to_lower() == LEGACY_IN_PROGRESS_ACCESS_PERMISSION:
			return true
	return false
