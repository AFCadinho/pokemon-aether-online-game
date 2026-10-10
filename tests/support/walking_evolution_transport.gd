extends "res://scripts/services/walking_evolution_service.gd"
signal release_reply
var requests: Array[Dictionary] = []
var receipt_totals: Dictionary = {}
var server_steps := 0
var fail_next := false
var hold_next := false

func _send_usage(id: String, mon_id: int, count: int) -> Dictionary:
	requests.append({"usageId": id, "pokemonId": mon_id, "totalSteps": count})
	if hold_next:
		hold_next = false
		await release_reply
	else:
		await get_tree().process_frame
	if fail_next:
		fail_next = false
		return {"success": false, "error": "Fixture connection lost."}
	var previous := int(receipt_totals.get(id, 0))
	server_steps = mini(server_steps + maxi(count - previous, 0), 1000)
	receipt_totals[id] = maxi(count, previous)
	return {"success": true, "body": {"usageId": id, "pokemonId": mon_id, "totalSteps": count,
		"walkSteps": server_steps, "walkReadyLevel": 20 if server_steps == 1000 else 0, "requiredSteps": 1000}}
