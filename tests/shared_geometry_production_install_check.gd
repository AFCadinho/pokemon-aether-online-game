extends SceneTree
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const Release = preload("res://launcher/scripts/release_asset_bundles.gd")
const Index = preload("res://launcher/scripts/asset_bundle_index.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const V11 = preload("res://data/approved_3d_release_v11.json")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var sources: Dictionary = config.assets
	var directory: String = args[1]
	assert(not DirAccess.dir_exists_absolute(directory))
	DirAccess.make_dir_recursive_absolute(directory)
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST", "1")
	var pin := Pilot.release()
	assert(pin.revision == "approved-pokemon-3d-v13")
	var descriptor := {"schema": 1, "kind": Release.DESCRIPTOR_KIND, "revision": pin.revision,
		"url": "https://updates.pokeaether.com/" + str(pin.index.object_key),
		"objectBaseUrl": "https://updates.pokeaether.com", "sha256": pin.index.sha256,
		"sizeBytes": pin.index.size_bytes, "requiredAssetIds": pin.requiredAssetIds}
	var adapter := Release.new(directory.path_join("store"), directory.path_join("indexes"))
	adapter.store.prune_previous_models = false
	var old_pin: Dictionary = V11.data
	var old_descriptor := {"schema": 1, "kind": Release.DESCRIPTOR_KIND, "revision": old_pin.revision,
		"url": "https://updates.pokeaether.com/" + str(old_pin.index.object_key),
		"objectBaseUrl": "https://updates.pokeaether.com", "sha256": old_pin.index.sha256,
		"sizeBytes": old_pin.index.size_bytes, "requiredAssetIds": old_pin.requiredAssetIds}
	var old_accepted := adapter.accept_index(old_descriptor, "res://release/approved_3d_bundles_v11_index.json", true)
	assert(str(old_accepted.error).is_empty(), str(old_accepted.error))
	var old_index := adapter.cached_index(old_descriptor)
	var old_ids: Array[String] = ["pokemon_3d:abomasnow:base"]
	var old_session := adapter.begin_collection(old_index, old_ids)
	assert(str(old_session.error).is_empty() and old_session.downloads == old_ids)
	var old_staged := adapter.stage_collection(old_session, old_ids[0], config.previous)
	assert(str(old_staged.error).is_empty(), str(old_staged.error))
	assert(str(adapter.finish_collection(old_session).error).is_empty())
	var accepted := adapter.accept_index(descriptor, Pilot.PRODUCTION_PATH, true)
	assert(str(accepted.error).is_empty(), str(accepted.error))
	var index := adapter.cached_index(descriptor)
	assert(index.catalog_revision == pin.revision and Index.validate(index).is_empty())
	var ids: Array[String] = []
	ids.assign(sources.keys())
	ids.sort()
	var session := adapter.begin_collection(index, ids)
	assert(str(session.error).is_empty() and session.downloads.size() == ids.size())
	for id: String in session.downloads.duplicate():
		var staged := adapter.stage_collection(session, id, sources[id])
		assert(str(staged.error).is_empty(), str(staged.error))
	assert(str(adapter.finish_collection(session).error).is_empty())
	var restarted := Release.new(directory.path_join("store"), directory.path_join("indexes"))
	restarted.store.prune_previous_models = false
	var catalog_path := restarted.catalog_path_for_launch()
	assert(not catalog_path.is_empty())
	var service := Service.new()
	assert(service._selected_release() == pin)
	var entries := service._catalog(catalog_path)
	assert(entries.size() == ids.size() * 2)
	var shared := 0
	for entry: Dictionary in entries:
		if entry.has("pair_asset"):
			var asset: Dictionary = entry.pair_asset
			var checked := Pair.inspect(entry.pack_path, asset)
			assert(str(checked.error).is_empty())
			assert(Pair.mount_checked(entry.pack_path, asset, checked).is_empty())
			shared += 1
		assert(ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
	assert(shared == 4 and entries.size() == 6)
	# Re-select the retained v11 tuple and confirm its original ZIP still works.
	var rollback := adapter.begin_collection(old_index, old_ids)
	assert(str(rollback.error).is_empty())
	if rollback.downloads.has(old_ids[0]):
		var restored := adapter.stage_collection(rollback, old_ids[0], config.previous)
		assert(str(restored.error).is_empty(), str(restored.error))
	assert(str(adapter.finish_collection(rollback).error).is_empty())
	assert(adapter.catalog_path_for_launch() != "")
	service.free()
	OS.unset_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST")
	print("SHARED_GEOMETRY_PRODUCTION_INSTALL_OK pairs=", ids.size(), " appearances=", entries.size(), " shared=", shared, " upgrade=true rollback=true")
	quit()
