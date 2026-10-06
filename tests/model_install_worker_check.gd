extends SceneTree

const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const FIXTURE := "user://model-install-worker-check"

class Probe extends Service:
	var release := {}
	var archive := PackedByteArray()
	var hold_unpack: Semaphore
	var unpack_started := Semaphore.new()
	var unpack_calls := 0
	var fetch_calls := 0
	var corrupt_download := false
	func _selected_release() -> Dictionary:
		return release
	func _local_index_path(_release: Dictionary) -> String:
		return FIXTURE.path_join("index.json")
	func _installed_models(_ids: Array[String], _source: String) -> Dictionary:
		return {} # Force the real install/merge path, including concurrent callers.
	func _catalog(_path: String) -> Array:
		return super._catalog(FIXTURE.path_join("catalog.json"))
	func _publish_catalog(entries: Array) -> String:
		var path := FIXTURE.path_join("catalog.json")
		var file := FileAccess.open(path + ".partial", FileAccess.WRITE)
		file.store_string(JSON.stringify(entries))
		file.close()
		return path if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".partial"), ProjectSettings.globalize_path(path)) == OK else ""
	func _fetch(_url: String, path: String, expected: int, digest: String, _limit: int, _label: String) -> String:
		fetch_calls += 1
		# Simulate a completed HTTP body; use the production verification and
		# atomic publication path, without a network dependency in this check.
		await _run_storage_work(_write_download.bind(path))
		return await _run_storage_work(_publish_verified_download.bind(ProjectSettings.globalize_path(path), expected, digest))
	func _write_download(path: String) -> bool:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var body := archive.duplicate()
		if corrupt_download:
			body[body.size() - 1] ^= 1
		var file := FileAccess.open(path + ".partial", FileAccess.WRITE)
		file.store_buffer(body)
		file.close()
		return true
	func _unpack_asset(asset: Dictionary, path: String) -> Dictionary:
		unpack_calls += 1
		unpack_started.post()
		if hold_unpack != null:
			hold_unpack.wait()
		return super._unpack_asset(asset, path)

class EmergencyRelease extends RefCounted:
	var stop := Semaphore.new()
	var hold: Semaphore
	var fired := false
	func run() -> void:
		for _iteration in 100:
			if stop.try_wait():
				return
			OS.delay_msec(20)
		fired = true
		hold.post()

var results := {}
var failed := false


func _init() -> void:
	_run.call_deferred()


func _collect(service: Probe, key: String, identities: Array[String]) -> void:
	results[key] = await service.ensure_models(identities, "")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE))
	var service := Probe.new()
	root.add_child(service)
	var originals := {}
	var models: Dictionary = Registry.DATA.data.models
	var appearances := []
	var packer := ZIPPacker.new()
	var zip_path := FIXTURE.path_join("source.zip")
	_check(packer.open(zip_path) == OK, "open local archive fixture")
	packer.start_file("bundle.json")
	packer.write_file("{}".to_utf8_buffer())
	packer.close_file()
	for variant in ["normal", "shiny"]:
		var identity := "garchomp@shiny" if variant == "shiny" else "garchomp"
		var bytes: PackedByteArray = ("verified-model-fixture-" + str(variant)).to_utf8_buffer()
		var digest := service._sha256(bytes)
		originals[identity] = models[identity].duplicate(true)
		models[identity].sha256 = digest
		models[identity].previous_sha256 = []
		appearances.append({"variant": variant, "runtime_identity": identity, "runtime_sha256": digest})
		packer.start_file("models/%s.scn" % variant)
		packer.write_file(bytes)
		packer.close_file()
	packer.close()
	service.archive = FileAccess.get_file_as_bytes(zip_path)
	var digest := FileAccess.get_sha256(zip_path)
	var asset := {"asset_id": "pokemon_3d:garchomp:base", "object_key": "optional-assets/pokemon_3d/garchomp/base/fixture.zip",
		"sha256": digest, "size_bytes": service.archive.size(), "appearances": appearances}
	var index := {"catalog_revision": "worker-fixture", "assets": [asset]}
	var index_path := FIXTURE.path_join("index.json")
	var file := FileAccess.open(index_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(index))
	file.close()
	service.release = {"revision": "worker-fixture", "requiredAssetIds": [asset.asset_id],
		"index": {"sha256": FileAccess.get_sha256(index_path), "size_bytes": FileAccess.get_file_as_bytes(index_path).size()}}
	# A stalled disk operation must leave frames, the downloader guard, and a
	# second caller responsive. The emergency thread bounds an old-code failure.
	service.hold_unpack = Semaphore.new()
	var rescue := EmergencyRelease.new()
	rescue.hold = service.hold_unpack
	var rescue_thread := Thread.new()
	rescue_thread.start(rescue.run)
	var before := Time.get_ticks_msec()
	_collect(service, "first", ["garchomp"])
	var deadline := before + 5000
	while not service.unpack_started.try_wait() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(Time.get_ticks_msec() - before < 1000 and not rescue.fired, "install starts without holding the main thread")
	_check(results.is_empty() and service._busy, "install stays pending until verification completes")
	_check(not service.can_clear_cache() and not service.clear_cache(), "cache cannot be cleared during installation")
	_collect(service, "second", ["garchomp@shiny"])
	for _frame in 10:
		await process_frame
	_check(results.is_empty() and service._battle_waiters == 1, "second caller waits while frames continue")
	_check(service.fetch_calls == 1, "concurrent callers do not start duplicate downloads")
	service.hold_unpack.post()
	while results.size() < 2 and Time.get_ticks_msec() < deadline:
		await process_frame
	rescue.stop.post()
	rescue_thread.wait_to_finish()
	_check(not rescue.fired and results.size() == 2, "normal completion does not need the timeout rescue")
	service.hold_unpack = null
	for result: Dictionary in results.values():
		_check(str(result.get("error", "")).is_empty(), "both callers receive the verified catalog")
	_check(service.fetch_calls == 1 and service.unpack_calls == 1, "second caller reuses the installed pair")
	_check(service.can_clear_cache() and service._local_checks == 0, "storage and downloader guards are released")
	var entries := service._catalog("")
	_check(entries.size() == 2, "both appearances are published")
	for entry: Dictionary in entries:
		_check(service._valid_file(entry.runtime_path, int(entry.bytes), str(entry.runtime_sha256)), "published bytes retain full SHA verification")
	# Force an uncached retry and prove an unverified body never becomes ready.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE.path_join("catalog.json")))
	service.corrupt_download = true
	var rejected: Dictionary = await service.ensure_models(["garchomp"], "")
	_check(not str(rejected.get("error", "")).is_empty(), "corrupt archive is rejected")
	_check(service._catalog("").is_empty() and service.can_clear_cache(), "failure publishes no catalog and releases guards")
	service.corrupt_download = false
	var repaired: Dictionary = await service.ensure_models(["garchomp", "garchomp@shiny"], "")
	_check(str(repaired.get("error", "")).is_empty(), "download can retry after corruption")
	# Deliberately wrong model hashes must still be rejected after ZIP approval.
	var invalid := asset.duplicate(true)
	invalid.appearances[0].runtime_sha256 = "0".repeat(64)
	var invalid_result: Dictionary = await service._run_storage_work(service._unpack_asset.bind(invalid, zip_path))
	_check(not str(invalid_result.get("error", "")).is_empty(), "wrong model digest is rejected in a worker")
	for identity: String in originals:
		models[identity] = originals[identity]
	service.free()
	for filename in ["source.zip", "index.json", "catalog.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE.path_join(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	print("model_install_worker_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL " + message)
