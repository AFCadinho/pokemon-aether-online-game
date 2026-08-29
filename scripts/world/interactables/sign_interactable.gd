extends WorldInteractable

class_name SignInteractable

const SignPortraitCatalogScript := preload("res://scripts/services/sign_portrait_catalog.gd")

@export var sign_id := ""
@export_enum("road", "town", "building", "trainer_tips", "notice", "generic") var sign_type := "generic"
@export_enum("local", "inline", "remote") var content_source := "local"
@export var title := ""
@export var speaker_name := ""
@export var fallback_lines: Array[String] = []
@export var locale := ""
@export_enum("small", "large") var sign_size := "small"
@export_enum("facing_target_tile", "standing_tile") var interaction_mode := "standing_tile"
@export_enum("any", "up", "down", "left", "right") var required_facing_direction := "up"


func _ready() -> void:
	interactable_kind = "sign"
	_ensure_interaction_area()


func interact_with_player(_player: Node2D) -> void:
	await show_sign_text()


func _start_manual_interaction(body: Node2D) -> void:
	is_interacting = true
	_lock_overworld_input()
	if body != null:
		if interaction_mode == "standing_tile" and required_facing_direction != "any":
			body.set("last_direction", _required_facing_vector())
			if body.has_method("set_idle_frame"):
				body.call("set_idle_frame")
		elif body.has_method("face_world_position"):
			body.face_world_position(global_position)

	var result := await _run_story_or_legacy_interaction(body, "interact")
	if str(result.get("status", "")) != "pending_battle":
		_unlock_overworld_input()
	is_interacting = false


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

	if interaction_mode == "standing_tile":
		if not _is_player_on_interaction_tile(nearby_player):
			return false
		if not _is_player_facing_required_direction(nearby_player):
			return false
	elif requires_facing and not _is_player_facing_interactable(nearby_player):
		return false

	var dialogue_box := _get_dialogue_box()
	if dialogue_box != null and dialogue_box.is_open:
		return false

	return true


func show_sign_text() -> void:
	var lines: Array[String] = []
	var resolved_title := title.strip_edges()
	var resolved_speaker_name := speaker_name.strip_edges()

	if content_source == "local":
		var metadata := _get_local_sign_metadata()
		lines = _get_string_array(metadata.get("lines", []))
		if resolved_title.is_empty():
			resolved_title = str(metadata.get("title", "")).strip_edges()
		if resolved_speaker_name.is_empty():
			resolved_speaker_name = str(metadata.get("speakerName", metadata.get("speaker_name", ""))).strip_edges()
	elif content_source == "inline":
		lines = _get_valid_dialogue_lines(dialogue_lines)
	else:
		push_warning("%s: remote sign content is not implemented yet; using fallback text." % name)

	if lines.is_empty():
		lines = _get_valid_dialogue_lines(fallback_lines)
	if lines.is_empty():
		lines = _get_valid_dialogue_lines(dialogue_lines)

	var speaker := _resolve_speaker_name(resolved_title, resolved_speaker_name)
	await _show_sign_dialogue(lines, speaker)


func _show_sign_dialogue(lines: Array[String], speaker: String) -> void:
	var dialogue_box := _get_dialogue_box()
	if dialogue_box == null:
		push_warning("%s: DialogueBox/Box not found." % name)
		return

	var valid_dialogue_lines := _get_valid_dialogue_lines(lines)
	if valid_dialogue_lines.is_empty():
		valid_dialogue_lines = MISSING_DIALOGUE_LINES

	var portrait: Texture2D = SignPortraitCatalogScript.get_portrait(sign_id)
	dialogue_box.start_dialogue(valid_dialogue_lines, speaker, portrait, portrait != null)
	await dialogue_box.dialogue_finished


