extends SceneTree

var failures := 0
var capture := OS.get_environment("DAYCARE_PICKER_CAPTURE") == "1"
var sizes: Array[Vector2i] = [Vector2i(1280, 960), Vector2i(520, 700), Vector2i(360, 640), Vector2i(320, 480), Vector2i(640, 360)]

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _entry(slot: int, id: int, species: String, allowed := true) -> Dictionary:
	return {"pokemon": {"ownedPokemonId": id, "species": species, "speciesId": species.to_lower(), "level": 20, "experience": 8000, "shiny": slot == 0, "evs": {}, "storedEvs": {}}, "location": {"type": "party", "partySlot": slot}, "eligible": allowed, "blockedReason": null if allowed else "pokemon_locked_for_loan"}

func _state() -> Dictionary:
	var party: Array = [_entry(5, 15, "Gengar"), _entry(1, 11, "Pikachu", false), _entry(4, 42, "Charmeleon"), _entry(2, 22, "Magikarp"), _entry(0, 10, "Eevee")]
	return {"party": party, "pokemon": party.filter(func(e: Dictionary): return e.eligible), "jobs": [], "money": 100000, "daycareLevelCap": 50}

func _quote() -> Dictionary:
	return {"previewId": "fixture", "price": 900, "requiredExperience": 8000, "durationSeconds": 51, "expDurationSeconds": 51, "expSelected": true, "evSelected": false, "startLevel": 20, "targetLevel": 21, "priceBreakdown": {"start": 500, "experience": 400, "evs": 0}}

func _settle() -> void:
	for _frame in range(10):
		await process_frame

func _run() -> void:
	var api := root.get_node("DaycareService")
	_check(not root.get_node("AuthService").is_authenticated(), "Fixtures must not use an authenticated player")
	var localization := root.get_node("LocalizationManager")
	for screen: Vector2i in sizes:
		var view := SubViewport.new()
		view.size = screen
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
			localization.set_locale(locale)
			var panel = load("res://scenes/interface/daycare_popup.tscn").instantiate()
			view.add_child(panel)
			panel.show()
			panel._apply_state(_state())
			panel._set_busy(false)
			await _settle()
			_check(panel._selection().pokemonId == 10, "First selection follows Party slot, not server order or Pokémon ID")
			panel._show_quote(_quote())
			await _settle()
			var frame_size: Vector2 = panel.size
			var frame_position: Vector2 = panel.position
			panel._open_picker()
			await _settle()
			_check(panel.picker.visible and panel.picker.top_level and panel.picker.get_parent() == panel, "Picker overlays the form")
			_check(panel.picker_buttons.size() == 6 and panel.picker_rows.size() == 6, "All six Party slots stay visible")
			_check(panel.picker_grid.columns == (6 if screen.x >= 900 else 3 if screen.x >= 500 else 2), "Responsive Party columns")
			_check(panel.picker_rows[0].pokemon.ownedPokemonId == 10 and panel.picker_rows[4].pokemon.ownedPokemonId == 42, "Cards keep actual Party positions")
			_check(panel.picker_buttons[1].disabled and panel.picker_buttons[3].disabled and panel.picker_rows[3].is_empty(), "Loaned and empty slots cannot be selected")
			_check(not panel.picker_buttons[0].disabled and not panel.picker_buttons[4].disabled, "Eligible slots remain available")
			_check(not panel._picker_reason(panel.picker_rows[1]).begins_with("ui."), "Eligibility reason is translated")
			for button: Button in panel.picker_buttons:
				_check(Rect2(Vector2.ZERO, Vector2(screen)).encloses(button.get_global_rect()), "Card fits " + str(screen) + " " + locale)
			_check(Rect2(Vector2.ZERO, Vector2(screen)).encloses(panel.picker_panel.get_global_rect()), "Whole modal fits " + str(screen) + " " + locale)
			_check(Rect2(Vector2.ZERO, Vector2(screen)).encloses(panel.picker_cancel.get_global_rect()), "Cancel fits " + str(screen) + " " + locale)
			_check(panel.size == frame_size and panel.position == frame_position, "Opening the picker keeps the Daycare frame stable " + str(screen) + " " + locale + " before=" + str(frame_size) + " after=" + str(panel.size))
			if capture and locale == "en":
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://.tmp/daycare-party-picker")
				view.get_texture().get_image().save_png("res://.tmp/daycare-party-picker/%sx%s.png" % [screen.x, screen.y])
			panel._picker_pressed(1, 11)
			_check(panel.picker.visible and panel._selection().pokemonId == 10, "Direct disabled selection is rejected")
			_check(panel.picker_cancel.get_node(panel.picker_cancel.focus_next) == panel.picker_close, "Tab focus stays inside the modal")
			panel._close_picker()
			_check(panel._selection().pokemonId == 10 and not panel.quote.is_empty(), "Cancel retains the selected Pokémon and quote")
			panel._open_picker()
			panel.picker_buttons[4].pressed.emit()
			_check(not panel.picker.visible and panel._selection().pokemonId == 42 and panel.quote.is_empty(), "Choosing another Party slot closes the popup and invalidates the quote")
			panel._show_quote(_quote())
			panel._open_picker()
			panel._picker_pressed(4, 42)
			_check(not panel.quote.is_empty(), "Selecting the same Pokémon preserves the quote")
			var refreshed := _state()
			refreshed.party.reverse()
			refreshed.pokemon.reverse()
			panel._apply_state(refreshed)
			_check(panel._selection().pokemonId == 42, "Refresh preserves identity when array order changes")
			panel._open_picker()
			panel.picker_rows[4] = _entry(4, 100, "Bulbasaur")
			panel.picker_buttons[4].pressed.emit()
			_check(panel.picker.visible and panel._selection().pokemonId == 42, "Old slot callback cannot choose a replacement Pokémon")
			panel._close_picker()
			api.pending_request = {"kind": "deposit"}
			panel._open_picker()
			_check(not panel.picker.visible, "An unresolved write blocks changing Pokémon")
			api.pending_request.clear()
			panel._set_busy(true)
			panel._open_picker()
			_check(not panel.picker.visible, "Busy requests block opening the picker")
			panel._set_busy(false)
			var blocked := _state()
			blocked.pokemon = []
			for entry: Dictionary in blocked.party:
				entry.eligible = false
				entry.blockedReason = "daycare_protected"
			panel._apply_state(blocked)
			panel._open_picker()
			_check(panel.picker.visible and panel.preview_button.disabled and panel.picker_buttons.all(func(b: Button): return b.disabled), "An all-blocked Party remains inspectable without permitting training")
			panel.close_popup()
			_check(not panel.picker.visible, "Closing the Daycare closes its picker")
			panel.free()
		view.free()
	localization.set_locale("en")
	print("DAYCARE_PARTY_PICKER_OK" if failures == 0 else "DAYCARE_PARTY_PICKER_FAILED: " + str(failures))
	quit(0 if failures == 0 else 1)
