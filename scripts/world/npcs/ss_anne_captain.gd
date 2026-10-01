@tool
extends DialogueNPC

# Both conversations use the same captain, selected from projected server progress.
func _find_story_hook() -> Node:
	var story := get_node_or_null("/root/StoryService")
	if story != null and bool(story.call("is_requirement_met", "help_ss_anne_captain", "ss_anne_return_tea", "active")):
		return get_node("ReturnTeaStoryHook")
	return get_node("MeetCaptainStoryHook")
