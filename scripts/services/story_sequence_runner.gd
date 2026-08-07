extends Node

class_name StorySequenceRunnerNode

const ALLOWED_ACTION_TYPES: Array[String] = [
	"dialogue",
	"wait",
	"face_actor",
	"move_actor",
	"battle",
]
const ALLOWED_ACTORS: Array[String] = ["self", "player"]
const ALLOWED_DIRECTIONS: Array[String] = ["up", "down", "left", "right"]
const MAX_ACTIONS := 64
const MAX_WAIT_DURATION_MS := 10000
const MAX_MOVE_PATH_STEPS := 32

var _is_running := false


func get_allowed_action_types() -> Array[String]:
	return ALLOWED_ACTION_TYPES.duplicate()


func validate_actions(actions_value: Variant) -> Dictionary:
	if not (actions_value is Array):
		return _validation_error("Story actions must be an array.")

	var actions: Array = actions_value as Array
	if actions.is_empty() or actions.size() > MAX_ACTIONS:
		return _validation_error("Story action count is outside the supported range.")

	var battle_count := 0
	for index: int in range(actions.size()):
		var action_value: Variant = actions[index]
		if not (action_value is Dictionary):
			return _validation_error("Story action %d is not an object." % index)
		var action: Dictionary = action_value as Dictionary
		if not (action.get("type") is String):
			return _validation_error("Story action %d has no string type." % index)
		var action_type := str(action.get("type", ""))
		if action_type not in ALLOWED_ACTION_TYPES:
			return _validation_error("Unsupported story action type: %s" % action_type)

		var action_error := _validate_action(action_type, action)
		if action_error != "":
			return _validation_error("Story action %d: %s" % [index, action_error])
		if action_type == "battle":
			battle_count += 1
			if index != actions.size() - 1:
				return _validation_error("Battle must be the final story action.")

	if battle_count > 1:
		return _validation_error("A story sequence may contain at most one battle.")
	return {"success": true}


func run_sequence(actions: Variant, host: Node, player: Node2D = null) -> Dictionary:
	var validation := validate_actions(actions)
	if not bool(validation.get("success", false)):
		return validation
	if _is_running:
		return {"success": false, "status": "busy", "error": "A story sequence is already running."}
	if host == null or not is_instance_valid(host):
		return {"success": false, "status": "invalid_host", "error": "Story host is unavailable."}

	var resolved_player := player if player != null else _get_player()
	var previous_input_state := _capture_input_state()
	_is_running = true
	GameState.lock_input()

	var action_list: Array = actions as Array
	for index: int in range(action_list.size()):
		var action: Dictionary = action_list[index] as Dictionary
		var action_result: Dictionary = await _run_action(action, host, resolved_player)
		if str(action_result.get("status", "")) == "pending_battle":
			_is_running = false
			_restore_input_state(previous_input_state, true)
			return {
				"success": false,
				"status": "pending_battle",
				"actionIndex": index,
				"battleId": str(action_result.get("battleId", "")),
			}
		if not bool(action_result.get("success", false)):
			_is_running = false
			_restore_input_state(previous_input_state)
			var failed_result := action_result.duplicate(true)
			failed_result["success"] = false
			failed_result["actionIndex"] = index
			return failed_result

		# Keep the sequence lock explicit between actions. DialogueBox restores
		# the lock state it inherited when it opened.
		GameState.lock_input()

	_is_running = false
	_restore_input_state(previous_input_state)
	return {"success": true, "status": "completed"}


