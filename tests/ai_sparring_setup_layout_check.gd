extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	if not value:
		failed = true
		push_error(label)

func _run() -> void:
	var overlay = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	overlay.set("root_control", overlay.get_node("Control"))
	overlay.call("_setup_pvp_room_popup")
	var setup: Control = overlay.find_child("AiSparringPracticeHero", true, false).get_parent()
	var original_parent := setup.get_parent()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(912, 650)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	setup.reparent(viewport)
	setup.position = Vector2(16, 16)
	RenderingServer.set_default_clear_color(Color("#080f19"))
	var consent: CheckBox = overlay.get("pvp_ai_sparring_allow_spectators")
	var start: Button = overlay.get("pvp_ai_sparring_start_button")
	var input: TextEdit = overlay.get("pvp_training_team_input")
	start.disabled = false
	overlay.call("_apply_ai_sparring_start_style", start)
	(overlay.get("pvp_training_ai_bot_select") as OptionButton).add_item("AI4 Scholar")
	(overlay.get("pvp_training_ai_mode_select") as OptionButton).add_item("Beginner")
	var teams: Array[Dictionary] = [{"teamId": "layout-team", "displayName": "Balance", "pokemon": [
		{"species": "Kyurem"}, {"species": "Primarina"}, {"species": "Zapdos"},
		{"species": "Groudon"}, {"species": "Infernape"}, {"species": "Chansey"}]}]
	overlay.set("pvp_training_ai_catalog_entries", teams)
	overlay.set("pvp_training_ai_resolved_team_id", "layout-team")
	overlay.call("_refresh_pvp_training_ai_opponent_preview")
	check(not consent.button_pressed, "Spectating remains opt-in")
	for state: String in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		check(consent.has_theme_icon_override(state), "Visible checkbox icon: " + state)
	check(consent.has_theme_stylebox_override("focus"), "Keyboard focus is visible")
	check(start.get_parent() == consent.get_parent(), "Consent and start share the action row")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		root.get_node("LocalizationManager").set_locale(locale)
		root.get_node("LocalizationManager").localize_tree(setup)
		for checked: bool in [false, true]:
			consent.button_pressed = checked
			setup.size = Vector2(880, 0)
			for frame in range(8):
				await process_frame
			# Wrapped labels need the settled column width before measuring height.
			setup.size = Vector2(880, 0)
			for frame in range(8):
				await process_frame
			check(setup.size.x <= 880, "Setup fits the dialog width: " + locale)
			check(setup.get_global_rect().end.y <= viewport.size.y - 16, "Start bar fits inside the setup viewport: %s %s" % [locale, setup.get_global_rect().end.y])
			check(consent.size.x > 400, "Consent has readable space: " + locale)
			check(consent.get_theme_font("font").get_string_size(consent.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 54 <= consent.size.x, "Consent label fits without truncation: " + locale)
			check(input.size.y > 200, "Team editor uses the empty card space")
			check(consent.get_global_rect().end.x <= start.global_position.x, "Action controls do not overlap")
			var capture := OS.get_environment("POKEAETHER_SETUP_CAPTURE")
			if not capture.is_empty() and locale == "en":
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png(capture + ("-checked.png" if checked else "-unchecked.png"))
	setup.reparent(original_parent)
	overlay.free()
	viewport.queue_free()
	await process_frame
	print("AI Sparring setup layout: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
