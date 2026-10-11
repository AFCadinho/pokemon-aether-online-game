extends SceneTree
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const Release = preload("res://launcher/scripts/release_asset_bundles.gd")
const Bulk = preload("res://launcher/scripts/bulk_asset_downloads.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Store = preload("res://launcher/scripts/asset_bundle_store.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1)
	OS.set_environment("POKEAETHER_SHARED_MODEL_QUALIFIED_TEST", "1")
	var installed := Store.new(args[0].path_join("fresh/store"))
	var catalog := installed.catalog_path_for_launch()
	assert(not catalog.is_empty())
	var pin := Pilot.release()
	var descriptor := {"schema": 1, "kind": Release.DESCRIPTOR_KIND, "revision": pin.revision,
		"url": "http://127.0.0.1/" + pin.index.object_key, "objectBaseUrl": "http://127.0.0.1",
		"sha256": pin.index.sha256, "sizeBytes": pin.index.size_bytes, "requiredAssetIds": pin.requiredAssetIds}
	# An empty launcher store must reuse the entire physical game catalog.
	var borrower := Release.new(args[0].path_join("consumer/empty-store"), args[0].path_join("fresh/indexes"))
	var plan := Bulk.models_plan(borrower, descriptor, catalog)
	assert(plan.error.is_empty() and plan.jobs.is_empty() and plan.available == 1200)
	var service := Service.new()
	var identities: Array[String] = []
	for asset: Dictionary in Pilot.catalog().assets:
		for appearance: Dictionary in asset.appearances:
			identities.append(str(appearance.runtime_identity))
	var ready := service._installed_models(identities, catalog)
	assert(ready.get("error", "missing").is_empty() and ready.path == catalog and ready.verified_models.size() == 2400)
	assert(service.active_request == null)
	service.free()
	var output := FileAccess.open(args[0].path_join("consumers.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"schema": 1, "ok": true, "bulk_available": plan.available,
		"on_demand_appearances": ready.verified_models.size(), "network_requests": 0,
		"catalog_sha256": FileAccess.get_sha256(catalog), "os": OS.get_name(), "godot": Engine.get_version_info().string}) + "\n")
	output.close()
	print("SHARED_MODEL_COLLECTION_CONSUMER_CHECK_OK bulk_reused=1200 on_demand_verified=2400 network_requests=0")
	quit()
