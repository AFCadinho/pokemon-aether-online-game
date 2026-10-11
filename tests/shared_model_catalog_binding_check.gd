extends SceneTree
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const Index = preload("res://launcher/scripts/asset_bundle_index.gd")
const Flight = preload("res://scripts/battle/animations/gliscor_flight.gd")
const Standing = preload("res://scripts/battle/animations/mega_garchomp_standing.gd")
const Breath = preload("res://scripts/battle/animations/charmander_breath.gd")
const Visibility = preload("res://scripts/battle/animations/reviewed_source_visibility.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	OS.unset_environment("POKEAETHER_SHARED_MODEL_PILOT")
	OS.unset_environment("POKEAETHER_SHARED_MODEL_CATALOG_TEST")
	assert(not Pilot.enabled() and Pilot._catalog.is_empty(), "Disabled catalog must not allocate the full index")
	var catalog: Dictionary = load(Pilot.CATALOG_PATH).data
	assert(catalog.assets.size() == 1200 and catalog.prototype_only and not catalog.production_approved)
	assert(Index.validate(catalog).is_empty())
	OS.set_environment("POKEAETHER_SHARED_MODEL_CATALOG_TEST", "1")
	assert(Pilot.release().requiredAssetIds.size() == 1200)
	# Start with a cold lookup: release and simultaneous first model requests
	# must finish, and one caller's copy must never alter another's binding.
	assert(Pilot._lookups.is_empty())
	var threads: Array[Thread] = []
	for lane in range(4):
		var thread := Thread.new()
		assert(thread.start(_concurrent_lookup.bind(lane)) == OK)
		threads.append(thread)
	var deadline := Time.get_ticks_msec() + 30000
	while threads.any(func(thread: Thread) -> bool: return thread.is_alive()):
		if Time.get_ticks_msec() >= deadline:
			push_error("Concurrent catalog lookup timed out")
			quit(1)
			return
		await create_timer(0.01).timeout
	var concurrent_checked := 0
	for thread in threads:
		var result: Dictionary = thread.wait_to_finish()
		assert(result.error.is_empty(), str(result.error))
		concurrent_checked += int(result.checked)
	assert(concurrent_checked == 2168)
	var checked := 0
	var corrections := 0
	for asset: Dictionary in catalog.assets:
		if asset.get("format") != Pair.FORMAT:
			continue
		for appearance: Dictionary in asset.appearances:
			var identity: String = appearance.runtime_identity
			var digest: String = appearance.runtime_sha256
			var source: String = appearance.source_sha256
			OS.unset_environment("POKEAETHER_SHARED_MODEL_CATALOG_TEST")
			assert(Reviewed.resolve(identity, digest).is_empty())
			var original := Reviewed.resolve(identity, source)
			assert(not original.is_empty())
			OS.set_environment("POKEAETHER_SHARED_MODEL_CATALOG_TEST", "1")
			var candidate := Reviewed.resolve(identity, digest)
			assert(not candidate.is_empty())
			for field in ["grounding", "motion"]:
				if candidate.get(field) is Dictionary:
					assert(candidate[field].sha256 == digest)
					candidate[field].sha256 = source
			assert(candidate == original, "Placement, motion, routing, timing or cache cost changed: " + identity)
			assert(int(candidate.cache_source_bytes) == int(appearance.cache_source_bytes))
			assert(Pair.budget(asset, str(appearance.variant)) >= int(candidate.cache_source_bytes))
			for helper in [Flight, Standing, Breath, Visibility]:
				assert(helper.matches(identity, digest) == helper.matches(identity, source))
				if helper.matches(identity, source):
					corrections += 1
				assert(not helper.matches(identity, "0".repeat(64)))
			assert(Pilot.source_digest(identity, digest) == source)
			assert(Pilot.asset_for(identity + "-unknown", digest).is_empty())
			assert(Reviewed.resolve(identity, "0".repeat(64)).is_empty())
			var altered := Pilot.asset_for(identity, digest)
			altered.appearances[0].source_sha256 = "0".repeat(64)
			assert(Pilot.asset_for(identity, digest) == asset, "Caller mutated trusted bindings")
			var entry := {"species": identity.trim_suffix("@shiny"), "variant": appearance.variant,
				"runtime_sha256": digest, "runtime_path": str(asset.pair_manifest.resource_root).path_join(appearance.runtime_path),
				"bytes": appearance.bytes, "pair_asset": asset, "pack_path": "/local-test.pck"}
			assert(Pilot.entry_asset(entry) == asset)
			entry.pair_asset = altered
			assert(Pilot.entry_asset(entry).is_empty(), "External catalog supplied a source binding")
			checked += 1
	assert(checked == 2168 and corrections == 16)
	OS.unset_environment("POKEAETHER_SHARED_MODEL_CATALOG_TEST")
	OS.set_environment("POKEAETHER_SHARED_MODEL_PILOT", "1")
	assert(Pilot.catalog() == Pilot.DATA.data and Pilot.release().requiredAssetIds.size() == 17)
	OS.unset_environment("POKEAETHER_SHARED_MODEL_PILOT")
	assert(Pilot.release().is_empty())
	assert(FileAccess.get_file_as_bytes(Pilot.CATALOG_PATH) == FileAccess.get_file_as_bytes("res://launcher/data/model_pair_catalog.json"))
	assert(FileAccess.get_file_as_bytes("res://scripts/services/model_pair_pilot.gd") == FileAccess.get_file_as_bytes("res://launcher/scripts/model_pair_pilot.gd"))
	print("SHARED_MODEL_CATALOG_BINDING_CHECK_OK appearances=", checked, " corrections=", corrections, " concurrent_lookups=", concurrent_checked, " defaults_and_forged_bindings_rejected=true")
	quit()

func _concurrent_lookup(lane: int) -> Dictionary:
	var checked := 0
	if Pilot.release().requiredAssetIds.size() != 1200:
		return {"error": "Concurrent release descriptor changed", "checked": checked}
	var assets: Array = Pilot.catalog().assets
	for index in range(lane, assets.size(), 4):
		var asset: Dictionary = assets[index]
		if asset.get("format") != Pair.FORMAT:
			continue
		for appearance: Dictionary in asset.appearances:
			var identity: String = appearance.runtime_identity
			var digest: String = appearance.runtime_sha256
			if Pilot.asset_for(identity, digest) != asset or Pilot.source_digest(identity, digest) != appearance.source_sha256:
				return {"error": "Concurrent binding changed: " + identity, "checked": checked}
			var copy := Pilot.asset_for(identity, digest)
			copy.appearances[0].source_sha256 = "0".repeat(64)
			if Pilot.asset_for(identity, digest) != asset:
				return {"error": "Concurrent caller mutated binding: " + identity, "checked": checked}
			checked += 1
	return {"error": "", "checked": checked}
