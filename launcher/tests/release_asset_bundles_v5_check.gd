extends SceneTree
## Certify the exact 82-base-plus-Mega release descriptor and index.
const ReleaseBundles = preload("res://scripts/release_asset_bundles.gd")
const BundleIndex = preload("res://scripts/asset_bundle_index.gd")
const V5 = preload("res://data/approved_3d_release_v5.json")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := OS.get_environment("POKEAETHER_APPROVED_3D_V5_DIR")
	var output := OS.get_environment("POKEAETHER_APPROVED_3D_V5_TEST_OUTPUT")
	assert(directory.is_absolute_path() and output.is_absolute_path() and not DirAccess.dir_exists_absolute(output))
	var path := directory.path_join("asset-index.json")
	var pinned: Dictionary = V5.data.index
	assert(FileAccess.get_sha256(path) == pinned.sha256)
	assert(FileAccess.get_file_as_bytes(path).size() == pinned.size_bytes)
	var descriptor := {"schema": 1, "kind": "pokeaether-release-asset-index",
		"revision": V5.data.revision,
		"url": "http://127.0.0.1/" + str(pinned.object_key),
		"objectBaseUrl": "http://127.0.0.1",
		"sha256": pinned.sha256, "sizeBytes": pinned.size_bytes,
		"requiredAssetIds": V5.data.requiredAssetIds.duplicate()}
	assert(ReleaseBundles.descriptor_error(descriptor).is_empty())
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(BundleIndex.validate(index).is_empty())
	var service := ReleaseBundles.new(output.path_join("store"), output.path_join("indexes"))
	assert(service._release_index_error(index, descriptor).is_empty())
	var result: Dictionary = service.accept_index(descriptor, path)
	assert(result.error.is_empty() and result.jobs.size() == 83)
	var jobs: Dictionary = {}
	for job: Dictionary in result.jobs:
		jobs[job.id] = job
	assert(jobs.has("pokemon_3d:dragonite:base") and jobs.has(ReleaseBundles.MEGA_ID))
	var by_id := BundleIndex.by_id(index)
	assert(jobs[ReleaseBundles.MEGA_ID].sha256 == by_id[ReleaseBundles.MEGA_ID].sha256)
	for asset_id in ["pokemon_3d:dragonite:base", ReleaseBundles.MEGA_ID]:
		var archive := directory.path_join(str(by_id[asset_id].object_key).get_file())
		assert(service.accept_bundle(index, asset_id, archive).error.is_empty())
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(service.catalog_path()))
	assert(catalog is Array and catalog.size() == 4)
	for entry: Dictionary in catalog:
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		assert(ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
	var bad_descriptor: Dictionary = descriptor.duplicate(true)
	bad_descriptor.sha256 = "0".repeat(64)
	assert(not ReleaseBundles.descriptor_error(bad_descriptor).is_empty())
	bad_descriptor = descriptor.duplicate(true)
	bad_descriptor.requiredAssetIds.erase(ReleaseBundles.MEGA_ID)
	assert(not ReleaseBundles.descriptor_error(bad_descriptor).is_empty())
	var bad_index: Dictionary = index.duplicate(true)
	for asset: Dictionary in bad_index.assets:
		if asset.asset_id == ReleaseBundles.MEGA_ID:
			asset.form_id = "base"
	assert(not service._release_index_error(bad_index, descriptor).is_empty())
	print("RELEASE_ASSET_BUNDLES_V5_OK assets=83 paired=166 mega_dependency=true descriptor_pinned=true")
	quit()
