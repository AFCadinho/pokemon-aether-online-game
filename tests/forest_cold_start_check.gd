extends SceneTree
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var settings = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "forest"
	settings.battle_3d_catalog_path = OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	settings.battle_3d_forest_manifest = ""
	assert(Arenas.forest_scene == null, "Must start in a fresh process")
	var pool: Node
	if OS.get_environment("POKEAETHER_TEST_FOREST_POOL") == "1":
		pool = preload("res://scripts/battle/arenas/forest_environment_pool.gd").prepare(root,settings.get_battle_3d_forest_manifest(),Vector2i(1152,648))
		assert(pool != null)
		while not pool.ready_for_battle:
			assert(not pool.failed)
			await process_frame
	if OS.get_environment("POKEAETHER_TEST_FOREST_PREFETCH") == "1":
		var prefetch_started := Time.get_ticks_msec()
		assert(Arenas.prepare_forest(settings.get_battle_3d_forest_manifest()).is_empty())
		while not Arenas.forest_ready():
			assert(Time.get_ticks_msec()-prefetch_started < 30000)
			await process_frame
		print("FOREST_PREFETCH_MS=",Time.get_ticks_msec()-prefetch_started)
	var host := Control.new()
	root.add_child(host)
	current_scene = host
	for cycle in 2:
		var stage := Renderer.new()
		host.add_child(stage)
		stage.size = Vector2(1152,648)
		stage.setup()
		stage.set_combatant(0,"Dragonite")
		stage.set_combatant(1,"Roaring Moon")
		var started := Time.get_ticks_msec()
		await stage.await_prepared(true)
		print("FOREST_COLD_PREP cycle=",cycle," ms=",Time.get_ticks_msec()-started," failed=",stage.preparation_failed," active=",stage.active," arena=",stage.arena_id," imports=",stage.import_times_ms," metrics=",stage.preparation_metrics)
		if stage.preparation_failed or not stage.active or stage.arena_id != "forest":
			quit(1)
			return
		if pool != null:
			assert(stage.viewport == pool.passes[0].viewport,"Must reuse the prepared terrain, not rebuild it")
			assert(await stage.recall("p1"))
			assert(await stage.send_out("p1"))
			for action in ["physical_attack","special_attack","damage","faint_start"]:
				await stage.play_action("p2",action)
			stage.set_combatant(0,"Roaring Moon")
			for frame in 10:
				await process_frame
			assert(stage.identities[0] == "roaring-moon")
			if cycle == 1:
				settings.battle_presentation_mode = "2.5d"
				for frame in 5:
					await process_frame
				assert(pool.borrower == null and stage.viewport == null)
				settings.battle_presentation_mode = "3d"
		var view: WeakRef = weakref(pool.passes[0].viewport if pool != null else stage.viewport)
		stage.queue_free()
		for frame in 5:
			await process_frame
		if pool != null:
			assert(view.get_ref() == pool.passes[0].viewport or cycle == 1)
			assert(pool.borrower == null)
			for pass_data in pool.passes:
				assert(pass_data.world.get_child_count() == pass_data.base.size(),"Battle nodes leaked into environment pool")
				assert(pass_data.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
			print("FOREST_POOL_IDLE cycle=",cycle," nodes=",Performance.get_monitor(Performance.OBJECT_NODE_COUNT)," video_mem=",Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		else:
			assert(view.get_ref()==null)
	if pool != null:
		var retained_view: WeakRef = weakref(pool.passes[0].viewport)
		pool.queue_free()
		await process_frame
		await process_frame
		assert(retained_view.get_ref() == null,"World teardown must free retained environment")
	host.queue_free()
	await process_frame
	print("FOREST_COLD_START_OK")
	quit()
