extends WorldInteractable

class_name PokemonPcInteractable

enum FacingDirection {
	ANY,
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

@export var required_facing_direction := FacingDirection.ANY


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
	if not _is_player_on_interaction_tile(nearby_player):
		return false
	if requires_facing and required_facing_direction != FacingDirection.ANY:
		var player_direction_value: Variant = nearby_player.get("last_direction")
		if not (player_direction_value is Vector2) or player_direction_value != _required_facing_vector():
			return false

	var dialogue_box := _get_dialogue_box()
	if dialogue_box != null and dialogue_box.is_open:
		return false

	return true


func _required_facing_vector() -> Vector2:
	match required_facing_direction:
		FacingDirection.DOWN:
			return Vector2.DOWN
		FacingDirection.LEFT:
			return Vector2.LEFT
		FacingDirection.RIGHT:
			return Vector2.RIGHT
		_:
			return Vector2.UP


func _is_player_on_interaction_tile(player: Node2D) -> bool:
	if player == null:
		return false

	var player_feet_position := player.global_position
	if player.has_method("get_feet_position"):
		player_feet_position = player.call("get_feet_position") as Vector2

	var target_position := global_position
	if interaction_area != null:
		target_position = interaction_area.global_position

	return _to_tile(player_feet_position) == _to_tile(target_position)


func _start_manual_interaction(body: Node2D) -> void:
	is_interacting = true
	_lock_overworld_input()
	if body != null:
		if required_facing_direction != FacingDirection.ANY:
			body.set("last_direction", _required_facing_vector())
		if body.has_method("set_idle_frame"):
			body.call("set_idle_frame")

	await interact_with_player(body)
	_unlock_overworld_input()
	is_interacting = false


func interact_with_player(_player: Node2D) -> void:
	var ui_overlay := get_tree().current_scene.get_node_or_null("UIOverlay")
	if ui_overlay == null or not ui_overlay.has_method("open_pokemon_pc"):
		push_warning("%s: UIOverlay.open_pokemon_pc not found." % name)
		return

	await ui_overlay.call("open_pokemon_pc")
