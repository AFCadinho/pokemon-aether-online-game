extends "res://scripts/world/npcs/museum_admission_npc.gd"

var offered_fee := 0


func _refresh_transition_access(_force_refresh := false) -> Dictionary:
	transition_access = {"allowed": false, "reasonCode": "ENTRY_FEE_REQUIRED", "entryFee": 100}
	return {"success": true, "access": transition_access}


func _confirm_admission(fee: int) -> bool:
	offered_fee = fee
	return false
