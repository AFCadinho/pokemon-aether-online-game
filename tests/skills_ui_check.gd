extends SceneTree

const SKILLS_PANEL_PATH := "res://scenes/interface/skills_panel.tscn"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var skills_service := root.get_node_or_null("SkillsService")
	_check(skills_service != null, "SkillsService is available as an autoload")
	if skills_service == null:
		quit(1)
		return

	var overlay_scene := FileAccess.get_file_as_string("res://scenes/interface/ui_overlay.tscn")
	var overlay_script := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check(
		overlay_scene.contains('[node name="SkillsButton" type="Button" parent="Control"]')
		and overlay_scene.contains('path="res://assets/ui/skills.svg" id="34_skills"')
		and overlay_scene.contains('icon = ExtResource("34_skills")'),
		"the bottom-right utility rail contains one Skills button"
	)
	_check(
		overlay_script.contains("SKILLS_PANEL_SCENE")
		and overlay_script.contains("skills_button.pressed.connect(_on_skills_button_pressed)")
		and overlay_script.contains("func _position_skills_panel()"),
		"the overlay connects and positions the Skills window"
	)
	var overlay_packed := load("res://scenes/interface/ui_overlay.tscn") as PackedScene
	_check(overlay_packed != null, "the complete overworld overlay still loads")
	var overlay := overlay_packed.instantiate() as CanvasLayer
	root.add_child(overlay)
	await process_frame
	_check(overlay.get_node_or_null("Control/SkillsButton") is Button, "the runtime overlay exposes the Skills button")
	_check(overlay.get("skills_panel") is Control, "the runtime overlay creates the Skills window")
	overlay.queue_free()
	await process_frame

	var panel_scene := load(SKILLS_PANEL_PATH) as PackedScene
	_check(panel_scene != null, "Skills panel scene loads")
	var panel := panel_scene.instantiate() as Control
	root.add_child(panel)
	await process_frame
	_check(not panel.visible, "Skills panel starts hidden")

	var test_skills: Array = [
		{
			"id": "fishing",
			"unlocked": false,
			"unlockHintKey": "ui.skills.fishing.unlock_hint",
			"nameKey": "ui.skills.fishing.name",
			"descriptionKey": "ui.skills.fishing.description",
			"level": 10,
			"maxLevel": 100,
			"totalExperience": 300,
			"experienceIntoLevel": 30,
			"experienceForNextLevel": 70,
			"progressPercent": 42.86,
			"stats": {"activeTier": 2, "badgeCount": 3},
			"unlocks": [
				{"id": "old_rod", "requiredLevel": 1, "unlocked": true, "labelKey": "ui.skills.unlock.old_rod"},
				{"id": "old_rod_tentacool", "requiredLevel": 5, "unlocked": true, "labelKey": "ui.skills.unlock.old_rod_tentacool"},
				{"id": "good_rod", "requiredLevel": 10, "unlocked": true, "labelKey": "ui.skills.unlock.good_rod"},
			],
		},
		{
			"id": "thieving",
			"unlocked": true,
			"unlockHintKey": "ui.skills.thieving.unlock_hint",
			"nameKey": "ui.skills.thieving.name",
			"descriptionKey": "ui.skills.thieving.description",
			"level": 20,
			"maxLevel": 100,
			"totalExperience": 9500,
			"experienceIntoLevel": 0,
			"experienceForNextLevel": 1000,
			"progressPercent": 0.0,
			"stats": {"currency": 42, "wanted": 65, "rewardBonusPercent": 19, "wantedReductionPercent": 9.5, "maximumCatchReductionPercent": 3.8},
			"unlocks": [
				{"id": "child", "requiredLevel": 1, "unlocked": true, "labelKey": "ui.skills.unlock.child"},
				{"id": "elderly", "requiredLevel": 1, "unlocked": true, "labelKey": "ui.skills.unlock.elderly"},
				{"id": "civilian", "requiredLevel": 5, "unlocked": true, "labelKey": "ui.skills.unlock.civilian"},
				{"id": "bug_catcher", "requiredLevel": 10, "unlocked": true, "labelKey": "ui.skills.unlock.bug_catcher"},
				{"id": "worker", "requiredLevel": 15, "unlocked": true, "labelKey": "ui.skills.unlock.worker"},
				{"id": "hiker", "requiredLevel": 20, "unlocked": true, "labelKey": "ui.skills.unlock.hiker"},
				{"id": "trainer", "requiredLevel": 25, "unlocked": false, "labelKey": "ui.skills.unlock.trainer"},
				{"id": "scientist", "requiredLevel": 30, "unlocked": false, "labelKey": "ui.skills.unlock.scientist"},
				{"id": "ace_trainer", "requiredLevel": 40, "unlocked": false, "labelKey": "ui.skills.unlock.ace_trainer"},
				{"id": "veteran_trainer", "requiredLevel": 60, "unlocked": false, "labelKey": "ui.skills.unlock.veteran_trainer"},
			],
			"targets": [
				{"npcId": "kanto_viridian_city_league_fan_dorian", "npcType": "elderly", "nameKey": "ui.skills.thieving.target.dorian", "townKey": "ui.skills.thieving.location.viridian_city", "locationKey": "ui.skills.thieving.location.viridian_city", "requiredLevel": 1, "unlocked": true, "attemptedToday": true, "availableToday": false},
				{"npcId": "kanto_viridian_city_school_kid_june", "npcType": "child", "nameKey": "ui.skills.thieving.target.june", "townKey": "ui.skills.thieving.location.viridian_city", "locationKey": "ui.skills.thieving.location.viridian_city", "requiredLevel": 1, "unlocked": true, "attemptedToday": false, "availableToday": true},
				{"npcId": "kanto_viridian_city_forest_scout_nico", "npcType": "bug_catcher", "nameKey": "ui.skills.thieving.target.nico", "townKey": "ui.skills.thieving.location.viridian_city", "locationKey": "ui.skills.thieving.location.viridian_city", "requiredLevel": 10, "unlocked": true, "attemptedToday": false, "availableToday": true},
				{"npcId": "kanto_pewter_city_gym_fan_max", "npcType": "child", "nameKey": "ui.skills.thieving.target.max", "townKey": "ui.skills.thieving.location.pewter_city", "locationKey": "ui.skills.thieving.location.pewter_city", "requiredLevel": 1, "unlocked": true, "attemptedToday": false, "availableToday": true},
			],
		},
	]
	skills_service.set("skills", test_skills)
	skills_service.set("state_loaded", true)
	skills_service.set("fishing_catalog", {
		"speciesCount": 3,
		"rods": [
			{
				"id": "old_rod",
				"name": "Old Rod",
				"entries": [{"species": "Magikarp", "requiredFishingLevel": 1, "minPokemonLevel": 5, "maxPokemonLevel": 10, "regions": ["kanto"], "areaIds": ["kanto_pallet_town"], "locationCount": 1}],
			},
			{
				"id": "good_rod",
				"name": "Good Rod",
				"entries": [{"species": "Horsea", "requiredFishingLevel": 18, "minPokemonLevel": 5, "maxPokemonLevel": 15, "regions": ["kanto"], "areaIds": ["kanto_pallet_town"], "locationCount": 1}],
			},
			{
				"id": "super_rod",
				"name": "Super Rod",
				"entries": [{"species": "Dragonair", "requiredFishingLevel": 45, "minPokemonLevel": 25, "maxPokemonLevel": 35, "regions": ["kanto"], "areaIds": ["kanto_safari_zone"], "locationCount": 1}],
			},
		],
	})
	panel.call("_render_skills", test_skills)
	panel.visible = true
	_check((panel.get("skill_cards") as GridContainer).get_child_count() == 2, "Fishing and Thieving receive separate overview cards")
	_check((panel.get("overview_panel") as VBoxContainer).visible, "Skills opens on the level overview")
	_check(not (panel.get("detail_panel") as PanelContainer).visible, "Skill details stay hidden until a skill is selected")
	panel.call("_select_skill", "fishing")
	_check((panel.get("detail_level") as Label).text.contains("Locked"), "locked Fishing is clearly identified")
	_check(not (panel.get("experience_bar") as ProgressBar).visible, "locked Fishing hides unavailable progression")
	_check((panel.get("stats_label") as Label).text.contains("Fishing Guru"), "locked Fishing explains where it is learned")
	test_skills[0]["unlocked"] = true
	skills_service.set("skills", test_skills)
	panel.call("_show_overview")
	panel.call("_select_skill", "thieving")
	await process_frame
	_check(not (panel.get("overview_panel") as VBoxContainer).visible, "Selecting Thieving leaves the overview")
	_check((panel.get("detail_panel") as PanelContainer).visible, "Selecting Thieving opens its dedicated interface")
	_check((panel.get("detail_name") as Label).text == "Thieving", "Thieving is the selected detailed skill")
	_check((panel.get("detail_level") as Label).text.contains("20"), "the detail view shows the server level")
	_check((panel.get("stats_label") as Label).text.contains("42"), "Thieving currency and modifiers are visible")
	_check((panel.get("wanted_section") as VBoxContainer).visible, "Thieving shows a dedicated Wanted meter")
	_check(is_equal_approx((panel.get("wanted_bar") as ProgressBar).value, 65.0), "Wanted meter reflects the server percentage")
	_check((panel.get("wanted_value_label") as Label).text == "65%", "Wanted meter keeps an exact percentage label")
	_check((panel.get("unlocks_container") as VBoxContainer).get_child_count() == 10, "class-based target unlocks are listed")
	_check(not (panel.get("targets_section") as VBoxContainer).visible, "Thieving opens on its compact progression tab")
	_check(panel.get_combined_minimum_size().y <= 600.0, "Thieving progression fits the fixed Skills window")
	panel.call("_select_detail_tab", "catalog")
	await process_frame
	_check((panel.get("targets_section") as VBoxContainer).visible, "Thieving has a dedicated target tab")
	_check(not (panel.get("progression_section") as VBoxContainer).visible, "the target tab hides level unlocks")
	_check((panel.get("catalog_tab_button") as Button).text == "Targets", "the secondary Thieving tab is labelled for targets")
	_check(panel.get("targets_scroll") is ScrollContainer, "daily targets use an internal scroll area")
	_check(panel.get_combined_minimum_size().y <= 600.0, "the target catalog does not lengthen the Skills window")
	_check((panel.get("target_town_tabs") as HBoxContainer).get_child_count() == 2, "each available town receives a target tab")
	_check(not (panel.get("target_town_previous_button") as Button).visible and not (panel.get("target_town_next_button") as Button).visible, "town arrows stay hidden while all tabs fit")
	_check(str(panel.get("selected_target_town_key")) == "ui.skills.thieving.location.viridian_city", "the first target town is selected initially")
	_check((panel.get("targets_container") as VBoxContainer).get_child_count() == 3, "only the selected town's targets are listed")
	_check((panel.get("targets_summary_label") as Label).text.contains("3") and (panel.get("targets_summary_label") as Label).text.contains("1/4"), "target summary shows available and attempted counts")
	var first_target := (panel.get("targets_container") as VBoxContainer).get_child(0) as PanelContainer
	var first_target_content := first_target.get_child(0) as HBoxContainer
	var first_target_status := first_target_content.get_child(1) as Label
	_check(first_target_status.text == "Attempted today", "attempted targets have a clear daily status")
	panel.call("_select_target_town", "ui.skills.thieving.location.pewter_city")
	_check((panel.get("targets_container") as VBoxContainer).get_child_count() == 1, "selecting Pewter shows only Pewter targets")
	panel.call("_select_target_town", "ui.skills.thieving.location.viridian_city")
	var expanded_town_order: Array[String] = [
		"ui.skills.thieving.location.viridian_city",
		"ui.skills.thieving.location.pewter_city",
		"test.town.cerulean",
		"test.town.saffron",
	]
	var expanded_town_targets: Dictionary = (panel.get("targets_by_town") as Dictionary).duplicate(true)
	expanded_town_targets["test.town.cerulean"] = []
	expanded_town_targets["test.town.saffron"] = []
	panel.set("target_town_order", expanded_town_order)
	panel.set("targets_by_town", expanded_town_targets)
	panel.call("_render_target_town_tabs")
	_check((panel.get("target_town_previous_button") as Button).visible and (panel.get("target_town_next_button") as Button).visible, "town arrows appear when tabs overflow")
	_check((panel.get("target_town_tabs") as HBoxContainer).get_child_count() == 3, "only one page of town tabs is rendered at once")
	panel.call("_change_target_town_page", 1)
	_check(str(panel.get("selected_target_town_key")) == "test.town.saffron", "the next arrow selects the first town on the next page")
	panel.call("_render_targets", test_skills[1]["targets"] as Array)
	skills_service.call("_on_thieving_state_changed", {
		"unlocked": true,
		"level": 20,
		"totalExperience": 9500,
		"experienceIntoLevel": 0,
		"experienceForNextLevel": 1000,
		"currency": 50,
		"wanted": 70,
		"attemptedNpcIds": [
			"kanto_viridian_city_league_fan_dorian",
			"kanto_viridian_city_school_kid_june",
		],
		"jailed": false,
	})
	var refreshed_second_target := (panel.get("targets_container") as VBoxContainer).get_child(1) as PanelContainer
	var refreshed_second_content := refreshed_second_target.get_child(0) as HBoxContainer
	_check((refreshed_second_content.get_child(1) as Label).text == "Attempted today", "a successful pickpocket refreshes the daily target status immediately")
	panel.call("_select_skill", "fishing")
	_check((panel.get("detail_name") as Label).text == "Fishing", "Fishing opens its own detailed interface")
	_check(not (panel.get("targets_section") as VBoxContainer).visible, "the target catalog only appears for Thieving")
	_check(not (panel.get("wanted_section") as VBoxContainer).visible, "Fishing hides the Thieving Wanted meter")
	_check(is_equal_approx((panel.get("experience_bar") as ProgressBar).value, 42.86), "XP progress uses the server percentage")
	panel.call("_select_detail_tab", "catalog")
	_check((panel.get("fishing_catalog_section") as VBoxContainer).visible, "Fishing has a dedicated catch catalog tab")
	_check((panel.get("fishing_rod_filters") as HBoxContainer).get_child_count() == 3, "the catch catalog can be filtered by all three rods")
	_check((panel.get("fishing_catalog_container") as VBoxContainer).get_child_count() == 1, "the selected rod lists its fishable Pokémon")
	var old_rod_row := (panel.get("fishing_catalog_container") as VBoxContainer).get_child(0) as PanelContainer
	var old_rod_status := ((old_rod_row.get_child(0) as HBoxContainer).get_child(2) as Label)
	_check(old_rod_status.text == "Available", "catalog entries reflect the player's Fishing level and active rod")
	panel.call("_select_fishing_rod", "good_rod")
	var good_rod_row := (panel.get("fishing_catalog_container") as VBoxContainer).get_child(0) as PanelContainer
	var good_rod_status := ((good_rod_row.get_child(0) as HBoxContainer).get_child(2) as Label)
	_check(good_rod_status.text.contains("18"), "species above the player's Fishing level remain visibly locked")
	panel.call("_show_overview")
	_check((panel.get("overview_panel") as VBoxContainer).visible, "the detail back action returns to all skill levels")
	_check(not (panel.get("detail_panel") as PanelContainer).visible, "returning to the overview hides skill-specific content")
	panel.position = Vector2.ZERO
	var drag_press := InputEventMouseButton.new()
	drag_press.button_index = MOUSE_BUTTON_LEFT
	drag_press.pressed = true
	panel.call("_on_window_header_gui_input", drag_press)
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.relative = Vector2(24, 20)
	panel.call("_input", drag_motion)
	_check(panel.position == Vector2(24, 20), "the Skills header drags the window within its parent")
	var drag_release := InputEventMouseButton.new()
	drag_release.button_index = MOUSE_BUTTON_LEFT
	drag_release.pressed = false
	panel.call("_input", drag_release)
	_check(not bool(panel.get("window_dragging")), "releasing the mouse stops Skills window dragging")

	for locale_path: String in [
		"res://localization/en.json",
		"res://localization/nl.json",
		"res://localization/pt_BR.json",
	]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(locale_path))
		_check(parsed is Dictionary and (parsed as Dictionary).has("ui.skills.thieving.name"), "%s contains Skills translations" % locale_path)
		_check(
			parsed is Dictionary
			and "Loot:" in str((parsed as Dictionary).get("ui.skills.thieving.stats", "")),
			"%s presents the Thieving balance as countable Loot" % locale_path
		)
		_check(
			parsed is Dictionary
			and (parsed as Dictionary).has("ui.skills.thieving.targets.tab")
			and (parsed as Dictionary).has("ui.skills.thieving.targets.town_summary")
			and (parsed as Dictionary).has("ui.skills.thieving.target.mabel")
			and (parsed as Dictionary).has("ui.skills.thieving.target.victor"),
			"%s contains the grouped target interface translations" % locale_path
		)

	panel.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
