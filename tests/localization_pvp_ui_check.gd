extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "PvP localization check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	var settings_manager := root.get_node("SettingsManager")
	var original_name_language := str(settings_manager.get("content_name_language"))
	settings_manager.set("content_name_language", "localized")
	await _check_pvp_runtime_translation()
	settings_manager.set("content_name_language", original_name_language)
	localization_manager.call("set_locale", original_locale)
	await process_frame
	quit(1 if failed else 0)


func _check_pvp_runtime_translation() -> void:
	var auth_service := root.get_node_or_null("AuthService")
	var original_user: Dictionary = (auth_service.get("current_user") as Dictionary).duplicate(true) if auth_service != null else {}
	if auth_service != null:
		auth_service.call("apply_current_user", {"permissions": []})
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "localized PvP overlay loads")
	if packed == null:
		if auth_service != null:
			auth_service.call("apply_current_user", original_user)
		return

	var overlay := packed.instantiate()
	overlay.set("root_control", overlay.get_node_or_null("Control"))
	localization_manager.call("set_locale", "nl")
	overlay.call("_setup_pvp_room_popup")
	overlay.call("_setup_pvp_queue_compact_panel")
	overlay.call("_setup_pvp_match_countdown_overlay")
	overlay.call("_setup_pvp_mode_menu")

	var popup := overlay.get("pvp_room_popup") as PanelContainer
	var title := overlay.get("pvp_popup_title_label") as Label
	var subtitle := overlay.get("pvp_popup_subtitle_label") as Label
	var ranked_tabs := overlay.get("pvp_ranked_tabs") as TabContainer
	var rewards_tabs := overlay.get("pvp_ranked_rewards_tabs") as TabContainer
	var objectives_filter := overlay.get("pvp_ranked_objectives_filter") as OptionButton
	var room_workspace := overlay.find_child("RoomWorkspace", true, false) as HBoxContainer
	var room_type_card := overlay.find_child("BattleTypeCard", true, false) as PanelContainer
	var room_flow_card := overlay.find_child("RoomFlowCard", true, false) as PanelContainer
	var room_join_button := overlay.get("pvp_room_join_mode_button") as Button
	var room_create_button := overlay.get("pvp_room_create_mode_button") as Button
	var room_ai_button := overlay.get("pvp_room_ai_mode_button") as Button
	var ai_sparring_menu_button := overlay.get("pvp_mode_ai_sparring_button") as Button
	var ai_sparring_tabs := overlay.get("pvp_ai_sparring_tabs") as TabContainer
	var ai_sparring_history_list := overlay.get("pvp_ai_sparring_history_list") as VBoxContainer
	var ai_sparring_history_clear := overlay.get("pvp_ai_sparring_history_clear_button") as Button
	var ai_sparring_intro := overlay.find_child("AiSparringIntro", true, false) as Label
	var ai_sparring_practice_hero := overlay.find_child("AiSparringPracticeHero", true, false) as PanelContainer
	var ai_sparring_start := overlay.get("pvp_ai_sparring_start_button") as Button
	var ai_sparring_tier_select := overlay.get("pvp_ai_sparring_tier_select") as OptionButton
	var ai_sparring_team_source := overlay.get("pvp_ai_sparring_team_source_select") as OptionButton
	var ai_sparring_party_preview := overlay.get("pvp_ai_sparring_party_preview") as VBoxContainer
	var ai_sparring_party_preview_title := overlay.get("pvp_ai_sparring_party_preview_title") as Label
	var ai_sparring_party_preview_grid := overlay.get("pvp_ai_sparring_party_preview_grid") as HBoxContainer
	var ai_sparring_catalog_search := overlay.get("pvp_ai_sparring_catalog_search") as LineEdit
	var ai_sparring_catalog_tier := overlay.get("pvp_ai_sparring_catalog_tier") as OptionButton
	var ai_sparring_catalog_results := overlay.get("pvp_ai_sparring_catalog_results") as VBoxContainer
	var ai_sparring_catalog_player_search := overlay.get("pvp_ai_sparring_player_catalog_search") as LineEdit
	var ai_sparring_catalog_player_suggestion_list := overlay.get("pvp_ai_sparring_player_catalog_suggestion_list") as VBoxContainer
	var ai_sparring_catalog_use_player := overlay.get("pvp_ai_sparring_catalog_use_player_button") as Button
	var ai_sparring_catalog_use_opponent := overlay.get("pvp_ai_sparring_catalog_use_opponent_button") as Button
	var ai_sparring_catalog_export := overlay.get("pvp_ai_sparring_catalog_export_button") as Button
	var ai_sparring_catalog_team_grid := overlay.get("pvp_ai_sparring_catalog_team_grid") as GridContainer
	var room_spectate_button := overlay.get("pvp_room_spectate_mode_button") as Button
	var casual_button := overlay.get("pvp_room_casual_type_button") as Button
	var training_button := overlay.get("pvp_room_training_type_button") as Button
	var room_type_note := overlay.get("pvp_room_type_note") as Label
	var room_flow_hint := overlay.get("pvp_room_flow_hint") as Label
	var training_input := overlay.get("pvp_training_room_team_input") as TextEdit
	var ai_training_input := overlay.get("pvp_training_team_input") as TextEdit
	var ai_team_step := overlay.find_child("AiSparringTeamStep", true, false) as PanelContainer
	var ai_opponent_step := overlay.find_child("AiSparringOpponentStep", true, false) as PanelContainer
	var ai_sparring_setup_steps := ai_team_step.get_parent() as HBoxContainer if ai_team_step != null else null
	var training_ai_mode_row := overlay.get("pvp_training_ai_mode_row") as HBoxContainer
	var training_ai_mode_select := overlay.get("pvp_training_ai_mode_select") as OptionButton
	var training_ai_bot_select := overlay.get("pvp_training_ai_bot_select") as OptionButton
	var training_ai_team_source_row := overlay.get("pvp_training_ai_team_source_row") as HBoxContainer
	var training_ai_team_source_select := overlay.get("pvp_training_ai_team_source_select") as OptionButton
	var training_ai_custom_team_input := overlay.get("pvp_training_ai_custom_team_input") as TextEdit
	var training_ai_archetype_row := overlay.get("pvp_training_ai_archetype_row") as HBoxContainer
	var training_ai_archetype_select := overlay.get("pvp_training_ai_archetype_select") as OptionButton
	var training_ai_team_row := overlay.get("pvp_training_ai_team_row") as HBoxContainer
	var training_ai_team_search := overlay.get("pvp_training_ai_team_search") as LineEdit
	var training_ai_team_suggestions := overlay.get("pvp_training_ai_team_suggestions") as PanelContainer
	var training_ai_team_suggestion_list := overlay.get("pvp_training_ai_team_suggestion_list") as VBoxContainer
	var ai_opponent_preview := overlay.get("pvp_training_ai_opponent_preview") as VBoxContainer
	var ai_opponent_preview_title := overlay.get("pvp_training_ai_opponent_preview_title") as Label
	var ai_opponent_preview_grid := overlay.get("pvp_training_ai_opponent_preview_grid") as HBoxContainer
	var training_preview := overlay.get("pvp_training_team_preview_section") as VBoxContainer
	var training_preview_title := overlay.get("pvp_training_team_preview_title") as Label
	var training_preview_grid := overlay.get("pvp_training_team_preview_grid") as HBoxContainer
	var room_code_input := overlay.get("pvp_room_code_input") as LineEdit
	var room_form_title := overlay.get("pvp_room_form_title") as Label
	var room_timer_check := overlay.get("pvp_timer_enabled_check") as CheckBox
	var room_timer_tier := overlay.get("pvp_timer_tier_select") as OptionButton
	var room_tier_row := overlay.get("pvp_room_tier_row") as HBoxContainer
	var room_tier_select := overlay.get("pvp_room_tier_select") as OptionButton
	var room_status := overlay.get("pvp_room_status_label") as Label
	var queue_status := overlay.get("pvp_queue_status_label") as Label
	var format_select := overlay.get("pvp_queue_select") as OptionButton
	var leaderboard_scope := overlay.get("pvp_leaderboard_scope_select") as OptionButton
	var rewards_status := overlay.find_child("RankedRewardsStatus", true, false) as Label
	var compact_status := overlay.get("pvp_queue_compact_status_label") as Label

	_check(title != null and title.text == "Ranked", "PvP ranked title renders in Dutch")
	_check(subtitle != null and subtitle.text.begins_with("Competitieve"), "PvP subtitle renders in Dutch")
	_check(ranked_tabs != null and ranked_tabs.get_tab_title(0) == "Spelen", "PvP tab title renders in Dutch")
	_check(ranked_tabs != null and ranked_tabs.get_tab_title(4) == "Beloningen", "Ranked Rewards tab renders in Dutch")
	_check(rewards_tabs != null and rewards_tabs.get_tab_count() == 5, "Ranked Rewards exposes five scalable destinations")
	_check(rewards_tabs != null and rewards_tabs.get_tab_title(0) == "Overzicht", "Reward overview subtab renders in Dutch")
	_check(rewards_tabs != null and rewards_tabs.get_tab_title(1) == "Per gevecht", "Battle reward subtab renders in Dutch")
	_check(rewards_tabs != null and rewards_tabs.get_tab_title(4) == "Seizoen", "Season reward subtab renders in Dutch")
	_check(rewards_status != null and rewards_status.text == "BELONINGEN NIET ACTIEF", "Ranked reward availability renders in Dutch")
	var active_ranked_queues: Array[Dictionary] = [
		{
			"id": "ranked_queue_v1",
			"name": "Ranked Queue",
			"mode": "ranked",
			"status": "active",
			"formatKey": "aether-ou",
			"formatName": "Aether OU",
			"battlePointRewards": {
				"enabled": true,
				"currency": "battle_points",
				"policyVersion": "ranked_bp_v1",
				"winAmount": 1000,
				"lossAmount": 500,
			},
		},
		{
			"id": "ranked_aether_uu_queue_v1",
			"name": "Aether UU Ranked Queue",
			"mode": "ranked",
			"status": "active",
			"formatKey": "aether-uu",
			"formatName": "Aether UU",
			"battlePointRewards": {"enabled": false},
		},
	]
	overlay.call("_populate_pvp_queue_select", active_ranked_queues)
	_check(format_select.item_count == 2, "Ranked matchmaking exposes both Aether OU and Aether UU")
	_check(format_select.get_item_text(0) == "Aether OU" and format_select.get_item_text(1) == "Aether UU", "Ranked tier labels come from the server queue catalog")
	overlay.call("_update_pvp_active_format_from_queue_id", "ranked_aether_uu_queue_v1")
	var leaderboard_title := overlay.get("pvp_leaderboard_title_label") as Label
	_check(leaderboard_title != null and leaderboard_title.text == "Aether UU-ranglijst", "Ranked data headings follow the selected tier")
	overlay.call("_update_pvp_active_format_from_queue_id", "ranked_queue_v1")
	var rewards_intro := overlay.get("pvp_ranked_rewards_intro_label") as Label
	var reward_win_labels: Array = overlay.get("pvp_ranked_battle_reward_win_value_labels") as Array
	_check(rewards_status != null and rewards_status.text == "BATTLE REWARDS ACTIEF", "Ranked reward availability follows the authoritative queue state")
	_check(rewards_intro != null and rewards_intro.text.contains("1.000"), "Active Ranked reward copy explains the Dutch payout")
	_check(not reward_win_labels.is_empty() and (reward_win_labels[0] as Label).text == "1.000 BP", "Active payout values come from the queue policy")
	_check(objectives_filter != null and objectives_filter.item_count == 3, "Objectives exposes daily, weekly and seasonal filters")
	_check(objectives_filter != null and objectives_filter.get_item_text(0) == "Dagelijks", "Objective filter renders in Dutch")
	_check_ranked_dropdown_style(objectives_filter, "Objective period")
	_check(room_join_button != null and room_join_button.text == "Deelnemen", "Private room action renders in Dutch")
	_check(room_ai_button != null and room_ai_button.text == "Tegen AI", "AI training action renders in Dutch")
	_check(
		room_ai_button != null
		and room_ai_button.has_theme_stylebox_override("normal")
		and room_ai_button.has_theme_stylebox_override("hover")
		and room_ai_button.has_theme_stylebox_override("pressed")
		and room_ai_button.has_theme_stylebox_override("focus"),
		"AI training action uses the interactive room-button styling"
	)
	_check(ai_sparring_menu_button != null, "AI Sparring has its own PvP destination")
	_check(ai_sparring_tabs != null and ai_sparring_tabs.get_tab_count() == 5, "AI Sparring separates practice, catalog, history, bot information and statistics")
	_check(ai_sparring_tabs.get_tab_title(4) == "Statistieken", "Statistics tab is localized")
	overlay.set("pvp_ai_sparring_stats_data", {"success": true, "bots": [
		{"bot": "ai4", "version": "v1", "completed": 2, "unconfirmed": 1, "sufficient": false},
		{"bot": "ai5", "version": "v4", "completed": 10.0, "unconfirmed": 0, "sufficient": true, "winRate": 0.6, "nativeRate": 0.9, "fallbackRate": 0.1, "averageTurns": 25.6}
	]})
	overlay.call("_render_ai_sparring_stats")
	var stats_list := overlay.get("pvp_ai_sparring_stats_list") as VBoxContainer
	for bot_id: String in ["ai4", "ai5"]:
		var stats_card := stats_list.get_node("AiSparringStatsCard_" + bot_id + ("_hard_v4" if bot_id == "ai5" else "_beginner_v1")) as PanelContainer
		_check(stats_card.get_node("CardPadding").get_theme_constant("margin_left") == 18, "Statistics match bot profile card padding")
		var stats_portrait := stats_card.find_child("BotPortrait", true, false) as TextureRect
		_check(stats_portrait.texture != null and stats_portrait.texture.resource_path.ends_with("veteran-gen7.png" if bot_id == "ai5" else "scientist-gen7.png"), "Statistics use the correct trainer portrait")
		var metrics := stats_card.find_child("Metrics", true, false) as GridContainer
		_check(metrics.get_child_count() == (6 if bot_id == "ai5" else 4), "Metric tiles retain all applicable statistics")
	var responsive_grid := GridContainer.new()
	for width: int in [320, 500, 800]:
		responsive_grid.size.x = width
		overlay.call("_resize_ai_sparring_stats_grid", responsive_grid)
		_check(responsive_grid.columns == (1 if width == 320 else 2 if width == 500 else 3), "Metric grid adapts to narrow and wide panels")
	responsive_grid.free()
	var stats_text := ""
	for stats_label: Node in stats_list.find_children("*", "Label", true, false):
		stats_text += (stats_label as Label).text + "\n"
	_check(stats_text.contains("AI4 Scholar") and stats_text.contains("AI5 Grandmaster"), "Statistics show both bot versions")
	_check(stats_text.contains("Nog onvoldoende gegevens") and stats_text.contains("60%") and stats_text.contains("90%") and stats_text.contains("26") and not stats_text.contains("10.0") and not stats_text.contains("25.6"), "Statistics show whole numbers and distinguish small samples from measured rates")
	_check(stats_list.get_node_or_null("AiSparringOlderStatisticsToggle") == null, "No archive toggle without older statistics")
	var archived_stats: Dictionary = overlay.get("pvp_ai_sparring_stats_data")
	archived_stats["bots"].append({"bot": "ai5", "version": "v1", "completed": 12, "sufficient": true})
	overlay.call("_render_ai_sparring_stats")
	var older_stats := stats_list.get_node("AiSparringOlderStatistics") as VBoxContainer
	var older_toggle := stats_list.get_node("AiSparringOlderStatisticsToggle") as Button
	_check(not older_stats.visible and older_stats.get_child_count() == 1, "Historical AI5 card is collapsed by default")
	_check(older_toggle.text == "Bekijk oudere versies", "Archive toggle is localized")
	older_toggle.button_pressed = true
	_check(older_stats.visible and older_toggle.text == "Verberg oudere versies", "Older statistics can be expanded")
	older_toggle.button_pressed = false
	_check(not older_stats.visible, "Older statistics can be collapsed again")
	# New v1 difficulties are current cards, not archived Hard versions.
	archived_stats["bots"].append({"bot": "ai5", "difficulty": "nightmare", "version": "v1", "completed": 0})
	archived_stats["bots"].append({"bot": "ai5", "difficulty": "intermediate", "version": "v1", "completed": 0})
	var saved_modes: Variant = overlay.get("pvp_training_ai_available_modes").duplicate()
	var test_modes: Array[String] = ["ai4", "active", "nightmare"]
	overlay.set("pvp_training_ai_available_modes", test_modes)
	overlay.call("_render_ai_sparring_stats")
	_check(stats_list.get_node_or_null("AiSparringStatsCard_ai5_nightmare_v1") != null, "Nightmare has a separate current card")
	_check(stats_list.get_node_or_null("AiSparringStatsCard_ai5_intermediate_v1") == null, "Unavailable Intermediate without results stays hidden")
	test_modes.append("intermediate")
	overlay.call("_render_ai_sparring_stats")
	_check(stats_list.get_node_or_null("AiSparringStatsCard_ai5_intermediate_v1") != null, "Available Intermediate has a separate current card")
	overlay.set("pvp_training_ai_available_modes", saved_modes)
	overlay.set("pvp_ai_sparring_stats_data", {"success": false})
	overlay.call("_render_ai_sparring_stats")
	_check(stats_list.get_child_count() == 0, "Failed statistics refresh does not leave stale rates visible")
	_check(ai_sparring_tabs.get_tab_title(3) == "Over de bots", "Bot information tab is localized")
	for bot_id: String in ["ai4", "ai5"]:
		var card := overlay.find_child("AiSparringAboutCard_" + bot_id, true, false)
		_check(card != null, "Each bot has its own profile card")
		var padding := card.get_node("CardPadding") as MarginContainer
		_check(padding.get_theme_constant("margin_left") >= 18, "Bot copy has comfortable padding")
		var portrait := card.find_child("AiSparringAboutPortrait_" + bot_id, true, false) as TextureRect
		_check(portrait != null and portrait.texture != null, "Bot trainer portrait loads")
		var expected_sprite := "scientist-gen7.png" if bot_id == "ai4" else "veteran-gen7.png"
		_check(portrait.texture.resource_path.ends_with(expected_sprite), "Each bot uses its assigned trainer")
	var bot_versions: Dictionary = overlay.get("pvp_ai_sparring_about_versions")
	_check(bot_versions.size() == 6, "About has independent status for all six difficulties")
	overlay.call("_apply_ai_sparring_bot_versions", {"success": true, "bots": [
		{"id": "ai5", "version": "v4", "available": false},
		{"id": "intermediate", "version": "v1", "available": false},
		{"id": "expert", "version": "v1", "available": true},
		{"id": "nightmare", "version": "v1", "available": true}
	]})
	_check(bot_versions["nightmare"].text.contains("Beschikbaar om tegen te spelen") and bot_versions["nightmare"].text.contains("Serverversie: v1"), "Nightmare keeps its own version and availability when Hard is disabled")
	_check(bot_versions["intermediate"].text.contains("Momenteel niet beschikbaar"), "Intermediate reports its own availability")
	_check(bot_versions["expert"].text.contains("Beschikbaar om tegen te spelen") and bot_versions["expert"].text.contains("Serverversie: v1"), "Expert reports its own version and availability")
	overlay.call("_apply_ai_sparring_bot_versions", {"success": false})
	_check(bot_versions["nightmare"].text.contains("Beschikbaarheid niet bevestigd"), "Failed refresh clears all difficulty availability")
	_check(bot_versions["ai5"].text.contains("Serverversie niet bevestigd"), "Missing server data does not claim a bot version")
	overlay.set("pvp_ai_sparring_bot_versions", {"ai5": {"version": "Native Z v4", "available": true}})
	overlay.call("_refresh_ai_sparring_about")
	_check(bot_versions["ai5"].text.contains("Native Z v4"), "About displays the confirmed server version")
	overlay.set("pvp_ai_sparring_bot_versions", {"ai5": {"version": "v5", "releaseStatus": "test", "available": true}})
	var gateway_config := root.get_node("GatewayApiConfig")
	var original_gateway_url: String = str(gateway_config.get("cached_url"))
	for gateway_url: String in ["http://localhost:8000", "http://127.0.0.1:8000", "http://[::1]:8000", "https://test.localhost"]:
		gateway_config.set("cached_url", gateway_url)
		overlay.call("_refresh_ai_sparring_about")
		_check(bot_versions["ai5"].text.contains("Serverversie: v5") and bot_versions["ai5"].text.contains("Testversie"), "Local server keeps the actual version and separate test label: " + gateway_url)
	for gateway_url: String in ["https://api.pokeaether.com", "https://api.pokeaether.com/", "https://staging.example.com", "https://localhost.example.com", "https://localhost@api.pokeaether.com"]:
		gateway_config.set("cached_url", gateway_url)
		overlay.call("_refresh_ai_sparring_about")
		_check(bot_versions["ai5"].text.contains("Serverversie: v5") and not bot_versions["ai5"].text.contains("Testversie"), "Remote server hides test label without changing actual version: " + gateway_url)
		_check(bot_versions["ai5"].text.contains(str(localization_manager.call("text", "ui.pvp.ai_sparring.about.available"))), "Hiding test status preserves availability")
		_check(str(overlay.get("pvp_ai_sparring_bot_versions")["ai5"]["releaseStatus"]) == "test", "Presentation does not rewrite server metadata")
	gateway_config.set("cached_url", "http://localhost:8000")
	overlay.call("_refresh_ai_sparring_about")
	_check(bot_versions["ai5"].text.contains("Serverversie: v5") and bot_versions["ai5"].text.contains("Testversie"), "Version number and test status are displayed separately")
	overlay.set("pvp_ai_sparring_bot_versions", {"ai5": {"version": "v5", "releaseStatus": "active", "available": true}})
	overlay.call("_refresh_ai_sparring_about")
	_check(bot_versions["ai5"].text.contains("Serverversie: v5") and not bot_versions["ai5"].text.contains("Testversie"), "Release status does not change the version number")
	gateway_config.set("cached_url", original_gateway_url)
	overlay.set("pvp_training_ai_resolved_team_id", "keep-selected-opponent")
	overlay.call("_apply_ai_sparring_bot_versions", {"success": true, "bots": [{"id": "ai5", "version": "Native Z v4", "available": true}]})
	_check(overlay.get("pvp_training_ai_resolved_team_id") == "keep-selected-opponent", "Refreshing bot information does not reroll the opponent")
	overlay.call("_apply_ai_sparring_bot_versions", {"success": false})
	_check(bot_versions["ai5"].text.contains("Serverversie niet bevestigd"), "A failed refresh clears an old confirmed version")
	overlay.set("pvp_training_ai_resolved_team_id", "")
	_check(ai_sparring_tabs != null and ai_sparring_tabs.get_tab_title(0) == "Vrij oefenen", "Free sparring tab renders in Dutch")
	_check(ai_sparring_tabs != null and ai_sparring_tabs.get_tab_title(1) == "Teamcatalogus", "Team catalog tab renders in Dutch")
	_check(ai_sparring_tabs != null and ai_sparring_tabs.get_tab_title(2) == "Matchhistorie", "Match history tab renders in Dutch")
	_check(ai_sparring_tabs != null and ai_sparring_tabs.custom_minimum_size.y == 595.0, "AI Sparring keeps a stable workspace height across tabs")
	_check(ai_sparring_tabs != null and ai_sparring_tabs.current_tab == 0, "Free sparring is the default AI destination")
	_check(ai_sparring_tier_select != null and ai_sparring_tier_select.item_count == 1 and ai_sparring_tier_select.get_item_text(0) == "Aether OU" and str(ai_sparring_tier_select.get_selected_metadata()) == "aether-ou", "Free sparring defaults to Aether OU before the catalog loads")
	_check(
		ai_sparring_practice_hero != null
		and ai_sparring_practice_hero.get_parent().get_parent() == ai_sparring_tabs.get_tab_control(0),
		"AI trainer introduction belongs only to the Free Sparring tab content"
	)
	overlay.call("_render_pvp_ai_sparring_match_history", [{
		"battleId": "battle-history-test",
		"result": "win",
		"aiLevel": 5,
		"endedAt": "2026-09-04T12:00:00+00:00",
		"durationSeconds": 125,
		"turns": 14,
		"teamDisplayName": "Balance Sample",
		"playerRoster": [{"species": "Gholdengo"}],
		"opponentRoster": [{"species": "Iron Treads"}],
	}])
	_check(ai_sparring_history_list != null and ai_sparring_history_list.get_child_count() == 1, "AI Sparring renders completed match-history cards")
	_check(ai_sparring_history_clear != null and not ai_sparring_history_clear.disabled, "AI Sparring enables clearing only after history has entries")
	var history_labels := ai_sparring_history_list.get_child(0).find_children("*", "Label", true, false) if ai_sparring_history_list != null and ai_sparring_history_list.get_child_count() == 1 else []
	var history_text := ""
	for history_label: Label in history_labels:
		history_text += history_label.text + " "
	_check(history_text.contains("Tegenstander: Grandmaster — Hard"), "Match history identifies Grandmaster Hard as the opponent")
	_check(history_text.contains("Gewonnen"), "Match history shows the localized player result")
	_check(overlay.find_child("AiVeteranPortrait", true, false) != null, "AI Sparring presents the Veteran trainer identity")
	_check(ai_team_step != null, "Free sparring groups the player's team as its first step")
	_check(
		ai_sparring_setup_steps != null
		and is_equal_approx(ai_sparring_setup_steps.custom_minimum_size.y, 385.0)
		and ai_team_step.size_flags_vertical == Control.SIZE_EXPAND_FILL
		and ai_opponent_step.size_flags_vertical == Control.SIZE_EXPAND_FILL,
		"AI setup cards fill one stable shared-height row"
	)
	_check(
		ai_sparring_team_source != null
		and ai_sparring_team_source.item_count == 3
		and str(ai_sparring_team_source.get_item_metadata(1)) == "party",
		"Free sparring offers the current party as a team source"
	)
	_check(str(ai_sparring_team_source.get_item_metadata(2)) == "catalog", "Free sparring offers catalog teams as a player source")
	var catalog_archetypes: Array[String] = ["balance"]
	var catalog_entries: Array[Dictionary] = [{
		"teamId": "catalog-balance",
		"homeTierId": "aether-ou",
		"displayName": "Zapdos Balance",
		"authors": ["Catalog Author"],
		"archetype": "balance",
		"eligibleTierIds": ["none", "aether-ou", "aether-uu"],
		"pokemon": [{"species": "Zapdos"}, {"species": "Gholdengo"}],
	}]
	overlay.set("pvp_training_ai_catalog_archetypes", catalog_archetypes)
	overlay.set("pvp_training_ai_catalog_entries", catalog_entries)
	var catalog_tiers: Array[Dictionary] = [
		{"tierId": "none", "tierName": "Open"},
		{"tierId": "aether-ou", "tierName": "Aether OU"},
		{"tierId": "aether-uu", "tierName": "Aether UU"},
	]
	overlay.set("pvp_training_ai_tiers", catalog_tiers)
	overlay.call("_refresh_ai_sparring_tier_options")
	overlay.call("_refresh_ai_sparring_player_catalog_options")
	overlay.call("_refresh_ai_sparring_catalog_filters")
	overlay.call("_refresh_ai_sparring_catalog_view")
	_check(ai_sparring_catalog_search != null and ai_sparring_catalog_search.placeholder_text.begins_with("Zoek Pokémon"), "Catalog search renders in Dutch")
	_check(ai_sparring_tier_select.item_count == 2 and ai_sparring_tier_select.get_item_text(0) == "Aether OU" and ai_sparring_tier_select.get_item_text(1) == "Aether UU", "Free sparring offers only Aether OU and Aether UU")
	_check(ai_sparring_catalog_tier != null and ai_sparring_catalog_tier.item_count == 2 and str(ai_sparring_catalog_tier.get_selected_metadata()) == "aether-ou", "Team catalog defaults to OU without Open or All tiers")
	_check(ai_sparring_catalog_results != null and ai_sparring_catalog_results.get_child_count() == 1, "Catalog renders matching team cards")
	_check(
		overlay.call("_ai_sparring_team_display_tier", {
			"homeTierId": "aether-uu",
			"eligibleTierIds": ["none"],
		}) == "",
		"Catalog cards do not label a currently ineligible team as Aether UU"
	)
	_check(
		overlay.call("_ai_sparring_team_display_tier", {
			"homeTierId": "aether-uu",
			"eligibleTierIds": ["none", "aether-uu"],
		}) == "aether-uu",
		"Catalog cards keep the home-tier badge for a currently eligible team"
	)
	var catalog_card := ai_sparring_catalog_results.get_child(0) as PanelContainer if ai_sparring_catalog_results != null and ai_sparring_catalog_results.get_child_count() == 1 else null
	_check(catalog_card != null and catalog_card.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "The complete catalog team card is selectable")
	_check(catalog_card != null and catalog_card.find_children("*", "Button", true, false).is_empty(), "Catalog roster icons are not separate button targets")
	_check(catalog_card != null and catalog_card.has_meta("hover_style"), "Catalog cards provide a dedicated hover style")
	if catalog_card != null:
		overlay.call("_on_ai_sparring_catalog_team_card_hover_changed", catalog_card, true)
		_check(catalog_card.get_theme_stylebox("panel") == catalog_card.get_meta("hover_style"), "Catalog cards use the hover style on pointer entry")
		overlay.call("_on_ai_sparring_catalog_team_card_hover_changed", catalog_card, false)
		_check(catalog_card.get_theme_stylebox("panel") == catalog_card.get_meta("normal_style"), "Catalog cards restore their resting style on pointer exit")
	var catalog_card_text := ""
	for catalog_label: Label in catalog_card.find_children("*", "Label", true, false) if catalog_card != null else []:
		catalog_card_text += catalog_label.text
	_check(not catalog_card_text.contains("Catalog Author"), "Catalog cards omit author labels from the player view")
	ai_sparring_catalog_search.text = "Gholdengo"
	overlay.call("_refresh_ai_sparring_catalog_view")
	_check(ai_sparring_catalog_results.get_child_count() == 1, "Catalog search matches a Pokémon inside a team")
	ai_sparring_catalog_search.text = "Pikachu"
	overlay.call("_refresh_ai_sparring_catalog_view")
	_check(ai_sparring_catalog_results.get_child_count() == 0, "Catalog search hides teams without the requested Pokémon")
	ai_sparring_catalog_search.text = ""
	_check(ai_sparring_catalog_player_search != null and ai_sparring_catalog_player_search.text == "Zapdos Balance", "Catalog teams populate the player search field")
	ai_sparring_team_source.select(2)
	overlay.call("_on_ai_sparring_team_source_selected", 2)
	_check(ai_sparring_catalog_player_search.visible, "Choosing a catalog player team reveals its search field")
	ai_sparring_catalog_player_search.text = "Balance"
	_check(ai_sparring_catalog_player_suggestion_list.get_child_count() == 1, "Typing in the player catalog field filters its matching teams")
	overlay.call("_on_ai_sparring_player_catalog_suggestion_selected", "catalog-balance")
	_check(str(overlay.call("_selected_ai_sparring_player_catalog_team_id")) == "catalog-balance", "Selecting a player catalog search result chooses that exact team")
	_check(not ai_training_input.visible, "Choosing a catalog player team hides the PokéPaste field")
	ai_sparring_team_source.select(0)
	overlay.call("_on_ai_sparring_team_source_selected", 0)
	overlay.set("pvp_ai_sparring_catalog_selected_team_id", "catalog-balance")
	var catalog_sets: Array = []
	for species: String in ["Zapdos", "Gholdengo", "Landorus-Therian", "Heatran", "Ogerpon-Wellspring", "Zamazenta"]:
		catalog_sets.append({
			"species": species,
			"item": "Leftovers",
			"ability": "Pressure",
			"nature": "Timid",
			"teraType": "Steel",
			"level": 100,
			"shiny": false,
			"evs": {"HP": 0, "Atk": 0, "Def": 4, "SpA": 252, "SpD": 0, "Spe": 252},
			"ivs": {"HP": 31, "Atk": 0, "Def": 31, "SpA": 31, "SpD": 31, "Spe": 31},
			"moves": ["Thunderbolt", "Volt Switch", "Roost", "Heat Wave"],
		})
	overlay.set("pvp_ai_sparring_catalog_detail", {"pokemon": catalog_sets})
	overlay.call("_render_ai_sparring_catalog_detail")
	_check(ai_sparring_catalog_use_player != null and not ai_sparring_catalog_use_player.disabled, "Catalog selection enables use as player team")
	_check(ai_sparring_catalog_use_opponent != null and not ai_sparring_catalog_use_opponent.disabled, "Catalog selection enables train-against action")
	_check(ai_sparring_catalog_export != null and not ai_sparring_catalog_export.disabled, "Catalog selection enables PokéPaste export")
	var catalog_export := str(overlay.call("_ai_sparring_catalog_pokepaste"))
	_check(catalog_export.contains("Zapdos @ Leftovers") and catalog_export.contains("Tera Type: Steel"), "Catalog export preserves Showdown set details")
	_check(catalog_export.contains("EVs: 4 Def / 252 SpA / 252 Spe") and catalog_export.contains("- Thunderbolt"), "Catalog export uses PokéPaste EV and move syntax")
	_check(ai_sparring_catalog_team_grid != null and ai_sparring_catalog_team_grid.columns == 3, "Catalog presents sets in a compact three-column grid")
	_check(ai_sparring_catalog_team_grid != null and ai_sparring_catalog_team_grid.get_child_count() == 6, "Catalog shows the complete six-Pokémon team at once")
	_check(overlay.call("_ai_sparring_stat_spread", catalog_sets[0]["evs"], 0) == "4 Def / 252 SpA / 252 Spe", "Catalog PokéPaste view omits zero EV values")
	_check(overlay.call("_ai_sparring_stat_spread", catalog_sets[0]["ivs"], 31) == "0 Atk", "Catalog PokéPaste view only shows non-default IV values")
	_check(ai_training_input != null and ai_training_input.visible, "Free sparring starts with Showdown team input visible")
	if ai_sparring_team_source != null:
		ai_sparring_team_source.select(1)
		overlay.call("_on_ai_sparring_team_source_selected", 1)
	_check(ai_training_input != null and not ai_training_input.visible, "Choosing the current party hides the paste field")
	_check(ai_sparring_party_preview != null and ai_sparring_party_preview.visible, "Choosing the current party reveals its compact team preview")
	_check(ai_sparring_party_preview_title != null and ai_sparring_party_preview_title.text == "JOUW TEAM", "Current-party preview heading renders in Dutch")
	_check(ai_sparring_party_preview_grid != null and ai_sparring_party_preview_grid.get_child_count() == 6, "Current-party preview always renders six ranked-style slots")
	if ai_sparring_team_source != null:
		ai_sparring_team_source.select(0)
		overlay.call("_on_ai_sparring_team_source_selected", 0)
	_check(ai_training_input != null and ai_training_input.visible, "Switching back restores the paste field")
	_check(ai_sparring_party_preview != null and not ai_sparring_party_preview.visible, "Paste mode hides the current-party preview")
	_check(ai_opponent_step != null, "Free sparring groups AI selection as its second step")
	_check(
		ai_team_step != null
		and ai_opponent_step != null
		and is_equal_approx(ai_team_step.size_flags_stretch_ratio, ai_opponent_step.size_flags_stretch_ratio),
		"Free sparring keeps equal team and opponent column proportions"
	)
	_check(overlay.find_child("AiSparringReadyStep", true, false) != null, "Free sparring marks the final battle action as its third step")
	_check(ai_sparring_start != null and ai_sparring_start.text == "Start sparring", "Free sparring uses a direct start action")
	_check(ai_sparring_start != null and ai_sparring_start.custom_minimum_size.y >= 42.0, "Free sparring has a prominent start action")
	var ai_sparring_start_style := ai_sparring_start.get_theme_stylebox("normal") as StyleBoxFlat if ai_sparring_start != null else null
	_check(ai_sparring_start_style != null and ai_sparring_start_style.bg_color == Color("#5d4aa4"), "Free sparring start action uses a distinct primary treatment")
	_check(training_button != null and training_button.text == "Training Room", "Training room selector renders in Dutch")
	_check(casual_button != null and casual_button.text.begins_with("✓ "), "Default room type is visibly selected")
	_check(room_workspace != null and room_workspace.get_child_count() == 2, "Room setup uses a clear two-column workflow")
	_check(room_type_card != null and room_type_card.custom_minimum_size.x >= 280.0, "Battle type has a dedicated setup card")
	_check(room_flow_card != null, "Room actions have a dedicated workflow card")
	_check(casual_button.custom_minimum_size.y >= 48.0 and training_button.custom_minimum_size.y >= 48.0, "Battle type cards have comfortable click targets")
	_check(room_flow_hint != null and room_flow_hint.visible, "Room action card explains the next step before a choice")
	_check(room_timer_check != null and room_timer_check.text.begins_with("Keuzetimer"), "Private room timer renders in Dutch")
	_check(
		overlay.call(
			"_pvp_room_failure_status_key",
			{"code": "room_timer_authority_disabled"},
			true,
			"ui.pvp.room.create_failed"
		) == "ui.pvp.room.timer_unavailable",
		"Unavailable room timers are not presented as an invalid Pokepaste"
	)
	_check(
		overlay.call(
			"_pvp_room_failure_status_key",
			{"detail": {"code": "CIRCUIT_BREAKER_OPEN"}},
			false,
			"ui.pvp.room.create_failed"
		) == "ui.pvp.room.battle_server_recovering",
		"Authority recovery is explained instead of shown as a generic room failure"
	)
	_check(
		overlay.call(
			"_pvp_room_failure_status_key",
			{"detail": {"code": "TRAINING_TEAM_INVALID"}},
			true,
			"ui.pvp.room.create_failed"
		) == "ui.pvp.training.paste_invalid",
		"Invalid Training Room teams keep the Pokepaste guidance"
	)
	_check(
		overlay.call(
			"_pvp_room_failure_status_key",
			{"code": "service_error"},
			true,
			"ui.pvp.room.create_failed"
		) == "ui.pvp.room.create_failed",
		"Unrelated Training Room failures use the room fallback"
	)
	_check(
		overlay.call(
			"_pvp_room_failure_status_key",
			{"detail": {"code": "PVP_ROOM_TEAM_INVALID"}},
			false,
			"ui.pvp.room.create_failed"
		) == "ui.pvp.room.tier_team_invalid",
		"Tier validation failures explain that the selected rules were not met"
	)
	var room_validation_response := {
		"code": "PVP_ROOM_TEAM_INVALID",
		"validation": {"errors": [{
			"code": "banned_move",
			"slot": 1,
			"value": "fissure",
			"message": "Move is banned.",
		}]},
	}
	var room_validation_issue: Dictionary = overlay.call(
		"_pvp_room_first_validation_issue",
		room_validation_response
	)
	_check(room_validation_issue.get("code") == "banned_move", "Room failures preserve their first actionable validation issue")
	overlay.call("_set_pvp_room_failure_status", room_validation_response, false, "ui.pvp.room.join_failed")
	_check(
		room_status != null and room_status.text.contains("Spleet") and room_status.text.contains("niet toegestaan"),
		"Room validation shows the localized concrete reason instead of a generic join failure"
	)
	overlay.set("pvp_ranked_team_validation_result", {
		"state": "invalid", "valid": false, "issues": [room_validation_issue],
	})
	overlay.call("_set_pvp_queue_validation_failure_status")
	_check(
		queue_status != null and queue_status.text.contains("Spleet") and queue_status.text.contains("Ranked"),
		"Ranked join feedback includes the concrete localized validation reason"
	)
	_check(
		overlay.call(
			"_pvp_room_failure_status_key",
			{"detail": {"code": "MEGA_READINESS_PENDING"}},
			false,
			"ui.pvp.room.create_failed"
		) == "backend.error.mega_readiness_pending",
		"Mega readiness failures keep their specific localized explanation"
	)
	var party_validation_feedback: Dictionary = overlay.call(
		"_training_ai_failure_feedback",
		{
			"detail": {
				"code": "TRAINING_PLAYER_TEAM_TIER_INVALID",
				"validation": {
					"errors": [{
						"slot": 6,
						"message": "battle-bond is not legal for this Pokemon",
					}],
				},
			},
		},
		"party",
		"catalog"
	)
	var party_validation_values := party_validation_feedback.get("values", {}) as Dictionary
	_check(
		party_validation_feedback.get("key", "") == "ui.pvp.training.ai.player_team_invalid_detail"
		and not bool(party_validation_feedback.get("log_warning", true))
		and party_validation_values.get("reason", "")
			== "Vak 6 · battle-bond is not legal for this Pokemon",
		"AI Sparring reports player-party validation issues without console warnings"
	)
	var opponent_validation_feedback: Dictionary = overlay.call(
		"_training_ai_failure_feedback",
		{
			"detail": {
				"code": "TRAINING_AI_TEAM_ILLEGAL",
				"problems": ["Greninja's ability Battle Bond is not legal."],
			},
		},
		"party",
		"paste"
	)
	var opponent_validation_values := opponent_validation_feedback.get("values", {}) as Dictionary
	_check(
		opponent_validation_feedback.get("key", "") == "ui.pvp.training.ai.opponent_team_invalid_detail"
		and not bool(opponent_validation_feedback.get("log_warning", true))
		and opponent_validation_values.get("reason", "")
			== "Greninja's ability Battle Bond is not legal.",
		"AI Sparring identifies opponent-team legality failures without console warnings"
	)
	var paste_import_feedback: Dictionary = overlay.call(
		"_training_ai_failure_feedback",
		{"detail": {"code": "TRAINING_AI_TEAM_IMPORT_FAILED"}},
		"party",
		"paste"
	)
	_check(
		paste_import_feedback.get("key", "") == "ui.pvp.training.paste_invalid"
		and not bool(paste_import_feedback.get("log_warning", true)),
		"AI Sparring keeps paste import failures actionable without console warnings"
	)
	var technical_failure_feedback: Dictionary = overlay.call(
		"_training_ai_failure_feedback",
		{"detail": {"code": "TRAINING_AI_TIER_RULES_UNAVAILABLE"}},
		"party",
		"catalog"
	)
	_check(
		bool(technical_failure_feedback.get("log_warning", true)),
		"AI Sparring keeps console warnings enabled for technical failures"
	)
	_check(leaderboard_scope != null and leaderboard_scope.get_item_text(0) == "Preseason", "Leaderboard season renders in Dutch")
	_check_ranked_dropdown_style(format_select, "Matchmaking format")
	_check_ranked_dropdown_style(leaderboard_scope, "Leaderboard period")

	# This focused localization test does not mount the overlay in the tree, so
	# treat the remote catalog as already checked and keep the signal path local.
	overlay.set("pvp_training_ai_catalog_loaded", true)
	training_button.emit_signal("pressed")
	await process_frame
	_check(overlay.get("pvp_room_battle_purpose") == "training", "Training button signal selects training mode")
	_check(training_button.text.begins_with("✓ "), "Training selection is immediately visible on its button")
	_check(room_ai_button != null and not room_ai_button.visible, "Training Rooms keep AI battles out of the room action row")
	_check(room_type_note != null and room_type_note.text.contains("beide spelers"), "Training selection immediately changes its explanation")
	_check(room_status != null and room_status.text.begins_with("Training Room geselecteerd"), "Training selection immediately changes room status")
	_check(room_create_button != null and room_create_button.text == "Training maken", "Training selection changes the create action")
	var training_ai_catalog_entries: Array = overlay.get("pvp_training_ai_catalog_entries") as Array
	training_ai_catalog_entries.clear()
	training_ai_catalog_entries.append({
		"teamId": "smogon-ndou-screens-lameflame",
		"displayName": "Screens",
		"authors": ["Lameflame"],
		"archetype": "hyper_offense",
		"pokemon": [
			{"species": "Mawile-Mega"}, {"species": "Ceruledge"},
			{"species": "Zamazenta"}, {"species": "Ogerpon-Wellspring"},
			{"species": "Moltres-Galar"}, {"species": "Iron Treads"},
		],
	})
	training_ai_catalog_entries.append({
		"teamId": "smogon-ndou-stall-example",
		"displayName": "Stall",
		"authors": ["Example"],
		"archetype": "stall",
		"pokemon": [
			{"species": "Alomomola"}, {"species": "Gliscor"},
			{"species": "Blissey"}, {"species": "Corviknight"},
			{"species": "Clodsire"}, {"species": "Sableye-Mega"},
		],
	})
	var training_ai_available_modes: Array = overlay.get("pvp_training_ai_available_modes") as Array
	for entry: Dictionary in training_ai_catalog_entries:
		entry["homeTierId"] = "aether-ou"
		entry["eligibleTierIds"] = ["none", "aether-ou"]
	training_ai_available_modes.assign(["ai4", "active", "expert", "master", "nightmare", "intermediate"])
	overlay.call("_refresh_pvp_training_ai_mode_options")
	_check(training_ai_bot_select.item_count == 2, "Bot selector separates Scholar and Grandmaster")
	_check(training_ai_bot_select.get_item_text(0) == "AI4 Scholar" and training_ai_bot_select.get_item_text(1) == "AI5 Grandmaster", "Bot names remain familiar")
	_check(training_ai_mode_select.item_count == 1 and training_ai_mode_select.get_item_text(0) == "Beginner", "Scholar exposes only Beginner")
	training_ai_bot_select.select(1)
	overlay.call("_on_pvp_training_ai_bot_selected", 1)
	_check(training_ai_mode_select.item_count == 5, "Grandmaster exposes all five server-enabled difficulties")
	_check(training_ai_mode_select.get_item_text(0) == "Intermediate" and training_ai_mode_select.get_item_text(1) == "Hard" and training_ai_mode_select.get_item_text(2) == "Expert" and training_ai_mode_select.get_item_text(3) == "Master" and training_ai_mode_select.get_item_text(4) == "Nightmare", "Master sits between Expert and Nightmare")
	training_ai_mode_select.select(0)
	_check(overlay.call("_selected_pvp_training_ai_mode") == "intermediate", "Intermediate selection preserves its server mode")
	training_ai_mode_select.select(2)
	_check(overlay.call("_selected_pvp_training_ai_mode") == "expert", "Expert selection preserves its server mode")
	training_ai_mode_select.select(3)
	_check(overlay.call("_selected_pvp_training_ai_mode") == "master", "Master selection preserves its server mode")
	training_ai_mode_select.select(4)
	_check(overlay.call("_selected_pvp_training_ai_mode") == "nightmare", "Nightmare selection preserves its server mode")
	training_ai_available_modes.assign(["ai4", "active"])
	training_ai_bot_select.select(0)
	overlay.call("_on_pvp_training_ai_bot_selected", 0)
	var training_ai_archetypes: Array = overlay.get("pvp_training_ai_catalog_archetypes") as Array
	training_ai_archetypes.assign(["hyper_offense", "stall"])
	overlay.set("pvp_training_ai_enabled", true)
	overlay.call("_refresh_pvp_training_ai_mode_options")
	overlay.call("_refresh_pvp_training_ai_archetype_options")
	overlay.call("_refresh_pvp_training_ai_team_options")
	overlay.call("_refresh_pvp_room_battle_purpose_ui")
	overlay.call("_on_pvp_ai_sparring_tab_changed", 0)
	_check(overlay.get("pvp_room_selected_mode") == "ai", "Free sparring selects the server-owned opponent flow")
	_check(ai_training_input != null and ai_training_input.visible, "AI flow accepts an imported Gen 9 National Dex team")
	_check(training_ai_mode_row != null and training_ai_mode_row.visible, "AI flow exposes AI4 and active AI5 execution modes")
	_check(training_ai_bot_select.item_count == 2 and training_ai_mode_select.item_count == 1, "Both bots are selectable with filtered difficulties")
	_check(str(training_ai_mode_select.get_selected_metadata()) == "ai4", "plain AI4 without shadow observation is the safe default")
	_check(training_ai_team_source_row != null and training_ai_team_source_row.visible, "AI flow lets players choose a catalog or PokéPaste opponent")
	_check(training_ai_team_source_select != null and training_ai_team_source_select.item_count == 2, "AI team source offers catalog and PokéPaste choices")
	for select: OptionButton in [training_ai_mode_select, training_ai_team_source_select, training_ai_archetype_select]:
		_check(
			select != null
			and not select.fit_to_longest_item
			and select.clip_text
			and select.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
			"AI opponent dropdown content cannot resize the sparring columns"
		)
	_check(training_ai_archetype_row != null and training_ai_archetype_row.visible, "AI flow exposes an archetype selector")
	_check(training_ai_archetype_select != null and training_ai_archetype_select.item_count == 2, "AI4 archetype selector excludes stall")
	_check(training_ai_team_row != null and training_ai_team_row.visible, "AI flow exposes the sample-team selector")
	_check(training_ai_team_search != null and training_ai_team_search.visible and training_ai_team_search.clear_button_enabled, "AI team selector is one clearable name input")
	_check(training_ai_team_suggestions != null and training_ai_team_suggestion_list != null and training_ai_team_suggestion_list.get_child_count() == 2, "AI4 team suggestions exclude stall teams")
	training_ai_team_search.text = "geen-resultaat"
	overlay.call("_on_pvp_training_ai_team_search_changed", training_ai_team_search.text)
	_check(
		training_ai_team_suggestion_list.get_child_count() == 1
		and str(training_ai_team_suggestion_list.get_child(0).get_meta("team_id")) == "random",
		"A non-matching AI team search leaves only the random choice"
	)
	training_ai_team_search.text = ""
	overlay.call("_on_pvp_training_ai_team_search_changed", training_ai_team_search.text)
	_check(ai_opponent_preview != null and ai_opponent_preview.visible, "A random AI team is resolved before the battle starts")
	_check(ai_opponent_preview_grid != null and ai_opponent_preview_grid.get_child_count() == 6, "AI opponent preview renders all six Pokemon")
	_check(ai_opponent_preview_title != null and ai_opponent_preview_title.text.begins_with("TEAM TEGENSTANDER"), "AI opponent preview identifies the resolved team")
	var ai_sparring_hover_card := overlay.get("pvp_ai_sparring_hover_card") as PartyHoverCard
	_check(
		ai_sparring_hover_card != null
		and ai_sparring_hover_card.storage_visuals
		and ai_sparring_hover_card.z_index == 1099,
		"Free Sparring reuses the PC Pokemon hover card above the PvP popup"
	)
	var catalog_hover_data: Dictionary = overlay.call("_pc_pokemon_hover_data", {
		"species": "Zamazenta",
		"types": ["Fighting"],
		"currentHp": 325,
		"maxHp": 325,
		"stats": {"hp": 325, "atk": 339, "def": 266, "spa": 176, "spd": 266, "spe": 390},
		"moves": ["Close Combat"],
		"moveData": [{"name": "Close Combat", "pp": 5, "maxPp": 5}],
	})
	_check(
		int((catalog_hover_data.get("stats") as Dictionary).get("spe", 0)) == 390
		and catalog_hover_data.get("moves") is Array
		and int(((catalog_hover_data.get("moves") as Array)[0] as Dictionary).get("maxPp", 0)) == 5,
		"Free Sparring catalog hovers keep calculated stats and complete move PP"
	)
	_check(
		ai_opponent_preview_grid != null
		and not ai_opponent_preview_grid.get_child(0).get_signal_connection_list("mouse_entered").is_empty(),
		"AI opponent preview slots open a full Pokemon hover card"
	)
	_check(
		training_ai_team_suggestions != null
		and training_ai_team_suggestion_list.get_child_count() > 1
		and str(training_ai_team_suggestion_list.get_child(1).get_meta("team_id")) == "smogon-ndou-screens-lameflame",
		"AI searchable selector preserves the stable team ID"
	)
	overlay.call("_on_pvp_training_ai_team_suggestion_selected", "smogon-ndou-screens-lameflame")
	_check(str(overlay.call("_resolved_pvp_training_ai_team_id")) == "smogon-ndou-screens-lameflame", "Selecting a named AI team binds its exact preview and battle identity")
	_check(ai_opponent_preview_grid.get_child(0).tooltip_text.contains("Mawile"), "Named AI team preview uses that team's roster")
	training_ai_team_search.text = ""
	overlay.call("_on_pvp_training_ai_team_search_changed", training_ai_team_search.text)
	var opponent_minimum_width_before_filter := ai_opponent_step.get_combined_minimum_size().x
	var opponent_minimum_height_before_filter := ai_opponent_step.get_combined_minimum_size().y
	training_ai_bot_select.select(1)
	overlay.call("_on_pvp_training_ai_bot_selected", 1)
	_check(str(training_ai_mode_select.get_selected_metadata()) == "active", "AI5 mode can expose its complete catalog")
	_check(training_ai_archetype_select.item_count == 3, "AI5 archetype selector keeps stall available")
	_check(training_ai_team_suggestion_list.get_child_count() == 3, "AI5 team suggestions keep stall teams available")
	training_ai_team_search.text = "stall"
	overlay.call("_on_pvp_training_ai_team_search_changed", training_ai_team_search.text)
	_check(
		training_ai_team_suggestion_list.get_child_count() == 2
		and str(training_ai_team_suggestion_list.get_child(1).get_meta("team_id")) == "smogon-ndou-stall-example",
		"Searching an AI team name narrows its choices without changing its stable ID"
	)
	training_ai_team_search.text = ""
	overlay.call("_on_pvp_training_ai_team_search_changed", training_ai_team_search.text)
	training_ai_archetype_select.select(2)
	overlay.call("_on_pvp_training_ai_archetype_selected", 2)
	_check(training_ai_team_suggestion_list.get_child_count() == 2, "Choosing an archetype filters the specific team list")
	_check(str(training_ai_team_suggestion_list.get_child(1).get_meta("team_id")) == "smogon-ndou-stall-example", "Filtered team keeps its stable catalog identity")
	_check(str(overlay.call("_resolved_pvp_training_ai_team_id")) == "smogon-ndou-stall-example", "Random archetype choice resolves to the exact team that will battle")
	_check(ai_opponent_preview_grid.get_child(0).tooltip_text == "Alomomola", "AI opponent preview exposes each Pokemon name on hover")
	training_ai_bot_select.select(0)
	overlay.call("_on_pvp_training_ai_bot_selected", 0)
	_check(str(training_ai_mode_select.get_selected_metadata()) == "ai4", "AI4 can be reselected after browsing AI5")
	_check(str(training_ai_archetype_select.get_selected_metadata()) == "random", "Switching to AI4 clears a selected stall archetype")
	_check(training_ai_archetype_select.item_count == 2, "Switching to AI4 removes stall from the archetype selector")
	_check(training_ai_team_suggestion_list.get_child_count() == 2, "Switching to AI4 removes stall from the team suggestions")
	var first_opponent_name_labels := ai_opponent_preview_grid.get_child(0).find_children("*", "Label", true, false)
	_check(first_opponent_name_labels.is_empty(), "AI opponent names stay out of the compact icon row")
	_check(
		is_equal_approx(
			opponent_minimum_width_before_filter,
			ai_opponent_step.get_combined_minimum_size().x
		),
		"Changing the archetype cannot change the opponent column minimum width"
	)
	var cross_tier_ou_entry := training_ai_catalog_entries[0].duplicate(true) as Dictionary
	cross_tier_ou_entry["homeTierId"] = "aether-ou"
	cross_tier_ou_entry["eligibleTierIds"] = ["none", "aether-ou", "aether-uu"]
	var uu_entry := cross_tier_ou_entry.duplicate(true)
	uu_entry["teamId"] = "smogon-nduu-hyper-offense"
	uu_entry["displayName"] = "UU Hyper Offense"
	uu_entry["homeTierId"] = "aether-uu"
	training_ai_catalog_entries.assign([cross_tier_ou_entry, uu_entry])
	ai_sparring_tier_select.select(1)
	training_ai_archetype_select.select(1)
	overlay.call("_on_ai_sparring_tier_selected", 1)
	overlay.call("_on_pvp_training_ai_archetype_selected", 1)
	_check(
		training_ai_team_suggestion_list.get_child_count() == 2
		and str(training_ai_team_suggestion_list.get_child(1).get_meta("team_id")) == "smogon-nduu-hyper-offense"
		and str(overlay.call("_resolved_pvp_training_ai_team_id")) == "smogon-nduu-hyper-offense",
		"Aether UU random opponents resolve only from the UU home-tier catalog"
	)
	_check(
		str(overlay.call("_selected_ai_sparring_player_catalog_team_id")) == "smogon-nduu-hyper-offense",
		"Aether UU player catalog choices exclude cross-eligible OU teams"
	)
	_check(str(ai_sparring_catalog_tier.get_selected_metadata()) == "aether-uu" and ai_sparring_catalog_results.get_child_count() == 1, "Practice tier changes synchronize and filter the catalog")
	overlay.call("_on_pvp_ai_sparring_tab_changed", 1)
	overlay.call("_on_pvp_ai_sparring_tab_changed", 0)
	_check(str(overlay.call("_selected_ai_sparring_tier_id")) == "aether-uu", "Switching tabs preserves the selected tier")
	overlay.call("_refresh_ai_sparring_tier_options")
	overlay.call("_refresh_ai_sparring_catalog_filters")
	_check(str(ai_sparring_catalog_tier.get_selected_metadata()) == "aether-uu", "Refreshing tier options preserves UU in both tabs")
	ai_sparring_catalog_tier.select(0)
	overlay.call("_on_ai_sparring_catalog_tier_selected", 0)
	_check(str(overlay.call("_selected_ai_sparring_tier_id")) == "aether-ou", "Catalog tier changes synchronize back to practice")
	_check(str(overlay.call("_resolved_pvp_training_ai_team_id")) == str(cross_tier_ou_entry["teamId"]) and str(overlay.call("_selected_ai_sparring_player_catalog_team_id")) == str(cross_tier_ou_entry["teamId"]), "Catalog tier changes replace incompatible player and opponent selections")
	training_ai_team_source_select.select(1)
	overlay.call("_on_pvp_training_ai_team_source_selected", 1)
	_check(training_ai_custom_team_input != null and training_ai_custom_team_input.visible, "PokéPaste source reveals an opponent-team paste field")
	_check(training_ai_archetype_row != null and not training_ai_archetype_row.visible, "Custom opponent paste hides irrelevant catalog archetypes")
	_check(training_ai_team_row != null and not training_ai_team_row.visible, "Custom opponent paste hides irrelevant catalog teams")
	_check(ai_opponent_preview != null and not ai_opponent_preview.visible, "Custom opponent paste does not claim a catalog roster preview")
	_check(
		is_equal_approx(
			opponent_minimum_height_before_filter,
			ai_opponent_step.get_combined_minimum_size().y
		),
		"Switching between a catalog team and PokéPaste keeps the opponent panel height stable"
	)
	_check(overlay.get("pvp_ai_sparring_status_label") == null, "AI Sparring omits the redundant footer status bar")
	_check(subtitle != null and subtitle.text == "Oefen PvP-gevechten tegen AI-tegenstanders", "AI Sparring presents itself as general AI PvP practice")
	_check(ai_sparring_intro != null and not ai_sparring_intro.text.to_lower().contains("onderzoek"), "Free Sparring copy does not mention the research campaign")
	overlay.set("pvp_popup_active_section", "AI Sparring")
	overlay.call("_on_pvp_ai_sparring_tab_changed", 0)
	overlay.call("_set_pvp_status_key", "ui.pvp.training.paste_required", {}, true)
	_check(subtitle != null and subtitle.text.begins_with("Plak eerst"), "AI Sparring keeps actionable feedback visible without a footer")
	_check(
		subtitle != null and subtitle.get_theme_color("font_color") == Color("#ff6b74"),
		"AI Sparring renders error feedback in red"
	)
	overlay.call("_on_pvp_ai_sparring_tab_changed", 0)
	_check(
		subtitle != null and subtitle.get_theme_color("font_color") == Color("#aeb8c5"),
		"AI Sparring restores the normal subtitle color after leaving an error state"
	)
	overlay.call("_on_pvp_ai_sparring_tab_changed", 1)
	_check(popup.get_combined_minimum_size().y <= 620.0, "Team catalog fits inside the AI Sparring popup")
	overlay.call("_on_pvp_ai_sparring_tab_changed", 0)
	_check(popup.get_combined_minimum_size().y <= 620.0, "AI mode and team selectors fit inside the room popup")
	room_create_button.emit_signal("pressed")
	await process_frame
	_check(room_tier_row != null and room_tier_row.visible, "Room creation exposes the optional battle tier")
	_check(room_tier_select != null and room_tier_select.item_count == 5, "Custom rooms include the separate PokeMMO OU tier")
	_check(str(room_tier_select.get_selected_metadata()) == "none", "No tier is selected by default")
	_check(room_tier_select.get_item_text(0) == "Geen tier", "The default tier is localized in Dutch")
	_check(room_tier_select.get_item_text(1) == "Aether OU", "Aether OU is available for unrated rooms")
	room_tier_select.select(1)
	_check(overlay.call("_selected_pvp_room_format_id") == "gen9nationaldex", "Aether OU resolves to the reviewed National Dex engine")
	room_tier_select.select(2)
	_check(room_tier_select.get_item_text(2) == "Aether UU", "Aether UU is available for unrated rooms")
	_check(str(room_tier_select.get_selected_metadata()) == "aether-uu", "Aether UU keeps its public tier identity")
	_check(overlay.call("_selected_pvp_room_format_id") == "gen9nationaldex", "Aether UU resolves to the reviewed National Dex engine")
	room_tier_select.select(3)
	_check(room_tier_select.get_item_text(3) == "Champions ZA", "Champions ZA is available without a developer label")
	_check(str(room_tier_select.get_selected_metadata()) == "pokeaether-mega-z-test", "Champions ZA keeps its bounded room identity")
	_check(overlay.call("_selected_pvp_room_format_id") == "pokeaether-mega-z-test-v1", "Champions ZA maps to the versioned engine format")
	room_tier_select.select(4)
	_check(room_tier_select.get_item_text(4) == "PokeMMO OU", "PokeMMO OU is available for custom rooms")
	_check(str(room_tier_select.get_selected_metadata()) == "pokemmo-ou", "PokeMMO OU has its own room identity")
	_check(overlay.call("_selected_pvp_room_format_id") == "pokemmo-ou-v1", "PokeMMO OU maps to its isolated engine")
	room_tier_select.select(3)
	_check(room_timer_check != null and room_timer_check.visible, "Training room creation exposes the shared decision timer option")
	room_timer_check.button_pressed = true
	room_timer_check.emit_signal("toggled", true)
	await process_frame
	_check(room_timer_tier != null and room_timer_tier.visible, "Enabling the timer exposes standard speed tiers")
	_check(room_timer_tier.item_count == 6, "Room timer offers the Casual default and five speed tiers")
	_check(str(room_timer_tier.get_selected_metadata()) == "casual_v1", "Casual is the default room timer tier")
	room_join_button.emit_signal("pressed")
	await process_frame
	_check(not room_tier_row.visible, "Joiners inherit the host tier instead of selecting their own")
	_check(not room_flow_hint.visible, "Choosing a room action replaces guidance with its form")
	_check(training_input != null and training_input.visible, "Training room exposes the paste-only team input")
	_check(room_code_input.get_index() < training_input.get_index(), "Training join asks for the room code before the team paste")
	_check(room_form_title != null and room_form_title.text.begins_with("VOER EEN ROOMCODE"), "Training join form explains both required inputs")
	overlay.call("_set_pvp_training_team_preview", [
		{"species": "Pikachu", "shiny": true, "moves": ["Thunderbolt"]},
		{"species": "Staryu", "shiny": false, "item": "Leftovers"},
	])
	_check(training_preview != null and training_preview.visible, "Accepted training team exposes its read-only preview")
	_check(training_preview_title != null and training_preview_title.text == "JOUW TRAININGSTEAM  ·  2/6", "Training preview count renders in Dutch")
	_check(training_preview_grid != null and training_preview_grid.get_child_count() == 6, "Training preview always renders six team slots")
	_check(training_preview_grid.get_child(0).tooltip_text == "Pikachu", "Training preview identifies the accepted species")
	_check(popup.get_combined_minimum_size().y <= 620.0, "Training preview fits inside the room popup")
	casual_button.emit_signal("pressed")
	await process_frame
	_check(overlay.get("pvp_room_battle_purpose") == "casual", "Custom button signal selects custom mode")
	_check(not training_input.visible, "Custom selection hides the Pokepaste input")
	_check(not training_preview.visible, "Changing room type clears the submitted training preview")
	room_spectate_button.emit_signal("pressed")
	await process_frame
	_check(room_code_input != null and room_code_input.visible, "Spectate flow keeps the room code field visible")
	_check(not training_input.visible, "Spectate flow never asks for a Pokepaste team")
	training_button.emit_signal("pressed")
	room_join_button.emit_signal("pressed")
	await process_frame
	overlay.call("_set_pvp_status_key", "ui.pvp.room.waiting")
	overlay.set("pvp_active_queue_entry_id", "queue-entry")
	overlay.set("pvp_active_queue_status", "waiting")
	overlay.set("pvp_queue_compact_minimized", true)
	overlay.call("_refresh_pvp_queue_compact_panel", 0.0)
	_check(room_status != null and room_status.text == "Wachten op een andere speler...", "Dynamic room status renders in Dutch")
	_check(compact_status != null and compact_status.text == "Ranked-wachtrij", "Compact queue status renders in Dutch")
	_check(
		overlay.call("_pvp_history_result_label", {"winnerUserId": 7}, 7) == "Overwinning",
		"PvP history outcome renders in Dutch"
	)

	localization_manager.call("set_locale", "pt_BR")
	overlay.call("_refresh_pvp_localized_ui")
	_check(title != null and title.text == "Ranqueada", "PvP ranked title updates to Portuguese")
	_check(subtitle != null and subtitle.text.begins_with("Pareamento"), "PvP subtitle updates to Portuguese")
	_check(ranked_tabs != null and ranked_tabs.get_tab_title(0) == "Jogar", "PvP tab title updates to Portuguese")
	_check(ranked_tabs != null and ranked_tabs.get_tab_title(4) == "Recompensas", "Ranked Rewards tab updates to Portuguese")
	_check(rewards_tabs != null and rewards_tabs.get_tab_title(0) == "Visão geral", "Reward overview subtab updates to Portuguese")
	_check(rewards_tabs != null and rewards_tabs.get_tab_title(1) == "Por batalha", "Battle reward subtab updates to Portuguese")
	_check(rewards_tabs != null and rewards_tabs.get_tab_title(4) == "Temporada", "Season reward subtab updates to Portuguese")
	_check(rewards_status != null and rewards_status.text == "RECOMPENSAS DE BATALHA ATIVAS", "Active Ranked reward availability updates to Portuguese")
	_check(objectives_filter != null and objectives_filter.get_item_text(0) == "Diário", "Objective filter updates to Portuguese")
	_check(room_join_button != null and room_join_button.text == "Entrar no treinamento", "Training room action updates to Portuguese")
	_check(training_button != null and training_button.text == "✓ Sala de treinamento", "Selected training room updates to Portuguese")
	_check(room_timer_check != null and room_timer_check.text.begins_with("Cronômetro"), "Private room timer updates to Portuguese")
	_check(room_timer_tier != null and room_timer_tier.get_item_text(0).begins_with("Casual"), "Timer tier labels update to Portuguese")
	_check(room_tier_select != null and room_tier_select.get_item_text(0) == "Sem tier", "Room tier labels update to Portuguese")
	_check(room_status != null and room_status.text == "Aguardando outro jogador...", "Dynamic room status updates to Portuguese")
	_check(leaderboard_scope != null and leaderboard_scope.get_item_text(0) == "Pré-temporada", "Leaderboard season updates to Portuguese")
	_check(compact_status != null and compact_status.text == "Fila ranqueada", "Compact queue status updates to Portuguese")

	if popup != null:
		var minimum_size := popup.get_combined_minimum_size()
		_check(minimum_size.x <= 980.0 and minimum_size.y <= 620.0, "PvP translations fit the designed popup bounds")
	if auth_service != null:
		auth_service.call("apply_current_user", original_user)

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	await _check_sparring_source_size(overlay)
	overlay.free()


