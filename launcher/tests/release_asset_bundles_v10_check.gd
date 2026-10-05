extends SceneTree

const ReleaseBundles = preload("res://scripts/release_asset_bundles.gd")
const BundleIndex = preload("res://scripts/asset_bundle_index.gd")
const V10 = preload("res://data/approved_3d_release_v10.json")
const V7 = preload("res://data/approved_3d_release_v7.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var path := ProjectSettings.globalize_path("res://../release/approved_3d_bundles_v10_index.json")
	var pin: Dictionary = V10.data.index
	var index_file := FileAccess.open(path, FileAccess.READ)
	assert(index_file != null and index_file.get_length() == pin.size_bytes)
	index_file.close()
	assert(FileAccess.get_sha256(path) == pin.sha256)
	var descriptor := {
		"schema": 1,
		"kind": "pokeaether-release-asset-index",
		"revision": V10.data.revision,
		"url": "http://127.0.0.1/" + str(pin.object_key),
		"objectBaseUrl": "http://127.0.0.1",
		"sha256": pin.sha256,
		"sizeBytes": pin.size_bytes,
		"requiredAssetIds": V10.data.requiredAssetIds.duplicate(),
	}
	assert(V10.data.requiredAssetIds.size() == 1200)
	assert(ReleaseBundles.descriptor_error(descriptor).is_empty())
	var service := ReleaseBundles.new("user://v10-check/bundles", "user://v10-check/index-" + str(Time.get_ticks_usec()))
	var plan: Dictionary = service.jobs(descriptor, false)
	assert(plan.error.is_empty() and plan.jobs.size() == 1)
	assert(plan.jobs[0].type == "asset_bundle_index")
	var v7pin: Dictionary = V7.data.index
	var v7descriptor := {
		"schema": 1,
		"kind": "pokeaether-release-asset-index",
		"revision": V7.data.revision,
		"url": "http://127.0.0.1/" + str(v7pin.object_key),
		"objectBaseUrl": "http://127.0.0.1",
		"sha256": v7pin.sha256,
		"sizeBytes": v7pin.size_bytes,
		"requiredAssetIds": V7.data.requiredAssetIds.duplicate(),
	}
	assert(ReleaseBundles.descriptor_error(v7descriptor).is_empty())
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(BundleIndex.validate(index).is_empty())
	assert(service._release_index_error(index, descriptor).is_empty())
	assert(service._release_index_error(index).is_empty())
	var initial_accept: Dictionary = service.accept_index(descriptor, path, false)
	assert(initial_accept.error.is_empty() and initial_accept.jobs.is_empty())
	assert(not service.cached_index(descriptor).is_empty())
	assert(service.jobs(descriptor, false).jobs.is_empty())
	var full_plan: Dictionary = service.jobs(descriptor, true)
	assert(full_plan.error.is_empty() and full_plan.jobs.size() == 1200, "Full collection should plan all 1200 bundles")
	assert(service.accept_index(descriptor, path, false).error.is_empty())
	var invalid: Dictionary = index.duplicate(true)
	invalid.assets.remove_at(0)
	assert(not service._release_index_error(invalid, descriptor).is_empty())
	invalid = index.duplicate(true)
	invalid.assets[0].appearances[0].runtime_sha256 = "0".repeat(64)
	assert(not service._release_index_error(invalid, descriptor).is_empty())
	# Exercise the packaging output through the actual launcher install path.
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--descriptor="):
			var packaged: Variant = JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--descriptor=")))
			assert(packaged is Dictionary)
			var isolated := ReleaseBundles.new("user://v10-install-check/bundles", "user://v10-install-check/index-" + str(Time.get_ticks_usec()))
			var accepted: Dictionary = isolated.accept_index(packaged, path, false)
			assert(accepted.error.is_empty(), str(accepted.error))
			assert(accepted.jobs.is_empty())
			assert(not isolated.cached_index(packaged).is_empty())
			assert(isolated.jobs(packaged, false).jobs.is_empty())
			assert(isolated.accept_index(packaged, path, false).error.is_empty())
	var by_id := BundleIndex.by_id(index)
	for asset_id: String in [
		"pokemon_3d:articuno-galar:base",
		"pokemon_3d:zapdos-galar:base",
		"pokemon_3d:moltres-galar:base",
		"pokemon_3d:ogerpon-wellspring:base",
		"pokemon_3d:terapagos-stellar:base",
		"pokemon_3d:kyurem-white:base",
		"pokemon_3d:calyrex-ice:base",
		"pokemon_3d:charizard:mega-x",
		"pokemon_3d:absol:mega-z",
	]:
		assert(by_id.has(asset_id))
		assert(ReleaseBundles._safe_object_key(asset_id, str(by_id[asset_id].object_key)))
	var cohort: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../release/approved_3d_regional_58_index.json"))
	assert(cohort.assets.size() == 58)
	for asset: Dictionary in cohort.assets:
		assert(by_id.has(asset.asset_id))
		assert(ReleaseBundles._safe_object_key(asset.asset_id, str(by_id[asset.asset_id].object_key)))
	var bad: Dictionary = descriptor.duplicate(true)
	bad.sha256 = "0".repeat(64)
	assert(not ReleaseBundles.descriptor_error(bad).is_empty())
	bad = descriptor.duplicate(true)
	bad.requiredAssetIds.remove_at(0)
	assert(not ReleaseBundles.descriptor_error(bad).is_empty())
	print("RELEASE_ASSET_BUNDLES_V10_OK assets=1200 forms=true hashes=true per_pokemon_download=true")
	quit()
