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
	root.size = Vector2i(1920, 1080)
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
	_disable_gameplay(battle)
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	for zoom in [1.0, 0.72]:
		renderer.user_camera_zoom = zoom
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("%s-%s-%.2f.png" % [left_species.to_snake_case(), right_species.to_snake_case(), zoom]))
		var safe: Rect2 = renderer.OverviewCamera.safe_rect(renderer)
		for point in renderer.OverviewCamera.resting_points(renderer):
			var pixel: Vector2 = renderer.camera.unproject_position(point)
			assert(safe.grow(0.0001).has_point(pixel / Vector2(renderer.viewport.size)), "Real model outside safe frame")
	print("OVERVIEW_CAMERA_PREVIEW_OK caster=%s opponent=%s default_zoom=true maximum_zoom=true" % [left_species, right_species])
	host.release()
	host.queue_free()
	await process_frame
	quit()
