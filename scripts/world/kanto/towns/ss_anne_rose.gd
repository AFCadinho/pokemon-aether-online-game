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
