extends SceneTree

const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Cache.clear()
	var scene := PackedScene.new()
	var node := Node3D.new()
	assert(scene.pack(node) == OK)
	node.free()
	assert(Cache.key("a", "hash", {"a": 1, "b": 2}) == Cache.key("a", "hash", {"b": 2, "a": 1}))
	assert(Cache.key("a", "hash", {}) != Cache.key("a", "changed", {}))
	assert(Cache.key("a", "hash", {}) != Cache.key("b", "hash", {}))
	assert(Cache.key("a", "hash", {}) != Cache.key("a", "hash", {"duration": 2}))
	Cache.retain("a", scene, 10)
	Cache.retain("b", scene, 10)
	assert(Cache.fetch("a") == scene)
	Cache.retain("c", scene, 10)
	assert(Cache.fetch("b") == null and Cache.order.size() == 2)
	Cache.retain("large", scene, Cache.MAX_SOURCE_BYTES)
	assert(Cache.order == ["large"] and Cache.source_bytes == Cache.MAX_SOURCE_BYTES)
	Cache.retain("oversize", scene, Cache.MAX_SOURCE_BYTES + 1)
	assert(Cache.fetch("oversize") == null)
	Cache.clear()
	assert(Cache.items.is_empty() and Cache.source_bytes == 0)
	node = scene.instantiate()
	assert(node != null) # Eviction does not invalidate an active resource owner.
	node.free()
	print("MODEL_CACHE_LIMITS_OK")
	var report := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	assert(not report.is_empty(), "Real prepared pair required")
	var ids := {}
	var retained_bytes := 0
	for cycle in 3:
		var stage := Renderer.new()
		var started := Time.get_ticks_usec()
		stage._load_catalog(report)
		var deadline := Time.get_ticks_msec() + 15000
		while not stage.pending_entries.is_empty() or not stage.loading_path.is_empty():
			stage._import_next_model()
			assert(Time.get_ticks_msec() < deadline)
			await process_frame
		assert(stage.packed.size() == 2, stage.catalog_problem)
		assert(stage.model_cache_hits == (0 if cycle == 0 else 2))
		for species in stage.packed:
			if cycle == 0:
				ids[species] = stage.packed[species].get_instance_id()
			else:
				assert(ids[species] == stage.packed[species].get_instance_id())
				assert(stage.import_times_ms[species] == 0.0)
			var actor = stage.packed[species].instantiate()
			var actor_ref: WeakRef = weakref(actor)
			actor.free()
			assert(actor_ref.get_ref() == null)
		if cycle == 0:
			retained_bytes = Cache.source_bytes
		assert(Cache.source_bytes == retained_bytes and Cache.order.size() == 2)
		print("MODEL_CACHE_CYCLE ", cycle, " hits=", stage.model_cache_hits, " catalog_ms=", stage.catalog_read_ms,
			" import_ms=", stage.import_times_ms, " total_ms=", (Time.get_ticks_usec()-started)/1000.0,
			" retained_source_bytes=", Cache.source_bytes)
		stage.free()
	Cache.clear()
	print("MODEL_CACHE_REAL_PAIR_OK")
	quit()
