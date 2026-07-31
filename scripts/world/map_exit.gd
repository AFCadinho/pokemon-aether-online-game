extends Area2D

@export_file("*.tscn") var target_scene_path := ""
@export var target_spawn_name := ""
@export var transition_id := ""
@export_enum("up", "down", "left", "right") var transition_facing_direction := "down"
@export var player_node_name := "Player"

var is_transitioning := false


func _on_body_entered(body: Node2D) -> void:
	if is_transitioning:
		return
	if body.name != player_node_name:
		return

	if target_scene_path.strip_edges() == "":
		push_error("MapExit failed: target_scene_path is empty on %s." % get_path())
		return
	if target_spawn_name.strip_edges() == "":
		push_error("MapExit failed: target_spawn_name is empty on %s." % get_path())
		return

	var normalized_transition_id := _resolve_transition_id()
	if normalized_transition_id.is_empty():
		push_warning("MapExit is using legacy loading because its source map has no map_id: %s." % get_path())

	var world := GameState.get_world()
	if world == null or not world.has_method("load_map"):
		push_error("MapExit failed: could not resolve World.")
		return
	if world.has_method("is_map_transition_in_progress") and bool(world.call("is_map_transition_in_progress")):
		return

	is_transitioning = true
	if normalized_transition_id.is_empty():
		world.call_deferred("load_map", target_scene_path, target_spawn_name)
		return
	_enter_authorized_transition.call_deferred(body, world, normalized_transition_id)


func _enter_authorized_transition(player: Node2D, world: Node, normalized_transition_id: String) -> void:
	if (
		not world.has_method("begin_authorized_teleport")
		or not world.has_method("apply_authorized_teleport_state")
		or not world.has_method("cancel_authorized_teleport")
	):
		is_transitioning = false
		push_error("MapExit failed: World does not support authorized transitions.")
		return

	var begin_result: Dictionary = await world.call("begin_authorized_teleport", true)
	if not bool(begin_result.get("success", false)):
		is_transitioning = false
		push_warning("MapExit transition could not start: %s" % str(begin_result.get("error", "")))
		return

	var response: Dictionary = await WorldTransitionService.enter_transition(normalized_transition_id)
	if not bool(response.get("success", false)):
		world.call("cancel_authorized_teleport")
		is_transitioning = false
		await _show_transition_error(response)
		return

	if not bool(response.get("allowed", false)):
		world.call("cancel_authorized_teleport")
		is_transitioning = false
		await _present_denied_transition(
			normalized_transition_id,
			response.get("access", {}),
			player
		)
		return

	var state: Dictionary = response.get("state", {})
	if state.is_empty():
		world.call("cancel_authorized_teleport")
		is_transitioning = false
		await _show_transition_error()
		return

	var apply_result: Dictionary = await world.call("apply_authorized_teleport_state", state)
	if not bool(apply_result.get("success", false)):
		is_transitioning = false
		await _show_transition_error()


func _present_denied_transition(
	normalized_transition_id: String,
	access_value: Variant,
	player: Node2D
) -> void:
	var access: Dictionary = access_value if access_value is Dictionary else {}
	for candidate: Node in get_tree().get_nodes_in_group("world_transition_denial_presenters"):
		if (
			candidate.has_method("handles_world_transition")
			and bool(candidate.call("handles_world_transition", normalized_transition_id))
			and candidate.has_method("present_world_transition_denied")
		):
			await candidate.call("present_world_transition_denied", access, player)
			return

	var dialogue_id := str(access.get("dialogueId", "")).strip_edges()
	var lines: Array[String] = []
	if not dialogue_id.is_empty():
		lines = await DialogueMetadataService.get_lines(dialogue_id)
	if lines.is_empty():
		lines = ["This area is not available right now."]
	GameState.lock_overworld_input()
	await GameErrorDialogService.show_message(lines)
	GameState.unlock_overworld_input()


func _show_transition_error(response: Dictionary = {}) -> void:
	GameState.lock_overworld_input()
	if response.is_empty():
		await GameErrorDialogService.show_report_to_staff_message()
	else:
		await GameErrorDialogService.show_response(
			response,
			"backend.error.world_transition"
		)
	GameState.unlock_overworld_input()


func _resolve_transition_id() -> String:
	var configured_transition_id := transition_id.strip_edges()
	if not configured_transition_id.is_empty():
		return configured_transition_id
	var current_map: Node = GameState.current_map
	if current_map == null or not current_map.has_method("get_map_id"):
		return ""
	var source_map_id := str(current_map.call("get_map_id")).strip_edges()
	if source_map_id.is_empty():
		return ""
	return "%s__%s" % [source_map_id, str(name).to_snake_case()]
