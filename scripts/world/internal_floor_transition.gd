extends Area2D
class_name InternalFloorTransition

const TRANSITION_LOCK_META := &"pao_internal_floor_transition_locked"

@export var destination_marker_path: NodePath
@export var floor_mask_path: NodePath = ^"../../FloorVisibilityMask"
@export var target_floor: StringName
@export var player_node_name: StringName = &"Player"
@export_range(0.0, 1.0, 0.05) var cooldown_seconds := 0.25

var is_transitioning := false


func _on_body_entered(body: Node2D) -> void:
	if is_transitioning or body.name != player_node_name:
		return

	var destination := get_node_or_null(destination_marker_path) as Marker2D
	if destination == null:
		push_error("InternalFloorTransition: destination marker is missing on %s." % get_path())
		return

	var floor_mask := get_node_or_null(floor_mask_path)
	if floor_mask == null or not floor_mask.has_method("show_floor"):
		push_error("InternalFloorTransition: floor mask is missing on %s." % get_path())
		return

	var map_root := floor_mask.get_parent()
	if map_root == null:
		push_error("InternalFloorTransition: map root is missing on %s." % get_path())
		return
	if bool(map_root.get_meta(TRANSITION_LOCK_META, false)):
		return

	is_transitioning = true
	map_root.set_meta(TRANSITION_LOCK_META, true)
	floor_mask.call("show_floor", target_floor)
	_place_player(body, destination.global_position)

	await get_tree().physics_frame
	if cooldown_seconds > 0.0:
		await get_tree().create_timer(cooldown_seconds).timeout
	if is_instance_valid(map_root):
		map_root.set_meta(TRANSITION_LOCK_META, false)
	is_transitioning = false


func _place_player(player: Node2D, destination: Vector2) -> void:
	player.global_position = destination
	_set_property_if_present(player, &"target_position", destination)
	_set_property_if_present(player, &"move_start_position", destination)
	_set_property_if_present(player, &"is_moving", false)

	if player.has_method("set_idle_frame"):
		player.call("set_idle_frame")
	if player.has_method("refresh_map_layers"):
		player.call("refresh_map_layers")
	if player.has_method("reset_pokemon_follower_position"):
		player.call("reset_pokemon_follower_position")

	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.reset_smoothing()

	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		_set_property_if_present(game_state, &"player_position", destination)
		_set_property_if_present(game_state, &"has_player_position", true)


func _set_property_if_present(object: Object, property_name: StringName, value: Variant) -> void:
	for property: Dictionary in object.get_property_list():
		if StringName(property.get("name", &"")) == property_name:
			object.set(property_name, value)
			return
