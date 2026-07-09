extends DialogueNPC

class_name GateNPC

const STAFF_ROLE_CATEGORY := "staff"
const LEGACY_STAFF_ROLE_IDS := ["staff", "owner", "senior_staff", "developer", "moderator", "gamemaster"]

@export var gate_id := "route_1"
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


func _ready() -> void:
	_ready_base_npc()
	Callable(self, "_load_gate_metadata").call_deferred()


func is_gate_open() -> bool:
	if requires_party_pokemon and PlayerSave.party.is_empty():
		return false

	if requires_staff_role and not _current_player_has_staff_role():
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

	var lines: Array[String] = await _get_blocked_dialogue_lines()
	if is_gate_open():
		lines = await _resolve_dialogue_lines(allowed_dialogue_id, allowed_dialogue_lines)

	await show_dialogue(lines)


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

	if requires_staff_role and not _current_player_has_staff_role():
		return await _resolve_dialogue_lines(staff_blocked_dialogue_id, staff_blocked_dialogue_lines)

	return await _resolve_dialogue_lines(blocked_dialogue_id, blocked_dialogue_lines)


func _get_metadata_dialogue_id(metadata: Dictionary, camel_key: String, snake_key: String, current_value: String) -> String:
	var metadata_dialogue_id := str(metadata.get(camel_key, metadata.get(snake_key, ""))).strip_edges()
	if metadata_dialogue_id.is_empty():
		return current_value
	return metadata_dialogue_id


func _resolve_dialogue_lines(dialogue_reference_id: String, fallback_lines: Array[String]) -> Array[String]:
	var resolved_dialogue_id := dialogue_reference_id.strip_edges()
	if resolved_dialogue_id.is_empty():
		return fallback_lines

	var lines: Array[String] = await DialogueMetadataService.get_lines(resolved_dialogue_id)
	if lines.is_empty():
		push_warning("GateNPC: Dialogue metadata was empty for %s; falling back to inline dialogue." % resolved_dialogue_id)
		return fallback_lines

	return lines


func _current_player_has_staff_role() -> bool:
	var roles_value: Variant = AuthService.current_user.get("roles", [])
	if not roles_value is Array:
		return false

	var roles: Array = roles_value as Array
	for role_value: Variant in roles:
		var role_id := ""
		var role_category := ""
		if role_value is Dictionary:
			var role := role_value as Dictionary
			role_id = str(role.get("id", "")).strip_edges().to_lower()
			role_category = str(role.get("category", "")).strip_edges().to_lower()
		else:
			role_id = str(role_value).strip_edges().to_lower()

		if role_category == STAFF_ROLE_CATEGORY or LEGACY_STAFF_ROLE_IDS.has(role_id):
			return true

	return false
