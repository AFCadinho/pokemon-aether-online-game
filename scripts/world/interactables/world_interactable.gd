extends Node2D

class_name WorldInteractable

const TILE_SIZE := 32
const MISSING_DIALOGUE_LINES: Array[String] = [
	"There is nothing written here.",
]

@export var interactable_id := ""
@export var interactable_kind := "generic"
@export var display_name := ""
@export var dialogue_id := ""
@export var dialogue_lines: Array[String] = []
@export var blocks_movement := true
@export var requires_facing := true
# The offset selects the top-left tile of the blocked footprint relative to
# this node. A 1x1 footprint preserves the original single-tile behaviour.
@export var blocked_tile_offset := Vector2i.ZERO
@export var blocked_tile_footprint := Vector2i.ONE
@export var interaction_shape_size := Vector2(96, 96)

var player_nearby := false
var nearby_player: Node2D
var is_interacting := false

@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")


func _ready() -> void:
	_ensure_interaction_area()


func _process(_delta: float) -> void:
	if _can_start_manual_interaction():
		await _start_manual_interaction(nearby_player)


func blocks_world_position(world_position: Vector2) -> bool:
	if not blocks_movement:
		return false

	return _is_tile_in_blocked_footprint(_to_tile(world_position))


func interact_with_player(_player: Node2D) -> void:
	await show_dialogue()


func show_dialogue(
	lines: Array[String] = [],
	speaker_name_override := "",
	mugshot_override: Texture2D = null
) -> bool:
	var dialogue_box := _get_dialogue_box()
	if dialogue_box == null:
		push_warning("%s: DialogueBox/Box not found." % name)
		return false

	var valid_dialogue_lines := _get_valid_dialogue_lines(lines)
	if valid_dialogue_lines.is_empty():
		valid_dialogue_lines = _get_valid_dialogue_lines(dialogue_lines)
	if valid_dialogue_lines.is_empty():
		valid_dialogue_lines = MISSING_DIALOGUE_LINES

	var speaker_name := speaker_name_override
	if speaker_name.is_empty():
		speaker_name = display_name
	if speaker_name.is_empty():
		speaker_name = "Sign" if interactable_kind == "road_sign" else name

	dialogue_box.start_dialogue(valid_dialogue_lines, speaker_name, mugshot_override)
	await dialogue_box.dialogue_finished
	return true


func _can_start_manual_interaction() -> bool:
	if is_interacting:
		return false
	if not player_nearby or nearby_player == null:
		return false
	if _is_overworld_input_locked():
		return false
	if _is_ui_typing():
		return false
	if not Input.is_action_just_pressed("interact"):
		return false
	if requires_facing and not _is_player_facing_interactable(nearby_player):
		return false

	var dialogue_box := _get_dialogue_box()
	if dialogue_box != null and dialogue_box.is_open:
		return false

	return true


func _start_manual_interaction(body: Node2D) -> void:
	is_interacting = true
	_lock_overworld_input()
	if body.has_method("face_world_position"):
		body.face_world_position(global_position)

	var result := await _run_story_or_legacy_interaction(body, "interact")
	if str(result.get("status", "")) != "pending_battle":
		_unlock_overworld_input()
	is_interacting = false


func _run_story_or_legacy_interaction(body: Node2D, trigger: String) -> Dictionary:
	var story_hook := _find_story_hook()
	if story_hook == null or not bool(story_hook.call("is_configured")):
		await interact_with_player(body)
		return {"success": true, "handled": false, "legacy": true}

	var result_value: Variant = await story_hook.call(
		"try_handle_interaction",
		self,
		body,
		trigger
	)
	if not (result_value is Dictionary):
		await _show_story_hook_error()
		return {"success": false, "handled": true, "status": "invalid_story_hook_result"}

	var result: Dictionary = result_value as Dictionary
	if bool(result.get("success", false)) and result.has("handled") and not bool(result.get("handled", true)):
		await interact_with_player(body)
		var fallback_result := result.duplicate(true)
		fallback_result["legacy"] = true
		return fallback_result
	return result


func _find_story_hook() -> Node:
	for child: Node in get_children():
		if child.has_method("try_handle_interaction") and child.has_method("is_configured"):
			return child
	return null


