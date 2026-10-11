extends SceneTree
## Physical full collection: fresh/resume, v11 update, repair and restart handoff.
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const Store = preload("res://launcher/scripts/asset_bundle_store.gd")
const Release = preload("res://launcher/scripts/release_asset_bundles.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Index = preload("res://launcher/scripts/asset_bundle_index.gd")
var failures: Array[String] = []
var records: Array[Dictionary] = []
var started := Time.get_ticks_msec()

class Sink extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append(code + " " + rationale)
var sink := Sink.new()

func _init() -> void:
	_run.call_deferred()

func check(value: bool, reason: String) -> bool:
	if not value:
		failures.append(reason)
		print("COLLECTION_INSTALL_FAIL ", reason)
	return value

func install(config: Dictionary, mode: String) -> bool:
	var directory: String = config.root.path_join(mode)
	var adapter := Release.new(directory.path_join("store"), directory.path_join("indexes"))
	# Keep previous files until explicit cleanup has proved the current generation.
	adapter.store.prune_previous_models = false
	var baseline := ""
	if mode == "upgrade":
		var original: Dictionary = load("res://release/approved_3d_bundles_v11_index.json").data
		var old_result: Dictionary = adapter.accept_bundles(original, config.original_sources)
		if not check(str(old_result.error).is_empty(), "Install complete v11 baseline: " + str(old_result.error)):
			return false
		baseline = adapter.store.active_generation()
		print("COLLECTION_V11_INSTALLED assets=1200")
	var pin := Pilot.release()
	var descriptor := {"schema": 1, "kind": Release.DESCRIPTOR_KIND, "revision": pin.revision,
		"url": "http://127.0.0.1/" + pin.index.object_key, "objectBaseUrl": "http://127.0.0.1",
		"sha256": pin.index.sha256, "sizeBytes": pin.index.size_bytes, "requiredAssetIds": pin.requiredAssetIds}
	var accepted := adapter.accept_index(descriptor, Pilot.QUALIFIED_PATH, true)
	if not check(str(accepted.error).is_empty(), "Actual pinned descriptor accepted: " + str(accepted.error)):
		return false
	var index := adapter.cached_index(descriptor)
	var ids: Array[String] = []
	ids.assign(pin.requiredAssetIds)
	var session := adapter.begin_collection(index, ids)
	var expected_downloads := 1200 if mode == "fresh" else 1082
	if not check(str(session.error).is_empty() and session.downloads.size() == expected_downloads, "Exact fresh/update selection"):
		return false
	# Interrupt after the first completed immutable object, before publication.
	var first: String = session.downloads[0]
	var staged := adapter.stage_collection(session, first, config.sources[first])
	if not check(str(staged.error).is_empty(), "First stage: " + str(staged.error)):
		return false
	check(adapter.store.active_generation() == baseline, "Partial collection retains old active generation")
	check(not str(adapter.finish_collection(session).error).is_empty(), "Incomplete collection cannot publish")
	session = adapter.begin_collection(index, ids)
	check(session.downloads.size() == expected_downloads - 1, "Resume reuses verified staged object")
	var count := 1
	for asset_id: String in session.downloads.duplicate():
		var result := adapter.stage_collection(session, asset_id, config.sources[asset_id])
		if not check(str(result.error).is_empty(), "Stage " + asset_id + ": " + str(result.error)):
			return false
		count += 1
		if count % 50 == 0:
			print("COLLECTION_STAGE mode=", mode, " assets=", count, "/", expected_downloads)
	var finished := adapter.finish_collection(session)
	if not check(str(finished.error).is_empty(), "Publish complete collection: " + str(finished.error)):
		return false
	var catalog: String = adapter.store.catalog_path_for_launch()
	var generation: String = catalog.get_base_dir().get_file()
	var state_path := catalog.get_base_dir().path_join("installed-state.json")
	var state_file := FileAccess.open(state_path, FileAccess.READ)
	var catalog_file := FileAccess.open(catalog, FileAccess.READ)
	var state_bytes := state_file.get_length()
	var catalog_bytes := catalog_file.get_length()
	var service := Service.new()
	var entries := service._catalog(catalog)
	service.free()
	check(entries.size() == 2400, "Game reads all compact appearances")
	check(state_bytes <= Store.MAX_STATE_JSON and catalog_bytes <= Service.MAX_CATALOG_BYTES, "Existing metadata limits")
	var restarted := Release.new(directory.path_join("store"), directory.path_join("indexes"))
	restarted.store.prune_previous_models = false
	check(restarted.catalog_path_for_launch() == catalog, "Restart retains launcher handoff")
	var jobs := restarted.jobs(descriptor, true)
	check(str(jobs.error).is_empty() and jobs.jobs.is_empty(), "Restart downloads nothing")
	var first_asset: Dictionary = Index.by_id(index)[first]
	var pack: String = restarted.store._objects_root().path_join(first_asset.sha256).path_join("model-pair.pck")
	var damaged := FileAccess.open(pack, FileAccess.WRITE)
	damaged.store_string("owned fixture: simulate disk corruption")
	damaged.close()
	var repair := restarted.begin_collection(index, ids)
	if not check(str(repair.error).is_empty() and repair.downloads == [first], "Repair requests only corrupted pair"):
		return false
	var fixed := restarted.stage_collection(repair, first, config.sources[first])
	check(str(fixed.error).is_empty(), "Repair physical pack: " + str(fixed.error))
	check(str(restarted.finish_collection(repair).error).is_empty(), "Repair reactivates complete generation")
	check(restarted.store.active_generation() == generation, "Repair preserves generation identity")
	var cleanup: Dictionary = restarted.store.prune_model_versions()
	check(str(cleanup.error).is_empty() and not cleanup.deferred, "Verified old-version cleanup")
	check(int(cleanup.removed_objects) == (1082 if mode == "upgrade" else 0), "Cleanup removes exactly replaced v11 pairs")
	check(DirAccess.get_directories_at(restarted.store._objects_root()).size() == 1200, "Exactly one physical object per asset after cleanup")
	OS.unset_environment("POKEAETHER_SHARED_MODEL_QUALIFIED_TEST")
	check(restarted.catalog_path_for_launch().is_empty(), "Disabled opt-in cannot activate compact shared generation")
	OS.set_environment("POKEAETHER_SHARED_MODEL_QUALIFIED_TEST", "1")
	check(restarted.catalog_path_for_launch() == catalog, "Re-enable restores verified generation")
	records.append({"mode": mode, "assets": 1200, "downloads": expected_downloads,
		"appearances": entries.size(), "state_bytes": state_bytes, "catalog_bytes": catalog_bytes,
		"generation": generation, "catalog": catalog, "catalog_sha256": FileAccess.get_sha256(catalog),
		"cleanup": cleanup, "repair_asset": first})
	print("COLLECTION_MODE_DONE ", JSON.stringify(records[-1]))
	return failures.is_empty()

func _run() -> void:
	OS.add_logger(sink)
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	OS.set_environment("POKEAETHER_SHARED_MODEL_QUALIFIED_TEST", "1")
	if not check(FileAccess.get_sha256(Pilot.QUALIFIED_PATH) == config.index_sha256, "Pinned fixture metadata"):
		quit(1)
		return
	for mode in ["fresh", "upgrade"]:
		if not install(config, mode):
			break
	failures.append_array(sink.errors)
	var receipt := {"schema": 1, "ok": failures.is_empty() and records.size() == 2,
		"os": OS.get_name(), "godot": Engine.get_version_info().string, "records": records,
		"elapsed_ms": Time.get_ticks_msec() - started, "errors": failures,
		"input_sha256": FileAccess.get_sha256(args[0]), "index_sha256": config.index_sha256}
	var output := FileAccess.open(str(config.root).path_join("installation.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(receipt, "\t") + "\n")
	output.close()
	print("SHARED_MODEL_COLLECTION_INSTALL_CHECK ", "OK" if receipt.ok else "FAILED")
	quit(0 if receipt.ok else 1)
