extends SceneTree
## Real game HTTP downloader -> pinned launcher adapter -> installed scene loading.
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const Release = preload("res://launcher/scripts/release_asset_bundles.gd")
const Index = preload("res://launcher/scripts/asset_bundle_index.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const PairPack = preload("res://scripts/services/model_pair_pack.gd")
const SAMPLES: Array[String] = ["pokemon_3d:abomasnow:base", "pokemon_3d:garchomp:mega", "pokemon_3d:greninja:base", "pokemon_3d:inkay:base"]
var failures: Array[String] = []
var completed: Array[Dictionary] = []
var output_root := ""
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
		print("PUBLIC_DOWNLOAD_FAIL ", reason)
	return value

func finish() -> void:
	failures.append_array(sink.errors)
	var receipt := {"schema": 1, "ok": failures.is_empty() and completed.size() == SAMPLES.size(),
		"scope": "Linux debug opt-in; real public downloads and installed scene decoding, not release activation",
		"samples": completed, "index_sha256": Pilot.release().index.sha256,
		"os": OS.get_name(), "godot": Engine.get_version_info().string,
		"elapsed_ms": Time.get_ticks_msec() - started, "errors": failures}
	var file := FileAccess.open(output_root.path_join("public-downloads.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.close()
	print("SHARED_MODEL_PUBLIC_DOWNLOAD_CHECK ", "OK" if receipt.ok else "FAILED")
	quit(0 if receipt.ok else 1)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_absolute_path() or not args[0].begins_with(ProjectSettings.globalize_path("res://.tmp/").trim_suffix("/") + "/") or DirAccess.dir_exists_absolute(args[0]):
		print("Use a fresh absolute .tmp output directory")
		quit(2)
		return
	output_root = args[0]
	DirAccess.make_dir_recursive_absolute(output_root)
	OS.add_logger(sink)
	OS.set_environment("POKEAETHER_SHARED_MODEL_QUALIFIED_TEST", "1")
	var pin := Pilot.release()
	var descriptor := {"schema": 1, "kind": Release.DESCRIPTOR_KIND, "revision": pin.revision,
		"url": Service.BASE_URL + pin.index.object_key, "objectBaseUrl": Service.BASE_URL.trim_suffix("/"),
		"sha256": pin.index.sha256, "sizeBytes": pin.index.size_bytes, "requiredAssetIds": pin.requiredAssetIds}
	var service := Service.new()
	root.add_child(service)
	var index_path := output_root.path_join("index.json")
	var error: String = await service._fetch(descriptor.url, index_path, pin.index.size_bytes, pin.index.sha256, Service.MAX_INDEX_BYTES, "qualified public index")
	if not check(error.is_empty(), "Actual game index HTTP: " + error):
		service.free()
		finish()
		return
	var adapter := Release.new(output_root.path_join("store"), output_root.path_join("indexes"))
	var accepted := adapter.accept_index(descriptor, index_path, true)
	if not check(str(accepted.error).is_empty() and accepted.get("jobs", []).size() == 1200, "Actual launcher accepts full public pinned index"):
		service.free()
		finish()
		return
	var index := adapter.cached_index(descriptor)
	var indexed := Index.by_id(index)
	for key: String in SAMPLES:
		var asset: Dictionary = indexed[key]
		var destination := output_root.path_join(str(asset.object_key).get_file())
		error = await service._fetch(Service.BASE_URL + asset.object_key, destination, asset.size_bytes, asset.sha256, Service.MAX_ARCHIVE_BYTES, key)
		if not check(error.is_empty(), "Actual game payload HTTP " + key + ": " + error):
			break
		var installed := adapter.accept_bundle(index, key, destination)
		if not check(str(installed.error).is_empty(), "Actual launcher installation " + key + ": " + str(installed.error)):
			break
		completed.append({"asset_id": key, "sha256": asset.sha256, "size_bytes": asset.size_bytes,
			"format": asset.get("format", "zip")})
	var catalog := adapter.catalog_path_for_launch()
	var entries := service._catalog(catalog)
	check(entries.size() == completed.size() * 2, "Game reads normal/shiny catalog after HTTP installation")
	for entry: Dictionary in entries:
		if entry.has("pair_asset"):
			var inspected := PairPack.inspect(entry.pack_path, entry.pair_asset)
			if not check(str(inspected.error).is_empty(), "Downloaded physical pack inspection"):
				continue
			if not check(PairPack.mount_checked(entry.pack_path, entry.pair_asset, inspected).is_empty(), "Downloaded pack closure/mount"):
				continue
		var scene := ResourceLoader.load(str(entry.runtime_path), "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		check(scene != null, "Downloaded normal/shiny scene decoding: " + str(entry.species))
	service.free()
	finish()
