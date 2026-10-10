extends SceneTree
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(15).timeout.connect(func() -> void: quit(1))
	for autoload: Node in root.get_children():
		autoload.set_process(false)
	root.get_node("GatewayApiConfig").cached_url = "http://127.0.0.1:1"
	root.get_node("ThievingService").set_process(false)
	root.get_node("RockSmashService").set_process(false)
	root.get_node("WalkingEvolutionService").set_process(false)
	root.get_node("LocalizationManager").set_locale("en")
	var conditions_view = load("res://scripts/ui/evolution_conditions_view.gd")
	var partner_lines: Array[String] = conditions_view.requirement_lines({"rule": {"trade_species": "shelmet"}})
	_check(partner_lines.size() == 1 and partner_lines[0].contains("Shelmet") and partner_lines[0].contains("Linking Cord"), "partner conditions explain the required real trade")
	var shed_lines: Array[String] = conditions_view.requirement_lines({"rule": {"trigger": "shed", "evolves_with": "ninjask"}})
	_check(shed_lines.size() == 1 and shed_lines[0].contains("Ninjask") and shed_lines[0].contains("party"), "Shedinja conditions explain the bonus and free party slot")
	var auth := root.get_node("AuthService")
	auth.session_token = "evolution-conditions-fixture"
	auth.current_user = {"id": 1}
	var overlay = load("res://tests/support/evolution_conditions_overlay_probe.gd").new()
	var control := Control.new()
	root.add_child(control)
	overlay.root_control = control
	overlay.party_slot_context_menu = PopupMenu.new()
	control.add_child(overlay.party_slot_context_menu)
	var pokemon := Pokemon.new("Pawmo", 20)
	pokemon.owned_pokemon_id = 77
	pokemon.can_evolve = true
	overlay._populate_party_slot_context_menu(pokemon, 0)
	_check(overlay.party_slot_context_menu.get_item_index(4) >= 0, "evolvable Pokemon show Evolution conditions before requirements are met")
	pokemon.can_evolve = false
	overlay._populate_party_slot_context_menu(pokemon, 0)
	_check(overlay.party_slot_context_menu.get_item_index(4) == -1, "final-stage Pokemon do not show the extra context action")
	pokemon.can_evolve = true
	overlay.fixture_conditions = {"pokemonId": 77, "walkSteps": 640, "isLead": true,
		"evolutions": [{"speciesId": "pawmot", "name": "Pawmot", "gameplaySupported": true,
			"conditionsMet": false, "rule": {"min_walk_steps": 1000}}]}
	await overlay._show_evolution_conditions(pokemon)
	var dialog: Control = overlay.evolution_conditions_dialog
	await process_frame
	var bar := dialog.find_child("WalkingProgress", true, false) as ProgressBar
	_check(bar != null and bar.value == 640, "party action opens a separate popup with individual progress")
	_check(dialog.panel.size.x <= root.get_visible_rect().size.x and dialog.panel.size.y <= root.get_visible_rect().size.y,
		"conditions popup fits inside the viewport")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(argument.trim_prefix("--capture="))
	_check(root.get_node("GameState").is_overworld_input_locked(), "conditions popup blocks overworld movement")
	dialog.canceled.emit()
	await process_frame
	_check(not root.get_node("GameState").is_overworld_input_locked(), "closing the popup releases the movement lock")
	overlay.hold_reply = true
	overlay._show_evolution_conditions(pokemon)
	await process_frame
	overlay.evolution_conditions_dialog.queue_free()
	await process_frame
	overlay.release_conditions_reply.emit()
	await process_frame
	_check(not is_instance_valid(overlay.evolution_conditions_dialog), "late response cannot reopen a closed conditions popup")
	pokemon = null
	control.free()
	overlay.free()
	auth.clear_session()
	await process_frame
	await process_frame
	quit(1 if failed else 0)

func _check(ok: bool, text: String) -> void:
	if ok:
		print("PASS ", text)
	else:
		failed = true
		push_error(text)
