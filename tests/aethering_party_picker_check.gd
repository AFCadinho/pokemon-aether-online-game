extends SceneTree

var failures := 0
var popup


func _init() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)


func _entry(slot: int, species: String, groups: Array) -> Dictionary:
	return {"pokemonId": slot + 100, "pokemon": {"speciesId": species, "species": species, "nickname": "", "ivs": {"hp": 31, "atk": 31, "def": 31, "spa": 0, "spd": 17, "spe": 31}}, "location": {"type": "party", "partySlot": slot}, "eggGroups": groups, "recipientAllowed": true, "donorAllowed": true, "shiny": slot == 0}


func _layout() -> void:
	for frame in range(4):
		await process_frame


func _run() -> void:
	# Let startup window preferences settle before exercising explicit viewport sizes.
	await _layout()
	var fit := root.get_node("WindowFit")
	var handler := Callable(fit, "apply_ui_scale")
	if root.size_changed.is_connected(handler):
		root.size_changed.disconnect(handler)
	root.min_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.mode = Window.MODE_WINDOWED
	popup = load("res://scenes/interface/aethering_popup.tscn").instantiate()
	root.add_child(popup)
	popup.show()
	var recipient := _entry(0, "pikachu", ["ground", "fairy"])
	var donor := _entry(1, "eevee", ["ground"])
	var incompatible := _entry(2, "magikarp", ["water2", "dragon"])
	var held := _entry(3, "bulbasaur", ["monster", "plant"])
	held["donorAllowed"] = false
	held["donorBlockedReason"] = "aethering_donor_held_item"
	var protected := _entry(4, "charmander", ["monster", "dragon"])
	protected["donorAllowed"] = false
	protected["donorBlockedReason"] = "aethering_donor_protected"
	var ditto := _entry(5, "ditto", ["ditto"])
	popup.candidates = [ditto, protected, recipient, incompatible, donor, held]
	popup.recipient = recipient
	popup.resources_ready = true
	popup._render()
	for dimensions in [Vector2i(1200, 720), Vector2i(640, 360), Vector2i(360, 640), Vector2i(320, 480)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		popup._fit()
		popup._open_picker(true)
		await _layout()
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(dimensions))
		print("PICKER GEOMETRY viewport=", dimensions, " panel=", popup.picker_panel.get_global_rect(), " minimum=", popup.picker_panel.get_combined_minimum_size(), " grid=", popup.picker_grid.get_combined_minimum_size())
		_check(viewport_rect.encloses(popup.picker_panel.get_global_rect()), "Modal fits viewport " + str(dimensions))
		var expected_columns := 6 if dimensions.x >= 900 else 3 if dimensions.x >= 500 else 2
		_check(popup.picker_grid.columns == expected_columns, "Responsive columns " + str(dimensions))
		_check(popup.picker_grid.get_child_count() == 6, "Six choices without a scroll list " + str(dimensions))
		for index in range(6):
			var button: Button = popup.picker_buttons[index]
			_check(viewport_rect.encloses(button.get_global_rect()), "Party slot on screen " + str(dimensions) + "/" + str(index + 1))
			_check(button.size.y >= 44, "Party slot has touch height " + str(index + 1))
		_check(popup.picker_buttons[0].disabled and not popup.picker_buttons[1].disabled, "Recipient disabled and compatible Donor selectable")
		_check(popup.picker_buttons[2].disabled and popup.picker_buttons[3].disabled and popup.picker_buttons[4].disabled and popup.picker_buttons[5].disabled, "Incompatible, held-item, protected and Ditto Donors blocked")
		_check(popup.confirm_button.disabled and popup.preview_button.disabled, "Modal freezes underlying actions")
		if DisplayServer.get_name() != "headless":
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("/tmp/aethering-party-picker-%dx%d.png" % [dimensions.x, dimensions.y])
	for locale in ["en", "nl", "pt_BR", "zh_CN"]:
		root.get_node("LocalizationManager").call("set_locale", locale)
		_check(not popup.picker_title.text.begins_with("ui.") and not popup.picker_hint.text.begins_with("ui."), "Localized modal " + locale)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	popup._unhandled_input(cancel)
	_check(not popup.picker.visible and popup.recipient["pokemonId"] == 100, "Escape closes picker without changing selection")
	popup._open_picker(false)
	_check(not popup.picker_buttons[4].disabled, "Donor-protected Pokémon remains selectable as Recipient")
	popup.picker_buttons[4].pressed.emit()
	_check(popup.recipient["pokemonId"] == 104 and popup.donor.is_empty() and not popup.picker.visible, "Recipient card selection returns directly to comparison")
	popup.free()
	print("AETHERING PARTY PICKER failures: ", failures)
	quit(1 if failures else 0)
