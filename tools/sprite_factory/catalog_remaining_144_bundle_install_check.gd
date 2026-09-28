extends SceneTree
## Verify each locally prepared species bundle through transactional installation.
const Index = preload("res://scripts/asset_bundle_index.gd")
const Store = preload("res://scripts/asset_bundle_store.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var directory := OS.get_environment("POKEAETHER_CANDIDATE_BUNDLE_DIR")
	var output := OS.get_environment("POKEAETHER_CANDIDATE_INSTALL_OUTPUT")
	var expected := int(OS.get_environment("POKEAETHER_CANDIDATE_BUNDLE_COUNT"))
	assert(directory.is_absolute_path() and output.is_absolute_path() and expected > 0)
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("asset-index.json")))
	assert(index is Dictionary and Index.validate(index).is_empty())
	assert(FileAccess.get_sha256(directory.path_join("asset-index.json")) == OS.get_environment("POKEAETHER_CANDIDATE_INDEX_SHA256"))
	assert(index.assets.size() == expected)
	var all_scenes: Array[Dictionary] = []
	var resumed := 0
	for asset: Dictionary in index.assets:
		var asset_id := str(asset.asset_id)
		var store := Store.new(output.path_join(str(asset.species_id)))
		var requested: Array[String] = [asset_id]
		var initial := store.plan(index, requested)
		assert(initial.error.is_empty() and initial.missing.is_empty())
		assert(initial.downloads.size() + initial.unchanged.size() == 1)
		if initial.downloads.size() == 1:
			var archive := directory.path_join(str(asset.object_key).get_file())
			var installed := store.install_archive(index, asset_id, archive)
			assert(installed.error.is_empty(), installed.error)
		else:
			resumed += 1
		var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(store.catalog_path()))
		assert(catalog is Array and catalog.size() == 2)
		assert(store.state().assets.size() == 1)
		assert(store.state().assets[asset_id].version == asset.version)
		assert(store.state().assets[asset_id].archive_sha256 == asset.sha256)
		for entry: Dictionary in catalog:
			assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
			assert(ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
			all_scenes.append(entry)
		var settled := store.plan(index, requested)
		assert(settled.error.is_empty() and settled.downloads.is_empty() and settled.unchanged.size() == 1)
		var restarted := Store.new(output.path_join(str(asset.species_id)))
		assert(restarted.plan(index, requested).downloads.is_empty())
		print("BUNDLE_OK ", asset.species_id)
	assert(all_scenes.size() == expected * 2)
	var aggregate := FileAccess.open(output.path_join("installed-catalog.json"), FileAccess.WRITE)
	assert(aggregate != null)
	aggregate.store_string(JSON.stringify(all_scenes, "\t") + "\n")
	aggregate.close()
	print("REMAINING_144_BUNDLES_OK bundles=", expected, " scenes=", all_scenes.size(),
		" resumed=", resumed, " no_op=true restart=true")
	quit()
