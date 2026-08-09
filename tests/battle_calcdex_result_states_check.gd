extends SceneTree

const DamageCalcPanel := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel := DamageCalcPanel.new()
	var content := VBoxContainer.new()
	content.name = "VBoxContainer"
	panel.add_child(content)
	root.add_child(panel)
	await process_frame

	panel.show_response({
		"success": true,
		"attacker": {"species": "Pikachu"},
		"defender": {"species": "Mew", "hp": {"display": "75%"}},
		"results": [{
			"move": {"name": "Unsupported Move", "category": "Special"},
			"shortLabel": "--",
			"resultState": "unsupported",
			"warnings": ["Unsupported public mechanic."],
			"koWarnings": ["Recovery is unknown."],
			"endOfTurn": {
				"state": "not_included",
				"reasonCode": "CALC_END_OF_TURN_NOT_INCLUDED",
			},
		}],
		"warnings": ["Opponent nature is assumed."],
	})
	await process_frame

	var rendered_text := _collect_label_text(panel)
	var expected := [
		["battle.calc.unsupported_mechanic", "This mechanic is not safely supported.", "Deze mechanic wordt nog niet veilig ondersteund."],
		["Unsupported public mechanic."],
		["Recovery is unknown."],
		["battle.calc.end_of_turn_not_included", "Direct damage only; end-of-turn effects are not included.", "Alleen directe schade; einde-van-de-beurt-effecten zijn niet meegenomen."],
		["Opponent nature is assumed."],
	]
	for alternatives: Array in expected:
		if not _contains_any(rendered_text, alternatives):
			push_error("Missing visible Calcdex result state: %s" % str(alternatives))
			quit(1)
			return
	print("PASS battle_calcdex_result_states_check")
	quit(0)


func _collect_label_text(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label:
		result.append((node as Label).text)
	for child: Node in node.get_children():
		result.append_array(_collect_label_text(child))
	return result


func _contains_any(values: Array[String], alternatives: Array) -> bool:
	for alternative: Variant in alternatives:
		if str(alternative) in values:
			return true
	return false
