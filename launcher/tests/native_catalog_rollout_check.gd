extends SceneTree
const Release = preload("res://scripts/release_asset_bundles.gd")
const Demand = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
var report := {"complete": false, "production_approved": false, "prototype_only": true}
var output: String

func release_actor(actor: Node3D) -> void:
	# Let RenderingServer observe scene/material creation and teardown in the
	# same order as the client. Immediate detached free races override RIDs.
	root.add_child(actor)
	await process_frame
	await RenderingServer.frame_post_draw
	actor.queue_free()
	await process_frame
	await process_frame

class ErrorSink extends Logger:
	var tree: SceneTree
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, _kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		tree.call_deferred("abort", code + " " + rationale)
var sink := ErrorSink.new()
func _init() -> void: _run.call_deferred()
func save() -> void:
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
func abort(message: String) -> void:
	report.complete = false
	report["failure"] = message
	if not output.is_empty(): save()
	quit(2)
func snapshot(service: RefCounted, label: String, identities := []) -> Array:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(service.catalog_path()))
	var selected := []
	for row: Dictionary in rows:
		var identity: String = row.species + ("@shiny" if row.variant == "shiny" else "")
		if identities.is_empty() or identity in identities:
			assert(FileAccess.get_sha256(row.runtime_path) == row.runtime_sha256)
			selected.append(row)
	var file := FileAccess.open(output.path_join(label + "-catalog.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(selected, "\t") + "\n")
	return selected
func _run() -> void:
	sink.tree = self
	OS.add_logger(sink)
	output = OS.get_environment("NATIVE_ROLLOUT_OUTPUT")
	var lifetime_catalog := OS.get_environment("NATIVE_ROLLOUT_LIFETIME_CATALOG")
	if not lifetime_catalog.is_empty():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(lifetime_catalog))
		assert(rows.size() == int(OS.get_environment("NATIVE_ROLLOUT_EXPECTED_SCENES")))
		var loaded := 0
		for row: Dictionary in rows:
			assert(FileAccess.get_sha256(row.runtime_path) == row.runtime_sha256)
			assert(ResourceLoader.get_dependencies(row.runtime_path).is_empty())
			var packed: PackedScene = ResourceLoader.load(row.runtime_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
			assert(packed != null)
			var reference: WeakRef = weakref(packed)
			var actor := packed.instantiate() as Node3D
			assert(actor != null)
			await release_actor(actor)
			packed = null
			await process_frame
			assert(reference.get_ref() == null, "Scene retained after actor cleanup")
			loaded += 1
			if loaded % 100 == 0: print("NATIVE_CATALOG_LIFETIME_OK ", loaded, "/", rows.size())
		report["phase"] = "native_load_instantiate_render_release"
		report["native_scenes_loaded"] = loaded
		report["scene_references_released"] = true
		report["renderer"] = RenderingServer.get_current_rendering_method()
		report["godot"] = Engine.get_version_info().string
		report.complete = true
		save()
		quit()
		return
	var load_catalog := OS.get_environment("NATIVE_ROLLOUT_LOAD_ONLY_CATALOG")
	if not load_catalog.is_empty():
		# A distinct deserialization check. This does not certify instantiation
		# or erase the retained full-run renderer failure.
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(load_catalog))
		assert(rows.size() == 2400)
		var loaded := 0
		for row: Dictionary in rows:
			assert(FileAccess.get_sha256(row.runtime_path) == row.runtime_sha256)
			assert(ResourceLoader.get_dependencies(row.runtime_path).is_empty())
			var packed: PackedScene = ResourceLoader.load(row.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
			assert(packed != null and packed.get_state().get_node_count() > 0)
			packed = null
			loaded += 1
			if loaded % 100 == 0: print("NATIVE_CATALOG_DESERIALIZED ", loaded, "/2400")
			await process_frame
		report["phase"] = "full_native_deserialization_only"
		report["native_scenes_deserialized"] = loaded
		report["runtime_instantiation_qualified"] = false
		report["godot"] = Engine.get_version_info().string
		report.complete = true
		save()
		quit()
		return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("NATIVE_ROLLOUT_FIXTURE")))
	var installation := OS.get_environment("NATIVE_ROLLOUT_ROLLBACK_INSTALLATION")
	if not installation.is_empty():
		var service := Release.new(installation.path_join("store"), installation.path_join("indexes"))
		var original: Dictionary = fixture.stages[0]
		var index := service.cached_index(original.descriptor)
		assert(index.assets.size() == 1200)
		var paths := {}
		for asset_id: String in fixture.control_asset_ids: paths[asset_id] = original.archives[asset_id]
		assert(service.accept_bundles(index, paths).error.is_empty())
		var restored := snapshot(service, "rollback", fixture.control_identities)
		var before: Array = JSON.parse_string(FileAccess.get_file_as_string(installation.path_join("original-catalog.json")))
		assert(restored == before)
		report["phase"] = "nine_control_pairs_rollback_only"
		report["control_pairs_rollback"] = paths.size()
		report["appearances_restored"] = restored.size()
		report.complete = true
		save()
		quit()
		return
	var identities: Array[String] = []
	identities.assign(fixture.control_identities)
	var service := Release.new(output.path_join("store"), output.path_join("indexes"))
	for stage: Dictionary in fixture.stages:
		assert(Release.descriptor_error(stage.descriptor).is_empty())
		assert(service.accept_index(stage.descriptor, stage.index_path, false).error.is_empty())
		assert(service.cached_index(stage.descriptor).assets.size() == 1200)
		var mixed: Dictionary = stage.descriptor.duplicate(true)
		mixed.sha256 = fixture.stages[1 if stage.label == "original" else 0].descriptor.sha256
		assert(not Release.descriptor_error(mixed).is_empty())
	var original: Dictionary = fixture.stages[0]
	var native: Dictionary = fixture.stages[1]
	var old_index: Dictionary = service.cached_index(original.descriptor)
	var new_index: Dictionary = service.cached_index(native.descriptor)
	var old_paths := {}
	for asset_id: String in fixture.control_asset_ids:
		old_paths[asset_id] = original.archives[asset_id]
	var original_rows: Array
	var all_rows: Array
	if OS.get_environment("NATIVE_ROLLOUT_RESUME_INSTALLED") == "1":
		report = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("previous-attempt-report.json")))
		report.erase("failure")
		assert(service.jobs(native.descriptor).jobs.is_empty())
		original_rows = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("original-catalog.json")))
		for row: Dictionary in original_rows:
			assert(FileAccess.get_sha256(row.runtime_path) == row.runtime_sha256)
		all_rows = snapshot(service, "full-native")
		assert(all_rows.size() == 2400)
	else:
		assert(service.jobs(native.descriptor).jobs.size() == 1200)
		assert(service.accept_bundles(old_index, old_paths).error.is_empty())
		original_rows = snapshot(service, "original", fixture.control_identities)
		assert(original_rows.size() == fixture.control_identities.size())
		var stable: String = service.store.active_generation()
		var failed := {fixture.control_asset_ids[0]: native.archives[fixture.control_asset_ids[0]], fixture.control_asset_ids[-1]: output.path_join("missing.zip")}
		assert(not service.accept_bundles(new_index, failed).error.is_empty())
		assert(service.store.active_generation() == stable, "Failed collection exposed its successful prefix")
		report["failed_batch_preserves_active_generation"] = true
		var started := Time.get_ticks_usec()
		var installed := service.accept_bundles(new_index, native.archives)
		assert(installed.error.is_empty(), installed.error)
		report["complete_install_ms"] = (Time.get_ticks_usec() - started) / 1000.0
		all_rows = snapshot(service, "full-native")
		assert(all_rows.size() == 2400)
		snapshot(service, "native-256k", fixture.control_identities)
	var generation: String = service.store.active_generation()
	service = Release.new(output.path_join("store"), output.path_join("indexes"))
	assert(service.store.active_generation() == generation)
	assert(service.jobs(native.descriptor).jobs.is_empty())
	report["pairs_installed"] = 1200
	report["appearances_installed"] = all_rows.size()
	report["restart_no_op"] = true
	# Both exact pins remain selectable even though their ID sets are identical.
	var demand := Demand.new()
	root.add_child(demand)
	for stage: Dictionary in fixture.stages:
		OS.set_environment("POKEAETHER_MODEL_INDEX", stage.index_path)
		assert(demand._selected_release().revision == stage.descriptor.revision)
		var path := output.path_join(stage.label + "-catalog.json")
		var ready := await demand.ensure_models(identities, path)
		assert(ready.error.is_empty() and ready.path == path and demand.active_request == null)
	OS.set_environment("POKEAETHER_MODEL_INDEX", native.index_path)
	assert(demand._installed_models(identities, output.path_join("original-catalog.json")).is_empty())
	var first: Dictionary = new_index.assets[0]
	var unpacked := demand._unpack_asset(first, native.archives[first.asset_id])
	assert(unpacked.error.is_empty() and unpacked.entries.size() == 2)
	var damaged := FileAccess.open(unpacked.entries[0].runtime_path, FileAccess.WRITE)
	damaged.store_string("corrupt-test")
	damaged.close()
	assert(not demand._entry_available(unpacked.entries, first.appearances[0].runtime_identity, first.appearances[0].runtime_sha256))
	assert(demand._unpack_asset(first, native.archives[first.asset_id]).error.is_empty())
	demand.queue_free()
	report["on_demand_pin_selection_cached_reuse_and_repair"] = true
	# Load every native scene using the real engine; no original cache is seeded.
	var loaded := 0
	for row: Dictionary in all_rows:
		assert(ResourceLoader.get_dependencies(row.runtime_path).is_empty())
		var packed: PackedScene = ResourceLoader.load(row.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		assert(packed != null)
		var node := packed.instantiate() as Node3D
		assert(node != null)
		await release_actor(node)
		packed = null
		loaded += 1
		await process_frame
		if loaded % 100 == 0:
			print("NATIVE_CATALOG_ENGINE_LOADED ", loaded, "/2400")
	report["native_scenes_loaded"] = loaded
	assert(service.accept_bundles(old_index, old_paths).error.is_empty())
	var rolled_back := snapshot(service, "rollback", fixture.control_identities)
	assert(rolled_back == original_rows)
	report["control_pairs_rollback"] = fixture.control_asset_ids.size()
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["godot"] = Engine.get_version_info().string
	report.complete = true
	save()
	print("NATIVE_FULL_CATALOG_INSTALL_LOAD_OK pairs=1200 appearances=2400")
	quit()
