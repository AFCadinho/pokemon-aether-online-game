extends SceneTree

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)

func _run() -> void:
	for frame in range(4):
		await process_frame
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var overlay = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	overlay.set("root_control", host)
	overlay.call("_setup_pokemon_summary_popup", "aethering-count-check")
	var payload := {"species": "Tyranitar", "speciesId": "tyranitar", "level": 20, "ownedPokemonId": 57, "types": ["rock", "dark"], "gender": "M", "item": "leftovers", "ivs": {"hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 31}, "stats": {"hp": 88, "atk": 67, "def": 59, "spa": 48, "spd": 55, "spe": 36}, "currentHp": 88, "maxHp": 88, "aetheringCount": 12}
	var pokemon := PokemonFactory.create_pokemon_from_backend_payload(payload)
	_check(pokemon.aethering_count == 12, "Server history is materialized in runtime Pokémon")
	_check(not pokemon.to_battle_dict().has("aetheringCount"), "History is not included in battle mutation data")
	_check(PokemonFactory.create_pokemon_from_backend_payload(pokemon.to_persistence_dict()).aethering_count == 12, "Local display persistence retains server history")
	var legacy := payload.duplicate(true)
	legacy.erase("aetheringCount")
	_check(PokemonFactory.create_pokemon_from_backend_payload(legacy).aethering_count == 0, "New or legacy payloads display zero")
	legacy["aetheringCount"] = -1
	_check(PokemonFactory.create_pokemon_from_backend_payload(legacy).aethering_count == 0, "Invalid negative display values are clamped")
	overlay.set("pokemon_summary_preview_pokemon", pokemon)
	# Build the production card without invoking the full HUD's network lifecycle.
	# The generic read-only flag suppresses world/battle checks on this unattached harness.
	overlay.set("pokemon_summary_mode", "readonly")
	overlay.set("pokemon_summary_active_tab", "general")
	overlay.call("_refresh_pokemon_summary")
	overlay.call("_set_pokemon_summary_sprite", pokemon, false)
	for frame in range(4):
		await process_frame
	var baseline_size: Vector2 = overlay.get("pokemon_summary_popup").size
	overlay.set("pokemon_summary_mode", "interactive")
	overlay.set("pokemon_summary_active_tab", "ivs")
	overlay.call("_refresh_pokemon_summary_tab_buttons")
	var popup := overlay.get("pokemon_summary_popup") as PanelContainer
	popup.show()
	var stack := overlay.get("pokemon_summary_content_stack") as VBoxContainer
	for locale in ["en", "nl", "pt_BR", "zh_CN"]:
		root.get_node("LocalizationManager").call("set_locale", locale)
		for count in [0, 1, 12, 123456]:
			pokemon.aethering_count = count
			overlay.call("_render_pokemon_summary_content", pokemon)
			for frame in range(3):
				await process_frame
			var history := stack.get_node_or_null("AetheringHistory") as PanelContainer
			_check(history != null and history.get_index() == 2, "History follows the six IV tiles " + locale + " / " + str(count))
			_check(history != null and (history.find_child("Count", true, false) as Label).text == "%d×" % count, "Exact count displayed " + locale + " / " + str(count))
			_check(history != null and not history.tooltip_text.begins_with("ui."), "History explanation translated " + locale)
			_check(history != null and history.get_global_rect().end.y <= stack.get_global_rect().end.y + 1, "History stays inside fixed IV content " + locale)
			_check(popup.size.is_equal_approx(baseline_size), "History preserves Summary geometry " + locale)
		pokemon.aethering_count = 12
		overlay.call("_render_pokemon_summary_content", pokemon)
		for frame in range(3):
			await process_frame
		if DisplayServer.get_name() != "headless":
			RenderingServer.force_draw()
			var screenshot := root.get_texture().get_image()
			screenshot.save_png("/tmp/aethering-summary-count-%s.png" % locale)
			var ratio := Vector2(screenshot.get_size()) / root.get_visible_rect().size
			var card := popup.get_global_rect()
			var crop := Rect2i(card.position * ratio, card.size * ratio)
			screenshot.get_region(crop).save_png("/tmp/aethering-summary-count-card-%s.png" % locale)
	overlay.set("pokemon_summary_active_tab", "evs")
	overlay.call("_render_pokemon_summary_content", pokemon)
	_check(stack.get_node_or_null("AetheringHistory") == null, "History is confined to the IV tab")
	root.get_node("LocalizationManager").call("set_locale", "en")
	for key in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(key) as Node
		if loader != null:
			loader.free()
	overlay.free()
	host.free()
	print("AETHERING SUMMARY COUNT failures: ", failures)
	quit(1 if failures else 0)
