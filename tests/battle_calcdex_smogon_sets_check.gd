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
		"format": {"formatKey": "aether-ou"},
		"viewerPokemon": [{"pokemonRef": "viewer:1", "active": true, "identity": {"state": "known", "value": "Mew"}}],
		"opponentPokemon": [{"pokemonRef": "opponent:1", "active": true, "identity": {"state": "known", "value": "Mew"},
			"item": {"state": "known", "value": "Leftovers"}, "ability": {"state": "known", "value": "Synchronize"},
			"hp": {"display": {"current": 50, "maximum": 100, "scale": "percent"}}}],
	})
	var variant := {
		"id": "smogon-test-a", "name": "Pivot", "item": "Heavy-Duty Boots", "ability": "Synchronize", "nature": "Bold",
		"evs": {"hp": 252, "def": 252, "spd": 4}, "ivs": {"atk": 0},
		"moves": ["Psychic", "U-turn", "Roost", "Will-O-Wisp"],
		"provenance": {"kind": "smogon", "formatId": "gen9nationaldexuu"},
	}
	var alternative := variant.duplicate(true)
	alternative["id"] = "smogon-test-b"
	alternative["moves"][1] = "Volt Switch"
	alternative["nature"] = "Timid"
	var group := variant.duplicate(true)
	group["id"] = "smogon-test"
	group["variants"] = [variant, alternative]
	var response := {"schemaVersion": 1, "formatId": "aether-ou", "engineFormatId": "gen9nationaldex",
		"dataFormatId": "gen9nationaldex", "source": "pokeaether_library", "species": "Mew", "sets": [group]}
	panel.show_sample_set_catalog_response("Mew", response)
	_expect(panel.sample_set_options.size() == 1, "External set groups must load")
	panel._apply_sample_set(group)
	_expect(panel.selected_sample_set_id == "smogon-test", "Default variant must retain group identity")
	_expect(panel.selected_sample_variant_id == "smogon-test-a", "Default variant identity must be selected")
	_expect(panel.defender_assumptions["item"] == "Leftovers", "Confirmed item must override the preset")
	_expect(panel.defender_assumptions["ivs"] == {"atk": 0}, "Non-default IVs must be applied")
	panel._on_sample_variant_selected(1, "smogon-test")
	_expect(panel.selected_sample_set_id == "smogon-test" and panel.selected_sample_variant_id == "smogon-test-b", "Changing variant must preserve its set group")
	_expect(panel.defender_assumptions["assumedMoves"][1] == "Volt Switch" and panel.defender_assumptions["nature"] == "Timid", "Alternative move and nature must reach calculation inputs")
	_expect(panel.defender_assumptions["item"] == "Leftovers", "Variant selection must preserve confirmed facts")
	_expect(not panel.defender_assumptions.has("level") and not panel.defender_assumptions.has("hp"), "Set must not replace battle level or HP")
	var host := VBoxContainer.new()
	content.add_child(host)
	panel._add_sample_set_selector(host)
	var selector := host.find_child("SampleSetSelector", true, false) as Button
	_expect(selector != null and "Smogon · National Dex UU" in selector.text, "Set menu must show source and format")
	var variants := host.find_child("SampleSetVariantSelector", true, false) as OptionButton
	_expect(variants != null and variants.item_count == 2 and variants.selected == 1, "Variants must have a separate selector")
	if variants != null:
		_expect("Volt Switch" in variants.get_item_tooltip(1), "Variant tooltip must describe the complete build")
	panel._on_nature_option_pressed("Modest")
	_expect(panel.selected_sample_set_id == "", "Manual edits must switch to a custom scenario")
	panel._reset_to_current()
	_expect(not panel.defender_assumptions.has("assumedMoves"), "Reset must clear imported moves")
	var mixed := group.duplicate(true)
	mixed["provenance"] = {"kind": "pokeaether_curated"}
	mixed["variants"][0]["provenance"] = {"kind": "pokeaether_curated"}
	response["sets"] = [mixed]
	panel.show_sample_set_catalog_response("Mew", response)
	_expect(panel.sample_set_options.size() == 1, "Curated and Smogon builds must share one named group")
	_expect(panel._get_sample_set_source_label(mixed) == "Aether / Smogon · National Dex UU", "Mixed group must retain both sources")
	panel._apply_sample_set(mixed)
	panel._on_sample_variant_selected(1, "smogon-test")
	_expect(panel.defender_assumptions["nature"] == "Timid", "Mixed-source alternative must remain selectable")
	var unknown := mixed.duplicate(true)
	unknown["variants"][1]["provenance"] = {"kind": "unknown"}
	_expect(not panel._is_valid_sample_group(unknown), "Unknown variant sources must be rejected")
	var broken := response.duplicate(true)
	broken["sets"][0]["variants"][1]["id"] = "smogon-test-a"
	panel.show_sample_set_catalog_response("Mew", broken)
	_expect(panel.sample_set_options.is_empty(), "Duplicate variant identities must be rejected")
	panel.queue_free()
	await process_frame
	if not failed:
		print("PASS: Smogon calculator sources, variants and confirmed facts")
	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
