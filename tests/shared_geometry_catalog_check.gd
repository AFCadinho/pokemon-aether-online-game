extends SceneTree
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Index = preload("res://launcher/scripts/asset_bundle_index.gd")
const Helpers = [preload("res://scripts/battle/animations/gliscor_flight.gd"), preload("res://scripts/battle/animations/mega_garchomp_standing.gd"), preload("res://scripts/battle/animations/charmander_breath.gd"), preload("res://scripts/battle/animations/reviewed_source_visibility.gd")]
class Sink extends Logger:
	var tree: SceneTree
	func _log_error(_fn: String, _file: String, _line: int, _code: String, _why: String, _notify: bool, kind: int, _trace: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING: tree.call_deferred("quit", 2)
var sink := Sink.new()
func _init() -> void:
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST", "0")
	sink.tree = self; OS.add_logger(sink)
	_run.call_deferred()
func _run() -> void:
	for name in ["GEOMETRY_TEST", "QUALIFIED_TEST", "CATALOG_TEST", "PILOT"]:
		OS.unset_environment("POKEAETHER_SHARED_MODEL_" + name)
	assert(not Pilot.enabled() and Pilot._geometry_catalog.is_empty())
	var draft: Dictionary = load(Pilot.GEOMETRY_CATALOG_PATH).data
	assert(not draft.assets.is_empty())
	OS.set_environment("POKEAETHER_SHARED_MODEL_GEOMETRY_TEST", "1")
	var threads: Array[Thread] = []
	for lane in 4:
		var thread := Thread.new()
		assert(thread.start(_cold_lookup.bind(draft.assets[lane % draft.assets.size()])) == OK)
		threads.append(thread)
	var deadline := Time.get_ticks_msec() + 30000
	while threads.any(func(thread: Thread): return thread.is_alive()):
		assert(Time.get_ticks_msec() < deadline, "Concurrent geometry catalog lookup timed out")
		await create_timer(0.01).timeout
	for thread in threads: assert(thread.wait_to_finish())
	var catalog := Pilot.catalog()
	assert(catalog.assets.size() == 1200 and catalog.prototype_only and not catalog.production_approved)
	assert(Index.validate(catalog).is_empty())
	assert(Pilot.release().requiredAssetIds.size() == 1200)
	var checked := 0
	var corrections := 0
	for asset: Dictionary in draft.assets:
		assert(asset.pair_manifest.schema == 2 and Pair.metadata_error(asset).is_empty())
		for appearance: Dictionary in asset.appearances:
			var identity: String = appearance.runtime_identity
			var digest: String = appearance.runtime_sha256
			var source: String = appearance.source_sha256
			OS.unset_environment("POKEAETHER_SHARED_MODEL_GEOMETRY_TEST")
			assert(Reviewed.resolve(identity, digest).is_empty())
			var original := Reviewed.resolve(identity, source)
			assert(not original.is_empty())
			OS.set_environment("POKEAETHER_SHARED_MODEL_GEOMETRY_TEST", "1")
			var candidate := Reviewed.resolve(identity, digest)
			assert(not candidate.is_empty())
			for field in ["grounding", "motion"]:
				if candidate.get(field) is Dictionary:
					assert(candidate[field].sha256 == digest)
					candidate[field].sha256 = source
			assert(candidate == original, "Reviewed profile changed: " + identity)
			assert(Pair.budget(asset, appearance.variant) >= candidate.cache_source_bytes)
			for helper in Helpers:
				assert(helper.matches(identity, digest) == helper.matches(identity, source))
				corrections += int(helper.matches(identity, source))
			assert(Pilot.source_digest(identity, digest) == source)
			var forged := Pilot.asset_for(identity, digest)
			assert(forged == asset)
			forged.appearances[0].source_sha256 = "0".repeat(64)
			assert(Pilot.asset_for(identity, digest) == asset)
			assert(Pilot.asset_for(identity, "0".repeat(64)).is_empty())
			checked += 1
	for path in [Pilot.GEOMETRY_PATH, Pilot.GEOMETRY_CATALOG_PATH]:
		assert(FileAccess.get_file_as_bytes(path) == FileAccess.get_file_as_bytes(path.replace("res://data/", "res://launcher/data/")))
	OS.unset_environment("POKEAETHER_SHARED_MODEL_GEOMETRY_TEST")
	assert(Pilot.release().is_empty())
	OS.set_environment("POKEAETHER_SHARED_MODEL_QUALIFIED_TEST", "1")
	assert(Pilot.data_path() == Pilot.QUALIFIED_PATH and Pilot.catalog().assets.size() == 1200)
	print("SHARED_GEOMETRY_CATALOG_OK appearances=", checked, " corrections=", corrections, " legacy_collection=true explicit_legacy_override=true")
	quit()

func _cold_lookup(asset: Dictionary) -> bool:
	if Pilot.release().requiredAssetIds.size() != 1200: return false
	var appearance: Dictionary = asset.appearances[0]
	return Pilot.asset_for(appearance.runtime_identity, appearance.runtime_sha256) == asset
