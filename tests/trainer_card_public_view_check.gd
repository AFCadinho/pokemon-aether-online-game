extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var localization_manager := root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "public Trainer Card check can access localization")
	if localization_manager == null:
		quit(1)
		return
	var original_locale := str(localization_manager.get("current_locale"))
	localization_manager.call("set_locale", "en")
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	var overlay := packed.instantiate() if packed != null else null
	_check(overlay != null, "public Trainer Card overlay loads")
	if overlay == null:
		quit(1)
		return
	overlay.set("root_control", overlay.get_node_or_null("Control"))
	overlay.set("own_trainer_card_data", {
		"favoritePokemon": "charizard", "favoritePokemonShiny": false,
		"pokedex": {"registered": 83, "total": 1025},
		"ratings": [{"format": "aether-ou", "rating": 1234, "period": "all_time"}],
	})
	root.add_child(overlay)
	overlay.call("_show_public_trainer_card", {
		"userId": 42.0,
		"username": "misty",
		"displayName": "Misty",
		"favoritePokemon": "charizard",
		"favoritePokemonShiny": false,
		"pokedex": {"registered": 83, "total": 1025},
		"ratings": [{"format": "aether-ou", "rating": 1234, "period": "all_time"}],
		"createdAt": "2026-05-04T12:00:00Z",
		"guildName": "Cerulean Waves",
		"mapId": "private_internal_map_id",
		"appearance": {},
		"follower": {"visible": true, "species": "rattata", "shiny": false},
		"badges": {
			"badges": [
				{"region": "kanto", "badgeId": "boulder", "earned": true},
				{"region": "kanto", "badgeId": "cascade", "earned": true},
			],
		},
		"playtimeSeconds": 7200,
		"pvp": {
			"gamesPlayed": 5.0,
			"wins": 4.0,
			"losses": 1.0,
			"winRate": 80.0,
			"ranked": {"gamesPlayed": 3, "wins": 2, "losses": 1, "winRate": 66.7},
			"aetherClash": {"gamesPlayed": 2, "wins": 2, "losses": 0, "winRate": 100.0},
		},
	})
	await process_frame
	var capture_dir := OS.get_environment("POKEAETHER_TRAINER_CARD_CAPTURE")
	if not capture_dir.is_empty():
		for frame in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join("public.png"))
		var public_tabs := (overlay.get("public_trainer_card_popup") as Control).find_child("PublicTrainerCardTabs", true, false) as TabContainer
		public_tabs.current_tab = 2
		for frame in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join("pvp.png"))
		overlay.call("_hide_public_trainer_card")
		var own := overlay.get("trainer_card_popup") as Control
		own.show()
		for frame in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join("own.png"))
		root.get_node("PokedexService").set("_owned_species_cache", {"normal": ["charizard", "pikachu", "scizor"], "shiny": ["pikachu"]})
		overlay.call("_open_trainer_card_companion_picker")
		for frame in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join("picker.png"))
		print("Trainer card captures saved; own card size: ", own.size)
		overlay.queue_free()
		quit(0)
		return

	var popup := overlay.get("public_trainer_card_popup") as PanelContainer
	var tabs := popup.find_child("PublicTrainerCardTabs", true, false) as TabContainer if popup != null else null
	var overview_tab := tabs.get_node_or_null("Overview") as Control if tabs != null else null
	var badges_tab := tabs.get_node_or_null("Badges") as Control if tabs != null else null
	var pvp_tab := tabs.get_node_or_null("Pvp") as Control if tabs != null else null
	var avatar_panel := popup.find_child("PublicTrainerAvatarPanel", true, false) as PanelContainer if popup != null else null
	var avatar_preview := popup.find_child("PublicTrainerAvatarPreview", true, false) as Node2D if popup != null else null
	var profile_panel := popup.find_child("PublicTrainerProfilePanel", true, false) as PanelContainer if popup != null else null
	var profile_grid := popup.find_child("PublicTrainerProfileGrid", true, false) as GridContainer if popup != null else null
	var follower_preview := avatar_preview.find_child("RemotePokemonFollower", true, false) as Node2D if avatar_preview != null else null
	_check(popup != null, "public Trainer Card opens as a dedicated view")
	_check(popup.find_child("FavoritePokemon", true, false) is Sprite2D, "public card renders only the explicitly selected HOME companion")
	_check(_find_label(popup, "Pokédex · 83 / 1025 registered") != null, "public card displays registered Pokédex progress")
	_check(_find_label(popup, "Ranked rating: AETHER OU  1234") != null, "public PvP view labels the format and rating")
	_check(_find_label(popup, "5.0") == null, "JSON float battle counters render as whole numbers")
	overlay.call("_apply_own_trainer_card_details", overlay.get("public_trainer_card_data"))
	var own_card := overlay.get("trainer_card_popup") as Control
	_check(own_card.find_child("FavoritePokemon", true, false) is Sprite2D, "own card refresh renders the saved HOME companion")
	_check((overlay.get("trainer_card_tabs") as TabContainer).get_tab_count() == 5, "own details refresh keeps exactly one PvP tab")
	_check(
		popup != null
		and popup.get_combined_minimum_size().x <= 720.0
		and popup.get_combined_minimum_size().y <= 500.0,
		"public Trainer Card fits the designed popup bounds"
	)
	_check(
		tabs != null
		and tabs.get_tab_count() == 3
		and tabs.get_tab_title(0) == "Overview"
		and tabs.get_tab_title(1) == "Badges"
		and tabs.get_tab_title(2) == "PvP",
		"public Trainer Card exposes simple Overview, Badges and PvP navigation"
	)
	_check(
		tabs != null and tabs.get_tab_bar().focus_mode == Control.FOCUS_ALL,
		"public Trainer Card tabs support keyboard and controller focus"
	)
	_check(
		_find_label(popup, "TRAINER PASSPORT · ID 42") != null
		and _find_label(popup, "TRAINER PASSPORT · ID 42.0") == null,
		"public Trainer Card formats Trainer IDs as whole numbers"
	)
	_check(
		_find_label(popup, "Misty") != null and _find_visible_label(avatar_panel, "Misty") == null,
		"public Trainer Card shows the trainer name only in its header"
	)
	_check(
		avatar_panel != null
		and avatar_panel.size.y >= 280.0
		and avatar_preview != null
		and avatar_preview.get_node_or_null("Body") is Sprite2D
		and avatar_preview.get_node_or_null("Top") is Sprite2D
		and (follower_preview == null or not follower_preview.visible),
		"public Trainer Card fills its avatar column without showing the overworld follower"
	)
	var joined_value := _find_label(overview_tab, "04-05-2026")
	var guild_value := _find_label(overview_tab, "Cerulean Waves")
	var playtime_value := _find_label(overview_tab, "2 H.")
	_check(
		joined_value != null and joined_value.is_visible_in_tree() and joined_value.size.x > 0.0
		and guild_value != null and guild_value.is_visible_in_tree() and guild_value.size.x > 0.0
		and playtime_value != null and playtime_value.is_visible_in_tree() and playtime_value.size.x > 0.0,
		"public Trainer Card renders Joined, Guild and Playtime values visibly"
	)
	_check(
		avatar_panel != null
		and profile_panel != null
		and profile_grid != null
		and profile_grid.get_child_count() == 4
		and absf(profile_panel.size.y - avatar_panel.size.y) <= 2.0
		and _find_label(profile_panel, "TRAINER PROFILE") != null
		and _find_label(profile_panel, "ADVENTURE") == null,
		"public Trainer Card fills Overview with one balanced four-value profile grid"
	)
	_check(
		_find_label(overview_tab, "Gym Badges") == null and _find_label(overview_tab, "2 / 8") == null,
		"public Trainer Card keeps Gym Badges out of Overview"
	)
	_check(
		_find_label(badges_tab, "GYM BADGES · 2/8") != null,
		"public Trainer Card keeps Gym Badge progress in the Badges tab"
	)
	_check(
		_find_label(pvp_tab, "PVP RECORD") != null
		and _find_label(pvp_tab, "80%") != null
		and _find_label(pvp_tab, "Ranked") != null
		and _find_label(pvp_tab, "Aether Clash") != null,
		"public Trainer Card presents the official PvP total and its two sources"
	)
	_check(
		_find_label(popup, "private_internal_map_id") == null,
		"public Trainer Card never exposes a raw internal map identifier"
	)
	var message_button := _find_button(popup, "Message")
	_check(
		message_button != null and message_button.focus_mode == Control.FOCUS_ALL,
		"public Trainer Card provides a focused primary social action"
	)

	await process_frame
	await process_frame
	localization_manager.call("set_locale", original_locale)
	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()
	await process_frame
	quit(1 if failed else 0)


func _find_label(node: Node, text: String) -> Label:
	if node == null:
		return null
	if node is Label and (node as Label).text == text:
		return node as Label
	for child: Node in node.get_children():
		var result := _find_label(child, text)
		if result != null:
			return result
	return null


func _find_button(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is Button and (node as Button).text == text:
		return node as Button
	for child: Node in node.get_children():
		var result := _find_button(child, text)
		if result != null:
			return result
	return null


func _find_visible_label(node: Node, text: String) -> Label:
	var label := _find_label(node, text)
	return label if label != null and label.is_visible_in_tree() else null


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
