extends SceneTree

const ReleaseBundles = preload("res://scripts/release_asset_bundles.gd")
const BundleIndex = preload("res://scripts/asset_bundle_index.gd")
const V8 = preload("res://data/approved_3d_release_v8.json")
const V7 = preload("res://data/approved_3d_release_v7.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var path := ProjectSettings.globalize_path("res://../release/approved_3d_bundles_v8_index.json")
	var pin: Dictionary = V8.data.index
	var index_file := FileAccess.open(path, FileAccess.READ)
	assert(index_file != null and index_file.get_length() == pin.size_bytes)
	index_file.close()
	assert(FileAccess.get_sha256(path) == pin.sha256)
	var descriptor := {
		"schema": 1,
		"kind": "pokeaether-release-asset-index",
		"revision": V8.data.revision,
		"url": "http://127.0.0.1/" + str(pin.object_key),
		"objectBaseUrl": "http://127.0.0.1",
		"sha256": pin.sha256,
		"sizeBytes": pin.size_bytes,
		"requiredAssetIds": V8.data.requiredAssetIds.duplicate(),
	}
	assert(V8.data.requiredAssetIds.size() == 1139)
	assert(ReleaseBundles.descriptor_error(descriptor).is_empty())
	var service := ReleaseBundles.new()
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
	# Exercise the packaging output through the actual launcher install path.
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--descriptor="):
			var packaged: Variant = JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--descriptor=")))
			assert(packaged is Dictionary)
			var isolated := ReleaseBundles.new("user://v8-install-check/bundles", "user://v8-install-check/index-" + str(Time.get_ticks_usec()))
			var accepted: Dictionary = isolated.accept_index(packaged, path, false)
			assert(accepted.error.is_empty(), str(accepted.error))
			assert(accepted.jobs.is_empty())
			assert(not isolated.cached_index(packaged).is_empty())
			assert(isolated.jobs(packaged, false).jobs.is_empty())
			assert(isolated.accept_index(packaged, path, false).error.is_empty())
	var by_id := BundleIndex.by_id(index)
	for asset_id: String in [
		"pokemon_3d:ogerpon-wellspring:base",
		"pokemon_3d:terapagos-stellar:base",
		"pokemon_3d:kyurem-white:base",
		"pokemon_3d:calyrex-ice:base",
		"pokemon_3d:charizard:mega-x",
		"pokemon_3d:absol:mega-z",
	]:
		assert(by_id.has(asset_id))
		assert(ReleaseBundles._safe_object_key(asset_id, str(by_id[asset_id].object_key)))
	var bad: Dictionary = descriptor.duplicate(true)
	bad.sha256 = "0".repeat(64)
	assert(not ReleaseBundles.descriptor_error(bad).is_empty())
	print("RELEASE_ASSET_BUNDLES_V8_OK assets=1139 forms=true hashes=true per_pokemon_download=true")
	quit()
