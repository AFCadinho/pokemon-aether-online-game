extends SceneTree
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var settings = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "2.5d"
	settings.battle_ui_layout = "immersive"
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	host.mount(battle)
	host.generation += 1 # Hold preparation for the cover's rendered regression check.
	for frame in 3:
		await process_frame
	assert(host.get_node("Cover").visible)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var cover_image := root.get_texture().get_image()
		var corner := cover_image.get_pixel(10,10)
		for point in [Vector2(0.05,0.3),Vector2(0.3,0.5),Vector2(0.85,0.85)]:
			var sample := cover_image.get_pixel(int(cover_image.get_width()*point.x),int(cover_image.get_height()*point.y))
			assert(sample.is_equal_approx(corner),"Battle controls or sprites leaked through the loading cover")
	print("BATTLE_PREPARATION_COVER_OK")
	var prompt_style = battle.current_action_panel.get_theme_stylebox("panel")
	assert(prompt_style.border_width_left == 3 and prompt_style.border_width_top == 1)
	var cave_world := Node3D.new()
	var cave = load("res://scripts/battle/arenas/cave_arena.gd").new(cave_world).build()
	var found_ceiling := false
	for child in cave.get_children():
		if child is MeshInstance3D and child.mesh is PlaneMesh and child.position.y == 10:
			found_ceiling = true
			assert(child.material_override.cull_mode == BaseMaterial3D.CULL_FRONT)
			assert(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert(found_ceiling)
	cave.free()
	cave_world.free()
	host.get_node("Cover").hide()
	battle.remove_meta("battle_screen_preparing")
	battle.current_action_panel.set_message("What will Dragonite do?")
	battle.moves_grid.set_moves([{"move":"Earthquake","type":"ground","pp":9,"maxpp":10}])
	battle.moves_grid.show()
	battle.player_sprite_box.set_single_pokemon_species("Roaring Moon", "back")
	battle.enemy_sprite_box.set_single_pokemon_species("Dragonite", "front")
	var pokemon := {"species":"Arcanine","level":100,"hp":321,"max_hp":321,"ability":"Intimidate","nature":"Hardy","stats":{"atk":256,"def":196,"spa":236,"spd":196,"spe":226},"moves":[{"move":"Flamethrower","pp":15,"maxpp":15}, {"move":"Extreme Speed","pp":5,"maxpp":5}]}
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	root.mode = Window.MODE_WINDOWED
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = dimensions
		for frame in 5:
			await process_frame
		var viewport_size := root.get_visible_rect().size
		host.size = viewport_size
		host._fit_battle()
		battle.party_hover_card.show_for_pokemon(pokemon)
		for frame in 20:
			await process_frame
		battle.current_party_hover_rect = Rect2(Vector2(viewport_size.x * 0.55,viewport_size.y - 100),Vector2(100,45))
		battle.party_hover_card.position_near_rect(battle.current_party_hover_rect,viewport_size)
		await process_frame
		var typography = battle.get_node("ImmersiveTypography")
		for control in [battle.current_action_panel.message_label,battle.party_hover_card.name_label,battle.party_hover_card.ability_value_label]:
			var pixels: float = control.get_theme_font_size("font_size") * control.get_screen_transform().y.length()
			assert(absf(pixels - typography._target(control)) <= 1.5,str(dimensions," ",control.name," pixels=",pixels))
			assert(control.get_theme_font("font").multichannel_signed_distance_field)
		assert(root.get_visible_rect().grow(2).encloses(battle.party_hover_card.get_global_rect()),str("viewport=",root.get_visible_rect()," hover=",battle.party_hover_card.get_global_rect()))
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(output)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("typography-"+str(dimensions.x)+".png"))
		print("TYPOGRAPHY_OK ",dimensions)
		assert(not battle.battle_stage.get_node("ResetCameraButton").visible)
		assert(battle.player_sprite_box.scale == battle.player_battle_platform.scale)
		assert(battle.enemy_sprite_box.scale == battle.enemy_battle_platform.scale)
		assert((battle.player_sprite_box.position - battle.player_battle_platform.position).is_equal_approx(Vector2(11,-37)*0.82))
		assert((battle.enemy_sprite_box.position - battle.enemy_battle_platform.position).is_equal_approx(Vector2(23,-29)*0.82))
		var platform_gap: float = battle.enemy_battle_platform.position.x - battle.player_battle_platform.position.x
		assert(is_equal_approx(platform_gap,battle.battle_stage.size.x*0.27))
		print("IMMERSIVE_SPRITE_COMPOSITION_OK ",dimensions)
		var badges: Control = battle.player_sprite_box.single_stat_stage_panel
		badges.set_badges([{"label":"Atk","value":"▲2","line":"stage"},{"label":"Spe","value":"▲2","line":"stage"},{"label":"Taunt","line":"modifier"}])
		badges.show()
		for frame in 10:
			await process_frame
			var hud_bottom: Vector2 = battle.player_hud_panel.get_global_rect().end
			assert(absf(badges.global_position.y - hud_bottom.y) < 12,"Badges must track moving HP HUD")
		battle.party_hover_card.hide()
		battle.player_hud_panel.position = battle.enemy_hud_panel.position
		await process_frame
		await process_frame
		assert(not battle.player_hud_panel.get_global_rect().intersects(battle.enemy_hud_panel.get_global_rect()),"Overlapping HP panels must be separated")
		battle.calc_drawer.show()
		battle.calc_panel.show()
		battle.calc_panel.show_response({"success":true,"direction":battle.calc_panel.get_matchup_selection().direction,"attacker":{"species":"Dragonite","level":100,"relation":"viewer"},"defender":{"species":"Roaring Moon","level":100,"relation":"opponent","hp":351,"maxHp":351},"results":[{"move":{"name":"Outrage","type":"Dragon","category":"Physical"},"minPercent":40.0,"maxPercent":50.0,"shortLabel":"40–50%","hkoLabel":"2HKO"}]})
		battle._update_calc_drawer_layout()
		var four_moves: Dictionary = battle.calc_panel.last_response.duplicate(true)
		for move_name in ["Earthquake", "Fire Punch", "Dragon Dance"]:
			var row: Dictionary = four_moves.results[0].duplicate(true)
			row.move.name = move_name
			four_moves.results.append(row)
		battle.calc_panel.show_response(four_moves)
		for frame in 20:
			await process_frame
		var frame_rect: Rect2 = battle.battle_frame.get_global_rect()
		assert(frame_rect.encloses(battle.calc_drawer.get_global_rect()),"Calculator must remain inside battle frame")
		var workspace = battle.calc_panel.content.get_node("CalcdexWorkspace")
		assert(workspace.has_node("ResultsScroll") and workspace.has_node("SettingsScroll"))
		assert(workspace.overview_scroll.visible)
		if dimensions.x == 1280:
			assert(workspace.compact, "Small windows must use Results/Settings navigation")
		assert(workspace.overview_scroll.get_v_scroll_bar().max_value <= workspace.overview_scroll.size.y + 2,"Four move results must fit without vertical scrolling")
		if workspace.compact:
			assert(not workspace.inspector_scroll.visible)
			workspace.settings_button.pressed.emit()
			for frame in 3:
				await process_frame
			assert(workspace.inspector_scroll.visible and not workspace.overview_scroll.visible)
			battle.calc_panel.show_response(four_moves)
			for frame in 5:
				await process_frame
			workspace = battle.calc_panel.content.get_node("CalcdexWorkspace")
			assert(workspace.settings_selected,"Recalculation must preserve Settings navigation")
			workspace.results_button.pressed.emit()
			for frame in 3:
				await process_frame
		else:
			assert(workspace.inspector_scroll.visible)
			assert(not workspace.overview_scroll.get_global_rect().intersects(workspace.inspector_scroll.get_global_rect()))
		assert(battle.calc_panel.get_node("CalcScroll").vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("calculator-"+str(dimensions.x)+".png"))
		battle.calc_drawer.hide()
		print("IMMERSIVE_CALCULATOR_OK ",dimensions)
	var portraits: Node
	for child in battle.get_children():
		if child.get_script() == load("res://scripts/battle/battle_ui/immersive_portraits.gd"):
			portraits = child
	assert(portraits != null)
	var appearance: Dictionary = root.get_node("PlayerSave").to_appearance_state()
	battle.player_trainer_sprite.show_player(appearance, Vector2.RIGHT)
	battle.enemy_trainer_sprite.show_player(appearance, Vector2.LEFT)
	for frame in 3:
		await process_frame
	assert(not portraits.speakers[0].visible and not portraits.speakers[1].visible)
	battle.player_trainer_sprite.show_command("Dragonite, use Dragon Dance!", 0.6)
	battle.enemy_trainer_sprite.show_command("We are ready for you!", 0.6)
	await create_timer(0.25).timeout
	for index in 2:
		assert(portraits.speakers[index].visible)
		assert(portraits.figures[index].get_child_count() > 0)
		assert(portraits.cards[index].visible)
		assert(portraits.figures[index].get_child(0).flip_h == (index == 0))
		assert(portraits.speakers[index].mouse_filter == Control.MOUSE_FILTER_IGNORE)
		assert(portraits.figures[index].get_child_count() == BattlePlayerTrainerCatalog.build_layers(appearance).size())
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("speaking-trainers.png"))
	await create_timer(0.8).timeout
	assert(not portraits.speakers[0].visible and not portraits.speakers[1].visible)
	assert(portraits.cards[0].visible and portraits.cards[1].visible)
	print("IMMERSIVE_SPEAKING_TRAINERS_OK")
	host.release()
	host.queue_free()
	await process_frame
	quit()
