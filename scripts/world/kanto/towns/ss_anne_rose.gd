@tool
extends DialogueNPC


func interact_with_player(player: Node2D) -> void:
	# Quest acceptance re-enters this method: perform the pose immediately.
	if StoryService.is_requirement_met("ss_anne_titanic_pose", "", "active"):
		var hook := _find_story_hook()
		if hook != null:
			await hook.call("try_handle_interaction", self, player, "interact")
		return
	await show_dialogue()


func prepare_player_pose(player: Node2D) -> void:
	# Conversation faces the player; turn back toward the sea before posing.
	face_world_position(get_feet_position() + Vector2.LEFT * 32.0)
	if player != null and player.has_method("face_world_position"):
		var player_position: Vector2 = player.call("get_feet_position") if player.has_method("get_feet_position") else player.global_position
		player.call("face_world_position", player_position + Vector2.LEFT * 32.0)
	await get_tree().create_timer(0.25).timeout
