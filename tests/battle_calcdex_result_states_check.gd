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
	var collapsed_text := _collect_visible_text(panel)
	for header_alternatives: Array in [
		["battle.calc.move_header", "MOVE", "AANVAL", "GOLPE"],
		["battle.calc.damage_header", "DAMAGE", "SCHADE", "DANO"],
		["battle.calc.ko_header", "KO %"],
	]:
		if not _contains_fragment(collapsed_text, header_alternatives):
			push_error("Missing Showdex-style Calcdex table header: %s" % str(header_alternatives))
			quit(1)
			return
	if not _contains_fragment(collapsed_text, ["calculation notes", "opmerkingen bij de berekening", "observações do cálculo"]):
		push_error("Calcdex calculation notes must have a compact summary")
		quit(1)
		return
	panel._on_warning_details_pressed()
	await process_frame
	var corrected_ko := panel._get_primary_result_label(
		{"minPercent": 147.2, "maxPercent": 173.6, "koSummaryLabel": "0% chance to OHKO"},
		{"hp": {"percent": 100.0}}
	)
	if corrected_ko != "OHKO":
		push_error("A guaranteed percent range must override a contradictory KO summary")
		quit(1)
		return

	var rendered_text := _collect_label_text(panel)
	if not _contains_fragment(rendered_text, ["end-of-turn effects", "einde-van-de-beurt-effecten", "efeitos de fim de turno"]):
		push_error("Missing consolidated end-of-turn footnote")
		quit(1)
		return
	var expected := [
		["battle.calc.unsupported_mechanic", "This mechanic is not safely supported.", "Deze mechanic wordt nog niet veilig ondersteund."],
		["Unsupported public mechanic."],
		["Recovery is unknown."],
		["Opponent nature is assumed."],
	]
	for alternatives: Array in expected:
		if not _contains_fragment(rendered_text, alternatives):
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


func _collect_visible_text(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label:
		result.append((node as Label).text)
	elif node is Button:
		result.append((node as Button).text)
	for child: Node in node.get_children():
		result.append_array(_collect_visible_text(child))
	return result


func _contains_fragment(values: Array[String], alternatives: Array) -> bool:
	for value: String in values:
		for alternative: Variant in alternatives:
			if value.contains(str(alternative)):
				return true
	return false
