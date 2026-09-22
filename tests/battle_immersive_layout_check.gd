extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_browser_contracts()
	var settings = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "2.5d"
	var preview_team := [
		{"species":"Dragonite"},
		{"species":"Roaring Moon"},
		{"species":"Dragonite"},
		{"species":"Roaring Moon"},
		{"species":"Dragonite"},
		{"species":"Roaring Moon"},
	]
	for layout in ["classic", "immersive"]:
		settings.battle_ui_layout = layout
		var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
		var battle = load("res://scenes/battle/battle.tscn").instantiate()
		battle.active_enemy_pokemon = Pokemon.new("Garchomp", 50)
		root.add_child(host)
		host.mount(battle)
		battle.player_party_grid.set_party([
			{"species":"Dragonite","hp":100,"max_hp":100,"active":true},
			{"species":"Roaring Moon","hp":100,"max_hp":100},
			{"species":"Dragonite","hp":100,"max_hp":100},
			{"species":"Roaring Moon","hp":100,"max_hp":100},
			{"species":"Dragonite","hp":100,"max_hp":100},
			{"species":"Roaring Moon","hp":100,"max_hp":100}])
		host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		for dimensions in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2560,1080), Vector2i(1024,768), Vector2i(960,540), Vector2i(800,600)]:
			host.size = Vector2(dimensions)
			host._fit_battle()
			for frame in 5:
				await process_frame
			if layout == "immersive":
				assert(battle.has_meta("immersive_battle_ui"))
				var player_platform_center: Vector2 = battle.player_battle_platform.position + Vector2(250, 150) * battle.player_battle_platform.scale
				var enemy_platform_center: Vector2 = battle.enemy_battle_platform.position + Vector2(250, 150) * battle.enemy_battle_platform.scale
				assert(battle.player_team_preview_layer.position.is_equal_approx(player_platform_center + Vector2(-40, -29) * battle.player_battle_platform.scale))
				assert(battle.enemy_team_preview_layer.position.is_equal_approx(enemy_platform_center + Vector2(28.5, -34) * battle.enemy_battle_platform.scale))
				var player_portrait: Control = battle.battle_stage.get_node("TrainerPortrait0")
				var social_button: Control = battle.battle_stage.get_node("BattleSocialButton")
				var social_menu: Control = battle.battle_stage.get_node("BattleSocialMenu")
				var opponent_portrait: Control = battle.battle_stage.get_node("TrainerPortrait1")
				var bounds: Rect2 = battle.get_global_rect()
				assert(battle.field_timers_panel.position.is_equal_approx(Vector2(player_portrait.position.x + player_portrait.size.x + 12, player_portrait.position.y)))
				assert(battle.battle_status_panel.position.x + battle.battle_status_panel.size.x * battle.battle_status_panel.scale.x <= opponent_portrait.position.x - 10)
				assert(battle.get_node("%PlayerStagePartyRail").visible)
				assert(battle.player_hud_panel.scale.is_equal_approx(Vector2.ONE * 0.65))
				assert(social_button.visible and player_portrait.get_global_rect().grow(12).intersects(social_button.get_global_rect()))
				social_button.emit_signal("pressed")
				await process_frame
				assert(social_menu.visible and bounds.grow(2).encloses(social_menu.get_global_rect()))
				var actions: VBoxContainer = (social_menu.get_child(0) as MarginContainer).get_child(0) as VBoxContainer
				var friends_action: Button = actions.get_child(0) as Button
				assert(actions.get_child(1).name == "BattleGuildAction")
				friends_action.emit_signal("pressed")
				await process_frame
				var friends_popup: Control = host.get_node("FriendlistPopup")
				assert(friends_popup.visible)
				friends_popup.call("close")
				assert(battle.moves_grid.scale.is_equal_approx(Vector2.ONE * 0.8))
				assert(not battle.battle_log_toggle_button.visible and not battle.calc_log_button.visible)
				var wild_portrait: Control = battle.battle_stage.get_node("TrainerPortrait1")
				var wild_icon: TextureRect = wild_portrait.get_child(1) as TextureRect
				assert(wild_portrait.visible and not wild_portrait.get_child(0).visible and wild_icon.visible and wild_icon.texture != null, "Wild encounters show the opponent's HOME icon, never a trainer avatar")
				assert(battle.battle_frame.get_global_rect().is_equal_approx(bounds))
				var viewport = battle.get_node("%BattleStageViewport")
				assert(viewport.get_global_rect().size.distance_to(bounds.size)<2.0,str(dimensions," viewport=",viewport.get_global_rect()," battle=",bounds))
				var before: Vector2 = battle.size
				battle._on_battle_log_toggle_pressed()
				await process_frame
				assert(battle.size.is_equal_approx(before), "Log toggle must not resize fullscreen arena")
				battle._on_battle_log_toggle_pressed()
				for key in ["BattleLogButton", "CalcLogButton", "ActionsDock", "PlayerPartyGrid", "MovesGrid", "UtilityActions", "OpponentStagePartyRail"]:
					var control: Control = battle.get_node("%"+key)
					assert(bounds.grow(2).encloses(control.get_global_rect()), key+" is outside screen")
				battle.player_team_preview_layer.show_team(preview_team, "back")
				battle.enemy_team_preview_layer.show_team(preview_team, "front")
				for frame in 3:
					await process_frame
				var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
				if not output.is_empty() and DisplayServer.get_name() != "headless":
					DirAccess.make_dir_recursive_absolute(output)
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join("immersive-team-preview-%sx%s.png" % [dimensions.x, dimensions.y]))
				battle.player_team_preview_layer.clear()
				battle.enemy_team_preview_layer.clear()
			else:
				assert(not battle.has_meta("immersive_battle_ui"))
				assert(battle.battle_frame.get_parent().name == "CenterColumn")
		host.release()
		host.queue_free()
		await process_frame
		print("BATTLE_UI_LAYOUT_OK ",layout)
	settings.battle_3d_catalog_path = OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	settings.battle_3d_forest_manifest = ""
	assert(FileAccess.file_exists(settings.get_battle_3d_forest_manifest()),"Local forest pack discovery")
	settings.battle_3d_forest_manifest = "user://explicit-missing.json"
	assert(settings.get_battle_3d_forest_manifest()=="user://explicit-missing.json","Explicit path wins")
	print("FOREST_DISCOVERY_OK")
	quit()


func _check_browser_contracts() -> void:
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	assert(world_source.contains('SettingsManager.battle_ui_layout == "immersive"\n\t\tand not OS.has_feature("mobile")'))
	assert(world_source.contains('SettingsManager.battle_presentation_mode == "3d"\n\t\tand not OS.has_feature("web")'))
	var settings_source := FileAccess.get_file_as_string("res://scripts/ui/settings_menu.gd")
	var layout_index := settings_source.find('layout_options.name = "BattleUILayoutOptions"')
	var desktop_index := settings_source.find('if not OS.has_feature("web") and not OS.has_feature("mobile"):')
	assert(layout_index >= 0 and desktop_index > layout_index, "Battle UI choice must remain available in browser settings")
	print("IMMERSIVE_BROWSER_CONTRACT_OK")
