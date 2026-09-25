extends SceneTree
const ReleaseBundles = preload("res://scripts/release_asset_bundles.gd")

var output: String


func _init() -> void:
	_run.call_deferred()


func _descriptor(index_path: String, revision: String) -> Dictionary:
	return {
		"schema": 1,
		"kind": "pokeaether-release-asset-index",
		"revision": revision,
		"url": "http://127.0.0.1/" + revision + ".json",
		"objectBaseUrl": "http://127.0.0.1",
		"sha256": FileAccess.get_sha256(index_path),
		"sizeBytes": FileAccess.get_file_as_bytes(index_path).size(),
		"requiredAssetIds": ReleaseBundles.V1_ASSET_IDS.duplicate(),
	}


func _archive(directory: String, asset: Dictionary) -> String:
	return directory.path_join(str(asset.object_key).get_file())


func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.close()


func _run() -> void:
	var release := OS.get_environment("POKEAETHER_APPROVED_3D_RELEASE_DIR")
	var update := OS.get_environment("POKEAETHER_APPROVED_3D_UPDATE_DIR")
	output = OS.get_environment("POKEAETHER_APPROVED_3D_TEST_OUTPUT")
	assert(release.is_absolute_path() and update.is_absolute_path() and output.is_absolute_path())
	assert(not DirAccess.dir_exists_absolute(output) and DirAccess.make_dir_recursive_absolute(output) == OK)
	var store_root := output.path_join("store")
	var index_root := output.path_join("indexes")
	var service := ReleaseBundles.new(store_root, index_root)
	var index_path := release.path_join("asset-index.json")
	var descriptor := _descriptor(index_path, "approved-pokemon-3d-v1")
	var initial := service.jobs(descriptor)
	assert(initial.error.is_empty() and initial.jobs.size() == 1 and initial.jobs[0].type == "asset_bundle_index")
	var accepted := service.accept_index(descriptor, index_path)
	assert(accepted.error.is_empty() and accepted.jobs.size() == 7)
	var index: Dictionary = service.cached_index(descriptor)
	for job: Dictionary in accepted.jobs:
		var asset: Dictionary = preload("res://scripts/asset_bundle_index.gd").by_id(index)[job.id]
		var result := service.accept_bundle(index, job.id, _archive(release, asset))
		assert(result.error.is_empty())
	var catalog_path := service.catalog_path()
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	assert(catalog is Array and catalog.size() == 14)
	var identities: Array[String] = []
	for entry: Dictionary in catalog:
		identities.append(str(entry.species) + ("@shiny" if entry.variant == "shiny" else ""))
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		assert(ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
	assert(identities.has("dragonite") and identities.has("dragonite@shiny"))
	var no_op := service.jobs(descriptor)
	assert(no_op.error.is_empty() and no_op.jobs.is_empty() and no_op.unchanged.size() == 7)
	var restarted := ReleaseBundles.new(store_root, index_root)
	assert(restarted.catalog_path() == catalog_path and restarted.jobs(descriptor).jobs.is_empty())

	# Create a release index where only Dragonite advances to version 2.
	var update_index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(update.path_join("asset-index.json")))
	var next_index: Dictionary = index.duplicate(true)
	next_index.catalog_revision = "approved-pokemon-3d-v2-dragonite"
	var update_assets := preload("res://scripts/asset_bundle_index.gd").by_id(update_index)
	for asset_index in next_index.assets.size():
		if next_index.assets[asset_index].asset_id == "pokemon_3d:dragonite:base":
			next_index.assets[asset_index] = update_assets["pokemon_3d:dragonite:base"]
	var next_path := output.path_join("dragonite-v2-index.json")
	_write_json(next_path, next_index)
	var next_descriptor := _descriptor(next_path, "approved-pokemon-3d-v2-dragonite")
	var next_accept := service.accept_index(next_descriptor, next_path)
	assert(next_accept.error.is_empty() and next_accept.jobs.size() == 1)
	assert(next_accept.jobs[0].id == "pokemon_3d:dragonite:base")
	var before_failed_update: String = service.store.active_generation()
	var dragonite_v2: Dictionary = update_assets["pokemon_3d:dragonite:base"]
	var valid_update := _archive(update, dragonite_v2)
	var corrupt := output.path_join("corrupt-dragonite.zip")
	var corrupt_file := FileAccess.open(corrupt, FileAccess.WRITE)
	var valid_bytes := FileAccess.get_file_as_bytes(valid_update)
	corrupt_file.store_buffer(valid_bytes.slice(0, valid_bytes.size() / 2))
	corrupt_file.close()
	assert(not service.accept_bundle(next_index, dragonite_v2.asset_id, corrupt).error.is_empty())
	assert(service.store.active_generation() == before_failed_update)
	assert(service.accept_bundle(next_index, dragonite_v2.asset_id, valid_update).error.is_empty())
	assert(service.store.active_generation() != before_failed_update)

	# The release adapter rejects expansion to the screened/local-only cohort.
	var screened := next_index.duplicate(true)
	screened.assets.append(screened.assets[0].duplicate(true))
	screened.assets[-1].asset_id = "pokemon_3d:azumarill:base"
	screened.assets[-1].species_id = "azumarill"
	var screened_path := output.path_join("screened.json")
	_write_json(screened_path, screened)
	var screened_result := service.accept_index(_descriptor(screened_path, "screened"), screened_path)
	assert(not screened_result.error.is_empty())
	print("RELEASE_ASSET_BUNDLES_OK initial=7 appearances=14 no_op=0 update=dragonite rollback=true restart=true screened_rejected=true")
	quit()
