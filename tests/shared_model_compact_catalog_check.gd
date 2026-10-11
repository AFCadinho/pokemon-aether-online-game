extends SceneTree
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const LauncherPilot = preload("res://launcher/scripts/model_pair_pilot.gd")
const Store = preload("res://launcher/scripts/asset_bundle_store.gd")
const Release = preload("res://launcher/scripts/release_asset_bundles.gd")
const Index = preload("res://launcher/scripts/asset_bundle_index.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	OS.unset_environment("POKEAETHER_SHARED_MODEL_PILOT")
	OS.unset_environment("POKEAETHER_SHARED_MODEL_CATALOG_TEST")
	OS.unset_environment("POKEAETHER_SHARED_MODEL_QUALIFIED_TEST")
	var wire: Dictionary = load(Pilot.QUALIFIED_PATH).data
	assert(Pilot.expand_index(wire).is_empty())
	OS.set_environment("POKEAETHER_SHARED_MODEL_QUALIFIED_TEST", "1")
	var index := Pilot.catalog()
	assert(index == LauncherPilot.catalog() and Index.validate(index).is_empty())
	assert(Pilot.expand_index(wire) == index and index.assets.size() == 1200)
	var store := Store.new("user://compact-metadata-check-" + str(Time.get_ticks_usec()))
	var state := store._empty_state(index.catalog_revision)
	var pairs := 0
	for asset: Dictionary in index.assets:
		var manifest: Dictionary = asset.get("pair_manifest", asset).duplicate(true)
		if asset.get("format") != "model-pair-pck-v1":
			for appearance: Dictionary in manifest.appearances:
				appearance["runtime_path"] = "models/" + str(appearance.variant) + ".scn"
				appearance["bytes"] = 1 # Synthetic legacy metadata; physical test reads real ZIP manifest.
		state.assets[asset.asset_id] = store._state_entry(asset, manifest)
		if asset.get("format") == "model-pair-pck-v1":
			pairs += 1
		if asset.asset_id in ["pokemon_3d:greninja:base", "pokemon_3d:inkay:base"]:
			assert(asset.get("format", "zip") == "zip")
	assert(pairs == 1082)
	var entries := store._runtime_catalog(state)
	var compact := Pilot.compact_entries(entries)
	assert(entries.size() == 2400 and not entries[0].has("pair_ref"))
	assert(Pilot.expand_entries(compact.duplicate(true)) == entries)
	assert(LauncherPilot.expand_entries(compact.duplicate(true)) == entries)
	assert(Pilot.expand_state(Pilot.compact_state(state)) == state)
	var state_bytes := JSON.stringify(Pilot.compact_state(state)).to_utf8_buffer().size()
	var catalog_bytes := JSON.stringify(compact).to_utf8_buffer().size()
	assert(state_bytes < Store.MAX_STATE_JSON and catalog_bytes < Service.MAX_CATALOG_BYTES)
	var pin := Pilot.release()
	var descriptor := {"schema": 1, "kind": Release.DESCRIPTOR_KIND, "revision": pin.revision,
		"url": "http://127.0.0.1/" + pin.index.object_key, "objectBaseUrl": "http://127.0.0.1",
		"sha256": pin.index.sha256, "sizeBytes": pin.index.size_bytes, "requiredAssetIds": pin.requiredAssetIds}
	assert(pin.index.size_bytes < Store.MAX_JSON and Release.descriptor_error(descriptor).is_empty())
	var adapter := Release.new("user://compact-release-" + str(Time.get_ticks_usec()), "user://compact-index-" + str(Time.get_ticks_usec()))
	var accepted := adapter.accept_index(descriptor, Pilot.QUALIFIED_PATH, false)
	assert(accepted.error.is_empty() and adapter.cached_index(descriptor) == index)
	var service := Service.new()
	assert(service._read_local_index(Pilot.QUALIFIED_PATH, pin) == index)
	for field in ["sha256", "asset_id", "extra"]:
		var bad := wire.duplicate(true)
		bad.assets[0][field] = "invalid"
		assert(Pilot.expand_index(bad).is_empty())
	var held: Dictionary = load(Pilot.CATALOG_PATH).data.assets.filter(func(a: Dictionary): return a.asset_id == "pokemon_3d:greninja:base")[0]
	var bad := wire.duplicate(true)
	bad.assets[0] = {"format": Pilot.REFERENCE_FORMAT, "asset_id": held.asset_id, "sha256": held.sha256}
	assert(Pilot.expand_index(bad).is_empty(), "A held candidate cannot enter the qualified set")
	for field in ["sha256", "asset_id", "extra"]:
		var corrupt := compact.duplicate(true)
		corrupt[0].pair_ref[field] = "invalid"
		assert(Pilot.expand_entries(corrupt).is_empty())
	var ambiguous := compact.duplicate(true)
	ambiguous[0].pair_asset = entries[0].pair_asset
	assert(Pilot.expand_entries(ambiguous).is_empty())
	# A compact reference supplies metadata, never a replacement for path/hash validation.
	var forged := compact.duplicate(true)
	forged[0].runtime_path = "res://unapproved.scn"
	assert(Pilot.entry_asset(Pilot.expand_entries(forged)[0]).is_empty())
	# Empty installed states still require an actual, valid array catalog.
	assert(store._write_generation(store._empty_state("empty-test")).is_empty())
	var empty_catalog := store.catalog_path()
	var empty_generation := empty_catalog.get_base_dir().get_file()
	for invalid in [{}, [{"pair_ref": {"asset_id": "unknown", "sha256": "0".repeat(64)}}]]:
		assert(store._write_text(empty_catalog, JSON.stringify(invalid)) == OK)
		assert(not store._validate_generation_metadata(empty_generation))
	assert(store._write_text(empty_catalog, "[]") == OK)
	assert(store._validate_generation_metadata(empty_generation))
	OS.unset_environment("POKEAETHER_SHARED_MODEL_QUALIFIED_TEST")
	assert(Pilot.expand_entries(compact).is_empty())
	assert(not Release.descriptor_error(descriptor).is_empty())
	service.free()
	print("SHARED_MODEL_COMPACT_CATALOG_CHECK_OK pairs=", pairs, " appearances=", entries.size(),
		" index_bytes=", pin.index.size_bytes, " state_bytes=", state_bytes, " runtime_bytes=", catalog_bytes)
	quit()
