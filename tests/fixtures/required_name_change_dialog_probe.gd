extends "res://scripts/ui/required_name_change_dialog.gd"

var submitted_names: Array[String] = []
var next_response: Dictionary = {"success": false, "body": {"detail": {"code": "username_unavailable"}}}


func _submit_name(new_name: String) -> Dictionary:
	submitted_names.append(new_name)
	await get_tree().process_frame
	return next_response


var next_status := {"success": false}


func _refresh_requirement() -> Dictionary:
	await get_tree().process_frame
	return next_status


func _is_authenticated() -> bool:
	return true
