extends SceneTree

const DamageCalcPanel := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")
var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel := DamageCalcPanel.new()
	var content := VBoxContainer.new()
	content.name = "VBoxContainer"
	panel.add_child(content)
	root.add_child(panel)
	await process_frame
	panel.set_knowledge_snapshot({
		"format": {"formatKey": "aether-ou", "engineFormatId": "gen9nationaldex"},
		"viewerPokemon": [{"pokemonRef": "viewer:1", "active": true, "identity": {"state": "known", "value": "Mew"}}],
		"opponentPokemon": [{"pokemonRef": "opponent:1", "active": true, "identity": {"state": "known", "value": "Mew"},
			"item": {"state": "known", "value": "Leftovers"}, "ability": {"state": "known", "value": "Synchronize"},
			"hp": {"display": {"current": 50, "maximum": 100, "scale": "percent"}}}],
	})
	var variant := {
		"id": "smogon-test-a", "name": "Pivot", "item": "Heavy-Duty Boots", "ability": "Synchronize", "nature": "Bold",
		"evs": {"hp": 252, "def": 252, "spd": 4}, "ivs": {"atk": 0},
		"moves": ["Psychic", "U-turn", "Roost", "Will-O-Wisp"],
		"provenance": {"kind": "smogon", "formatId": "gen9nationaldexuu", "formatName": "National Dex UU"},
	}
	var alternative := variant.duplicate(true)
	alternative["id"] = "smogon-test-b"
	alternative["moves"][1] = "Volt Switch"
	alternative["nature"] = "Timid"
	var group := variant.duplicate(true)
	group["id"] = "smogon-test"
	group["variants"] = [variant, alternative]
	var response := {"schemaVersion": 1, "formatId": "aether-ou", "engineFormatId": "gen9nationaldex",
		"catalogProfileId": "aether-gen9-singles", "dataFormatId": "aether-gen9-singles",
		"source": "smogon_set_catalog", "species": "Mew", "sets": [group]}
	panel.show_sample_set_catalog_response("Mew", response)
	_expect(panel.sample_set_options.size() == 1, "External set groups must load")
	panel._apply_sample_set(group)
	_expect(panel.selected_sample_set_id == "smogon-test", "Selecting the default build must retain group identity")
	_expect(panel.defender_assumptions["item"] == "Leftovers", "Confirmed item must override the preset")
	_expect(panel.defender_assumptions["ivs"] == {"atk": 0}, "Non-default IVs must be applied")
	_expect(panel.defender_assumptions["assumedMoves"][1] == "U-turn" and panel.defender_assumptions["nature"] == "Bold", "Selecting a named set must apply its first Smogon build")
	_expect(not panel.defender_assumptions.has("level") and not panel.defender_assumptions.has("hp"), "Set must not replace battle level or HP")
	var host := VBoxContainer.new()
	content.add_child(host)
	panel._add_sample_set_selector(host)
	var selector := host.find_child("SampleSetSelector", true, false) as Button
	_expect(selector != null and selector.text == "National Dex UU Pivot", "Set menu must show format followed by set name")
	_expect(host.find_child("SampleSetVariantSelector", true, false) == null, "Internal source alternatives must not create a variant selector")
	panel._on_nature_option_pressed("Modest")
	_expect(panel.selected_sample_set_id == "", "Manual edits must switch to a custom scenario")
	panel._reset_to_current()
	_expect(not panel.defender_assumptions.has("assumedMoves"), "Reset must clear imported moves")
	var unknown := group.duplicate(true)
	unknown["variants"][1]["provenance"] = {"kind": "unknown"}
	_expect(not panel._is_valid_sample_group(unknown), "Unknown variant sources must be rejected")
	response["sets"] = [group]
	var broken := response.duplicate(true)
	broken["sets"][0]["variants"][1]["id"] = "smogon-test-a"
	panel.show_sample_set_catalog_response("Mew", broken)
	_expect(panel.sample_set_options.is_empty(), "Duplicate variant identities must be rejected")
	panel.queue_free()
	await process_frame
	if not failed:
		print("PASS: Smogon calculator sets use one editable default build")
	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
