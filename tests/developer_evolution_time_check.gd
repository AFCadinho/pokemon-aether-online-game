extends SceneTree

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(12.0).timeout.connect(func() -> void:
		push_error("Developer evolution time check did not finish")
		quit(1)
	)
	root.get_node("ThievingService").set_process(false)
	root.get_node("RockSmashService").set_process(false)
	var auth := root.get_node("AuthService")
	auth.session_token = "developer-evolution-fixture"
	auth.current_user = {"id": 1, "permissions": ["generating"]}
	root.get_node("GatewayApiConfig").cached_url = "http://127.0.0.1:1"
	var clock := root.get_node("WorldTimeService")
	var transport = load("res://tests/support/evolution_time_party_transport.gd").new()
	root.add_child(transport)
	var overlay = load("res://tests/support/evolution_time_overlay_probe.gd").new()
	overlay.transport = transport
	overlay.fixture_pokemon.species = "Rockruff"
	overlay.evolution_prompt_popup = PanelContainer.new()
	overlay.evolution_prompt_popup.visible = false

	clock.set_debug_time(0)
	transport.responses.append(_response("Rockruff", "lycanroc-midnight"))
	var queued: int = overlay._queue_reward_evolution_prompts_from_reward({
		"levelUps": [{"pokemonId": 77, "previousLevel": 24, "level": 25}],
		"evolutionPrompts": [{"pokemonId": 77, "fromSpecies": "Rockruff", "toSpeciesId": "lycanroc"}],
	})
	_check(queued == 0 and overlay.evolution_prompt_queue.is_empty(), "default-clock Midday offer is not queued under a night override")
	await _settle()
	_check(overlay.evolution_active_prompt.get("toSpeciesId") == "lycanroc-midnight", "night review displays the server's Midnight target")
	_check(transport.requests[-1].get("debugTimeHour") == 0 and transport.requests[-1].get("confirm") == false, "review sends developer night without confirming an evolution")

	transport.responses.append(_response("Rockruff", "lycanroc"))
	overlay._on_dev_world_time_selected(2)
	_check(overlay.evolution_active_prompt.is_empty() and not overlay.evolution_prompt_popup.visible, "changing time removes the stale open target while refreshing")
	await _settle()
	_check(overlay.evolution_active_prompt.get("toSpeciesId") == "lycanroc", "changing to Day refreshes the open offer to Midday")
	_check(transport.requests[-1].get("debugTimeHour") == 12, "day review uses the selected hour")
	var requests_before: int = transport.requests.size()
	overlay.evolution_prompt_processing = true
	overlay._on_dev_world_time_selected(4)
	_check(clock.get_utc_datetime().hour == 12 and transport.requests.size() == requests_before, "time cannot change during an evolution confirmation")
	overlay.evolution_prompt_processing = false

	# This species had no default-clock offer: levelUps alone must still trigger
	# a developer review instead of relying on the reward's evolutionPrompts.
	overlay.evolution_active_prompt.clear()
	overlay.evolution_prompt_popup.visible = false
	overlay.fixture_pokemon.species = "Rockruff Dusk"
	clock.set_debug_time(19)
	transport.responses.append(_response("Rockruff Dusk", "lycanroc-dusk"))
	overlay._queue_reward_evolution_prompts_from_reward({"levelUps": [{"pokemonId": 77, "level": 25}], "evolutionPrompts": []})
	await _settle()
	_check(overlay.evolution_active_prompt.get("toSpeciesId") == "lycanroc-dusk", "Evening can offer Dusk even if the default-clock reward had no target")
	_check(transport.requests[-1].get("debugTimeHour") == 19, "dusk uses the actual Evening hour rather than a day/night label")

	overlay.fixture_pokemon.species = "Rockruff"
	transport.responses.append(_response("Rockruff", "lycanroc"))
	overlay._on_dev_world_time_selected(0)
	await _settle()
	_check(not clock.is_debug_time_active() and not transport.requests[-1].has("debugTimeHour"), "Default restores server-authoritative game time")

	# Hold a Night answer until a newer Day request has already returned.
	transport.hold_next = true
	transport.responses.append(_response("Rockruff", "lycanroc-midnight"))
	overlay._on_dev_world_time_selected(4)
	transport.responses.append(_response("Rockruff", "lycanroc"))
	overlay._on_dev_world_time_selected(2)
	await _settle()
	transport.release_held_response.emit()
	await _settle()
	_check(overlay.evolution_active_prompt.get("toSpeciesId") == "lycanroc" and overlay.evolution_prompt_queue.is_empty(), "late Night response cannot replace the newer Day review")

	transport.responses.append({"success": false, "error": "Fixture review failure"})
	overlay._on_dev_world_time_selected(4)
	await _settle()
	_check(overlay.evolution_active_prompt.is_empty() and overlay.evolution_prompt_queue.is_empty(), "failed developer review does not fall back to a wrong default-clock target")
	_check(overlay.messages[-1].contains("Fixture review failure"), "developer receives a review failure message")
	transport.hold_next = true
	transport.responses.append(_response("Rockruff", "lycanroc-midnight"))
	overlay._on_dev_world_time_selected(4)
	auth.session_token = "different-evolution-fixture"
	transport.release_held_response.emit()
	await _settle()
	_check(overlay.evolution_active_prompt.is_empty(), "a reply from the previous session cannot open an evolution prompt")
	auth.session_token = "developer-evolution-fixture"

	# The real request builder is shared by review and confirmation.
	clock.set_debug_time(0)
	transport.responses.append(_response("Rockruff", "lycanroc-midnight"))
	await transport.evolve_pokemon(77, "lycanroc-midnight", true)
	_check(transport.requests[-1].get("confirm") == true and transport.requests[-1].get("debugTimeHour") == 0, "confirmation forwards the same selected developer hour")
	auth.current_user = {"id": 2, "permissions": [], "roles": []}
	_check(not transport._evolution_request_payload("lycanroc", true).has("debugTimeHour"), "ordinary accounts never forward a leftover developer clock")
	auth.current_user = {"id": 1, "roles": [{"id": "owner"}]}
	_check(transport._evolution_request_payload("lycanroc-midnight", true).get("debugTimeHour") == 0, "fixed Owner permission fallback agrees with the developer selector")
	var inventory := root.get_node("InventoryService")
	_check(inventory._pokemon_item_use_request_payload("peat-block", 1).get("debugTimeHour") == 0, "timed item use forwards authorized developer game time")
	auth.current_user = {"id": 2, "permissions": [], "roles": []}
	_check(not inventory._pokemon_item_use_request_payload("peat-block", 1).has("debugTimeHour"), "ordinary item use cannot forward a leftover developer clock")
	var item_preview = load("res://scripts/ui/bag_item_effect_preview.gd")
	var timed_item := {"effects": [{"type": "evolve_item", "time_of_day": "night"}]}
	for hour: int in [0, 4, 21, 23]:
		_check(item_preview.unmet_evolution_time(timed_item, hour) == "", "Peat Block preview allows night hour %s" % hour)
	for hour: int in [5, 12, 20]:
		_check(item_preview.unmet_evolution_time(timed_item, hour) == "night", "Peat Block preview blocks day hour %s" % hour)
	_check(item_preview.unmet_evolution_time({"effects": [{"type": "evolve_item"}]}, 12) == "", "ordinary evolution items remain usable during daytime")
	overlay.fixture_pokemon.species = "Ursaring"
	overlay.fixture_pokemon.owned_pokemon_id = 77
	overlay.bag_item_use_pending_item = {"id": "peat-block", "pokemonCompatibilityKnown": true,
		"compatiblePokemonIds": [77], "gameplay": timed_item}
	clock.set_debug_time(12)
	_check(not overlay._bag_item_use_preview_for_pokemon(overlay.fixture_pokemon, "peat-block", 1).get("canApply", true), "real Bag preview disables Peat Block during game daytime")
	clock.set_debug_time(22)
	_check(overlay._bag_item_use_preview_for_pokemon(overlay.fixture_pokemon, "peat-block", 1).get("canApply", false), "same Bag compatibility becomes usable during game nighttime")
	overlay.bag_item_use_pending_item.clear()
	var icon_resolver = load("res://scripts/services/item_icon_resolver.gd")
	for item_id: String in ["stick", "leaders-crest", "peat-block", "strawberry-sweet"]:
		var icon: Texture2D = icon_resolver.load_icon(item_id)
		_check(icon != null and not icon.resource_path.ends_with("000.png"), "%s has its own existing item sprite" % item_id)
		for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
			_check(root.get_node("ItemLocalization").has_translation(item_id, locale), "%s has item text for %s" % [item_id, locale])

	# A replacement move can satisfy a level-up requirement for an ordinary player.
	clock.clear_debug_time()
	auth.current_user = {"id": 2, "permissions": [], "roles": []}
	overlay.fixture_pokemon.species = "Piloswine"
	overlay.evolution_active_prompt.clear()
	overlay.evolution_prompt_popup.visible = false
	overlay.move_learn_queue.append({"pokemonId": 77, "moveId": "ancient-power"})
	transport.responses.append(_response("Piloswine", "mamoswine"))
	await overlay._refresh_evolutions_after_level_up_move(77)
	_check(overlay.evolution_active_prompt.is_empty() and overlay.evolution_prompt_queue.size() == 1, "replacement-move review waits for the move learning queue")
	_check(not transport.requests[-1].has("debugTimeHour"), "ordinary replacement-move review uses normal game time")
	overlay.move_learn_queue.clear()
	overlay._show_next_evolution_prompt()
	_check(overlay.evolution_active_prompt.get("toSpeciesId") == "mamoswine", "newly learned Ancient Power can immediately offer Mamoswine")
	transport.responses.append({"success": true, "body": {"pokemon": {}, "party": {}, "evolutionCandidates": []}})
	await overlay._refresh_evolutions_after_level_up_move(77)
	_check(overlay.evolution_active_prompt.is_empty() and overlay.evolution_prompt_queue.is_empty(), "replacing a required move clears its old evolution target")
	transport.hold_next = true
	transport.responses.append(_response("Piloswine", "mamoswine"))
	overlay._refresh_evolutions_after_level_up_move(77)
	transport.responses.append({"success": true, "body": {"pokemon": {}, "party": {}, "evolutionCandidates": []}})
	await overlay._refresh_evolutions_after_level_up_move(77)
	transport.release_held_response.emit()
	await _settle()
	_check(overlay.evolution_active_prompt.is_empty() and overlay.evolution_prompt_queue.is_empty(), "a late review from the previous move selection cannot restore its old target")

	clock.clear_debug_time()
	auth.current_user = {}
	auth.session_token = ""
	overlay.evolution_prompt_popup.free()
	overlay.free()
	transport.free()
	quit(1 if failures else 0)


func _response(source: String, target: String) -> Dictionary:
	return {"success": true, "body": {
		"pokemon": {}, "party": {}, "skipped": true, "evolution": null,
		"evolutionCandidates": [{"fromSpecies": source, "toSpeciesId": target, "toSpecies": target, "level": 25}],
	}}


func _settle() -> void:
	for _frame in range(4):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures += 1
		push_error(message)
