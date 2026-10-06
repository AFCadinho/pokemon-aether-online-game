extends SceneTree
## Real compiled v10/v11 pins and model admission, not generated future pins.
const Adapter = preload("res://launcher/scripts/release_asset_bundles.gd")
const Bulk = preload("res://launcher/scripts/bulk_asset_downloads.gd")
const Index = preload("res://launcher/scripts/asset_bundle_index.gd")
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const V10 = preload("res://data/approved_3d_release_v10.json")
const V11 = preload("res://data/approved_3d_release_v11.json")

class ErrorSink extends Logger:
	var tree: SceneTree
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, _kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		print("V11_BINDING_CHECK_FAILED ", code, " ", rationale)
		tree.call_deferred("quit", 2)

var sink := ErrorSink.new()

func _init() -> void:
	sink.tree = self
	OS.add_logger(sink)
	_run.call_deferred()

func descriptor(release: Dictionary) -> Dictionary:
	var pin: Dictionary = release.index
	return {"schema": 1, "kind": "pokeaether-release-asset-index", "revision": release.revision,
		"url": "http://127.0.0.1/" + str(pin.object_key), "objectBaseUrl": "http://127.0.0.1",
		"sha256": pin.sha256, "sizeBytes": pin.size_bytes, "requiredAssetIds": release.requiredAssetIds.duplicate()}

