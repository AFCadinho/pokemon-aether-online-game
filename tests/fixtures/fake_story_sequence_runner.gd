extends "res://scripts/services/story_sequence_runner.gd"

var replies: Dictionary = {}
var calls: Dictionary = {}
var delay_frames := 1


func _fetch_story_dialogue(dialogue_id: String) -> Dictionary:
	for _frame in range(delay_frames):
		await get_tree().process_frame
	calls[dialogue_id] = int(calls.get(dialogue_id, 0)) + 1
	var responses: Array = replies.get(dialogue_id, []) as Array
	var index := mini(int(calls[dialogue_id]) - 1, responses.size() - 1)
	return responses[index] as Dictionary if index >= 0 else {"success": false, "status": 404}
