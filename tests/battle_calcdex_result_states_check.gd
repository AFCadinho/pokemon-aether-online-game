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
			"description": "0 SpA Pikachu Unsupported Move vs. 0 HP / 0 SpD Mew: 0-0 (0 - 0%)",
			"warnings": ["Unsupported public mechanic."],
			"koWarnings": ["Recovery is unknown."],
			"koProjection": {"state": "unavailable", "chance": null, "hits": null, "text": "", "basedOn": "public_percent_upper_bound", "effects": [], "reasonCode": "CALC_UNSUPPORTED_MECHANIC"},
		}, {
			"move": {"name": "Thunderbolt", "type": "Electric", "category": "Special"},
			"shortLabel": "44.0-52.0%",
			"minPercent": 44.0,
			"maxPercent": 52.0,
			"resultState": "supported",
			"description": "252 SpA Pikachu Thunderbolt vs. 252 HP / 8 SpD Mew: 176-210 (43.5 - 51.9%) -- 10.9% chance to 2HKO after Stealth Rock, burn damage, and Leftovers recovery",
			"warnings": [],
			"koProjection": {
				"state": "available", "chance": 0.109, "hits": 2, "text": "10.9% chance to 2HKO after Stealth Rock, burn damage, and Leftovers recovery",
				"basedOn": "public_percent_upper_bound",
				"effects": [
					{"id": "stealth_rock", "kind": "entry_hazard", "timing": "before_first_attack"},
					{"id": "burn_damage", "kind": "status", "timing": "between_attacks"},
					{"id": "leftovers_recovery", "kind": "recovery", "timing": "between_attacks"},
				],
			},
		}],
		"warnings": ["Opponent nature is assumed."],
	})
	await process_frame
	if panel.result_summary_panels.size() != 2 or panel.result_disclosure_buttons.size() != 2:
		push_error("Every safely described move result must expose a calculation-summary disclosure")
		quit(1)
		return
	var first_summary_key := ""
	var second_summary_key := ""
	for key_value: Variant in panel.result_summary_panels.keys():
		var key := str(key_value)
		if key.contains("unsupportedmove"):
			first_summary_key = key
		elif key.contains("thunderbolt"):
			second_summary_key = key
	if first_summary_key == "" or second_summary_key == "":
		push_error("Calculation-summary disclosures must have stable per-move keys")
		quit(1)
		return
	if (panel.result_summary_panels[first_summary_key] as Control).visible or (panel.result_summary_panels[second_summary_key] as Control).visible:
		push_error("Calculation summaries must start collapsed")
		quit(1)
		return
	panel._on_result_disclosure_pressed(first_summary_key)
	if not (panel.result_summary_panels[first_summary_key] as Control).visible:
		push_error("Clicking a move row must expand its calculation summary")
		quit(1)
		return
	panel._on_result_disclosure_pressed(second_summary_key)
	if (panel.result_summary_panels[first_summary_key] as Control).visible or not (panel.result_summary_panels[second_summary_key] as Control).visible:
		push_error("Opening a calculation summary must close the previously expanded move")
		quit(1)
		return
	var expanded_summary_text := _collect_label_text(panel.result_summary_panels[second_summary_key])
	for summary_fragment: String in ["252 SpA Pikachu Thunderbolt", "10.9% chance to 2HKO", "Stealth Rock", "burn damage", "Leftovers recovery"]:
		if not _contains_fragment(expanded_summary_text, [summary_fragment]):
			push_error("Expanded move rows must show the complete Showdown-style KO projection: %s" % summary_fragment)
			quit(1)
			return
	var projected_result := {
		"shortLabel": "44.0-52.0%", "minPercent": 44.0, "maxPercent": 52.0,
		"koProjection": {"state": "available", "chance": 0.109, "hits": 2},
	}
	if panel._get_percent_label(projected_result) != "44.0-52.0%":
		push_error("KO projection effects must never alter the move's direct damage percentage")
		quit(1)
		return
	if panel._get_primary_result_label(projected_result, {"hp": {"percent": 75.0}}) != "2HKO":
		push_error("The compact KO badge must use the structured projection while chance details stay in the summary")
		quit(1)
		return
	var stealth_rock_summary := panel._get_result_summary_text({
		"description": "252 Atk Sharpness Samurott-Hisui Ceaseless Edge vs. 0 HP / 0 Def Volcarona: 198-234 (63.6 - 75.2%) -- guaranteed 2HKO",
		"koProjection": {
			"state": "available",
			"chance": 1.0,
			"hits": 1,
			"text": "guaranteed OHKO after Stealth Rock",
		},
	})
	if not stealth_rock_summary.contains("guaranteed OHKO after Stealth Rock") or stealth_rock_summary.contains("guaranteed 2HKO"):
		push_error("Structured entry-hazard KO projections must override a stale direct-damage description")
		quit(1)
		return
	var envelope_summary := panel._get_result_summary_text({
		"description": panel.CONFIRMED_INFORMATION_ENVELOPE_DESCRIPTION,
	})
	if envelope_summary == panel.CONFIRMED_INFORMATION_ENVELOPE_DESCRIPTION or not _contains_fragment([envelope_summary], ["privacy-safe", "privacyveilige", "privacidade"]):
		push_error("Privacy-safe envelopes must be presented as non-exact scenario ranges")
		quit(1)
		return
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
	var immune_result := {
		"minDamage": 0,
		"maxDamage": 0,
		"minPercent": 0.0,
		"maxPercent": 0.0,
		"resultState": "supported",
	}
	if panel._get_percent_label(immune_result) != "0.0%":
		push_error("A supported immunity must render as zero damage instead of an unavailable result")
		quit(1)
		return
	if panel._get_primary_result_label(immune_result, {"hp": {"percent": 100.0}}) != panel._t("battle.calc.no_effect"):
		push_error("A supported immunity must use the localized no-effect result badge")
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