func _show_story_hook_error() -> void:
	var root := get_tree().root
	var error_service := root.get_node_or_null("GameErrorDialogService") if root != null else null
	if error_service != null and error_service.has_method("show_report_to_staff_message"):
		await error_service.call("show_report_to_staff_message")
	else:
		push_warning("WorldInteractable: story hook returned an invalid result.")


func _is_player_facing_interactable(player: Node2D) -> bool:
	if player == null:
		return false

	var player_direction_value: Variant = player.get("last_direction")
	if not (player_direction_value is Vector2):
		return false

	var player_direction: Vector2 = player_direction_value as Vector2
	if player_direction == Vector2.ZERO:
		return false

	var player_feet_position := player.global_position
	if player.has_method("get_feet_position"):
		player_feet_position = player.call("get_feet_position") as Vector2

	var player_tile := _to_tile(player_feet_position)
	var cardinal_direction := Vector2i(roundi(player_direction.x), roundi(player_direction.y))
	var facing_tile := player_tile + cardinal_direction
	return _is_tile_in_blocked_footprint(facing_tile)


func _is_tile_in_blocked_footprint(tile: Vector2i) -> bool:
	var origin := _to_tile(global_position + _blocked_tile_offset_pixels())
	var footprint := Vector2i(
		maxi(1, blocked_tile_footprint.x),
		maxi(1, blocked_tile_footprint.y)
	)
	var relative := tile - origin
	return (
		relative.x >= 0
		and relative.y >= 0
		and relative.x < footprint.x
		and relative.y < footprint.y
	)


func _blocked_tile_offset_pixels() -> Vector2:
	return Vector2(float(blocked_tile_offset.x), float(blocked_tile_offset.y)) * TILE_SIZE


func _ensure_interaction_area() -> void:
	if interaction_area == null:
		interaction_area = Area2D.new()
		interaction_area.name = "InteractionArea"
		add_child(interaction_area)

		var collision_shape := CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		interaction_area.add_child(collision_shape)

	var collision_shape := interaction_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		interaction_area.add_child(collision_shape)

	var shape := collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision_shape.shape = shape
	shape.size = interaction_shape_size

	var body_entered_callable := Callable(self, "_on_interaction_area_body_entered")
	var body_exited_callable := Callable(self, "_on_interaction_area_body_exited")
	if not interaction_area.body_entered.is_connected(body_entered_callable):
		interaction_area.body_entered.connect(body_entered_callable)
	if not interaction_area.body_exited.is_connected(body_exited_callable):
		interaction_area.body_exited.connect(body_exited_callable)


func _to_tile(world_position: Vector2) -> Vector2i:
	var local_position := world_position - _get_map_origin()
	return Vector2i(
		floori(local_position.x / TILE_SIZE),
		floori(local_position.y / TILE_SIZE)
	)


func _get_map_origin() -> Vector2:
	var game_state := _get_game_state()
	if game_state != null:
		var current_map: Node2D = game_state.get("current_map") as Node2D
		if current_map != null:
			return current_map.global_position

	return Vector2.ZERO


func _get_valid_dialogue_lines(lines: Array[String]) -> Array[String]:
	var valid_dialogue_lines: Array[String] = []
	for line: String in lines:
		if not line.strip_edges().is_empty():
			valid_dialogue_lines.append(line)

	return valid_dialogue_lines


func _get_dialogue_box() -> Node:
	if get_tree().current_scene == null:
		return null

	return get_tree().current_scene.get_node_or_null("DialogueBox/Box")


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = true
		nearby_player = body


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false
		if body == nearby_player:
			nearby_player = null


func _is_ui_typing() -> bool:
	var focused_control := get_viewport().gui_get_focus_owner()
	return focused_control is LineEdit or focused_control is TextEdit


func _get_game_state() -> Node:
	var root := get_tree().root
	if root == null:
		return null

	return root.get_node_or_null("GameState")


func _is_overworld_input_locked() -> bool:
	var game_state := _get_game_state()
	if game_state == null or not game_state.has_method("is_overworld_input_locked"):
		return false

	return bool(game_state.call("is_overworld_input_locked"))


func _lock_overworld_input() -> void:
	var game_state := _get_game_state()
	if game_state != null and game_state.has_method("lock_overworld_input"):
		game_state.call("lock_overworld_input")


func _unlock_overworld_input() -> void:
	var game_state := _get_game_state()
	if game_state != null and game_state.has_method("unlock_overworld_input"):
		game_state.call("unlock_overworld_input")
