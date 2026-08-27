extends SceneTree

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var service := root.get_node("FieldMoveService")
	var player_save := root.get_node("PlayerSave")
	var party: Array = player_save.get("party") as Array
	var original_party: Array = party.duplicate()
	party.clear()

	var surf_charm := {
		"itemId": "surf-charm",
		"name": "Surf Charm",
		"fieldMove": "surf",
		"requiredHm": "hm-surf",
	}
	service.call("update_owned_charms_from_inventory", [surf_charm])
	var without_hm: Dictionary = service.call("can_use_field_move", "surf")
	_check(not bool(without_hm.get("success", false)), "HM Charm is unavailable without its HM")
	_check(without_hm.get("requiredHm", "") == "hm-surf", "missing HM result identifies the required item")

	service.call("update_owned_charms_from_inventory", [
		surf_charm,
		{"itemId": "hm-surf", "machineKind": "hm"},
	])
	var with_hm: Dictionary = service.call("can_use_field_move", "surf")
	_check(bool(with_hm.get("success", false)), "HM Charm is available when its HM is owned")
	_check(with_hm.get("source", "") == "charm", "eligible HM Charm remains the move source")

	service.call("update_owned_charms_from_inventory", [{
		"itemId": "rain-dance-charm",
		"name": "Rain Dance Charm",
		"fieldMove": "rain-dance",
		"requiredHm": "",
	}])
	var non_hm_charm: Dictionary = service.call("can_use_field_move", "rain-dance")
	_check(bool(non_hm_charm.get("success", false)), "non-HM Charm remains available without an HM")

	party.clear()
	party.append_array(original_party)
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
