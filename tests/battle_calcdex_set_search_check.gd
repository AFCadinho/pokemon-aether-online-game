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
		"opponentPokemon": [{"pokemonRef": "opponent:1", "active": true, "identity": {"state": "known", "value": "Garchomp"}}],
	})
	panel.sample_set_loading = false
	panel.sample_set_options = [_fixture_set("dragon-z", "Dragonium Z"), _fixture_set("dice", "Loaded Dice"), _fixture_set("tank", "TankChomp")]
	var before := panel.defender_assumptions.duplicate(true)
	var anchor := Button.new()
	content.add_child(anchor)
	panel._open_sample_set_search(anchor)
	await process_frame
	var popup := panel.sample_set_search_popup
	var input := popup.find_child("SampleSetSearchInput", true, false) as LineEdit
	var results := popup.find_child("SampleSetSearchResults", true, false) as ItemList
	_expect(input != null and results != null, "Opening the set menu must show a search field and clickable choices")
	_expect(input.has_focus(), "Opening the set menu must focus the search field for immediate typing")
	_expect(popup.has_theme_stylebox_override("panel"), "Search popup must use the calculator style")
	_expect(results.item_count == 4, "Empty search must include Current and every available set")
	input.text = "  dRaG  "
	input.text_changed.emit(input.text)
	_expect(results.item_count == 1 and results.get_item_metadata(0) == "dragon-z", "Search must support partial case-insensitive names and surrounding whitespace")
	_expect(panel.defender_assumptions == before, "Typing must not apply a set")
	input.text_submitted.emit(input.text)
	_expect(panel.selected_sample_set_id == "dragon-z", "Enter must apply the highlighted matching set")
	_expect(panel.sample_set_search_popup == null, "Selecting a set must close the popup")
	await process_frame
	anchor = Button.new()
	content.add_child(anchor)
	panel._open_sample_set_search(anchor)
	await process_frame
	popup = panel.sample_set_search_popup
	input = popup.find_child("SampleSetSearchInput", true, false) as LineEdit
	results = popup.find_child("SampleSetSearchResults", true, false) as ItemList
	_expect(input.text == "" and results.item_count == 4, "Reopening must restore the full choice list")
	input.text = "does not exist"
	input.text_changed.emit(input.text)
	_expect(results.item_count == 1 and results.is_item_disabled(0), "A failed search must have an explicit disabled empty state")
	input.text_submitted.emit(input.text)
	_expect(panel.selected_sample_set_id == "dragon-z", "Enter on an empty result must not change the scenario")
	input.text = ""
	input.text_changed.emit("")
	_expect(results.item_count == 4, "Clearing the search must restore all choices")
	var down := InputEventKey.new()
	down.pressed = true
	down.keycode = KEY_DOWN
	input.gui_input.emit(down)
	_expect(results.get_selected_items()[0] == 2, "Arrow keys must move the highlighted result while typing")
	results.item_clicked.emit(3, Vector2.ZERO, MOUSE_BUTTON_LEFT)
	_expect(panel.selected_sample_set_id == "tank", "A result must also be selectable with a single mouse click")
	await process_frame
	anchor = Button.new()
	content.add_child(anchor)
	panel._open_sample_set_search(anchor)
	await process_frame
	popup = panel.sample_set_search_popup
	input = popup.find_child("SampleSetSearchInput", true, false) as LineEdit
	results = popup.find_child("SampleSetSearchResults", true, false) as ItemList
	input.text = "new"
	input.text_changed.emit(input.text)
	panel.sample_set_options.append(_fixture_set("new", "New set"))
	panel._refresh_sample_set_search()
	_expect(results.item_count == 1 and results.get_item_metadata(0) == "new" and input.text == "new", "A catalog refresh must preserve the query and refresh matches")
	panel._clear_sample_sets()
	_expect(panel.sample_set_search_popup == null, "Switching Pokemon must close the old search")
	panel.queue_free()
	await process_frame
	if not failed:
		print("PASS: calculator set-name search, keyboard and mouse selection")
	quit(1 if failed else 0)


func _fixture_set(id: String, label: String) -> Dictionary:
	return {"id": id, "name": label, "item": "Leftovers", "ability": "Rough Skin", "nature": "Jolly",
		"evs": {"atk": 252, "spe": 252}, "ivs": {}, "moves": ["Earthquake", "Dragon Claw"],
		"provenance": {"kind": "pokeaether_curated"}}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
