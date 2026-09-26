extends SceneTree
## Local install/load check for the 14 unreleased catalog batch-01 bundles.
const Index = preload("res://scripts/asset_bundle_index.gd")
const Store = preload("res://scripts/asset_bundle_store.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var directory := OS.get_environment("POKEAETHER_CANDIDATE_BUNDLE_DIR")
	var output := OS.get_environment("POKEAETHER_CANDIDATE_INSTALL_OUTPUT")
	assert(directory.is_absolute_path() and output.is_absolute_path())
	assert(not DirAccess.dir_exists_absolute(output))
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("asset-index.json")))
	assert(index is Dictionary and Index.validate(index).is_empty())
	assert(index.assets.size() == 14)
	var ids: Array[String] = []
	for asset: Dictionary in index.assets:
		ids.append(asset.asset_id)
		assert(asset.appearances.size() == 2)
	var store := Store.new(output)
	var plan := store.plan(index, ids)
	assert(plan.error.is_empty() and plan.downloads.size() == 14)
	for asset: Dictionary in index.assets:
		var archive: String = directory.path_join(str(asset.object_key).get_file())
		var installed := store.install_archive(index, asset.asset_id, archive)
		assert(installed.error.is_empty(), installed.error)
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(store.catalog_path()))
	assert(catalog is Array and catalog.size() == 28)
	for entry: Dictionary in catalog:
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		assert(ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
	var settled := store.plan(index, ids)
	assert(settled.error.is_empty() and settled.downloads.is_empty() and settled.unchanged.size() == 14)
	var restarted := Store.new(output)
	assert(restarted.plan(index, ids).downloads.is_empty())
	print("CATALOG_BATCH_01_CANDIDATE_BUNDLES_OK bundles=14 scenes=28 no_op=true restart=true")
	quit()
