extends SceneTree
## Migrate the real seven-bundle install to the 21-bundle approved index.
const ReleaseBundles = preload("res://scripts/release_asset_bundles.gd")
const BundleIndex = preload("res://scripts/asset_bundle_index.gd")


func _init() -> void:
	_run.call_deferred()


func _descriptor(path: String, revision: String, ids: Array[String]) -> Dictionary:
	return {"schema": 1, "kind": "pokeaether-release-asset-index",
		"revision": revision, "url": "http://127.0.0.1/" + revision + ".json",
		"objectBaseUrl": "http://127.0.0.1",
		"sha256": FileAccess.get_sha256(path),
		"sizeBytes": FileAccess.get_file_as_bytes(path).size(), "requiredAssetIds": ids}


func _install(service: RefCounted, index: Dictionary, directory: String, jobs: Array) -> void:
	var by_id := BundleIndex.by_id(index)
	for job: Dictionary in jobs:
		var asset: Dictionary = by_id[job.id]
		var archive := directory.path_join(str(asset.object_key).get_file())
		var result: Dictionary = service.accept_bundle(index, job.id, archive)
		assert(result.error.is_empty(), result.error)


func _run() -> void:
	var v1 := OS.get_environment("POKEAETHER_APPROVED_3D_V1_DIR")
	var v2 := OS.get_environment("POKEAETHER_APPROVED_3D_V2_DIR")
	var output := OS.get_environment("POKEAETHER_APPROVED_3D_V2_TEST_OUTPUT")
	assert(v1.is_absolute_path() and v2.is_absolute_path() and output.is_absolute_path())
	assert(not DirAccess.dir_exists_absolute(output))
	var service := ReleaseBundles.new(output.path_join("store"), output.path_join("indexes"))
	var original_descriptor := _descriptor(v1.path_join("asset-index.json"), "approved-pokemon-3d-v1", ReleaseBundles.V1_ASSET_IDS.duplicate())
	var original := service.accept_index(original_descriptor, v1.path_join("asset-index.json"))
	assert(original.error.is_empty() and original.jobs.size() == 7)
	var original_index: Dictionary = service.cached_index(original_descriptor)
	_install(service, original_index, v1, original.jobs)
	var old_catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(service.catalog_path()))
	assert(old_catalog is Array and old_catalog.size() == 14)
	var old_state: String = service.store.active_generation()
	var expanded_descriptor := _descriptor(v2.path_join("asset-index.json"), "approved-pokemon-3d-v2", ReleaseBundles.RELEASE_ASSET_IDS.duplicate())
	var expansion := service.accept_index(expanded_descriptor, v2.path_join("asset-index.json"))
	assert(expansion.error.is_empty() and expansion.jobs.size() == 14 and expansion.unchanged.size() == 7)
	var index: Dictionary = service.cached_index(expanded_descriptor)
	for job: Dictionary in expansion.jobs:
		assert(job.id not in ReleaseBundles.V1_ASSET_IDS)
	var first: Dictionary = expansion.jobs[0]
	var first_asset: Dictionary = BundleIndex.by_id(index)[first.id]
	var good_archive := v2.path_join(str(first_asset.object_key).get_file())
	var corrupt := output.path_join("corrupt.zip")
	var bytes := FileAccess.get_file_as_bytes(good_archive)
	bytes.resize(maxi(1, bytes.size() / 2))
	var file := FileAccess.open(corrupt, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	assert(not service.accept_bundle(index, first.id, corrupt).error.is_empty())
	assert(service.store.active_generation() == old_state)
	_install(service, index, v2, expansion.jobs)
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(service.catalog_path()))
	assert(catalog is Array and catalog.size() == 42)
	for entry: Dictionary in catalog:
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		assert(ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
	var settled := service.jobs(expanded_descriptor)
	assert(settled.error.is_empty() and settled.jobs.is_empty() and settled.unchanged.size() == 21)
	var restarted := ReleaseBundles.new(output.path_join("store"), output.path_join("indexes"))
	assert(restarted.jobs(expanded_descriptor).jobs.is_empty())
	var unsupported := index.duplicate(true)
	unsupported.assets.append(unsupported.assets[0].duplicate(true))
	unsupported.assets[-1].asset_id = "pokemon_3d:azumarill:base"
	unsupported.assets[-1].species_id = "azumarill"
	assert(not restarted._release_index_error(unsupported).is_empty())
	print("RELEASE_ASSET_BUNDLES_V2_OK old=7 new=14 scenes=42 no_op=true rollback=true restart=true")
	quit()