func _check_ranked_dropdown_style(option: OptionButton, label: String) -> void:
	_check(option != null, "%s dropdown exists" % label)
	if option == null:
		return
	var popup := option.get_popup()
	_check(option.has_theme_icon_override("arrow"), "%s uses the Ranked dropdown arrow" % label)
	_check(
		option.has_theme_stylebox_override("normal")
		and option.has_theme_stylebox_override("hover")
		and option.has_theme_stylebox_override("disabled"),
		"%s uses styled closed states" % label
	)
	_check(
		popup.has_theme_stylebox_override("panel")
		and popup.has_theme_stylebox_override("hover"),
		"%s uses styled popup states" % label
	)
	_check(
		popup.has_theme_icon_override("radio_checked")
		and popup.has_theme_icon_override("radio_unchecked"),
		"%s uses custom selection indicators" % label
	)


func _check_sparring_source_size(overlay: Node) -> void:
	# Mount the two setup cards: unlike the production section switcher, this
	# broad localization fixture leaves unrelated popup pages visible.
	var workspace := overlay.find_child("AiSparringOpponentStep", true, false).get_parent() as Control
	var parent := workspace.get_parent()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 960)
	root.add_child(viewport)
	workspace.reparent(viewport)
	var opponent := overlay.get("pvp_training_ai_team_source_select") as OptionButton
	var player := overlay.get("pvp_ai_sparring_team_source_select") as OptionButton
	var previous_opponent := opponent.selected
	var previous_player := player.selected
	var catalog_size := Vector2.ZERO
	for sources: Vector2i in [Vector2i(0, 2), Vector2i(1, 0), Vector2i(0, 0), Vector2i(1, 2), Vector2i(0, 2)]:
		opponent.select(sources.x)
		overlay.call("_on_pvp_training_ai_team_source_selected", sources.x)
		player.select(sources.y)
		overlay.call("_on_ai_sparring_team_source_selected", sources.y)
		workspace.size = Vector2(880, 0)
		for frame in range(8):
			await process_frame
		# Wrapped labels need the final column width before their minimum height
		# settles; then measure the smallest allowed workspace, not a stale size.
		workspace.size = Vector2(880, 0)
		for frame in range(8):
			await process_frame
		if catalog_size == Vector2.ZERO:
			catalog_size = workspace.size
		_check(workspace.size.is_equal_approx(catalog_size), "Sparring workspace keeps catalog dimensions across both source selectors: %s vs %s" % [workspace.size, catalog_size])
	workspace.reparent(parent)
	viewport.queue_free()
	opponent.select(previous_opponent)
	overlay.call("_on_pvp_training_ai_team_source_selected", previous_opponent)
	player.select(previous_player)
	overlay.call("_on_ai_sparring_team_source_selected", previous_player)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
