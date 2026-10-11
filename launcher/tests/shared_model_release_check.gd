extends SceneTree
const Service = preload("res://scripts/release_asset_bundles.gd")
const Pilot = preload("res://scripts/model_pair_pilot.gd")
const Bulk = preload("res://scripts/bulk_asset_downloads.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1)
	OS.set_environment("POKEAETHER_SHARED_MODEL_PILOT", "1")
	var release := Pilot.release()
	var descriptor := {"schema": 1, "kind": "pokeaether-release-asset-index", "revision": release.revision,
		"url": "http://127.0.0.1/" + str(release.index.object_key), "objectBaseUrl": "http://127.0.0.1",
		"sha256": release.index.sha256, "sizeBytes": release.index.size_bytes, "requiredAssetIds": release.requiredAssetIds}
	assert(Service.descriptor_error(descriptor).is_empty())
	var index: Dictionary = Pilot.DATA.data
	var directory := "user://shared-release-check-" + str(Time.get_ticks_usec())
	var service := Service.new(directory.path_join("store"), directory.path_join("indexes"))
	assert(service._release_index_error(index, descriptor).is_empty())
	var result := service.accept_index(descriptor, "res://data/model_pair_pilot.json", true)
	assert(result.error.is_empty() and result.jobs.size() == 17)
	assert(result.jobs.filter(func(job: Dictionary): return str(job.file_name).ends_with(".pck")).size() == 16)
	var first: Dictionary = index.assets[0]
	assert(service.accept_bundle(index, first.asset_id, args[0].path_join(str(first.object_key).get_file())).error.is_empty())
	assert(service.jobs(descriptor, true).jobs.size() == 16)
	assert(not service.store.catalog_path_for_launch().is_empty())
	var entries := {}
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(service.store.catalog_path_for_launch())):
		entries[str(row.species) + ("@shiny" if row.variant == "shiny" else "")] = row
	assert(Bulk._available(first, entries))
	entries[str(first.appearances[0].runtime_identity)].runtime_path = "res://unqualified.scn"
	assert(not Bulk._available(first, entries), "Bulk planning cannot trust a forged virtual scene path")
	var invalid := index.duplicate(true)
	invalid.assets[0].appearances[0].runtime_sha256 = "0".repeat(64)
	assert(not service._release_index_error(invalid, descriptor).is_empty())
	OS.unset_environment("POKEAETHER_SHARED_MODEL_PILOT")
	assert(not Service.descriptor_error(descriptor).is_empty())
	print("SHARED_MODEL_RELEASE_CHECK_OK pinned_descriptor=true pck_jobs=16 legacy_dependency=1 restart=true unqualified_rejected=true disabled_by_default=true")
	quit()
