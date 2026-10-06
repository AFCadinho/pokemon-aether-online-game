extends "res://tests/native_compression_install_check.gd"
## Actual launcher UI/download queue with generated future pins. Run via the
## native HTTP runner --streaming; every phase owns a new engine process.
const Bulk = preload("res://scripts/bulk_asset_downloads.gd")

func _run() -> void:
	phase = OS.get_environment("POKEAETHER_NATIVE_PHASE")
	if phase == "policy":
		super._run()
		return
	sink.tree = self
	OS.add_logger(sink)
	base = OS.get_environment("POKEAETHER_NATIVE_HTTP_BASE")
	output = OS.get_environment("POKEAETHER_NATIVE_INSTALL_OUTPUT")
	assert(base.begins_with("http://127.0.0.1:") and output.is_absolute_path())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	fixture = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("POKEAETHER_NATIVE_FIXTURE")))
	assert(fixture.prototype_only and not fixture.production_approved)
	var label := "original" if phase in ["original-pause", "rollback"] else phase
	var stage: Dictionary = fixture.stages.filter(func(item): return item.label == label)[0]
	var descriptor := pin_stage(stage)
	service = Release.new(output.path_join("store"), output.path_join("indexes"))
	assert(service.accept_index(descriptor, stage.index_path, false).error.is_empty())
	var baseline: String = service.store.active_generation()
	var pointer_path: String = service.store.root.path_join("active.json")
	var baseline_pointer := FileAccess.get_file_as_bytes(pointer_path) if FileAccess.file_exists(pointer_path) else PackedByteArray()
	var planned := Bulk.models_plan(service, descriptor)
	assert(planned.error.is_empty(), planned.error)
	if phase == "original":
		assert(planned.jobs.size() == fixture.stages[0].descriptor.requiredAssetIds.size() - 1, "A new process must reuse the staged first bundle")
	# Known scene UID fallback warnings occur only during this cold load.
	# The runner independently rejects actual errors anywhere in the full log.
	OS.remove_logger(sink)
	var launcher = load("res://scenes/launcher.tscn").instantiate()
	launcher.set_script(load("res://tests/fixtures/offline_bulk_launcher.gd"))
	OS.add_logger(sink)
	root.add_child(launcher)
	await process_frame
	launcher.server_health_refresh_timer.stop()
	launcher.release_asset_bundles = service
	launcher.install_dir = output.path_join("game")
	launcher.manifest = {"assetBundleIndex": descriptor}
	launcher.bulk_plans = {"3d": planned}
	launcher.download_service.download_completed.connect(func(_path: String, summary: Dictionary): report.downloads.append(summary.duplicate(true)))
	launcher._set_busy(false)
	if phase == "rollback":
		launcher.download_all_3d = true
		launcher._build_download_queue()
		assert(launcher.pending_downloads.size() == 1 and launcher.pending_downloads[0].type == "asset_collection_commit", "A ready collection must activate through the normal update queue without downloading again")
		launcher._set_busy(true)
		launcher._start_next_download()
		report["automatic_update_queue"] = true
	else:
		launcher._start_bulk_download("3d")
	var deadline := Time.get_ticks_msec() + 180000
	while launcher.content_busy:
		assert(Time.get_ticks_msec() < deadline, "Streaming collection timed out")
		if phase == "original-pause" and launcher.bulk_completed_files == 1 and launcher.download_service.is_active() and launcher.download_service._current_downloaded_size() > 4096:
			report["paused_partial_bytes"] = launcher.download_service._current_downloaded_size()
			launcher._pause_bulk_download()
			assert(launcher.bulk_paused and launcher.model_collection.downloads.size() > 0)
			assert(service.store.active_generation() == baseline and baseline.is_empty())
			report["staged_bundles"] = 1
			report["active_generation_unchanged"] = true
			break
		if phase == "native-256k" and not report.get("same_process_pause_resume", false) and launcher.bulk_completed_files == 1 and launcher.download_service.is_active() and launcher.download_service._current_downloaded_size() > 4096:
			launcher._pause_bulk_download()
			assert(launcher.bulk_paused)
			await launcher._resume_bulk_download()
			assert(not launcher.bulk_paused and launcher.content_busy)
			report["same_process_pause_resume"] = true
		# No partly installed prefix may become visible while downloading.
		if launcher.download_service.is_active():
			var pointer := FileAccess.get_file_as_bytes(pointer_path) if FileAccess.file_exists(pointer_path) else PackedByteArray()
			assert(pointer == baseline_pointer)
		await process_frame
	if phase == "original-pause":
		assert(report.get("staged_bundles", 0) == 1, "Pause scenario must actually interrupt the second file")
	else:
		assert(not launcher.bulk_paused and launcher.bulk_kind.is_empty(), "Launcher failed instead of completing")
		assert(launcher.model_collection.is_empty() and launcher.pending_downloads.is_empty())
		var state: Dictionary = service.store.state()
		assert(state.assets.size() == stage.descriptor.requiredAssetIds.size())
		var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(service.catalog_path()))
		assert(entries.size() == stage.models.size())
		for entry: Dictionary in entries:
			var identity := str(entry.species) + ("@shiny" if entry.variant == "shiny" else "")
			assert(entry.runtime_sha256 == stage.models[identity].sha256)
			assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
			assert(ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
		var restarted := Release.new(service.store.root, service.index_root)
		var no_op := Bulk.models_plan(restarted, descriptor)
		assert(no_op.error.is_empty() and no_op.jobs.is_empty() and no_op.collection.is_empty())
		if phase in ["original", "native-256k"]:
			assert(report.downloads.any(func(summary: Dictionary): return int(summary.get("resumed_bytes", 0)) > 0), "Interrupted HTTP body must resume in the new process")
		if phase == "native-256k":
			assert(report.get("same_process_pause_resume", false))
		report["generation"] = service.store.active_generation()
		report["verified_appearances"] = entries.size()
		report["restart_no_op"] = true
		assert(DirAccess.get_files_at(ProjectSettings.globalize_path(launcher.TEMP_DIR)).is_empty(), "Completed ZIPs must not accumulate")
	launcher.queue_free()
	await process_frame
	report.complete = true
	report["phase"] = phase
	report["engine_os"] = OS.get_name()
	report["engine_version"] = Engine.get_version_info()
	report["engine_architecture"] = "x86_64" if OS.has_feature("x86_64") else ("arm64" if OS.has_feature("arm64") else "unknown")
	save_report()
	print("NATIVE_STREAMING_COLLECTION_OK ", phase)
	quit()
