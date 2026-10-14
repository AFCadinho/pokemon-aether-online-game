extends SceneTree
## Exercise dependency planning against the complete unpublished collection.
const Index = preload("res://scripts/services/asset_bundle_index.gd")
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const LauncherPair = preload("res://launcher/scripts/model_pair_pack.gd")
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")

func _init() -> void:
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST", "1")
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0].get_base_dir().path_join("catalog.json")))
	assert(not catalog.production_approved and catalog.prototype_only)
	assert(FileAccess.get_sha256(args[0].get_base_dir().path_join("catalog.json")) == config.catalog_sha256)
	assert(Index.validate(catalog).is_empty(), Index.validate(catalog))
	var assets := Index.by_id(catalog)
	var multi_pool_pairs := 0
	for job: Dictionary in config.jobs:
		var asset: Dictionary = job.asset
		assert(Pair.metadata_error(asset).is_empty())
		assert(LauncherPair.metadata_error(asset).is_empty())
		var downloads: Array[String] = []
		Index._append_dependencies(asset.asset_id, assets, downloads)
		assert(downloads[-1] == asset.asset_id)
		if asset.pair_manifest.texture_pools.size() > 1:
			multi_pool_pairs += 1
		for pool: Dictionary in asset.pair_manifest.texture_pools:
			assert(assets[pool.asset_id] == pool)
			assert(downloads.count(pool.asset_id) == 1)
			assert(downloads.find(pool.asset_id) < downloads.find(asset.asset_id))
		# Existing production selectors must not admit unpublished scene hashes.
		for look: Dictionary in asset.appearances:
			assert(Pilot.asset_for(str(look.runtime_identity), str(look.runtime_sha256)).is_empty())
		for look: Dictionary in job.previous.appearances:
			assert(not Pilot.asset_for(str(look.runtime_identity), str(look.runtime_sha256)).is_empty())
	assert(multi_pool_pairs > 0)
	var chosen: Dictionary = config.jobs[0].asset
	var plan := Index.plan(catalog, {}, [chosen.asset_id, config.jobs[-1].asset.asset_id])
	assert(str(plan.error).is_empty() and plan.missing.is_empty())
	var bad := chosen.duplicate(true)
	bad.pair_manifest.texture_pools[0].sha256 = "0".repeat(64)
	var changed := catalog.duplicate(true)
	for i in changed.assets.size():
		if changed.assets[i].asset_id == chosen.asset_id:
			changed.assets[i] = bad
	assert(not Index.validate(changed).is_empty())
	changed = catalog.duplicate(true)
	var missing: String = str(chosen.pair_manifest.texture_pools[0].asset_id)
	changed.assets = changed.assets.filter(func(a: Dictionary) -> bool: return a.asset_id != missing)
	assert(not Index.validate(changed).is_empty())
	print("SHARED_TEXTURE_EXPANSION_CONTRACT_OK pairs=", config.jobs.size(), " multi_pool_pairs=", multi_pool_pairs,
		" production_unchanged=true")
	quit()
