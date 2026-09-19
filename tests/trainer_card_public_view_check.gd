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
		"favoritePokemon": "greninja", "favoritePokemonShiny": false,
		"pokedex": {"seen": 126, "caught": 83, "shinyCaught": 7, "registered": 83, "total": 1025},
		"ratings": [
			{"format": "aether-ou", "rating": 1234, "period": "all_time"},
			{"format": "aether-uu", "rating": 1198, "period": "all_time"},
			{"format": "aether-randbats", "rating": 1092, "period": "all_time"},
			{"format": "aether-doubles", "rating": 1260, "period": "all_time"},
		],
	})
	root.add_child(overlay)
	overlay.call("_show_public_trainer_card", {
		"userId": 42.0,
		"username": "misty",
		"displayName": "Misty",
		"favoritePokemon": "greninja",
		"favoritePokemonShiny": false,
		"pokedex": {"seen": 126, "caught": 83, "shinyCaught": 7, "registered": 83, "total": 1025},
		"ratings": [
			{"format": "aether-ou", "rating": 1234, "period": "all_time"},
			{"format": "aether-uu", "rating": 1198, "period": "all_time"},
			{"format": "aether-randbats", "rating": 1092, "period": "all_time"},
			{"format": "aether-doubles", "rating": 1260, "period": "all_time"},
		],
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
		overlay.call("_open_trainer_card_companion_picker")
		var companion_dialog := overlay.find_child("TrainerCardCompanionPicker", true, false) as ConfirmationDialog
		_check(companion_dialog != null and companion_dialog.borderless, "companion picker uses the Trainer Card shell instead of the default dialog title bar")
		var picker := overlay.find_child("OwnedCompanions", true, false) as ItemList
		picker.set_meta("owned_companions", [
			{"species": "articuno", "shiny": false}, {"species": "charizard", "shiny": false},
			{"species": "dragonite", "shiny": false}, {"species": "garchomp", "shiny": false},
			{"species": "lucario", "shiny": false}, {"species": "magikarp", "shiny": false},
			{"species": "mew", "shiny": false}, {"species": "pikachu", "shiny": false},
			{"species": "rattata", "shiny": false}, {"species": "scizor", "shiny": false},
			{"species": "starly", "shiny": false}, {"species": "tyranitar", "shiny": false},
			{"species": "zapdos", "shiny": false}, {"species": "greninja", "shiny": true},
		])
		overlay.call("_fill_trainer_card_companions", picker, "")
		_check(picker.get_v_scroll_bar().custom_minimum_size.x >= 10.0, "companion picker reserves a visible scrollbar rail")
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
	var public_companion := popup.find_child("FavoritePokemon", true, false) as Sprite2D
	var public_art := public_companion.get_parent().find_child("PublicTrainerAvatarPreview", false, false) if public_companion != null else null
	_check(public_companion != null, "public card renders only the explicitly selected HOME companion")
	_check(
		public_companion != null
		and public_companion.get_parent().get_children().find(public_companion) < public_companion.get_parent().get_children().find(public_art)
		and public_companion.texture.get_image().get_used_rect().size.x * public_companion.scale.x >= 100.0
		and public_companion.position.x > 110.0
		and public_companion.position.y < 250.0,
		"public companion stays compact beside and behind the Trainer portrait"
	)
	for field: String in ["seen", "caught", "shinyCaught"]:
		var tile := popup.find_child("Dex_%s" % field, true, false)
		_check(tile != null, "public card displays %s counter" % field)
		var expected := {"seen": "126", "caught": "83", "shinyCaught": "7"}
		_check(_find_label(tile, expected[field]) != null, "public %s counter has its server value" % field)
	var ranked_tiers := popup.find_child("RankedRatingTiers", true, false) as HFlowContainer
	_check(ranked_tiers != null and ranked_tiers.get_child_count() == 4, "public PvP gives each ranked tier its own flexible card")
	_check(_find_label(ranked_tiers, "OU") != null and _find_label(ranked_tiers, "1234") != null, "public PvP tier cards show a compact format and rating")
	_check(ranked_tiers != null and ranked_tiers.get_combined_minimum_size().x <= 520.0, "ranked tiers wrap instead of widening the Trainer Card")
	_check(_find_label(popup, "5.0") == null, "JSON float battle counters render as whole numbers")
	overlay.call("_apply_own_trainer_card_details", overlay.get("public_trainer_card_data"))
	var own_card := overlay.get("trainer_card_popup") as Control
	for field: String in ["seen", "caught", "shinyCaught"]:
		var tile := own_card.find_child("Dex_%s" % field, true, false)
		var expected := {"seen": "126", "caught": "83", "shinyCaught": "7"}
		_check(tile != null and _find_label(tile, expected[field]) != null, "own %s counter refreshes" % field)
	var legacy := overlay.call("_create_trainer_card_dex_panel", {"pokedex": {"registered": 83}}) as Control
	for field: String in ["seen", "caught", "shinyCaught"]:
		_check(_find_label(legacy.find_child("Dex_%s" % field, true, false), "—") != null, "missing %s is not presented as zero" % field)
	legacy.free()
	_check(own_card.get_combined_minimum_size().x <= 720.0 and own_card.get_combined_minimum_size().y <= 500.0, "own counters fit the designed popup bounds")
	localization_manager.call("set_locale", "nl")
	var dutch_dex := overlay.call("_create_trainer_card_dex_panel", {"pokedex": {"seen": 1025, "caught": 1025, "shinyCaught": 1025}}) as Control
	_check(_find_label(dutch_dex, "Shiny verkregen") != null, "Dutch shiny counter is localized")
	_check(dutch_dex.get_combined_minimum_size().x <= 412.0, "Dutch counters fit with four-digit totals")
	dutch_dex.free()
	localization_manager.call("set_locale", "en")
	_check(own_card.find_child("FavoritePokemon", true, false) is Sprite2D, "own card refresh renders the saved HOME companion")
	_check((overlay.get("trainer_card_tabs") as TabContainer).get_tab_count() == 5, "own details refresh keeps exactly one PvP tab")
	var choices := ItemList.new()
	choices.set_meta("owned_companions", [{"species": "pikachu", "shiny": true}, {"species": "scizor", "shiny": false}])
	overlay.call("_fill_trainer_card_companions", choices, "")
	_check(choices.item_count == 3 and bool(choices.get_item_metadata(1).get("shiny")), "companion choices preserve the server-owned shiny variant")
	overlay.call("_fill_trainer_card_companions", choices, "pika")
	_check(choices.item_count == 2 and choices.get_item_metadata(1).get("species") == "pikachu", "companion search only filters owned choices")
	choices.free()
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
	# Locale refresh schedules chat layout updates across two frames.
	for frame in range(3):
		await process_frame
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
