extends SceneTree

const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Release = preload("res://data/approved_3d_release_v5.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var source := OS.get_environment("POKEAETHER_APPROVED_3D_V5_DIR")
	assert(source.is_absolute_path())
	var index_path := source.path_join("asset-index.json")
	assert(FileAccess.get_sha256(index_path) == Release.data.index.sha256)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	var service := Service.new()
	root.add_child(service)
	assert(service._asset_id("garchomp") == "pokemon_3d:garchomp:base")
	assert(service._asset_id("garchomp@shiny") == "pokemon_3d:garchomp:base")
	assert(service._asset_id("dragonite-mega") == "pokemon_3d:dragonite:mega")
	assert(service._asset_id("unapproved-pokemon").is_empty())
	var asset: Dictionary = service._indexed_asset(index, "pokemon_3d:garchomp:base")
	var archive := source.path_join(str(asset.object_key).get_file())
	var bad: Dictionary = asset.duplicate(true)
	bad.sha256 = "0".repeat(64)
	assert(not str(service._unpack_asset(bad, archive).error).is_empty())
	var installed: Dictionary = service._unpack_asset(asset, archive)
	assert(installed.error.is_empty() and installed.entries.size() == 2)
	for entry: Dictionary in installed.entries:
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
	var corrupt_path := str(installed.entries[0].runtime_path)
	var corrupt := FileAccess.open(corrupt_path, FileAccess.WRITE)
	corrupt.store_string("corrupt")
	corrupt.close()
	assert(not service._entry_available(installed.entries, str(installed.entries[0].species)))
	installed = service._unpack_asset(asset, archive)
	assert(installed.error.is_empty())
	var catalog := service._publish_catalog(installed.entries)
	assert(not catalog.is_empty())
	var ready: Dictionary = await service.ensure_models(["garchomp", "garchomp@shiny"], "")
	assert(ready.error.is_empty() and ready.path == catalog)
	assert(service.active_request == null)
	print("ON_DEMAND_3D_BUNDLE_OK approved_pair=true corrupt_archive_rejected=true corrupt_model_repaired=true no_network_for_installed=true")
	quit()
