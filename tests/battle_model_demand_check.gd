extends SceneTree

const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
var retained_memory: Array[int] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_catalog_path = OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	assert(not settings.battle_3d_catalog_path.is_empty())
	settings.battle_3d_arena = "stadium"
	settings.battle_3d_camera_motion = false
	Renderer.ModelCache.clear()
	for cycle in 3:
		var stage := Renderer.new()
		root.add_child(stage)
		stage.setup()
		await stage.await_prepared(true)
		assert(stage.active and not stage.preparation_failed)
		assert(stage.identities == ["", ""] and stage.packed.is_empty())
		assert(stage.pending_entries.is_empty() and stage.import_times_ms.is_empty())
		assert(stage.model_validation_ms == 0.0)
		print("DEMAND_EMPTY_PREVIEW ", cycle, " ", stage.preparation_metrics)
		stage.set_combatant(0, "Eevee")
		await stage.await_prepared(true)
		assert(not stage.active and stage.packed.is_empty())
		assert(stage.import_times_ms.is_empty())
		stage.set_combatant(0, "Dragonite")
		stage.set_actor_shown(0, false)
		await stage.await_prepared()
		assert(stage.handles("p1") and not stage.handles("p2"))
		assert(stage.packed.keys() == ["dragonite"])
		assert(not stage.import_times_ms.has("roaring-moon"))
		assert(not stage.actors[0].visible)
		assert(await stage.send_out("p1"))
		var first_actor: WeakRef = weakref(stage.actors[0])
		stage.set_combatant(1, "Roaring Moon")
		stage.set_actor_shown(1, false)
		await stage.await_prepared()
		assert(stage.handles("p2") and not stage.actors[1].visible)
		assert(await stage.send_out("p2"))
		assert(stage.packed.size() == 2)
		print("DEMAND_PAIR ", cycle, " ", stage.preparation_metrics)
		var validation_before: float = stage.model_validation_ms
		for repeat in 3:
			assert(await stage.recall("p1"))
			stage.set_combatant(0, "Roaring Moon")
			assert(not stage.handles("p1"), "Retiring actor must not handle new identity")
			stage.set_actor_shown(0, false)
			await stage.await_prepared()
			assert(stage.identities == ["roaring-moon", "roaring-moon"])
			assert(stage.actors[0] != stage.actors[1])
			assert(stage.packed.keys() == ["roaring-moon"])
			assert(await stage.send_out("p1"))
			stage.set_combatant(0, "Dragonite")
			stage.set_actor_shown(0, false)
			await stage.await_prepared()
			assert(stage.handles("p1"))
			assert(stage.import_times_ms.dragonite == 0.0)
			assert(await stage.send_out("p1"))
		assert(first_actor.get_ref() == null)
		assert(stage.model_validation_ms == validation_before, "Switching must reuse this catalog snapshot")
		# Render real models/material response and measure CPU/GPU independently
		# of scene imports. No shader cache deletion or quality changes.
		await stage.await_prepared(true)
		var rid := stage.viewport.get_viewport_rid()
		var response_rid: RID = stage.material_response.viewport.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(rid, true)
		RenderingServer.viewport_set_measure_render_time(response_rid, true)
		var cpu_ms := 0.0
		var gpu_ms := 0.0
		var response_cpu_ms := 0.0
		var response_gpu_ms := 0.0
		for frame in 20:
			await process_frame
			cpu_ms = maxf(cpu_ms, RenderingServer.viewport_get_measured_render_time_cpu(rid))
			gpu_ms = maxf(gpu_ms, RenderingServer.viewport_get_measured_render_time_gpu(rid))
			response_cpu_ms = maxf(response_cpu_ms, RenderingServer.viewport_get_measured_render_time_cpu(response_rid))
			response_gpu_ms = maxf(response_gpu_ms, RenderingServer.viewport_get_measured_render_time_gpu(response_rid))
		print("DEMAND_RENDER ", cycle, " main_viewport_cpu_max_ms=", cpu_ms, " main_viewport_gpu_max_ms=", gpu_ms,
			" response_cpu_max_ms=", response_cpu_ms, " response_gpu_max_ms=", response_gpu_ms,
			" video_bytes=", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED), " ", stage.preparation_metrics)
		RenderingServer.viewport_set_measure_render_time(rid, false)
		RenderingServer.viewport_set_measure_render_time(response_rid, false)
		stage.set_combatant(0, "")
		stage.set_combatant(1, "")
		await stage.await_prepared(true)
		assert(stage.active and stage.packed.is_empty() and stage.actors == [null, null])
		var viewport_ref: WeakRef = weakref(stage.viewport)
		stage.queue_free()
		for frame in 10:
			await process_frame
		assert(viewport_ref.get_ref() == null)
		assert(Renderer.ModelCache.items.size() == 2)
		retained_memory.append(OS.get_static_memory_usage())
	print("DEMAND_RETAINED_MEMORY ", retained_memory)
	assert(retained_memory[2] - retained_memory[1] < 1048576)
	Renderer.ModelCache.clear()
	# Cancel an actual asynchronous request; its detached drain may complete,
	# but must not publish into the cancelled presenter or shared cache.
	var cancelled := Renderer.new()
	root.add_child(cancelled)
	cancelled.setup()
	cancelled.set_combatant(0, "Dragonite")
	cancelled._load_catalog(settings.battle_3d_catalog_path)
	cancelled._import_next_model()
	assert(cancelled.integrity_read != null and cancelled._models_pending())
	cancelled.cancel_preparation()
	await process_frame
	assert(cancelled.integrity_read == null and cancelled.packed.is_empty())
	cancelled.preparation_cancelled = false
	cancelled._load_catalog(settings.battle_3d_catalog_path)
	var cancel_deadline := Time.get_ticks_msec() + 10000
	while cancelled.loading_path.is_empty():
		cancelled._import_next_model()
		assert(Time.get_ticks_msec() < cancel_deadline)
		await process_frame
	assert(not cancelled.loading_path.is_empty())
	cancelled.cancel_preparation()
	await cancelled.await_prepared(true)
	for frame in 40:
		await process_frame
	assert(cancelled.packed.is_empty() and Renderer.ModelCache.items.is_empty())
	cancelled.queue_free()
	await process_frame
	# A model changed between validation and threaded completion is rejected
	# once (no infinite retry); original approved files are never modified.
	var rejected := Renderer.new()
	root.add_child(rejected)
	rejected.setup()
	rejected.set_process(false)
	rejected.set_combatant(0, "Dragonite")
	rejected._load_catalog(settings.battle_3d_catalog_path)
	rejected.pending_entries[0]._verified_runtime_hash = "stale-fixture"
	rejected.pending_entries[0]._resource_cache_key = ""
	rejected._import_next_model()
	var deadline := Time.get_ticks_msec() + 10000
	while not rejected.loading_path.is_empty():
		rejected._import_next_model()
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	assert(rejected.failed_models.has("dragonite") and rejected.packed.is_empty())
	rejected._queue_needed_models()
	assert(rejected.pending_entries.is_empty() and Renderer.ModelCache.items.is_empty())
	rejected.queue_free()
	await process_frame
	print("MODEL_DEMAND_AND_SWITCH_OK")
	quit()
