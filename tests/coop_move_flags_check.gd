extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func _run() -> void:
	var service := root.get_node("CoopService")
	service.set_process(false)
	service.reset()
	service.view = {"legalActions": [
		{"type": "move", "slot": 1, "target": 1},
		{"type": "move", "slot": 1, "target": 1, "zMove": true},
		{"type": "move", "slot": 2, "target": 1},
	]}
	var panel = load("res://scripts/battle/coop_battle_panel.gd").new()
	var slot = load("res://scenes/battle/move_slot.tscn").instantiate()
	root.add_child(slot)
	var move := {"slot": 1, "id": "surf", "name": "Surf", "type": "Water", "pp": 12, "maxPp": 15,
		"zMove": {"name": "Hydro Vortex", "type": "Water"}}
	var original := move.duplicate(true)
	for metadata: Variant in [null, {"name": "Hydro Vortex", "type": "Water"}, false, true]:
		var raw := move.duplicate(true)
		raw["zMove"] = metadata
		# Exercise the actual widget too: nullable protocol data must never throw.
		slot.effectiveness_label.text = "unfinished"
		slot.set_move_data(raw)
		_check(slot.pp_label.text == "12/15" and slot.effectiveness_label.text != "unfinished",
			"MoveSlot finishes rendering nullable/object/boolean metadata")
		slot.set_move_data(panel._native_move_display_data(raw))
		_check(not slot.disabled and slot.current_move_data.zMove == false,
			"Normal co-op moves remain available without Z-Power styling")
	var missing := move.duplicate(true)
	missing.erase("zMove")
	slot.set_move_data(missing)
	_check(not slot.disabled, "Missing Z-Move metadata renders a normal move")
	panel._z_move_selected = true
	var powered: Dictionary = panel._native_move_display_data(move)
	slot.set_move_data(powered)
	_check(powered.zMove == true and powered.name == "Hydro Vortex" and powered.type == "Water"
		and not slot.disabled and slot.move_name_label.text == slot._localized_move_name(powered)
		and slot.move_name_label.text != slot._localized_move_name(move)
		and slot.effectiveness_label.text == slot._t("battle.move.z_power"),
		"Selecting Z-Power renders the legal powered move")
	var unavailable := {"slot": 2, "name": "Tackle", "type": "Normal", "pp": 35, "maxpp": 35, "zMove": null}
	slot.set_move_data(panel._native_move_display_data(unavailable))
	_check(slot.disabled and slot.current_move_data.zMoveUnavailable == true
		and slot.effectiveness_label.text == slot._t("battle.move.no_z_move"),
		"Unavailable Z-Move is disabled with an explanation")
	panel._z_move_selected = false
	slot.set_move_data(panel._native_move_display_data(move))
	_check(not slot.disabled and slot.current_move_data.name == "Surf" and slot.tooltip_text.is_empty(),
		"Toggling back restores the ordinary move and clears Z-Power tooltip")
	_check(move == original and unavailable.zMove == null, "Rendering never mutates the authoritative move metadata")
	var disabled_move := move.duplicate(true)
	disabled_move.disabled = true
	slot.set_move_data(panel._native_move_display_data(disabled_move))
	_check(slot.disabled, "Server-disabled moves remain disabled")
	service.view.legalActions = []
	slot.set_move_data(panel._native_move_display_data(move))
	_check(slot.disabled, "A move without a legal target remains disabled")
	panel.free()
	slot.queue_free()
	service.reset()
	await process_frame
	print("coop_move_flags_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