func _validate_action(action_type: String, action: Dictionary) -> String:
	var expected_fields := _expected_action_fields(action_type)
	if not _has_exact_fields(action, expected_fields):
		return "fields do not exactly match the %s contract." % action_type
	match action_type:
		"dialogue":
			var dialogue_id := str(action.get("dialogueId", ""))
			if not (action.get("dialogueId") is String) or not _is_valid_reference(dialogue_id):
				return "dialogueId is required."
		"wait":
			if not _is_semantic_integer(action.get("durationMs")):
				return "durationMs must be an integer."
			var duration_ms := int(action.get("durationMs", -1))
			if duration_ms < 0 or duration_ms > MAX_WAIT_DURATION_MS:
				return "durationMs is outside the supported range."
		"face_actor":
			var actor := str(action.get("actor", ""))
			var target := str(action.get("target", ""))
			if actor not in ALLOWED_ACTORS or target not in ALLOWED_ACTORS or actor == target:
				return "actor and target must identify different supported actors."
		"move_actor":
			if str(action.get("actor", "")) not in ALLOWED_ACTORS:
				return "actor is not supported."
			var path_value: Variant = action.get("path", null)
			if not (path_value is Array):
				return "path must be an array."
			var path: Array = path_value as Array
			if path.is_empty() or path.size() > MAX_MOVE_PATH_STEPS:
				return "path length is outside the supported range."
			for direction_value: Variant in path:
				if not (direction_value is String) or str(direction_value) not in ALLOWED_DIRECTIONS:
					return "path contains an unsupported direction."
		"battle":
			var trainer_id := str(action.get("trainerId", ""))
			if not (action.get("trainerId") is String) or not _is_valid_reference(trainer_id):
				return "trainerId is required."
	return ""


func _expected_action_fields(action_type: String) -> Array[String]:
	match action_type:
		"dialogue":
			return ["type", "dialogueId"]
		"wait":
			return ["type", "durationMs"]
		"face_actor":
			return ["type", "actor", "target"]
		"move_actor":
			return ["type", "actor", "path"]
		"battle":
			return ["type", "trainerId"]
	return []


func _has_exact_fields(action: Dictionary, expected_fields: Array[String]) -> bool:
	if action.size() != expected_fields.size():
		return false
	for field: String in expected_fields:
		if not action.has(field):
			return false
	return true


func _is_semantic_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var numeric_value := float(value)
	return is_finite(numeric_value) and floor(numeric_value) == numeric_value


func _is_valid_reference(value: String) -> bool:
	if value.is_empty() or value.length() > 160 or value != value.strip_edges():
		return false
	for index: int in range(value.length()):
		var character := value.substr(index, 1)
		var is_lowercase_letter := character >= "a" and character <= "z"
		var is_digit := character >= "0" and character <= "9"
		if index == 0 and not (is_lowercase_letter or is_digit):
			return false
		if not (is_lowercase_letter or is_digit or character in ["_", ".", ":", "-"]):
			return false
	return true


func _run_action(action: Dictionary, host: Node, player: Node2D) -> Dictionary:
	match str(action.get("type", "")):
		"dialogue":
			return await _run_dialogue(action, host)
		"wait":
			return await _run_wait(action)
		"face_actor":
			return _run_face_actor(action, host, player)
		"move_actor":
			return await _run_move_actor(action, host, player)
		"battle":
			return await _run_battle(action, host)
	return {"success": false, "status": "unsupported_action"}


func _run_dialogue(action: Dictionary, host: Node) -> Dictionary:
	if not host.has_method("show_dialogue"):
		return {"success": false, "status": "dialogue_host_unavailable"}
	if get_tree().current_scene == null or get_tree().current_scene.get_node_or_null("DialogueBox/Box") == null:
		return {"success": false, "status": "dialogue_box_unavailable"}
	var dialogue_id := str(action.get("dialogueId", ""))
	var response: Dictionary = await DialogueMetadataService.get_dialogue(
		dialogue_id
	)
	if not bool(response.get("success", false)):
		return response
	var metadata: Dictionary = response.get("metadata", {}) as Dictionary
	if (
		str(metadata.get("id", "")) != dialogue_id
		or str(metadata.get("dialogueId", "")) != dialogue_id
	):
		return {"success": false, "status": "dialogue_identity_mismatch"}
	var lines := _string_array(metadata.get("lines", []))
	if lines.is_empty():
		return {"success": false, "status": "dialogue_empty"}
	var presented: Variant = await host.call(
		"show_dialogue",
		lines,
		str(metadata.get("speakerName", ""))
	)
	return {
		"success": presented is bool and bool(presented),
		"status": "completed" if presented is bool and bool(presented) else "dialogue_not_presented",
	}


