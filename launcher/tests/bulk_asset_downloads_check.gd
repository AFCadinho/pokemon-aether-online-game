extends SceneTree
const Bulk = preload("res://scripts/bulk_asset_downloads.gd")
const Release = preload("res://scripts/release_asset_bundles.gd")
const V8 = preload("res://data/approved_3d_release_v8.json")

class DownloadProbe extends "res://scripts/resumable_download_service.gd":
	var active := false
	var started: Array = []
	func is_active() -> bool: return active
	func start_download(download: Dictionary) -> Error:
		started.append(download.duplicate(true))
		active = true
		return OK
	func cancel() -> void: active = false

class MetadataStore extends "res://scripts/asset_bundle_store.gd":
	# Only the metadata size/transaction is under test in this fixture.
	func _validate_object(_digest: String, _manifest := {}) -> bool: return true

var failed := false
var fixture := "user://bulk-download-test-" + str(Time.get_ticks_usec())

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings_path := "user://launcher_settings.json"
	var had_settings := FileAccess.file_exists(settings_path)
	var before := FileAccess.get_file_as_bytes(settings_path) if had_settings else PackedByteArray()
	var pin: Dictionary = V8.data.index
	var descriptor := {"schema": 1, "kind": "pokeaether-release-asset-index",
		"revision": V8.data.revision, "url": "https://updates.pokeaether.com/" + str(pin.object_key),
		"objectBaseUrl": "https://updates.pokeaether.com", "sha256": pin.sha256,
		"sizeBytes": pin.size_bytes, "requiredAssetIds": V8.data.requiredAssetIds}
	var index_path := ProjectSettings.globalize_path("res://../release/approved_3d_bundles_v8_index.json")
	var adapter := Release.new(fixture.path_join("bundles"), fixture.path_join("indexes"))
	_check(adapter.accept_index(descriptor, index_path, false).error.is_empty(), "approved index accepted without mandatory model downloads")
	var full := Bulk.models_plan(adapter, descriptor)
	_check(full.error.is_empty() and full.jobs.size() == 1139, "all approved bundles are planned")
	_check(full.total_bytes == 18988742373, "upfront full download size is exact")
	var fake := ProjectSettings.globalize_path(fixture.path_join("cached.scn"))
	_write(fake, "verified cached model fixture")
	var digest := FileAccess.get_sha256(fake)
	var asset := {"appearances": [{"runtime_identity": "fixture", "runtime_sha256": digest}]}
	var entries := {"fixture": {"runtime_path": fake, "runtime_sha256": digest, "runtime_schema": 1, "bytes": FileAccess.get_size(fake)}}
	_check(Bulk._available(asset, entries), "verified game downloads can be reused")
	_write(fake, "corrupted cached model fixture")
	_check(not Bulk._available(asset, entries), "corrupt cached model is not counted as installed")
	_write(fake, "verified cached model fixture")
	_check(not Bulk._available({"appearances": asset.appearances + [{"runtime_identity": "fixture@shiny", "runtime_sha256": digest}]}, entries), "missing shiny keeps the bundle in the download queue")
	var scene := load("res://scenes/launcher.tscn") as PackedScene
	var launcher = scene.instantiate()
	launcher.set_script(load("res://tests/fixtures/offline_bulk_launcher.gd"))
	root.add_child(launcher)
	await process_frame
	launcher.server_health_refresh_timer.stop()
	launcher.install_dir = fixture.path_join("game-install")
	launcher.release_asset_bundles = adapter
	launcher.download_service.free()
	var probe := DownloadProbe.new()
	launcher.download_service = probe
	launcher.add_child(probe)
	var packs: Array = []
	for id: String in ["pokemon-front", "pokemon-shiny-back", "pokemon-gen5-front", "music"]:
		packs.append({"id": id, "version": "test-v1", "optional": true, "url": "https://updates.example/" + id + ".zip",
			"sizeBytes": 100, "sha256": "1".repeat(64)})
	launcher.manifest = {"assetPacks": packs, "assetBundleIndex": descriptor}
	launcher.local_versions = {"gameVersion": "test", "assetPacks": {}}
	launcher._build_download_queue()
	_check(launcher.pending_downloads.is_empty(), "normal update stays on demand by default")
	var sprites := Bulk.sprites_plan(launcher)
	_check(sprites.jobs.size() == 3 and sprites.total_bytes == 300, "2D plan includes shiny and pixel packs, excludes music")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(launcher.install_dir.path_join("assets/sprites/pokemon/front")))
	launcher.local_versions.assetPacks["pokemon-front"] = "test-v1"
	sprites = Bulk.sprites_plan(launcher)
	_check(sprites.jobs.size() == 2 and sprites.available == 1, "installed sprite pack skipped")
	launcher.bulk_plans = {"3d": full, "2d": sprites}
	launcher._refresh_bulk_summaries()
	launcher._set_busy(false)
	launcher._show_asset_downloads()
	while launcher.bulk_planning: await process_frame
	_check(launcher.downloads_panel.visible and not launcher.content_layout.visible, "downloads has its own page")
	launcher.downloads_panel.buttons["2d"].pressed.emit()
	_check(launcher.bulk_kind == "2d" and probe.started.size() == 1, "2D action starts optional queue")
	_check(launcher.download_all_2d and not launcher.download_all_3d, "download choice enables updates only for chosen category")
	launcher.download_progress_snapshot = {"downloaded_bytes": 50, "recent_bytes_per_second": 10.0}
	launcher._update_bulk_progress()
	_check(is_equal_approx(launcher.downloads_panel.progress.value, 25), "overall progress includes all queued files")
	launcher._pause_bulk_download()
	_check(launcher.bulk_paused and not probe.active and launcher.pending_downloads.size() == 2, "pause preserves current and pending jobs")
	_check(not launcher.play_button.disabled, "optional paused download does not block play")
	launcher._resume_bulk_download()
	_check(not launcher.bulk_paused and probe.started.size() == 2 and probe.started[0].id == probe.started[1].id, "resume restarts same identity for partial reuse")
	launcher._set_busy(false) # Simulate install failure while the current job is retained.
	launcher.current_download.clear()
	_check(launcher.bulk_paused and launcher.pending_downloads.size() == 2, "failed file remains queued for retry")
	var persisted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
	_check(persisted.downloadAll2D and not persisted.downloadAll3D, "preferences are saved")
	var restarted: Node = load("res://scripts/launcher.gd").new()
	restarted._load_launcher_settings()
	_check(restarted.download_all_2d and not restarted.download_all_3d, "preferences survive restart")
	restarted.free()
	launcher.download_all_2d = true
	_check(launcher._should_auto_update_optional_asset_pack(packs[0]), "chosen sprite packs receive later updates")
	launcher.download_all_3d = true
	var expected: Dictionary = Bulk.models_plan(adapter, descriptor, Bulk.game_catalog_path())
	launcher._build_download_queue()
	_check(launcher.pending_downloads.filter(func(job: Dictionary): return job.type == "asset_bundle").size() == expected.jobs.size(), "chosen complete 3D catalog is kept current, reusing game downloads")
	await _check_full_metadata(adapter.cached_index(descriptor))
	var capture := OS.get_environment("BULK_DOWNLOAD_CAPTURE")
	if not capture.is_empty():
		launcher.bulk_kind = ""
		launcher.bulk_paused = false
		launcher._set_busy(false)
		launcher.downloads_panel.message.text = launcher._t("Choose a download above. You can pause and resume later.")
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture)
	for path: String in ["scripts/bulk_asset_downloads.gd", "scripts/asset_downloads_panel.gd", "tests/bulk_asset_downloads_check.gd", "tests/fixtures/offline_bulk_launcher.gd"]:
		if not FileAccess.file_exists("res://" + path + ".uid"):
			_write("res://" + path + ".uid", ResourceUID.id_to_text(ResourceUID.create_id()) + "\n")
	launcher._remove_directory_tree(fixture)
	launcher.free()
	if had_settings:
		var output := FileAccess.open(settings_path, FileAccess.WRITE)
		output.store_buffer(before)
		output.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	if not failed: print("PASS bulk_asset_downloads_check full_catalog=true opt_in=true reuse=true pause_resume=true updates=true metadata_scale=true")
	quit(1 if failed else 0)

func _check_full_metadata(index: Dictionary) -> void:
	var store := MetadataStore.new(fixture.path_join("metadata"))
	var state := store._empty_state(index.catalog_revision)
	for asset: Dictionary in index.assets:
		var appearances := []
		for appearance: Dictionary in asset.appearances:
			appearances.append(appearance.merged({"runtime_path": "models/" + str(appearance.runtime_sha256) + ".scn", "bytes": 1024}))
		var manifest := {"asset_id": asset.asset_id, "asset_type": asset.asset_type, "species_id": asset.species_id,
			"form_id": asset.form_id, "version": asset.version, "dependencies": asset.dependencies, "appearances": appearances}
		state.assets[asset.asset_id] = store._state_entry(asset, manifest)
		_write(store._objects_root().path_join(asset.sha256).path_join("bundle.json"), JSON.stringify(manifest))
	_check(JSON.stringify(state, "\t").length() > store.MAX_JSON, "full installed metadata exceeds the former one MiB bound")
	_check(store._write_generation(state).is_empty(), "all 1139 bundle records can be published atomically")
	_check(store.state().assets.size() == 1139, "full installed state survives restart validation")

func _write(path: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL " + message)
