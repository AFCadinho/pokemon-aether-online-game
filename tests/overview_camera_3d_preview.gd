extends "res://tests/battle_dialogue_preview.gd"
## Offline full-HUD review: --moves [--caster=Dragonite] [--opponent=Pikachu].
func _load_preview() -> void:
	left_species = "Iron Treads"
	right_species = "Zamazenta"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--caster="): left_species = arg.trim_prefix("--caster=")
		if arg.begins_with("--opponent="): right_species = arg.trim_prefix("--opponent=")
	await super._load_preview()

func _start() -> void:
	root.size = Vector2i(960, 600) if "--small-window" in OS.get_cmdline_user_args() else Vector2i(1920, 1080)
	root.get_node("SettingsManager").battle_3d_camera_motion = false
	await super._start()
	var renderer: Node = battle.animation_router.model_presenter
	assert(renderer.active, renderer.reason)
	toolbar.get_parent().hide()
	battle.current_action_panel.set_message("What will %s do?" % left_species)
	battle.moves_grid.set_moves([
		{"move":"Earthquake", "type":"Ground", "pp":15, "maxpp":16},
		{"move":"Ice Spinner", "type":"Ice", "pp":24, "maxpp":24},
		{"move":"Stealth Rock", "type":"Rock", "pp":32, "maxpp":32},
		{"move":"Rapid Spin", "type":"Normal", "pp":64, "maxpp":64}])
	battle.moves_grid.show()
	battle.player_sprite_box.single_stat_stage_panel.set_stat_stages({"atk":2, "spe":1})
	battle.enemy_sprite_box.single_stat_stage_panel.set_stat_stages({"def":1})
	_disable_gameplay(battle)
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	var hp_positions: Array[Vector2] = []
	for zoom in [1.0, 0.72]:
		renderer.user_camera_zoom = zoom
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		_check_hp_row()
		if hp_positions.is_empty():
			hp_positions.assign([battle.player_hud_panel.position, battle.enemy_hud_panel.position])
		else:
			assert(hp_positions == [battle.player_hud_panel.position, battle.enemy_hud_panel.position], "Zoom never moves HP cards")
		root.get_texture().get_image().save_png(output.path_join("%s-%s-%.2f.png" % [left_species.to_snake_case(), right_species.to_snake_case(), zoom]))
		var safe: Rect2 = renderer.OverviewCamera.safe_rect(renderer)
		for point in renderer.OverviewCamera.resting_points(renderer):
			var pixel: Vector2 = renderer.camera.unproject_position(point)
			assert(safe.grow(0.0001).has_point(pixel / Vector2(renderer.viewport.size)), "Real model outside safe frame")
	renderer.user_camera_yaw = 1.1
	renderer.user_camera_pitch = 0.25
	await create_timer(0.2).timeout
	assert(hp_positions == [battle.player_hud_panel.position, battle.enemy_hud_panel.position], "Orbit never moves HP cards")
	root.get_node("SettingsManager").battle_3d_camera_motion = true
	battle.animation_router.playback_speed = 0.0
	renderer.start_move_action("p1", "Hyper Beam")
	var effect: Node = renderer.create_move_effect("Hyper Beam", "p1", "p2", {})
	var sample: float = effect.launch * 0.6
	effect.clock = func(): return sample
	renderer.players[0].seek(sample, true)
	await create_timer(0.2).timeout
	_check_hp_row()
	assert(hp_positions == [battle.player_hud_panel.position, battle.enemy_hud_panel.position], "Cinematic shots never move HP cards")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("fixed-hp-cinematic.png"))
	effect.cancel()
	print("OVERVIEW_CAMERA_PREVIEW_OK caster=%s opponent=%s default_zoom=true maximum_zoom=true fixed_hp=true orbit=true cinematic=true" % [left_species, right_species])
	host.release()
	host.queue_free()
	await process_frame
	quit()

func _check_hp_row() -> void:
	var player: Control = battle.player_hud_panel
	var enemy: Control = battle.enemy_hud_panel
	assert(is_equal_approx(player.position.y, enemy.position.y), "HP cards share a row")
	assert(player.position.x + player.size.x * player.scale.x < battle.battle_stage.size.x * 0.5)
	assert(enemy.position.x > battle.battle_stage.size.x * 0.5)
	for card: Control in [player, enemy]:
		var rectangle := card.get_global_rect()
		for path in ["%VSPanelContainer", "%BattleStatusPanel"]:
			assert(not rectangle.intersects(battle.get_node(path).get_global_rect()), "HP cards leave the header clear")
	for index in 2:
		var box: Control = battle.player_sprite_box if index == 0 else battle.enemy_sprite_box
		var card: Control = player if index == 0 else enemy
		var badges: Control = box.single_stat_stage_panel
		assert(badges.is_visible_in_tree(), "Stat indicators remain visible in 3D")
		assert(badges.get_global_rect().position.y >= card.get_global_rect().end.y, "Indicators sit below their HP card")
		assert(absf(badges.global_position.x - card.global_position.x) < 1.0)
