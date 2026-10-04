extends SceneTree

const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const FIXTURE := "user://cached-3d-ready-check"

class Probe extends Service:
	var fixture_release := {}
	var fixture_index := ""
	var own_entries: Array = []
	var slow_calls := 0
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

var failed := false
var ready := {}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
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
		_write(path, variant + "-verified-test-model")
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
	_collect_ready(service, source)
	_check(not ready.is_empty() and ready.get("error") == "", "installed pair is ready while an unrelated download holds the lock")
	_check(service._busy and service._battle_waiters == 0 and service.slow_calls == 0, "cached entry never joins or alters the background download")
	_check(ready.get("path") == source and not ready.get("catalog_changed", true), "original catalog is reused")
	_check(FileAccess.get_file_as_string(source) == original_catalog, "catalog is not rewritten")
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
	var original_model := FileAccess.get_file_as_string(model_path)
	_write(model_path, "X" + original_model.substr(1))
	_check(service._installed_models(["garchomp"], source).is_empty(), "same-size corruption cannot use the fast path")
	var repair: Dictionary = await service.ensure_models(["garchomp"], source)
	_check(not str(repair.get("error", "")).is_empty() and service.slow_calls == 1, "corruption reaches the normal repair path")
	_write(model_path, original_model)
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
