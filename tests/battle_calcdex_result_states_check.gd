extends SceneTree

const DamageCalcPanel := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel := DamageCalcPanel.new()
	panel.size = Vector2(640, 320)
	var scroll := ScrollContainer.new()
	scroll.name = "CalcScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := VBoxContainer.new()
	content.name = "VBoxContainer"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	panel.add_child(scroll)
	root.add_child(panel)
	await process_frame

	panel.show_response({
		"success": true,
		"direction": "own-to-opponent",
		"attacker": {"species": "Pikachu", "hp": {"display": "100%", "percent": 100}},
		"defender": {"species": "Mew", "hp": {"display": "75%", "percent": 75}},
		"results": [{
			"move": {"name": "Unsupported Move", "type": null, "category": "Special"},
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
	if _count_nodes_of_type(panel, "TextureRect") < 2 or _count_nodes_of_type(panel, "ProgressBar") < 2:
		push_error("Calcdex matchup cards must render Pokemon art and HP bars")
		quit(1)
		return
	if _contains_fragment(collapsed_text, ["<null>", "<nil>"]):
		push_error("Null move metadata must never be rendered to players")
		quit(1)
		return
	if not _contains_fragment(collapsed_text, ["SPECIAL", "Special"]):
		push_error("Known move categories must remain visible when move type is unknown")
		quit(1)
		return
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
	await process_frame
	if not _expanded_notes_have_visible_height(panel):
		push_error("Expanded Calcdex notes must occupy visible layout space")
		quit(1)
		return
	if scroll.scroll_vertical <= 0:
		push_error("Opening Calcdex notes must scroll the disclosure into view")
		quit(1)
		return
	var corrected_ko := panel._get_primary_result_label(
		{"minPercent": 147.2, "maxPercent": 173.6, "koSummaryLabel": "0% chance to OHKO"},
		{"hp": {"percent": 100.0}}
	)
	if corrected_ko != "OHKO":
		push_error("A guaranteed percent range must override a contradictory KO summary")
		quit(1)
		return
	if panel._format_level_value(100.0) != "100" or panel._format_level_value("50.0") != "50":
		push_error("Calcdex levels must render as whole numbers")
		quit(1)
		return
	if panel._make_move_source_label("owned_exact") != null:
		push_error("Exact owned moves must not carry a redundant provenance badge")
		quit(1)
		return
	var water_row_style: StyleBoxFlat = panel._make_result_row_style("OHKO", 0, "Water")
	if not water_row_style.border_color.is_equal_approx(Color(0.20, 0.45, 0.80, 1.0)):
		push_error("Move rows must use move-type color instead of KO severity for their accent rail")
		quit(1)
		return
	var inline_move_input: LineEdit = panel._make_result_move_selector_button(0, "Thunderbolt")
	if inline_move_input.right_icon == null or inline_move_input.mouse_default_cursor_shape != Control.CURSOR_IBEAM:
		push_error("Inline opponent moves must visibly behave like editable text fields")
		quit(1)
		return
	inline_move_input.queue_free()

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


func _count_nodes_of_type(node: Node, type_name: String) -> int:
	var count := 1 if node.is_class(type_name) else 0
	for child: Node in node.get_children():
		count += _count_nodes_of_type(child, type_name)
	return count


func _expanded_notes_have_visible_height(node: Node) -> bool:
	var note_labels: Array[Label] = []
	_collect_note_labels(node, note_labels)
	if note_labels.is_empty():
		return false
	for label: Label in note_labels:
		if label.size.y < 20.0 or not label.is_visible_in_tree():
			return false
	return true


func _collect_note_labels(node: Node, result: Array[Label]) -> void:
	if node is Label and (node as Label).text.begins_with("-  "):
		result.append(node as Label)
	for child: Node in node.get_children():
		_collect_note_labels(child, result)
