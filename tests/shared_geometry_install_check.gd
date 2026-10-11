extends SceneTree
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const Release = preload("res://launcher/scripts/release_asset_bundles.gd")
const Index = preload("res://launcher/scripts/asset_bundle_index.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Pair = preload("res://scripts/services/model_pair_pack.gd")
class Sink extends Logger:
	var tree: SceneTree
	func _log_error(_fn: String, _file: String, _line: int, _code: String, _why: String, _notify: bool, kind: int, _trace: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING: tree.call_deferred("quit", 2)
var sink := Sink.new()
func _init() -> void:
	sink.tree = self; OS.add_logger(sink)
	_run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var directory: String = args[1]
	assert(not DirAccess.dir_exists_absolute(directory))
	DirAccess.make_dir_recursive_absolute(directory)
	OS.set_environment("POKEAETHER_SHARED_MODEL_GEOMETRY_TEST", "1")
	var pin := Pilot.release()
	var descriptor := {"schema": 1, "kind": Release.DESCRIPTOR_KIND, "revision": pin.revision,
		"url": "http://127.0.0.1/" + str(pin.index.object_key), "objectBaseUrl": "http://127.0.0.1",
		"sha256": pin.index.sha256, "sizeBytes": pin.index.size_bytes, "requiredAssetIds": pin.requiredAssetIds}
	var adapter := Release.new(directory.path_join("store"), directory.path_join("indexes"))
	adapter.store.prune_previous_models = false
	var accepted := adapter.accept_index(descriptor, Pilot.GEOMETRY_PATH, true)
	assert(str(accepted.error).is_empty(), str(accepted.error))
	var index := adapter.cached_index(descriptor)
	var indexed := Index.by_id(index)
	for key: String in config.asset_ids:
		var result := adapter.accept_bundle(index, key, config.sources[key])
		assert(str(result.error).is_empty(), str(result.error))
	var catalog := adapter.catalog_path_for_launch()
	assert(not catalog.is_empty())
	var service := Service.new()
	var entries := service._catalog(catalog)
	assert(entries.size() == config.asset_ids.size() * 2)
	var first: Dictionary = indexed[config.asset_ids[0]]
	var damaged_path := adapter.store._objects_root().path_join(first.sha256).path_join("model-pair.pck")
	var damaged := FileAccess.open(damaged_path, FileAccess.WRITE)
	damaged.store_string("owned geometry fixture corruption"); damaged.close()
	assert(not str(Pair.object_check(damaged_path.get_base_dir(), first).error).is_empty())
	var repaired := adapter.accept_bundle(index, first.asset_id, config.sources[first.asset_id])
	assert(str(repaired.error).is_empty(), str(repaired.error))
	var restarted := Release.new(directory.path_join("store"), directory.path_join("indexes"))
	assert(restarted.catalog_path_for_launch() == catalog)
	var decoded := 0
	for entry: Dictionary in service._catalog(catalog):
		var checked := Pair.inspect(entry.pack_path, entry.pair_asset)
		assert(str(checked.error).is_empty())
		assert(Pair.mount_checked(entry.pack_path, entry.pair_asset, checked).is_empty())
		var scene := ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		assert(scene != null)
		var actor := scene.instantiate(); actor.free(); decoded += 1
	OS.unset_environment("POKEAETHER_SHARED_MODEL_GEOMETRY_TEST")
	assert(restarted.catalog_path_for_launch().is_empty())
	OS.set_environment("POKEAETHER_SHARED_MODEL_GEOMETRY_TEST", "1")
	assert(restarted.catalog_path_for_launch() == catalog)
	service.free()
	var report := {"ok": true, "pairs": config.asset_ids.size(), "scenes": decoded,
		"repair": true, "restart": true, "opt_in_required": true, "index_sha256": pin.index.sha256}
	var file := FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report)); file.close()
	print("SHARED_GEOMETRY_INSTALL_OK pairs=", config.asset_ids.size(), " scenes=", decoded, " repair=true restart=true")
	quit()
