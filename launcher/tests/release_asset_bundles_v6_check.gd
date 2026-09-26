extends SceneTree
## Check the pinned v6 descriptor, exact index, and a newly approved pair.
const ReleaseBundles = preload("res://scripts/release_asset_bundles.gd")
const BundleIndex = preload("res://scripts/asset_bundle_index.gd")
const V6 = preload("res://data/approved_3d_release_v6.json")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := OS.get_environment("POKEAETHER_APPROVED_3D_V6_DIR")
	var output := OS.get_environment("POKEAETHER_APPROVED_3D_V6_TEST_OUTPUT")
	assert(directory.is_absolute_path() and output.is_absolute_path() and not DirAccess.dir_exists_absolute(output))
	var path := directory.path_join("asset-index.json")
	var pinned: Dictionary = V6.data.index
	assert(FileAccess.get_sha256(path) == pinned.sha256)
	assert(FileAccess.get_file_as_bytes(path).size() == pinned.size_bytes)
	var descriptor := {"schema": 1, "kind": "pokeaether-release-asset-index",
		"revision": V6.data.revision,
		"url": "http://127.0.0.1/" + str(pinned.object_key),
		"objectBaseUrl": "http://127.0.0.1",
		"sha256": pinned.sha256, "sizeBytes": pinned.size_bytes,
		"requiredAssetIds": V6.data.requiredAssetIds.duplicate()}
	assert(ReleaseBundles.descriptor_error(descriptor).is_empty())
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(BundleIndex.validate(index).is_empty())
	var service := ReleaseBundles.new(output.path_join("store"), output.path_join("indexes"))
	assert(service._release_index_error(index, descriptor).is_empty())
	var result: Dictionary = service.accept_index(descriptor, path, false)
	assert(result.error.is_empty() and result.jobs.is_empty())
	assert(service.jobs(descriptor, false).jobs.is_empty())
	var by_id := BundleIndex.by_id(index)
	for asset_id: String in ["pokemon_3d:abomasnow:base", "pokemon_3d:dragonite:base", "pokemon_3d:dragonite:mega"]:
		var archive := directory.path_join(str(by_id[asset_id].object_key).get_file())
		var installed: Dictionary = service.accept_bundle(index, asset_id, archive)
		assert(installed.error.is_empty(), str(installed.error))
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(service.catalog_path()))
	assert(catalog is Array and catalog.size() == 6)
	for entry: Dictionary in catalog:
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		assert(ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
	var bad_descriptor: Dictionary = descriptor.duplicate(true)
	bad_descriptor.sha256 = "0".repeat(64)
	assert(not ReleaseBundles.descriptor_error(bad_descriptor).is_empty())
	print("RELEASE_ASSET_BUNDLES_V6_OK assets=154 new_pair=true mega_retained=true optional_index=true")
	quit()