func _get_local_sign_metadata() -> Dictionary:
	var normalized_sign_id := sign_id.strip_edges()
	if normalized_sign_id.is_empty():
		push_warning("%s: missing sign_id." % name)
		return {}

	var sign_text_service := get_node_or_null("/root/SignTextService")
	if sign_text_service == null or not sign_text_service.has_method("get_sign"):
		push_warning("%s: SignTextService autoload not found." % name)
		return {}

	var response: Dictionary = sign_text_service.call("get_sign", normalized_sign_id, _get_current_map_id(), locale)
	if not response.get("success", false):
		push_warning("%s: sign text lookup failed for %s: %s" % [
			name,
			normalized_sign_id,
			str(response.get("error", "Unknown error")),
		])
		return {}

	return response.get("metadata", {})


func _resolve_speaker_name(resolved_title: String, resolved_speaker_name: String) -> String:
	if not resolved_speaker_name.is_empty():
		return resolved_speaker_name
	if not resolved_title.is_empty():
		return resolved_title
	if not display_name.strip_edges().is_empty():
		return display_name.strip_edges()

	match sign_type:
		"trainer_tips":
			return "Trainer Tips"
		"town":
			return "Town Sign"
		"road":
			return "Road Sign"
		"building":
			return "Building Sign"
		"notice":
			return "Notice"
		_:
			return "Sign"


func _get_current_map_id() -> String:
	var game_state := _get_game_state()
	if game_state == null:
		return ""

	var current_map: Node = game_state.get("current_map") as Node
	if current_map == null:
		return ""
	if current_map.has_method("get_map_id"):
		return str(current_map.call("get_map_id")).strip_edges()
	return ""


func _is_player_on_interaction_tile(player: Node2D) -> bool:
	if player == null:
		return false

	var player_feet_position := player.global_position
	if player.has_method("get_feet_position"):
		player_feet_position = player.call("get_feet_position") as Vector2

	var target_position := global_position
	if interaction_area != null:
		target_position = interaction_area.global_position
		var interaction_rect := _get_interaction_area_rect()
		if interaction_rect.has_point(player_feet_position):
			return true

	return _to_tile(player_feet_position) == _to_tile(target_position)


func _get_interaction_area_rect() -> Rect2:
	if interaction_area == null:
		return Rect2(global_position - Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5), Vector2(TILE_SIZE, TILE_SIZE))

	var collision_shape := interaction_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return Rect2(interaction_area.global_position - Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5), Vector2(TILE_SIZE, TILE_SIZE))

	var rectangle_shape := collision_shape.shape as RectangleShape2D
	if rectangle_shape == null:
		return Rect2(interaction_area.global_position - Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5), Vector2(TILE_SIZE, TILE_SIZE))

	var size := _get_standing_area_size(rectangle_shape.size)
	return Rect2(interaction_area.global_position - size * 0.5, size)


func _is_player_facing_required_direction(player: Node2D) -> bool:
	if not requires_facing:
		return true
	if required_facing_direction == "any":
		return true
	if player == null:
		return false

	var player_direction_value: Variant = player.get("last_direction")
	if not (player_direction_value is Vector2):
		return false

	return (player_direction_value as Vector2) == _required_facing_vector()


func _required_facing_vector() -> Vector2:
	match required_facing_direction:
		"down":
			return Vector2.DOWN
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		_:
			return Vector2.UP


func _get_standing_area_size(fallback_size: Vector2) -> Vector2:
	if sign_size == "large" or sign_size == "small":
		return _get_shape_size_for_sign_size()
	return fallback_size


func _get_shape_size_for_sign_size() -> Vector2:
	if sign_size == "large":
		return Vector2(TILE_SIZE * 2.0, TILE_SIZE)
	return Vector2(TILE_SIZE, TILE_SIZE)


func _get_string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if value is Array:
		for item: Variant in value:
			var line := str(item).strip_edges()
			if not line.is_empty():
				strings.append(line)
	elif value is String:
		var line := str(value).strip_edges()
		if not line.is_empty():
			strings.append(line)
	return strings
