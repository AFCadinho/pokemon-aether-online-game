extends SceneTree
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Approval = preload("res://launcher/scripts/model_pack_manifest.gd")
const Adapter = preload("res://launcher/scripts/release_asset_bundles.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Index = preload("res://launcher/scripts/asset_bundle_index.gd")
const V12 = preload("res://data/approved_3d_release_v12.json")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Exercise the historical v11-to-v12 source repair independently of v14.
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST", "0")
	var path := "res://release/approved_3d_bundles_v12_index.json"
	var current: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://release/approved_3d_bundles_v11_index.json"))
	assert(FileAccess.get_sha256(path) == V12.data.index.sha256)
	assert(FileAccess.get_file_as_bytes(path).size() == int(V12.data.index.size_bytes))
	assert(Index.validate(current).is_empty() and current.assets.size() == 1200)
	var adapter := Adapter.new("user://hawlucha-repair-check/store", "user://hawlucha-repair-check/indexes")
	var pin: Dictionary = V12.data.index
	var descriptor := {"schema": 1, "kind": "pokeaether-release-asset-index", "revision": V12.data.revision,
		"url": "https://updates.pokeaether.com/" + str(pin.object_key), "objectBaseUrl": "https://updates.pokeaether.com",
		"sha256": pin.sha256, "sizeBytes": pin.size_bytes, "requiredAssetIds": V12.data.requiredAssetIds}
	assert(Adapter.descriptor_error(descriptor).is_empty())
	assert(adapter._release_index_error(current, descriptor).is_empty())
	var old := Index.by_id(previous)
	var changed := 0
	for asset: Dictionary in current.assets:
		if asset == old[asset.asset_id]: continue
		assert(asset.asset_id == "pokemon_3d:hawlucha:mega" and asset.version == 3)
		changed += 1
		for appearance: Dictionary in asset.appearances:
			var identity: String = appearance.runtime_identity
			var model: Dictionary = Reviewed.DATA.data.models[identity]
			assert(appearance.runtime_sha256 == model.sha256 and model.profile == "hawlucha-mega")
			assert(not Reviewed.resolve(identity, model.sha256).is_empty())
			assert(not Approval.resolve(identity, model.sha256).is_empty())
			assert(Reviewed.resolve(identity, "0".repeat(64)).is_empty())
			assert(model.revoked_runtime_sha256.size() == 2)
			for digest: String in model.revoked_runtime_sha256:
				assert(Reviewed.resolve(identity, digest).is_empty())
				assert(Approval.resolve(identity, digest).is_empty())
	assert(changed == 1)
	assert(FileAccess.get_file_as_bytes("res://data/approved_3d_release_v12.json") == FileAccess.get_file_as_bytes("res://launcher/data/approved_3d_release_v12.json"))
	assert(FileAccess.get_file_as_bytes("res://scripts/battle/battle_ui/reviewed_model_catalog.json") == FileAccess.get_file_as_bytes("res://launcher/data/reviewed_model_catalog.json"))
	if FileAccess.file_exists("res://release/approved_3d_bundles_v12_r2_receipt.json"):
		assert(Service._v12_publication_verified())
		var service := Service.new()
		root.add_child(service)
		OS.set_environment("POKEAETHER_MODEL_INDEX", ProjectSettings.globalize_path("res://release/approved_3d_bundles_v11_index.json"))
		assert(service._selected_release() == V12.data)
		OS.unset_environment("POKEAETHER_MODEL_INDEX")
		service.queue_free()
		await process_frame
	print("HAWLUCHA_SOURCE_REPAIR_OK variants=2 changed_pairs=1 revoked_revisions=4")
	quit()
