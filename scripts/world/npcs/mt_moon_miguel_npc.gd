@tool
extends TrainerNPC

class_name MtMoonMiguelNPC

const QUEST_ID := "travel_through_mt_moon"
const BATTLE_STEP_ID := "defeat_miguel"
const BLOCKED_DIALOGUE_ID := "kanto_mt_moon_miguel_blocked"
const BLOCKING_TILE_OFFSETS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i.RIGHT,
	Vector2i.RIGHT * 2,
]

@export var cleared_position_marker: NodePath
@export var blocked_side_recovery_marker: NodePath

var _blocking_position := Vector2.ZERO
var _gate_feedback_in_flight := false


func _ready() -> void:
	_blocking_position = position
	super._ready()
	if Engine.is_editor_hint():
		return
	if not StoryService.story_changed.is_connected(_on_story_changed):
		StoryService.story_changed.connect(_on_story_changed)
	_apply_story_position()


func _exit_tree() -> void:
	if StoryService.story_changed.is_connected(_on_story_changed):
		StoryService.story_changed.disconnect(_on_story_changed)


func _can_auto_challenge() -> bool:
	return _story_allows_battle() and super._can_auto_challenge()


func interact_with_player(player: Node2D) -> void:
	if trainer_progress_state == STATE_FIRST_ENCOUNTER and not _story_allows_battle():
		await _show_blocked_dialogue()
		return
	await super.interact_with_player(player)


func is_gate_open() -> bool:
	return (
		_story_allows_battle()
		or StoryService.is_requirement_met(QUEST_ID, BATTLE_STEP_ID, "completed")
	)


func on_route_gate_blocked(player: Node2D) -> void:
	if _gate_feedback_in_flight or is_gate_open() or not is_instance_valid(player):
		return

	_gate_feedback_in_flight = true
	GameState.lock_overworld_input()
	_face_body(player)
	if player.has_method("face_world_position"):
		player.call("face_world_position", get_feet_position())
	await get_tree().process_frame
	await _show_blocked_dialogue()
	if is_instance_valid(player):
		await _send_player_back(player)
	_set_idle_frame(Vector2.RIGHT)
	GameState.unlock_overworld_input()
	_gate_feedback_in_flight = false


func blocks_world_position(world_position: Vector2) -> bool:
	if StoryService.is_requirement_met(QUEST_ID, BATTLE_STEP_ID, "completed"):
		return super.blocks_world_position(world_position)
	var blocking_tile := _to_tile(feet_marker.global_position)
	var checked_tile := _to_tile(world_position)
	for offset: Vector2i in BLOCKING_TILE_OFFSETS:
		if checked_tile == blocking_tile + offset:
			return true
	return false


func _story_allows_battle() -> bool:
	return StoryService.is_requirement_met(QUEST_ID, BATTLE_STEP_ID, "active")


func _show_blocked_dialogue() -> void:
	var result: Dictionary = await NpcDialogueService.resolve_dialogue(
		BLOCKED_DIALOGUE_ID,
		["Leave me alone!"],
		"MtMoonMiguelNPC"
	)
	var lines: Array[String] = _string_array(result.get("lines", []))
	var speaker_name := str(result.get("speakerName", display_name)).strip_edges()
	await show_dialogue(lines, speaker_name)


func _send_player_back(player: Node2D) -> void:
	if player.has_method("story_move_path"):
		var retreat_path: Array[String] = ["down"]
		var moved: Variant = await player.call("story_move_path", retreat_path)
		if bool(moved):
			return

	var marker := get_node_or_null(blocked_side_recovery_marker) as Marker2D
	if marker == null:
		return
	if player.has_method("teleport_within_current_map"):
		player.call("teleport_within_current_map", marker.global_position, Vector2.DOWN)
	else:
		player.global_position = marker.global_position


func _on_story_changed(_revision: int) -> void:
	_apply_story_position()


func _apply_story_position() -> void:
	if StoryService.is_requirement_met(QUEST_ID, BATTLE_STEP_ID, "completed"):
		var marker := get_node_or_null(cleared_position_marker) as Marker2D
		if marker != null:
			global_position = marker.global_position
	else:
		position = _blocking_position
		_recover_players_to_blocked_side.call_deferred()


func _recover_players_to_blocked_side() -> void:
	if StoryService.is_requirement_met(QUEST_ID, BATTLE_STEP_ID, "completed"):
		return
	var marker := get_node_or_null(blocked_side_recovery_marker) as Marker2D
	if marker == null:
		return
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		var player := candidate as Node2D
		if player == null or not player.has_method("teleport_within_current_map"):
			continue
		var player_feet: Vector2 = player.global_position
		if player.has_method("get_target_feet_position"):
			player_feet = player.call("get_target_feet_position") as Vector2
		if player_feet.y <= global_position.y:
			player.call("teleport_within_current_map", marker.global_position, Vector2.UP)
