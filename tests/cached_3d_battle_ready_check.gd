extends SceneTree

const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const FIXTURE := "user://cached-3d-ready-check"

class Probe extends Service:
	var fixture_release := {}
	var fixture_index := ""
	var own_entries: Array = []
	var slow_calls := 0
	var pause_check: Semaphore
	func _selected_release() -> Dictionary:
		return fixture_release
	func _local_index_path(_release: Dictionary) -> String:
		return fixture_index
	func _catalog(path: String) -> Array:
		if path == ROOT.path_join("runtime-catalog.json") or path == ProjectSettings.globalize_path(ROOT.path_join("runtime-catalog.json")):
			return own_entries
		return super._catalog(path)
	func _ensure_models(_ids: Array[String], _source: String) -> Dictionary:
		slow_calls += 1
		return {"error": "Offline fixture requires the normal install/repair path."}
	func _installed_models(ids: Array[String], source: String) -> Dictionary:
		if pause_check != null:
			pause_check.wait()
		return super._installed_models(ids, source)

var failed := false
var ready := {}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Catalog admission follows the selected presentation mode.
	root.get_node("SettingsManager").battle_presentation_mode = "3d"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE))
	var service := Probe.new()
	root.add_child(service)
	var index := {"catalog_revision": "cached-test", "assets": []}
	var asset := {"asset_id": "pokemon_3d:garchomp:base", "appearances": []}
	var entries := []
	var originals := {}
	var reviewed_models: Dictionary = Registry.DATA.data.models
	for variant in ["normal", "shiny"]:
		var identity := "garchomp" + ("@shiny" if variant == "shiny" else "")
		var path := FIXTURE.path_join(variant + ".scn")
		var packed := PackedScene.new()
		var node := Node3D.new()
		node.name = variant
		_check(packed.pack(node) == OK and ResourceSaver.save(packed, path) == OK, "create a valid standalone model fixture")
		node.free()
		var digest := FileAccess.get_sha256(path)
		originals[identity] = reviewed_models[identity].duplicate(true)
		reviewed_models[identity].sha256 = digest
		reviewed_models[identity].previous_sha256 = []
		entries.append({"species": "garchomp", "variant": variant, "runtime_schema": 1,
			"runtime_path": path, "runtime_sha256": digest, "bytes": FileAccess.get_file_as_bytes(path).size()})
		asset.appearances.append({"runtime_identity": identity, "runtime_sha256": digest})
	index.assets.append(asset)
	service.fixture_index = FIXTURE.path_join("index.json")
	_write(service.fixture_index, JSON.stringify(index))
	service.fixture_release = {"revision": "cached-test", "requiredAssetIds": [asset.asset_id],
		"index": {"sha256": FileAccess.get_sha256(service.fixture_index),
			"size_bytes": FileAccess.get_file_as_bytes(service.fixture_index).size()}}
	var source := FIXTURE.path_join("source.json")
	var original_catalog := JSON.stringify(entries)
	_write(source, original_catalog)
	# Hold the background downloader indefinitely. A ready battle must complete
	# without releasing that lock, joining its queue, downloading or publishing.
	service._busy = true
	service.pause_check = Semaphore.new()
	_collect_ready(service, source)
	_check(service._local_checks == 1 and ready.is_empty(), "disk verification is pending without blocking the calling frame")
	_check(not service.can_clear_cache(), "files cannot be removed while a verification worker is reading them")
	for frame in 3:
		await process_frame
	_check(ready.is_empty() and service._local_checks == 1, "frames continue while disk verification is deliberately held")
	service.pause_check.post()
	var ready_deadline := Time.get_ticks_msec() + 5000
	while ready.is_empty() and Time.get_ticks_msec() < ready_deadline:
		await process_frame
	service.pause_check = null
	_check(not ready.is_empty() and ready.get("error") == "", "installed pair is ready while an unrelated download holds the lock")
	_check(service._busy and service._battle_waiters == 0 and service.slow_calls == 0, "cached entry never joins or alters the background download")
	_check(ready.get("path") == source and not ready.get("catalog_changed", true), "original catalog is reused")
	_check(FileAccess.get_file_as_string(source) == original_catalog, "catalog is not rewritten")
	_check(ready.get("verified_models", {}).size() == 2, "successful SHA checks are handed to this battle only")
	await _check_verified_resource_reuse(source, ready.verified_models)
	service._busy = false
	await process_frame # Also drain the slow path if this regression fails.
	service.own_entries = entries.duplicate(true)
	var fallback: Dictionary = await service.ensure_models(["garchomp", "garchomp@shiny"], "")
	_check(fallback.get("error") == "" and str(fallback.get("path", "")).ends_with("runtime-catalog.json"), "downloaded catalog can be reused without a source selection")
	service.own_entries = []
	# A new service/process state still uses the files already on the device.
	var restarted := Probe.new()
	restarted.fixture_release = service.fixture_release
	restarted.fixture_index = service.fixture_index
	root.add_child(restarted)
	var after_restart: Dictionary = await restarted.ensure_models(["garchomp", "garchomp@shiny"], source)
	_check(after_restart.get("error") == "" and restarted.slow_calls == 0, "installed files remain usable without a warm in-memory cache")
	restarted.free()
	# Same-size corruption must still fail full SHA verification.
	var model_path: String = entries[0].runtime_path
	var original_model := FileAccess.get_file_as_bytes(model_path)
	var damaged := original_model.duplicate()
	damaged[0] = damaged[0] ^ 1
	_write_bytes(model_path, damaged)
	_check(service._installed_models(["garchomp"], source).is_empty(), "same-size corruption cannot use the fast path")
	var repair: Dictionary = await service.ensure_models(["garchomp"], source)
	_check(not str(repair.get("error", "")).is_empty() and service.slow_calls == 1, "corruption reaches the normal repair path")
	_write_bytes(model_path, original_model)
	_check(service._installed_models(["garchomp", "garchomp@shiny"], source).get("path") == source, "repaired pair becomes ready again")
	var original_index := FileAccess.get_file_as_string(service.fixture_index)
	_write(service.fixture_index, "X" + original_index.substr(1))
	_check(service._installed_models(["garchomp"], source).is_empty(), "unverified index cannot authorize cached files")
	_write(service.fixture_index, original_index)
	var stale := entries.duplicate(true)
	stale[1].runtime_sha256 = "0".repeat(64)
	_write(source, JSON.stringify(stale))
	_check(service._installed_models(["garchomp", "garchomp@shiny"], source).is_empty(), "one stale appearance prevents incomplete pair readiness")
	_write(source, JSON.stringify([entries[0]]))
	service.own_entries = [entries[1]]
	_check(service._installed_models(["garchomp", "garchomp@shiny"], source).is_empty(), "mixed catalogs use the locked merge path")
	for identity: String in originals:
		reviewed_models[identity] = originals[identity]
	service.free()
	for filename in ["source.json", "index.json", "normal.scn", "shiny.scn"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE.path_join(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	print("cached_3d_battle_ready_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check_verified_resource_reuse(source: String, proofs: Dictionary) -> void:
	Cache.clear()
	var stage := Renderer.new()
	stage.set_process(false)
	root.add_child(stage)
	stage.set_combatant(0, "Garchomp")
	stage._load_catalog(source)
	var entry: Dictionary = stage.catalog_entries.garchomp
	var proof: Dictionary = proofs.garchomp
	var key := Cache.key(entry.runtime_path, proof.sha256, entry.action_timing)
	var scene := ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	Cache.retain(key, scene, int(proof.bytes))
	stage.download_verified_files = proofs.duplicate(true)
	stage._import_next_model()
	_check(stage.packed.get("garchomp") == scene and stage.model_cache_hits == 1, "the downloader's current proof reuses the exact admitted RAM scene")
	_check(stage.integrity_read == null and stage.model_validation_ms == 0.0 and stage.verified_model_cache_hits == 1, "an already checked cached model is not hashed a second time")
	stage._load_catalog(source)
	_check(stage.download_verified_files.is_empty(), "catalog reload discards the ephemeral verification handoff")
	var mismatched := proofs.duplicate(true)
	mismatched.garchomp.path = proofs["garchomp@shiny"].path
	stage.download_verified_files = mismatched
	var wrong_path: Dictionary = stage.catalog_entries.garchomp.duplicate(true)
	stage._reuse_checked_resource(wrong_path)
	_check(not wrong_path.has("_verified_runtime_hash"), "proof from a different file cannot authorize this resource")
	mismatched.garchomp.path = proof.path
	mismatched.garchomp.bytes += 1
	stage.download_verified_files = mismatched
	var wrong_size: Dictionary = stage.catalog_entries.garchomp.duplicate(true)
	stage._reuse_checked_resource(wrong_size)
	_check(not wrong_size.has("_verified_runtime_hash"), "proof size must match this catalog entry")
	mismatched.garchomp.bytes = proof.bytes
	mismatched.garchomp.sha256 = "0".repeat(64)
	var wrong_hash: Dictionary = stage.catalog_entries.garchomp.duplicate(true)
	stage._reuse_checked_resource(wrong_hash)
	_check(not wrong_hash.has("_verified_runtime_hash"), "a stale digest cannot authorize a cached scene")
	Cache.clear()
	stage.download_verified_files = proofs.duplicate(true)
	stage._import_next_model()
	_check(stage.integrity_read != null and stage.packed.is_empty(), "a cold cache still uses the complete disk validation path")
	var read: Renderer.IntegrityRead = stage.integrity_read
	if read == null:
		stage.free()
		return
	stage.cancel_preparation()
	while not read.ready():
		await process_frame
	stage.free()
	await process_frame

func _write_bytes(path: String, value: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(value)
	file.close()

func _collect_ready(service: Probe, source: String) -> void:
	ready = await service.ensure_models(["garchomp", "garchomp@shiny"], source)

func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
