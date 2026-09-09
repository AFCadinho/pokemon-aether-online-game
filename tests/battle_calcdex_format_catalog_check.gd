extends SceneTree

const DamageCalcPanel := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")
var failed := false
var requests: Array[Array] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel := DamageCalcPanel.new()
	var content := VBoxContainer.new()
	content.name = "VBoxContainer"
	panel.add_child(content)
	root.add_child(panel)
	panel.sample_set_catalog_requested.connect(func(species: String, format_id: String) -> void:
		requests.append([species, format_id])
	)
	panel.set_knowledge_snapshot({
		"format": {"formatKey": "pokemmo-ou", "engineFormatId": "pokemmo-ou-v1"},
		"viewerPokemon": [{"pokemonRef": "viewer:1", "active": true, "identity": {"state": "known", "value": "Mew"}}],
		"opponentPokemon": [{"pokemonRef": "opponent:1", "active": true, "identity": {"state": "known", "value": "Garchomp"}}],
	})
	_expect(requests == [["Garchomp", "pokemmo-ou"]], "PokeMMO battle must request only its own set catalog profile")
	panel.show_sample_set_catalog_response("Garchomp", {
		"schemaVersion": 1, "formatId": "pokemmo-ou", "engineFormatId": "pokemmo-ou-v1",
		"catalogProfileId": "pokemmo-ou", "source": "smogon_set_catalog", "species": "Garchomp", "sets": [],
	})
	_expect(panel.sample_set_error == "" and panel.sample_set_options.is_empty(), "A deliberately empty PokeMMO catalog must be valid")

	requests.clear()
	panel.set_knowledge_snapshot({
		"format": {"formatKey": "aether-ou", "engineFormatId": "gen9nationaldex"},
		"viewerPokemon": [{"pokemonRef": "viewer:1", "active": true, "identity": {"state": "known", "value": "Mew"}}],
		"opponentPokemon": [{"pokemonRef": "opponent:1", "active": true, "identity": {"state": "known", "value": "Charizard"}}],
	})
	panel.selected_sample_set_id = "old-base-set"
	panel.defender_assumptions = {"item": "Heavy-Duty Boots", "ability": "Blaze"}
	panel.edited_assumption_fields = {"item": true, "ability": true}
	var forme_button := MenuButton.new()
	forme_button.name = "OpponentFormeButton"
	panel.add_child(forme_button)
	panel.forme_menu_buttons["opponent"] = forme_button
	var popup := forme_button.get_popup()
	popup.add_item("Charizard Mega X", 1)
	popup.set_item_metadata(0, "Charizard Mega X")
	panel._on_forme_menu_item_pressed(1, "opponent")
	_expect(panel._get_selected_opponent_species() == "Charizard Mega X", "Selected Mega forme must become the effective set species")
	_expect(not requests.is_empty() and requests[-1] == ["Charizard Mega X", "aether-ou"], "Mega selection must reload only the Mega species catalog")
	_expect(panel.selected_sample_set_id == "", "Changing forme must clear the base-form set selection")
	_expect(str(panel.defender_assumptions.get("item", "")) != "Heavy-Duty Boots", "Changing forme must clear assumptions from the old set")

	panel.queue_free()
	await process_frame
	if not failed:
		print("PASS: format-aware and forme-aware calculator set catalogs")
	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