func _run_wait(action: Dictionary) -> Dictionary:
	var duration_seconds := float(int(action.get("durationMs", 0))) / 1000.0
	if duration_seconds > 0.0:
		await get_tree().create_timer(duration_seconds).timeout
	return {"success": true}


func _run_face_actor(action: Dictionary, host: Node, player: Node2D) -> Dictionary:
	var actor := _resolve_actor(str(action.get("actor", "")), host, player)
	var target := _resolve_actor(str(action.get("target", "")), host, player)
	if actor == null or target == null or not actor.has_method("face_world_position"):
		return {"success": false, "status": "face_actor_unavailable"}
	actor.call("face_world_position", _actor_world_position(target))
	return {"success": true}


func _run_move_actor(action: Dictionary, host: Node, player: Node2D) -> Dictionary:
	var actor := _resolve_actor(str(action.get("actor", "")), host, player)
	if actor == null or not actor.has_method("story_move_path"):
		return {"success": false, "status": "move_actor_unavailable"}
	var path: Array[String] = []
	for direction_value: Variant in action.get("path", []):
		path.append(str(direction_value))
	var moved: Variant = await actor.call("story_move_path", path)
	return {
		"success": bool(moved),
		"status": "completed" if bool(moved) else "move_blocked",
	}


func _run_battle(action: Dictionary, host: Node) -> Dictionary:
	var trainer_id := str(action.get("trainerId", ""))
	var response: Dictionary = await TrainerMetadataService.get_trainer_metadata(
		trainer_id
	)
	if not bool(response.get("success", false)):
		return response
	var trainer_metadata: Dictionary = response.get("metadata", {}) as Dictionary
	if str(trainer_metadata.get("id", "")) != trainer_id:
		return {"success": false, "status": "trainer_identity_mismatch"}
	if host.has_method("build_battle_trainer_metadata"):
		trainer_metadata = host.call("build_battle_trainer_metadata", trainer_metadata)
	var world := GameState.get_world()
	if world == null or not world.has_method("start_trainer_battle"):
		return {"success": false, "status": "battle_world_unavailable"}
	var battle_result: Variant = await world.call(
		"start_trainer_battle",
		trainer_metadata.duplicate(true)
	)
	if not (battle_result is Dictionary) or not bool((battle_result as Dictionary).get("success", false)):
		return battle_result as Dictionary if battle_result is Dictionary else {
			"success": false,
			"status": "battle_start_failed",
		}
	return {
		"success": true,
		"status": "pending_battle",
		"battleId": str((battle_result as Dictionary).get("battleId", "")),
	}


func _resolve_actor(actor_id: String, host: Node, player: Node2D) -> Node2D:
	if actor_id == "self":
		return host as Node2D
	if actor_id == "player":
		return player
	return null


func _actor_world_position(actor: Node2D) -> Vector2:
	if actor.has_method("get_feet_position"):
		return actor.call("get_feet_position") as Vector2
	return actor.global_position


func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _capture_input_state() -> Dictionary:
	return {
		"input": bool(GameState.input_locked),
		"overworld": bool(GameState.overworld_input_locked),
		"ui": bool(GameState.ui_input_locked),
	}


func _restore_input_state(state: Dictionary, force_overworld_lock := false) -> void:
	GameState.unlock_input()
	if bool(state.get("input", false)):
		GameState.lock_input()
		return
	if bool(state.get("overworld", false)) or force_overworld_lock:
		GameState.lock_overworld_input()
	if bool(state.get("ui", false)):
		GameState.lock_ui_input()


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			var text := str(item).strip_edges()
			if text != "":
				result.append(text)
	return result


func _validation_error(message: String) -> Dictionary:
	return {"success": false, "status": "invalid_actions", "error": message}
