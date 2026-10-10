extends "res://scripts/ui/ui_overlay.gd"
signal release_conditions_reply
var hold_reply := false
var fixture_conditions: Dictionary = {}

func _request_evolution_conditions(_pokemon_id: int) -> Dictionary:
	if hold_reply:
		await release_conditions_reply
	return {"success": true, "body": fixture_conditions}
