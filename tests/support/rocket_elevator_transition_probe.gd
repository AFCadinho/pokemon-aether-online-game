extends Node
var requests: Array[String] = []
var response: Dictionary = {}
func enter_transition(transition_id: String, _facing: String) -> Dictionary:
	requests.append(transition_id)
	await get_tree().process_frame
	return response.duplicate(true)
