extends SceneTree
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const LauncherPilot = preload("res://launcher/scripts/model_pair_pilot.gd")
const Release = preload("res://launcher/scripts/release_asset_bundles.gd")
const Index = preload("res://launcher/scripts/asset_bundle_index.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Pin = preload("res://data/approved_3d_release_v13.json")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Default editor play uses the current published pin without an opt-in.
	assert(Pilot.production_enabled() and LauncherPilot.production_enabled())
	var service := Service.new()
	assert(service._selected_release() == Pin.data)
	for mode in ["GEOMETRY_TEST", "QUALIFIED_TEST", "CATALOG_TEST", "PILOT"]:
		OS.set_environment("POKEAETHER_SHARED_MODEL_" + mode, "1")
		assert(not Pilot.production_enabled() and not LauncherPilot.production_enabled(), "Explicit diagnostics must retain their catalog selection")
		OS.unset_environment("POKEAETHER_SHARED_MODEL_" + mode)
	assert(Pilot.production_enabled())
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST", "0")
	assert(not Pilot.production_enabled())
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST", "1")
	assert(Pilot.production_enabled() and LauncherPilot.production_enabled())
	assert(Pilot.data_path() == Pilot.PRODUCTION_PATH)
	assert(Pilot.release() == Pin.data and LauncherPilot.release() == Pin.data)
	assert(FileAccess.get_file_as_bytes(Pilot.PRODUCTION_PATH) == FileAccess.get_file_as_bytes("res://launcher/data/approved_3d_bundles_v13_index.json"))
	var compact: Dictionary = load(Pilot.PRODUCTION_PATH).data
	var full := Pilot.catalog()
	assert(compact.catalog_revision == Pin.data.revision)
	assert(compact.production_approved and not compact.prototype_only)
	assert(full == LauncherPilot.catalog())
	assert(full.assets.size() == 1200 and Index.validate(full).is_empty())
	assert(Pilot.expand_index(compact) == full)
	assert(Pilot.release().requiredAssetIds.size() == 1200)
	assert(service._selected_release() == Pin.data)
	var descriptor := {"schema": 1, "kind": Release.DESCRIPTOR_KIND, "revision": Pin.data.revision,
		"url": "https://updates.pokeaether.com/" + str(Pin.data.index.object_key),
		"objectBaseUrl": "https://updates.pokeaether.com", "sha256": Pin.data.index.sha256,
		"sizeBytes": Pin.data.index.size_bytes, "requiredAssetIds": Pin.data.requiredAssetIds}
	assert(Release.descriptor_error(descriptor).is_empty())
	var pcks := 0
	var appearances := 0
	for asset: Dictionary in full.assets:
		if asset.get("format") != "model-pair-pck-v1":
			continue
		pcks += 1
		for appearance: Dictionary in asset.appearances:
			assert(Pilot.asset_for(appearance.runtime_identity, appearance.runtime_sha256) == asset)
			assert(not Reviewed.resolve(appearance.runtime_identity, appearance.runtime_sha256).is_empty())
			appearances += 1
	var forged := compact.duplicate(true)
	for row: Dictionary in forged.assets:
		if row.get("format") == "model-pair-ref-v1":
			row.sha256 = "0".repeat(64)
			break
	assert(Pilot.expand_index(forged).is_empty())
	assert(pcks == 1145 and appearances == 2290)
	service.free()
	OS.unset_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST")
	print("SHARED_GEOMETRY_PRODUCTION_BINDING_OK pairs=1200 shared=", pcks, " appearances=", appearances)
	quit()
