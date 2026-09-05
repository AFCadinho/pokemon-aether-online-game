extends RefCounted

## HTTP battles share PvP's mechanical response ordering, without its transport.
const ResponseOrder := preload("res://scripts/battle/battle_response_order.gd")
var order := ResponseOrder.new()


func remember(response: Dictionary) -> bool:
	var battle_id := str(response.get("battleId", ""))
	if battle_id != str(order.latest_response.get("battleId", "")):
		order.reset()
	var accepted: bool = order.remember(_comparison_response(response))
	if accepted:
		order.latest_response = response.duplicate(true)
	return accepted


func is_stale(response: Dictionary) -> bool:
	if str(response.get("battleId", "")) != str(order.latest_response.get("battleId", "")):
		return false
	return order.is_stale(_comparison_response(response))


static func _comparison_response(response: Dictionary) -> Dictionary:
	var comparable := response.duplicate(true)
	# Legacy NPC and participant snapshots have different privacy projections.
	# Their fingerprints and opponent decision generations are not comparable.
	comparable.erase("snapshotFingerprint")
	var decisions: Dictionary = comparable.get("decisions", {})
	decisions.erase("p2")
	return comparable


static func has_gap(response: Dictionary, rendered_seq: int) -> bool:
	if bool(response.get("eventDeliveryGap", false)):
		return true
	var end := int(response.get("eventSeq", -1))
	if rendered_seq < 0 or end <= rendered_seq:
		return false
	var events: Array = response.get("events", [])
	var start := int(response.get("eventSeqStart", end - events.size() + 1))
	return events.is_empty() or start > rendered_seq + 1


static func public_force_switch(control: Dictionary, own: bool) -> bool:
	var prefix := "own" if own else "opponent"
	return bool(control.get(prefix + "ActionRequired", false)) and bool(control.get(prefix + "ForceSwitchRequired", false))


static func needs_resolution(response: Dictionary) -> bool:
	if bool(response.get("state", {}).get("ended", false)):
		return false
	if response.has("npcChoiceError"):
		return true
	var control: Dictionary = response.get("viewerControl", {})
	if control.has("ownActionRequired"):
		return not bool(control["ownActionRequired"])
	var own_decision: Dictionary = response.get("decisions", {}).get("p1", {})
	if not own_decision.is_empty():
		return str(own_decision.get("status", "")) != "ACTIVE"
	return bool(response.get("requests", {}).get("p1", {}).get("wait", false))
