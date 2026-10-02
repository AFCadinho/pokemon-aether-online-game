extends "catalog_remaining_144_bundle_install_check.gd"
## Multiple Mega forms of one species must coexist in the same transactional store.

func _run() -> void:
	var directory := OS.get_environment("POKEAETHER_CANDIDATE_BUNDLE_DIR")
	var output := OS.get_environment("POKEAETHER_CANDIDATE_INSTALL_OUTPUT")
	assert(directory.is_absolute_path() and output.is_absolute_path())
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("asset-index.json")))
	var count_text := OS.get_environment("POKEAETHER_MEGA_EXPECTED_PAIRS")
	var count := 71 if count_text.is_empty() else int(count_text)
	assert(count > 0 and (count_text.is_empty() or count_text.is_valid_int()))
	assert(Index.validate(index).is_empty() and index.assets.size() == count)
	assert(FileAccess.get_sha256(directory.path_join("asset-index.json")) == OS.get_environment("POKEAETHER_CANDIDATE_INDEX_SHA256"))
	var store := Store.new(output.path_join("content"))
	var resumed := 0
	for asset: Dictionary in index.assets:
		var requested: Array[String] = [asset.asset_id]
		var initial := store.plan(index, requested)
		assert(initial.error.is_empty() and initial.missing.is_empty())
		assert(initial.downloads.size() + initial.unchanged.size() == 1)
		if initial.downloads.size() == 1:
			var installed := store.install_archive(index, asset.asset_id, directory.path_join(str(asset.object_key).get_file()))
			assert(installed.error.is_empty(), installed.error)
		else:
			resumed += 1
		assert(store.state().assets.has(asset.asset_id))
		assert(store.state().assets[asset.asset_id].archive_sha256 == asset.sha256)
		var settled := store.plan(index, requested)
		assert(settled.error.is_empty() and settled.downloads.is_empty() and settled.unchanged.size() == 1)
		assert(Store.new(output.path_join("content")).plan(index, requested).downloads.is_empty())
		print("MEGA_BUNDLE_OK ", asset.asset_id)
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(store.catalog_path()))
	assert(catalog.size() == count * 2 and store.state().assets.size() == count)
	var expected := {}
	for asset in index.assets:
		for appearance in asset.appearances:
			expected[appearance.runtime_identity] = appearance.runtime_sha256
	var seen := {}
	for entry: Dictionary in catalog:
		var identity: String = entry.species + ("@shiny" if entry.variant == "shiny" else "")
		assert(not seen.has(identity) and expected.get(identity) == entry.runtime_sha256)
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		assert(ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
		seen[identity] = true
	assert(seen.size() == expected.size())
	var aggregate := FileAccess.open(output.path_join("installed-catalog.json"), FileAccess.WRITE)
	assert(aggregate != null)
	aggregate.store_string(JSON.stringify(catalog, "\t") + "\n")
	aggregate.close()
	print("MEGA_BUNDLES_OK bundles=", count, " scenes=", count * 2, " resumed=", resumed, " coexist=true no_op=true restart=true")
	quit()
