extends SceneTree
## Install and reload the 25 recovered batch-03 candidate bundles locally.
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
	assert(index.catalog_revision == "catalog-batch-03-hold-recovery-v1" and index.assets.size() == 25)
	var ids: Array[String] = []
	var archives := {}
	for asset: Dictionary in index.assets:
		ids.append(asset.asset_id)
		assert(asset.appearances.size() == 2)
		archives[asset.asset_id] = directory.path_join(str(asset.object_key).get_file())
	var store := Store.new(output)
	var initial := store.plan(index, ids)
	assert(initial.error.is_empty() and initial.missing.is_empty())
	assert(initial.downloads.size() + initial.unchanged.size() == 25)
	for asset_id: String in initial.downloads:
		var installed := store.install_archive(index, asset_id, archives[asset_id])
		assert(installed.error.is_empty(), installed.error)
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(store.catalog_path()))
	assert(catalog is Array and catalog.size() == 50)
	for entry: Dictionary in catalog:
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		assert(ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
	var settled := store.plan(index, ids)
	assert(settled.error.is_empty() and settled.downloads.is_empty() and settled.unchanged.size() == 25)
	var restarted := Store.new(output)
	assert(restarted.plan(index, ids).downloads.is_empty())
	print("CATALOG_BATCH_03_HOLD_RECOVERY_BUNDLES_OK bundles=25 scenes=50 no_op=true restart=true catalog=", store.catalog_path())
	quit()
