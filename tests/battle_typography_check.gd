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
	host.get_node("Cover").hide()
	battle.current_action_panel.set_message("What will Dragonite do?")
	battle.moves_grid.set_moves([{"move":"Earthquake","type":"ground","pp":9,"maxpp":10}])
	battle.moves_grid.show()
	var pokemon := {"species":"Arcanine","level":100,"hp":321,"max_hp":321,"ability":"Intimidate","nature":"Hardy","stats":{"atk":256,"def":196,"spa":236,"spd":196,"spe":226},"moves":[{"move":"Flamethrower","pp":15,"maxpp":15}, {"move":"Extreme Speed","pp":5,"maxpp":5}]}
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = dimensions
		host.size = Vector2(dimensions)
		host._fit_battle()
		battle.party_hover_card.show_for_pokemon(pokemon)
		for frame in 20:
			await process_frame
		battle.party_hover_card.position_near_rect(Rect2(Vector2(dimensions.x * 0.55,dimensions.y - 100),Vector2(100,45)),Vector2(dimensions))
		await process_frame
		var typography = battle.get_node("ImmersiveTypography")
		for control in [battle.current_action_panel.message_label,battle.party_hover_card.name_label,battle.party_hover_card.ability_value_label]:
			var pixels: float = control.get_theme_font_size("font_size") * control.get_screen_transform().y.length()
			assert(absf(pixels - typography._target(control)) <= 1.5,str(dimensions," ",control.name," pixels=",pixels))
			assert(control.get_theme_font("font").multichannel_signed_distance_field)
		assert(root.get_visible_rect().grow(2).encloses(battle.party_hover_card.get_global_rect()))
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(output)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("typography-"+str(dimensions.x)+".png"))
		print("TYPOGRAPHY_OK ",dimensions)
	host.release()
	host.queue_free()
	await process_frame
	quit()
