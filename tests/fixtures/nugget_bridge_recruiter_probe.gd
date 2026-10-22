extends NuggetBridgeRecruiter

# Exercise recruiter progression and dialogue without scene sensors or HTTP calls.
func _ready() -> void:
	set_process(false)
	set_physics_process(false)


var last_dialogue_id := ""
var last_speaker := ""


func _show_catalogue_dialogue(dialogue_id: String, _fallback_lines: Array[String], fallback_speaker: String) -> void:
	last_dialogue_id = dialogue_id
	last_speaker = fallback_speaker
	await get_tree().process_frame


var progress_response := {"success": true, "progress": {"state": "first_encounter"}}
var reward_response := {"success": false, "error": "Rejected reward fixture."}
var progress_requests := 0
var reward_requests := 0


func _request_recruiter_progress() -> Dictionary:
	progress_requests += 1
	return progress_response


func _claim_bridge_reward() -> Dictionary:
	reward_requests += 1
	return reward_response
