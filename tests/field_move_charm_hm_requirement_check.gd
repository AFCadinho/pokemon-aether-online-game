extends SceneTree

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var service := root.get_node("FieldMoveService")
	var player_save := root.get_node("PlayerSave")
	var party: Array = player_save.get("party") as Array
	var original_party: Array = party.duplicate()
	var badges: Array = player_save.get("earned_gym_badges") as Array
	var original_badges: Array = badges.duplicate()
	if not "kanto:soul" in badges:
		badges.append("kanto:soul")
	party.clear()
	party.append(Pokemon.new(
		"Lapras",
		20,
		"",
		"",
		"Hardy",
		{},
		{},
		{},
		[{"id": "surf"}]
	))

	service.call("update_owned_charms_from_inventory", [])
	var pokemon_without_hm: Dictionary = service.call("can_use_field_move", "surf")
	_check(not bool(pokemon_without_hm.get("success", false)), "HM field move is unavailable without its HM")
	_check(pokemon_without_hm.get("requiredHm", "") == "hm-surf", "general field move gate identifies the required HM")

	service.call("update_owned_charms_from_inventory", [
		{"itemId": "hm-surf", "machineKind": "hm"},
	])
	var pokemon_with_hm: Dictionary = service.call("can_use_field_move", "surf")
	_check(bool(pokemon_with_hm.get("success", false)), "Pokemon can use an HM field move when its HM is owned")
	_check(pokemon_with_hm.get("source", "") == "pokemon", "Pokemon remains the source without a Charm")

	var surf_charm := {
		"itemId": "surf-charm",
		"name": "Surf Charm",
		"fieldMove": "surf",
		"requiredHm": "hm-surf",
	}
	service.call("update_owned_charms_from_inventory", [surf_charm])
	var without_hm: Dictionary = service.call("can_use_field_move", "surf")
	_check(not bool(without_hm.get("success", false)), "HM field move stays unavailable even when its Charm is owned")
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
	badges.assign(original_badges)
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
