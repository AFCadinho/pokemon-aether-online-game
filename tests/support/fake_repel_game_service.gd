extends "res://scripts/services/player_game_state_service.gd"

var charge := 100
var accepted_totals: Dictionary = {}
var fail_next := false
var sync_calls := 0

func sync_repel_usage(usage_id: String, total_steps: int) -> Dictionary:
	sync_calls += 1
	await get_tree().process_frame
	if fail_next:
		fail_next = false
		return {"success": false, "error": "Offline"}
	var previous := int(accepted_totals.get(usage_id, 0))
	charge = maxi(charge - maxi(total_steps - previous, 0), 0)
	accepted_totals[usage_id] = maxi(previous, total_steps)
	return {"success": true, "repelSteps": charge}
