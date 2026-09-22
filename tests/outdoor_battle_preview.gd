extends SceneTree
## Render the actual paired Pokémon material pipeline at fixed world times.
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(100).timeout.connect(func(): printerr("OUTDOOR_PREVIEW_TIMEOUT"); quit(2))
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_camera_motion = false
	settings.battle_3d_arena = "auto"
	settings.battle_3d_catalog_path = OS.get_environment("SUMMARY_MODEL_CATALOG")
	settings._manual_model_catalog_this_session = true
	settings.battle_3d_forest_manifest = OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	var host := Node.new()
	root.add_child(host)
	current_scene = host
	var arenas := {
		&"forest": &"grass",
		&"sea": &"water",
		&"route_1": &"route_1",
		&"route_1_water": &"route_1_water",
		&"route_22": &"route_22",
		&"route_22_water": &"route_22_water",
	}
	for arena_id in arenas:
		var stage := Stage.new()
		stage.environment_id = arenas[arena_id]
		host.add_child(stage)
		stage.size = Vector2(1280, 720)
		stage.setup()
		stage.set_combatant(0, "garchomp")
		stage.set_combatant(1, "azumarill")
		while not stage.active or not stage._actors_resolved():
			await process_frame
		await stage.await_prepared(true, 30000)
		assert(not stage.preparation_failed and stage.arena_id == arena_id, stage.reason)
		assert(stage.arena_root.has_node("OutdoorLighting"))
		for hour in [6, 12, 19, 23]:
			root.get_node("WorldTimeService").set_debug_time(hour)
			await create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			assert(stage.viewport.get_texture().get_image().save_png(output.path_join("%s-pokemon-%02d.png" % [arena_id, hour])) == OK)
		stage.queue_free()
		for frame in 6:
			await process_frame
	root.get_node("WorldTimeService").clear_debug_time()
	host.queue_free()
	print("OUTDOOR_BATTLE_PREVIEW_OK")
	quit()
