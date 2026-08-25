@tool
extends DialogueNPC

class_name GateNPC

const LEGACY_IN_PROGRESS_ACCESS_PERMISSION := "world:areas:access-in-progress"
const GUARD_ROLE_ATTENDANT := "attendant"
const GUARD_ROLE_TRANSITION := "transition_guard"

@export var gate_id := "route_1"
@export_enum("attendant", "transition_guard") var guard_role := GUARD_ROLE_ATTENDANT
@export var guarded_transition_id := ""
## Optional guard-owned passage zone, centered at this offset from the NPC.
## A zero size keeps the guarded MapExit as the fallback zone.
@export var guard_blocking_offset := Vector2.ZERO
@export var guard_blocking_size := Vector2.ZERO
@export var requires_party_pokemon := true
@export var requires_staff_role := false
@export var blocked_dialogue_lines: Array[String] = [
	"It's dangerous to go that way without a Pokemon.",
]
@export var story_blocked_dialogue_lines: Array[String] = [
	"Professor Oak is waiting for you at his lab.",
]
@export var staff_blocked_dialogue_lines: Array[String] = [
	"This area is not available during the alpha.",
]
@export var allowed_dialogue_lines: Array[String] = []
@export var blocked_dialogue_id := ""
@export var story_blocked_dialogue_id := ""
@export var staff_blocked_dialogue_id := ""
@export var allowed_dialogue_id := ""

var transition_access: Dictionary = {}
var guarded_exit: Node
var transition_access_resolved := false
var guard_present := true


func _ready() -> void:
	_ready_base_npc()
	if Engine.is_editor_hint():
		return
	if not guarded_transition_id.strip_edges().is_empty():
		add_to_group("world_transition_denial_presenters")
		if guard_role == GUARD_ROLE_TRANSITION:
			_set_guard_present(true)
			_connect_guard_presence_signals()
		Callable(self, "_refresh_transition_access").call_deferred()
	Callable(self, "_load_gate_metadata").call_deferred()


func is_gate_open() -> bool:
	if not is_story_requirement_met():
		return false

	if requires_party_pokemon and PlayerSave.party.is_empty():
		return false

	if not guarded_transition_id.strip_edges().is_empty():
		if not transition_access_resolved or transition_access.is_empty():
			return false
		return bool(transition_access.get("allowed", false))

	if requires_staff_role and not _current_player_has_legacy_gate_permission():
		return false

	return true


func blocks_world_position(world_position: Vector2) -> bool:
	if guard_role == GUARD_ROLE_TRANSITION and not guard_present:
		return false
	return super.blocks_world_position(world_position)


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
		and _are_local_gate_requirements_met()
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


func guards_world_position(world_position: Vector2) -> bool:
	if guard_role != GUARD_ROLE_TRANSITION or is_gate_open():
		return false
	if guard_blocking_size.x > 0.0 and guard_blocking_size.y > 0.0:
		var blocking_center := global_position + guard_blocking_offset
		return Rect2(
			blocking_center - guard_blocking_size * 0.5,
			guard_blocking_size
		).has_point(world_position)
	var exit := _resolve_guarded_exit()
	return (
		exit != null
		and exit.has_method("contains_world_position")
		and bool(exit.call("contains_world_position", world_position))
	)


func present_world_transition_denied(access: Dictionary, player: Node2D) -> void:
	transition_access = access.duplicate(true)
	transition_access_resolved = true
	_sync_guard_presence()
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

	var metadata_story_blocked_dialogue: Array[String] = _get_string_array(
		metadata.get("storyBlockedDialogue", story_blocked_dialogue_lines)
	)
	if not metadata_story_blocked_dialogue.is_empty():
		story_blocked_dialogue_lines = metadata_story_blocked_dialogue
	story_blocked_dialogue_id = _get_metadata_dialogue_id(
		metadata,
		"storyBlockedDialogueId",
		"story_blocked_dialogue_id",
		story_blocked_dialogue_id
	)

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
	_sync_guard_presence()
	return response


func _get_blocked_dialogue_lines() -> Array[String]:
	if not is_story_requirement_met():
		return await _resolve_dialogue_lines(
			story_blocked_dialogue_id,
			story_blocked_dialogue_lines
		)

	if requires_party_pokemon and PlayerSave.party.is_empty():
		return await _resolve_dialogue_lines(blocked_dialogue_id, blocked_dialogue_lines)

	if requires_staff_role and not _current_player_has_legacy_gate_permission():
		return await _resolve_dialogue_lines(staff_blocked_dialogue_id, staff_blocked_dialogue_lines)

	return await _resolve_dialogue_lines(blocked_dialogue_id, blocked_dialogue_lines)


func _are_local_gate_requirements_met() -> bool:
	return (
		is_story_requirement_met()
		and not (requires_party_pokemon and PlayerSave.party.is_empty())
	)


func _get_metadata_dialogue_id(metadata: Dictionary, camel_key: String, snake_key: String, current_value: String) -> String:
	var metadata_dialogue_id := str(metadata.get(camel_key, metadata.get(snake_key, ""))).strip_edges()
	if metadata_dialogue_id.is_empty():
		return current_value
	return metadata_dialogue_id


func _resolve_dialogue_lines(dialogue_reference_id: String, fallback_lines: Array) -> Array[String]:
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
		transition_access_resolved = not transition_access.is_empty()
	else:
		transition_access_resolved = false
	_sync_guard_presence()
	return response


func _connect_guard_presence_signals() -> void:
	var party_changed_callable := Callable(self, "_on_guard_party_changed")
	if not PlayerSave.party_changed.is_connected(party_changed_callable):
		PlayerSave.party_changed.connect(party_changed_callable)
	var story_changed_callable := Callable(self, "_on_guard_story_changed")
	if not StoryService.story_changed.is_connected(story_changed_callable):
		StoryService.story_changed.connect(story_changed_callable)


func _on_guard_party_changed() -> void:
	_sync_guard_presence()


func _on_guard_story_changed(_revision: int) -> void:
	_sync_guard_presence()
	if not guarded_transition_id.strip_edges().is_empty():
		Callable(self, "_refresh_transition_access").call_deferred(true)


func _sync_guard_presence() -> void:
	if guard_role != GUARD_ROLE_TRANSITION:
		return
	var should_be_present := (
		not transition_access_resolved
		or not _are_local_gate_requirements_met()
		or not bool(transition_access.get("allowed", false))
	)
	_set_guard_present(should_be_present)


func _set_guard_present(present: bool) -> void:
	guard_present = present
	var effective_presence := present and story_visibility_active
	visible = effective_presence
	if interaction_area != null:
		interaction_area.monitoring = effective_presence
		interaction_area.monitorable = effective_presence
	if not effective_presence:
		player_nearby = false
		nearby_player = null


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


func _resolve_guarded_exit() -> Node:
	if guarded_exit != null and is_instance_valid(guarded_exit):
		return guarded_exit
	var transition_id := guarded_transition_id.strip_edges()
	if transition_id.is_empty():
		return null
	var map_node: Node = self
	while map_node != null:
		var exits := map_node.get_node_or_null("Exits")
		if exits != null:
			for candidate: Node in exits.get_children():
				if (
					candidate.has_method("handles_transition")
					and bool(candidate.call("handles_transition", transition_id))
				):
					guarded_exit = candidate
					return guarded_exit
		map_node = map_node.get_parent()
	return null
