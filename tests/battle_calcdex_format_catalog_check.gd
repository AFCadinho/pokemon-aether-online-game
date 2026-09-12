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
	var mmo_set := {
		"id": "rocky-helmet", "name": "Rocky Helmet", "item": "Rocky Helmet", "ability": "Rough Skin", "nature": "Impish",
		"evs": {"hp": 252, "def": 252, "spe": 4}, "ivs": {}, "moves": ["Earthquake", "Dragon Claw", "Stealth Rock", "Toxic"],
		"provenance": {"kind": "afcadinho_pokemmo", "formatId": "pokemmo-ou", "formatName": "MMO OU", "sourceUrl": "https://afcadinho.com/movesets/Garchomp"},
	}
	var mmo_variant := mmo_set.duplicate(true)
	mmo_variant["id"] = "rocky-helmet-default"
	var mmo_group := mmo_set.duplicate(true)
	mmo_group["variants"] = [mmo_variant]
	panel.show_sample_set_catalog_response("Garchomp", {
		"schemaVersion": 1, "formatId": "pokemmo-ou", "engineFormatId": "pokemmo-ou-v1",
		"catalogProfileId": "pokemmo-ou", "source": "afcadinho_pokemmo_set_catalog", "species": "Garchomp", "sets": [mmo_group],
	})
	_expect(panel.sample_set_error == "" and panel.sample_set_options.size() == 1, "The PokeMMO catalog must be available for manual selection")
	var selector_host := VBoxContainer.new()
	content.add_child(selector_host)
	panel._add_sample_set_selector(selector_host)
	var selector := selector_host.find_child("SampleSetSelector", true, false) as Button
	_expect(selector != null and selector.text == "Current", "The MMO set selector must be visible before a choice")
	selector.pressed.emit()
	await process_frame
	var set_results := panel.sample_set_search_popup.find_child("SampleSetSearchResults", true, false) as ItemList
	_expect(set_results != null and set_results.item_count == 2 and set_results.get_item_metadata(1) == "rocky-helmet", "The MMO set must appear as a manual dropdown choice")
	set_results.item_clicked.emit(1, Vector2.ZERO, MOUSE_BUTTON_LEFT)
	_expect(panel.selected_sample_set_id == "rocky-helmet", "An MMO catalog set must be manually selectable")
	_expect(panel.defender_assumptions.get("item") == "Rocky Helmet", "Selecting an MMO catalog set must apply its build")

	requests.clear()
	panel.set_knowledge_snapshot({
		"format": {"formatKey": "aether-ou", "engineFormatId": "gen9nationaldex"},
		"viewerPokemon": [{"pokemonRef": "viewer:1", "active": true, "identity": {"state": "known", "value": "Mew"}}],
		"opponentPokemon": [{"pokemonRef": "opponent:1", "active": true, "identity": {"state": "known", "value": "Garchomp"}}],
	})
	panel.selected_sample_set_id = "old-base-set"
	panel.defender_assumptions = {"item": "Heavy-Duty Boots", "ability": "Blaze"}
	panel.edited_assumption_fields = {"item": true, "ability": true}
	var forme_button := MenuButton.new()
	forme_button.name = "OpponentFormeButton"
	panel.add_child(forme_button)
	panel.forme_menu_buttons["opponent"] = forme_button
	var popup := forme_button.get_popup()
	popup.add_item("Garchomp Mega", 1)
	popup.set_item_metadata(0, "Garchomp Mega")
	panel._on_forme_menu_item_pressed(1, "opponent")
	_expect(panel._get_selected_opponent_species() == "Garchomp Mega", "Selected Mega forme must become the effective set species")
	_expect(not requests.is_empty() and requests[-1] == ["Garchomp Mega", "aether-ou"], "Mega selection must reload only the exact Mega species catalog")
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
