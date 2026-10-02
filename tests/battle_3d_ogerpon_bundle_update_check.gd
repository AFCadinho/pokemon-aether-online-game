extends SceneTree
## Actual v1 -> v2 transactional updates of each already released Ogerpon form.
const Store = preload("res://scripts/asset_bundle_store.gd")

func _init() -> void:
	var work := OS.get_environment("POKEAETHER_OGERPON_REVISION_WORK")
	var old_directory := OS.get_environment("POKEAETHER_OGERPON_OLD_BUNDLES")
	assert(work.is_absolute_path() and old_directory.is_absolute_path())
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(old_directory.path_join("asset-index.json")))
	var revised: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(work.path_join("bundles/asset-index.json")))
	assert(revised.assets.size() == 3)
	for asset: Dictionary in revised.assets:
		var matches: Array = old.assets.filter(func(r): return r.asset_id == asset.asset_id)
		assert(matches.size() == 1 and matches[0].version == 1 and asset.version == 2)
		var output := work.path_join("upgrade-installed").path_join(asset.species_id)
		assert(not DirAccess.dir_exists_absolute(output))
		var store := Store.new(output)
		assert(store.install_archive(old, asset.asset_id, old_directory.path_join(str(matches[0].object_key).get_file())).error.is_empty())
		var plan: Dictionary = store.plan(revised, [asset.asset_id])
		assert(plan.error.is_empty() and plan.downloads.size() == 1 and plan.unchanged.is_empty())
		assert(store.install_archive(revised, asset.asset_id, work.path_join("bundles").path_join(str(asset.object_key).get_file())).error.is_empty())
		assert(store.state().assets[asset.asset_id].version == 2)
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(store.catalog_path()))
		assert(rows.size() == 2)
		for row: Dictionary in rows:
			assert(FileAccess.get_sha256(row.runtime_path) == row.runtime_sha256)
			assert(ResourceLoader.load(row.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
		var settled: Dictionary = store.plan(revised, [asset.asset_id])
		assert(settled.error.is_empty() and settled.downloads.is_empty() and settled.unchanged.size() == 1)
		var restarted := Store.new(output)
		assert(restarted.plan(revised, [asset.asset_id]).downloads.is_empty())
	print("OGERPON_V1_V2_UPDATE_OK bundles=3 scenes=6 no_op=true restart=true")
	quit()
