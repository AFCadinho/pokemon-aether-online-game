extends Route24Gary

var progress_response := {"success": true, "progress": {"state": "first_encounter"}}
var starter_response := {"success": true, "rivalStarterSpeciesId": "squirtle"}
var progress_requests := 0
var starter_requests := 0


func _request_encounter_progress() -> Dictionary:
	progress_requests += 1
	await get_tree().process_frame
	return progress_response.duplicate(true)


func _request_starter_options() -> Dictionary:
	starter_requests += 1
	await get_tree().process_frame
	return starter_response.duplicate(true)


func _process(_delta: float) -> void:
	pass
