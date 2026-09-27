extends SceneTree
## Local install/load/no-op/restart check for the 24 unreleased batch-04 recovered bundles.
## A previous interrupted attempt can be resumed from the transactional store.
const Index = preload("res://scripts/asset_bundle_index.gd")
const Store = preload("res://scripts/asset_bundle_store.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var directory := OS.get_environment("POKEAETHER_CANDIDATE_BUNDLE_DIR")
	var output := OS.get_environment("POKEAETHER_CANDIDATE_INSTALL_OUTPUT")
	assert(directory.is_absolute_path() and output.is_absolute_path())
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("asset-index.json")))
	assert(index is Dictionary and Index.validate(index).is_empty())
	assert(FileAccess.get_sha256(directory.path_join("asset-index.json")) == OS.get_environment("POKEAETHER_CANDIDATE_INDEX_SHA256"))
	assert(index.assets.size() == 24)
	var ids: Array[String] = []
	var archives := {}
	for asset: Dictionary in index.assets:
		ids.append(asset.asset_id)
		assert(asset.appearances.size() == 2)
		archives[asset.asset_id] = directory.path_join(str(asset.object_key).get_file())
	var store := Store.new(output)
	var initial := store.plan(index, ids)
	assert(initial.error.is_empty() and initial.missing.is_empty())
	assert(initial.downloads.size() + initial.unchanged.size() == 24)
	var resumed: int = initial.unchanged.size()
	for asset_id: String in initial.downloads:
		var installed := store.install_archive(index, asset_id, archives[asset_id])
		assert(installed.error.is_empty(), installed.error)
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(store.catalog_path()))
	assert(catalog is Array and catalog.size() == 48)
	for entry: Dictionary in catalog:
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		assert(ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
	var settled := store.plan(index, ids)
	assert(settled.error.is_empty() and settled.downloads.is_empty() and settled.unchanged.size() == 24)
	var restarted := Store.new(output)
	assert(restarted.plan(index, ids).downloads.is_empty())
	print("CATALOG_BATCH_04_CANDIDATE_BUNDLES_OK bundles=24 scenes=48 resumed=", resumed,
		" no_op=true restart=true catalog=", store.catalog_path())
	quit()
