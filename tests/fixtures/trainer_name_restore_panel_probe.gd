extends "res://scripts/ui/trainer_name_restore_panel.gd"
var submissions: Array[String] = []
var next_response := {"success": false, "body": {"detail": {"code": "username_unavailable"}}}
var options_response := {"success": true, "body": {"options": [{"decisionId": "fixture", "displayName": "OldName", "username": "oldname", "available": true}]}}


func _load_options() -> Dictionary:
	await get_tree().process_frame
	return options_response


func _submit_restore(decision_id: String) -> Dictionary:
	submissions.append(decision_id)
	await get_tree().process_frame
	return next_response


func _is_authenticated() -> bool:
	return true
