extends SceneTree

class PositionWorld extends Node:
	var events: Array[String] = []
	var result := {"success": true}
	func save_current_player_state_now() -> Dictionary:
		events.append("save_started")
		await get_tree().process_frame
		events.append("save_finished")
		return result

var failures := 0
func _init() -> void:
	call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func _run() -> void:
	var position_events: Array[String] = []
	var position_world := PositionWorld.new()
	position_world.events = position_events
	root.add_child(position_world)
	position_world.add_to_group("world")
	var position_service = load("res://tests/support/fake_daycare_position_service.gd").new()
	position_service.events = position_events
	root.add_child(position_service)
	await position_service.state()
	_check(position_events == ["save_started", "save_finished", "catalog_requested"], "Daycare waits for the counter position to save before requesting its catalog")
	position_events.clear()
	position_world.result = {"success": false, "error": "Position save blocked"}
	var save_failure: Dictionary = await position_service.state()
	_check(not save_failure.get("success", true) and save_failure.get("error") == "Position save blocked" and not "catalog_requested" in position_events, "A blocked position save stops Daycare loading and preserves its error")
	position_service.free()
	position_world.free()
	if OS.get_environment("DAYCARE_CAPTURE") != "1":
		_check(load("res://scripts/ui/ui_overlay.gd") != null, "Daycare integrates with the overlay")
	var daycare := load("res://scenes/overworld/kanto/routes/route5/daycare.tscn") as PackedScene
	_check(daycare != null, "Daycare interior loads")
	if daycare:
		var interior := daycare.instantiate()
		var npc := interior.get_node_or_null("Entities/NPCs/DaycareTrainer")
		_check(npc != null and npc.npc_definition_id == "kanto_route_5_daycare_trainer", "Trainer uses the backend NPC definition")
		if npc:
			var collision := interior.get_node("Tiles/Collision") as TileMapLayer
			var cell := collision.local_to_map(npc.position)
			var backend_root := OS.get_environment("DAYCARE_BACKEND_ROOT")
			if not backend_root.is_empty():
				var guard := FileAccess.get_file_as_string(backend_root.path_join("account-service/daycare_services.py"))
				_check("NPC_POSITION = (%s, %s)" % [int(npc.position.x), int(npc.position.y)] in guard, "Daycare backend visit position matches the map NPC")
			var reach := int(npc.manual_interaction_reach_tiles)
			var approach_available := false
			for distance in range(1, reach + 1):
				approach_available = approach_available or collision.get_cell_source_id(cell + Vector2i.DOWN * distance) == -1
			_check(collision.get_cell_source_id(cell) == -1 and approach_available, "Trainer has a walkable approach within interaction reach")
		interior.free()
	var packed := load("res://scenes/interface/daycare_popup.tscn") as PackedScene
	_check(packed != null, "Daycare popup loads")
	if packed:
		var panel := packed.instantiate()
		root.add_child(panel)
		await process_frame
		panel.visible = true
		_check(not panel.training_form.visible and panel.training_notice.get_parent().visible, "Initial loading hides empty training inputs")
		panel.call("_show_load_error", "Something went wrong")
		panel.call("_set_busy", false)
		_check(not panel.training_form.visible and panel.training_notice.get_parent().visible and not panel.refresh_button.disabled, "Initial load failure offers Refresh without an empty form")
		panel.call("_apply_state", {"pokemon": [{"pokemon": {"ownedPokemonId": 12, "species": "Pikachu", "level": 10, "experience": 1000, "evs": {"atk": 12}, "storedEvs": {"spe": 40}}, "location": {"type": "party", "partySlot": 0}}], "jobs": [], "money": 100000, "daycareLevelCap": 25})
		_check(panel.training_form.visible and not panel.training_notice.get_parent().visible, "Successful refresh restores the training form")
		_check(panel.confirm_button.has_theme_stylebox_override("disabled") and panel.tabs.get_tab_bar().has_theme_stylebox_override("tab_selected"), "Actions and tabs use Aether styles")
		_check(panel.pokemon_select.item_count == 1 and "Pikachu" in panel.pokemon_select.get_item_text(0), "Pokemon selection shows the authoritative catalog")
		_check(panel.level_input.get_parent().get_combined_minimum_size().y < 64, "Target-level row does not wrap one character per line")
		_check(panel.level_input.max_value == 25 and panel.level_input.min_value == 10, "EXP target respects the Daycare story cap")
		panel.exp_check.button_pressed = false
		panel.ev_check.button_pressed = true
		panel.ev_inputs["atk"].value = 252
		var selection: Dictionary = panel.call("_selection")
		_check(not selection.has("targetLevel") and selection.get("targetEvs", {}).get("atk") == 252, "EV-only request omits EXP training")
		panel.exp_check.button_pressed = true
		panel.ev_check.button_pressed = false
		selection = panel.call("_selection")
		_check(selection.has("targetLevel") and not selection.has("targetEvs"), "EXP-only request omits EV training")
		panel.call("_show_quote", {"previewId": "quote", "price": 13100, "requiredExperience": 0, "requiredEvs": 252, "durationSeconds": 486, "expDurationSeconds": 0, "evDurationSeconds": 486, "targetLevel": 10, "targetEvs": {"atk": 252}})
		panel.call("_set_busy", false)
		_check(panel.quote_card.visible, "Server quote has its own visible card")
		panel.call("_ask_confirm")
		_check(panel.confirmation.visible and "13100" in panel.confirmation.message_label.text, "Paid confirmation displays the server quote")
		panel.confirmation.hide_dialog()
		var api := root.get_node("DaycareService")
		api.pending_request = {"kind": "deposit", "path": "/confirm", "payload": {"previewId": "quote", "requestId": "retry"}}
		panel.call("_set_busy", false)
		_check(panel.pokemon_select.disabled and panel.retry_button.visible and not panel.retry_button.disabled, "Uncertain writes lock new selection and permit safe retry")
		api.pending_account_id = "another-account"
		api.call("_reset_for_account")
		_check(api.pending_request.is_empty(), "Pending Daycare request cannot cross an account switch")
		var test_jobs: Array = []
		for i in range(6):
			test_jobs.append({"id": "job%s" % i, "bed": i, "pokemon": {"species": "Pikachu"}, "remainingSeconds": 0 if i == 0 else 90, "plan": {"targetLevel": 50, "expSelected": true, "evSelected": true, "durationSeconds": 100, "targetEvs": {"atk": 252, "spe": 252}}})
		panel.call("_apply_state", {"pokemon": [], "jobs": test_jobs, "money": 100, "daycareLevelCap": 50})
		panel.call("_set_busy", false)
		_check(panel.job_views.size() == 6 and panel.preview_button.disabled, "Six parallel places render and block another deposit")
		_check(not panel.job_views[0]["pickup"].disabled and panel.job_views[1]["pickup"].disabled, "Only completed Pokemon can be picked up individually")
		_check(not panel.training_form.visible and panel.training_notice.get_parent().visible, "Empty catalog shows a helpful message")
		_check(panel.job_views[0]["progress"].has_theme_stylebox_override("fill"), "Training progress uses the custom Aether style")
		var locales := root.get_node("LocalizationManager")
		for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
			locales.set_locale(locale)
			var visit_message := BackendErrorLocalizationService.message({"status": 403, "body": {"detail": {"code": "daycare_visit_required", "message": "Stand beside the Daycare Trainer"}}})
			_check(visit_message == locales.text("backend.error.daycare_visit_required"), "Daycare location errors resolve in " + locale)
			_check(visit_message != locales.text("backend.error.generic"), "Daycare errors do not silently become generic in " + locale)
			_check(locales.text("ui.daycare.title") != "ui.daycare.title" and "{price}" not in locales.text("ui.daycare.confirmation", {"price": 13100, "time": "00:08:06"}), "Daycare strings resolve in " + locale)
		locales.set_locale("en")
		if OS.get_environment("DAYCARE_CAPTURE") == "1":
			panel.call("_apply_state", {"pokemon": [{"pokemon": {"ownedPokemonId": 12, "species": "Pikachu", "level": 10, "experience": 1000, "evs": {}, "storedEvs": {}}, "location": {"type": "party", "partySlot": 0}}], "jobs": [], "money": 100000, "daycareLevelCap": 100})
			panel.level_input.value = 100
			panel.ev_check.button_pressed = true
			panel.ev_inputs["atk"].value = 252
			panel.ev_inputs["spe"].value = 252
			panel.ev_inputs["hp"].value = 6
			panel.call("_show_quote", {"previewId": "quote", "price": 75950, "requiredExperience": 999000, "requiredEvs": 510, "durationSeconds": 6354, "expDurationSeconds": 6354, "evDurationSeconds": 983, "targetLevel": 100, "targetEvs": {"atk": 252, "spe": 252, "hp": 6}})
			panel.call("_set_busy", false)
			for frame in range(4):
				await process_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://.tmp/daycare")
			print("DAYCARE DESKTOP size=", panel.size, " minimum=", panel.get_combined_minimum_size(), " viewport=", panel.get_viewport_rect().size, " position=", panel.position)
			root.get_texture().get_image().save_png("res://.tmp/daycare/desktop.png")
			panel.call("_apply_state", {"pokemon": [], "jobs": test_jobs, "money": 100000, "daycareLevelCap": 100})
			panel.tabs.current_tab = 1
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.tmp/daycare/jobs.png")
			panel.tabs.current_tab = 0
			panel.state_loaded = false
			panel.call("_show_load_error", "Something went wrong. Please try again.")
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.tmp/daycare/error.png")
			panel.call("_apply_state", {"pokemon": [{"pokemon": {"ownedPokemonId": 12, "species": "Pikachu", "level": 10, "experience": 1000, "evs": {}, "storedEvs": {}}, "location": {"type": "party", "partySlot": 0}}], "jobs": [], "money": 100000, "daycareLevelCap": 100})
			panel.call("_set_busy", false)
			var window_fit := root.get_node("WindowFit")
			var resize_handler := Callable(window_fit, "apply_ui_scale")
			if root.size_changed.is_connected(resize_handler):
				root.size_changed.disconnect(resize_handler)
			root.mode = Window.MODE_WINDOWED
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			root.min_size = Vector2i.ZERO
			DisplayServer.window_set_min_size(Vector2i.ZERO)
			root.content_scale_size = Vector2i(640, 360)
			root.content_scale_factor = 1.0
			root.size = Vector2i(640, 360)
			await create_timer(0.3).timeout
			panel.call("_show_quote", {"previewId": "compact", "price": 75950, "durationSeconds": 6354})
			panel.call("_set_busy", false)
			panel.call("_fit_window")
			await process_frame
			print("DAYCARE COMPACT size=", panel.size, " minimum=", panel.get_combined_minimum_size(), " viewport=", panel.get_viewport_rect().size, " position=", panel.position)
			_check(panel.size.x <= 640 and panel.size.y <= 360, "Compact Daycare fits its viewport")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.tmp/daycare/compact.png")
		panel.free()
	quit(1 if failures else 0)
