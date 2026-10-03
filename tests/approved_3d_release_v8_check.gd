extends SceneTree

const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Release = preload("res://data/approved_3d_release_v8.json")
const BundleIndex = preload("res://launcher/scripts/asset_bundle_index.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var index_path := ProjectSettings.globalize_path("res://release/approved_3d_bundles_v8_index.json")
	var pin: Dictionary = Release.data.index
	var index_file := FileAccess.open(index_path, FileAccess.READ)
	assert(index_file != null and index_file.get_length() == pin.size_bytes)
	index_file.close()
	assert(FileAccess.get_sha256(index_path) == pin.sha256)
	assert(pin.size_bytes < 1024 * 1024)
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	assert(index is Dictionary and BundleIndex.validate(index).is_empty())
	assert(index.catalog_revision == Release.data.revision)
	assert(index.assets.size() == 1139 and Release.data.requiredAssetIds.size() == 1139)

	var by_id := BundleIndex.by_id(index)
	var found := {}
	for asset_id: String in Release.data.requiredAssetIds:
		assert(by_id.has(asset_id))
		found[asset_id] = true
	assert(found.size() == index.assets.size())
	for asset_id: String in [
		"pokemon_3d:ogerpon-wellspring:base",
		"pokemon_3d:terapagos-terastal:base",
		"pokemon_3d:kyurem-black:base",
		"pokemon_3d:zacian-crowned:base",
		"pokemon_3d:absol:mega-z",
		"pokemon_3d:charizard:mega-x",
		"pokemon_3d:charizard:mega-y",
	]:
		assert(by_id.has(asset_id), "missing alternative-form bundle: " + asset_id)

	var previous := OS.get_environment("POKEAETHER_MODEL_INDEX")
	OS.set_environment("POKEAETHER_MODEL_INDEX", index_path)
	var service := Service.new()
	root.add_child(service)
	assert(service._asset_id("ogerpon-wellspring") == "pokemon_3d:ogerpon-wellspring:base")
	assert(service._asset_id("terapagos-terastal@shiny") == "pokemon_3d:terapagos-terastal:base")
	assert(service._asset_id("kyurem-black") == "pokemon_3d:kyurem-black:base")
	assert(service._asset_id("absol-mega-z") == "pokemon_3d:absol:mega-z")
	var approved: Dictionary = await service._approved_index()
	assert(approved.error.is_empty() and approved.index.assets.size() == 1139)
	if previous.is_empty():
		OS.unset_environment("POKEAETHER_MODEL_INDEX")
	else:
		OS.set_environment("POKEAETHER_MODEL_INDEX", previous)
	print("APPROVED_3D_RELEASE_V8_OK bundles=1139 appearances=2278 all_form_ids=true on_demand=true")
	quit()