func _run() -> void:
	var old_path := ProjectSettings.globalize_path("res://release/approved_3d_bundles_v10_index.json")
	var new_path := ProjectSettings.globalize_path("res://release/approved_3d_bundles_v11_index.json")
	assert(FileAccess.get_sha256(old_path) == V10.data.index.sha256)
	assert(FileAccess.get_sha256(new_path) == V11.data.index.sha256)
	assert(V11.data.index.size_bytes < 1048576)
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(old_path))
	var newer: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(new_path))
	assert(Index.validate(newer).is_empty())
	assert(old.assets.size() == 1200 and newer.assets.size() == 1200)
	assert(V10.data.requiredAssetIds == V11.data.requiredAssetIds)
	var test_root := OS.get_environment("LOSSLESS_CHECK_OUTPUT")
	if test_root.is_empty():
		test_root = "user://binding-" + str(Time.get_ticks_usec()) + "-" + str(randi())
	var adapter := Adapter.new(test_root.path_join("store"), test_root.path_join("indexes"))
	assert(adapter.store.active_generation().is_empty(), "A fresh test installation is required")
	for pair: Array in [[V10.data, old, old_path], [V11.data, newer, new_path]]:
		var pin := descriptor(pair[0])
		assert(Adapter.descriptor_error(pin).is_empty())
		assert(adapter.accept_index(pin, pair[2], false).error.is_empty())
		assert(adapter._release_index_error(pair[1], pin).is_empty())
		assert(adapter.jobs(pin, true).jobs.size() == 1200)
	var mixed := descriptor(V11.data)
	mixed.sha256 = V10.data.index.sha256
	assert(not Adapter.descriptor_error(mixed).is_empty())
	mixed = descriptor(V11.data)
	mixed.requiredAssetIds.remove_at(0)
	assert(not Adapter.descriptor_error(mixed).is_empty())
	var bad: Dictionary = newer.duplicate(true)
	bad.assets[0].appearances[0].runtime_sha256 = "0".repeat(64)
	assert(not adapter._release_index_error(bad, descriptor(V11.data)).is_empty())
	var by_old := Index.by_id(old)
	var by_new := Index.by_id(newer)
	var count := 0
	for asset_id: String in V11.data.requiredAssetIds:
		var previous: Dictionary = by_old[asset_id]
		var current: Dictionary = by_new[asset_id]
		for appearance: Dictionary in current.appearances:
			var identity: String = appearance.runtime_identity
			var previous_hash := ""
			for entry: Dictionary in previous.appearances:
				if entry.runtime_identity == identity:
					previous_hash = entry.runtime_sha256
			var a := Reviewed.resolve(identity, previous_hash)
			var b := Reviewed.resolve(identity, appearance.runtime_sha256)
			assert(not a.is_empty() and not b.is_empty())
			assert(Reviewed.resolve(identity, "0".repeat(64)).is_empty())
			for profile: Dictionary in [a, b]:
				for property: String in ["grounding", "motion"]:
					if profile.get(property) is Dictionary:
						profile[property].erase("sha256")
			assert(a == b, "Lossless revisions must preserve the reviewed profile: " + identity)
			count += 1
	assert(count == 2400)
	var service := Service.new()
	root.add_child(service)
	OS.set_environment("POKEAETHER_MODEL_INDEX", new_path)
	assert(service._selected_release().revision == V11.data.revision)
	var local: Dictionary = await service._approved_index()
	assert(local.error.is_empty() and local.index == newer)
	OS.set_environment("POKEAETHER_MODEL_INDEX", old_path)
	assert(service._selected_release().revision == V10.data.revision)
	OS.set_environment("POKEAETHER_MODEL_INDEX", new_path)
	var report_path := OS.get_environment("LOSSLESS_PREPARATION_REPORT")
	if report_path.is_empty():
		OS.unset_environment("POKEAETHER_MODEL_INDEX")
		service.queue_free()
		print("APPROVED_3D_V11_METADATA_OK appearances=2400 profiles_equal=true old_new_pins=true")
		quit()
		return
	assert(report_path.is_absolute_path())
	var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	var sample := {}
	var originals := {}
	var ids: Array[String] = []
	var names: Array[String] = ["gliscor", "charmander", "garchomp", "dragonite", "roaring-moon", "floragato", "grimmsnarl", "maushold", "marshadow", "toucannon", "arcanine-hisui"]
	for row: Dictionary in receipt.assets:
		if row.candidate_asset.species_id not in names:
			continue
		if row.candidate_asset.species_id == "garchomp" and row.candidate_asset.form_id != "mega":
			continue
		if row.candidate_asset.species_id == "dragonite" and row.candidate_asset.form_id != "base":
			continue
		var id: String = row.asset_id
		ids.append(id)
		sample[id] = row.candidate_archive
		originals[id] = row.source_archive
	assert(ids.size() == 11)
	var old_install: Dictionary = adapter.accept_bundles(old, originals)
	assert(old_install.error.is_empty(), str(old_install.error))
	var old_generation: String = adapter.store.active_generation()
	# A newer selected index must replace the old encoding even though that old
	# digest remains approved for compatible v10 installs and rollback.
	assert(service._installed_models(["gliscor"], adapter.catalog_path()).is_empty())
	OS.set_environment("POKEAETHER_MODEL_INDEX", old_path)
	assert(not service._installed_models(["gliscor"], adapter.catalog_path()).is_empty())
	OS.set_environment("POKEAETHER_MODEL_INDEX", new_path)
	var update: Dictionary = Bulk.models_plan(adapter, descriptor(V11.data))
	assert(update.error.is_empty() and update.jobs.size() == 1199, "Only the unchanged installed Toucannon bundle is reused")
	var install: Dictionary = adapter.accept_bundles(newer, sample)
	assert(install.error.is_empty(), str(install.error))
	assert(adapter.store.active_generation() != old_generation)
	var ready: Dictionary = adapter.store.plan(newer, ids)
	assert(ready.error.is_empty() and ready.downloads.is_empty())
	var restarted := Adapter.new(adapter.store.root, adapter.index_root)
	assert(restarted.store.plan(newer, ids).downloads.is_empty())
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(adapter.catalog_path()))
	assert(entries.size() == 22)
	var identities: Array[String] = []
	for entry: Dictionary in entries:
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		assert(ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
		identities.append(str(entry.species) + ("@shiny" if entry.variant == "shiny" else ""))
	var cached: Dictionary = await service.ensure_models(identities, adapter.catalog_path())
	assert(cached.error.is_empty() and not cached.catalog_changed and service.active_request == null)
	# Exercise the separate on-demand extractor using the real current approvals.
	var source_id := "pokemon_3d:gliscor:base"
	var extracted: Dictionary = service._unpack_asset(by_new[source_id], sample[source_id])
	assert(extracted.error.is_empty() and extracted.entries.size() == 2)
	var rollback: Dictionary = adapter.accept_bundles(old, originals)
	assert(rollback.error.is_empty())
	assert(adapter.store.active_generation() == old_generation)
	assert(adapter.store.plan(old, ids).downloads.is_empty())
	OS.unset_environment("POKEAETHER_MODEL_INDEX")
	service.queue_free()
	print("APPROVED_3D_V11_BINDING_OK appearances=2400 profiles_equal=true sample_installed=22 old_new_pins=true cached_on_demand=true rollback=true")
	quit()
