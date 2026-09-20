extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "2.5d"
	for layout in ["classic", "immersive"]:
		settings.battle_ui_layout = layout
		var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
		var battle = load("res://scenes/battle/battle.tscn").instantiate()
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
		for dimensions in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2560,1080), Vector2i(1024,768)]:
			host.size = Vector2(dimensions)
			host._fit_battle()
			for frame in 5:
				await process_frame
			if layout == "immersive":
				assert(battle.has_meta("immersive_battle_ui"))
				assert(battle.get_node("%PlayerStagePartyRail").visible)
				assert(battle.player_hud_panel.scale.is_equal_approx(Vector2.ONE * 0.65))
				assert(battle.moves_grid.scale.is_equal_approx(Vector2.ONE * 0.8))
				var bounds: Rect2 = battle.get_global_rect()
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
