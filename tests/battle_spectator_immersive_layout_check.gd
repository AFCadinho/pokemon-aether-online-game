extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_ui_layout = "immersive"
	settings.battle_presentation_mode = "2.5d"
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	host.mount(battle)
	await process_frame
	host.get_node("Cover").hide()
	battle.pvp_room_code = "spectator-layout"
	battle.pvp_viewer_role = "spectator"
	battle._enter_spectator_controls()
	var output := OS.get_environment("POKEAETHER_SPECTATOR_CAPTURE_DIR")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		host.size = dimensions
		host._fit_battle()
		for frame in 12:
			await process_frame
		var prompt_rect: Rect2 = battle.current_action_panel.get_global_rect()
		var spectator_rect: Rect2 = battle.spectator_action_panel.get_global_rect()
		_check(not prompt_rect.intersects(spectator_rect), "%s message clears spectator controls" % dimensions)
		_check(prompt_rect.end.y + 8.0 <= spectator_rect.position.y, "%s spectator rows retain visible vertical spacing" % dimensions)
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(output)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("immersive-spectator-%s.png" % dimensions.x))
	host.release()
	host.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
