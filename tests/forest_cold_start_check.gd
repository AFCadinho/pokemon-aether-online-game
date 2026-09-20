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
		var view: WeakRef = weakref(stage.viewport)
		stage.queue_free()
		for frame in 5:
			await process_frame
		assert(view.get_ref()==null)
	host.queue_free()
	await process_frame
	print("FOREST_COLD_START_OK")
	quit()
