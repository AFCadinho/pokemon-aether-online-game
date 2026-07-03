extends DialogueNPC

class_name GateNPC

const STAFF_ROLE_IDS := ["staff", "admin", "owner", "developer", "moderator", "gamemaster"]

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

	var lines: Array[String] = _get_blocked_dialogue_lines()
	if is_gate_open():
		lines = allowed_dialogue_lines

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

	var metadata_staff_blocked_dialogue: Array[String] = _get_string_array(
		metadata.get("staffBlockedDialogue", staff_blocked_dialogue_lines)
	)
	if not metadata_staff_blocked_dialogue.is_empty():
		staff_blocked_dialogue_lines = metadata_staff_blocked_dialogue

	var metadata_allowed_dialogue: Array[String] = _get_string_array(
		metadata.get("allowedDialogue", allowed_dialogue_lines)
	)
	allowed_dialogue_lines = metadata_allowed_dialogue
	return response


func _get_blocked_dialogue_lines() -> Array[String]:
	if requires_party_pokemon and PlayerSave.party.is_empty():
		return blocked_dialogue_lines

	if requires_staff_role and not _current_player_has_staff_role():
		return staff_blocked_dialogue_lines

	return blocked_dialogue_lines


func _current_player_has_staff_role() -> bool:
	if PlayerSave.is_staff:
		return true

	var roles_value: Variant = AuthService.current_user.get("roles", [])
	if not roles_value is Array:
		return false

	var roles: Array = roles_value as Array
	for role_value: Variant in roles:
		var role_id := ""
		if role_value is Dictionary:
			role_id = str((role_value as Dictionary).get("id", "")).strip_edges().to_lower()
		else:
			role_id = str(role_value).strip_edges().to_lower()

		if STAFF_ROLE_IDS.has(role_id):
			return true

	return false
