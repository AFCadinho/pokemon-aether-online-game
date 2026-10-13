extends SceneTree
## Real data-only pack: fresh proof, cold post-load verification and warm RAM reuse.
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")

class ErrorSink extends Logger:
	var tree: SceneTree
	func _log_error(_fn: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _trace: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			printerr("SHARED_HANDOFF_ABORT ", code, " ", rationale)
			tree.call_deferred("quit", 2)
var sink := ErrorSink.new()

func _init() -> void:
	sink.tree = self
	OS.add_logger(sink)
	_run.call_deferred()

func _run() -> void:
	# Finish autoload storage workers before replacing this process's trusted
	# offline cohort. Production never mutates these bindings at runtime.
	var original := root.get_node("OnDemand3DBundleService")
	root.remove_child(original)
	root.get_node("SettingsManager").battle_presentation_mode = "3d"
	var directory := OS.get_environment("POKEAETHER_HANDOFF_FIXTURE")
	assert(directory.is_absolute_path())
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("runtime-fixture.json")))
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("shared/index.json")))
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST", "0")
	OS.set_environment("POKEAETHER_SHARED_MODEL_CATALOG_TEST", "1")
	Pilot.catalog()
	Pilot._catalog = index
	Pilot._lookups.clear()
	Registry.DATA.data.models.merge(fixture.models, true)
	Registry.DATA.data.profiles.merge(fixture.profiles, true)
	var asset: Dictionary = index.assets[0]
	var object_root := directory.path_join("shared/validated/objects").path_join(str(asset.sha256))
	var rows := Pair.catalog_entries(asset, object_root)
	var catalog := ProjectSettings.globalize_path("user://shared-handoff-check.json")
	var file := FileAccess.open(catalog, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows))
	file.close()
	var service := Service.new()
	var index_path := directory.path_join("shared/index.json")
	var index_pin := {"revision": index.catalog_revision, "index": {
		"size_bytes": FileAccess.open(index_path, FileAccess.READ).get_length(),
		"sha256": FileAccess.get_sha256(index_path)}}
	var subset: Array[String] = [str(asset.asset_id)]
	var full: Dictionary = service._read_local_index(index_path, index_pin)
	var selected: Dictionary = service._read_local_index(index_path, index_pin, subset)
	assert(selected.assets.size() == 1 and selected.assets[0] == full.assets[0])
	index_pin.index.sha256 = "0".repeat(64)
	assert(service._read_local_index(index_path, index_pin, subset).is_empty())
	Cache.clear()
	for cycle in 2:
		var stage := Stage.new()
		root.add_child(stage)
		stage.set_process(false)
		stage.set_combatant(0, str(rows[0].species), rows[0].variant == "shiny")
		stage.set_combatant(1, str(rows[1].species), rows[1].variant == "shiny")
		stage._load_catalog(catalog)
		assert(stage.catalog_entries.size() >= 2)
		for row: Dictionary in rows:
			var identity := Registry.entry_key(row)
			var proof: Dictionary = service._verified_entry(rows, identity, str(row.runtime_sha256))
			assert(proof.has("pair_check") and proof.pair_check.error.is_empty())
			stage.download_verified_files[identity] = proof
		# Catalog metadata and mismatched receipts cannot supply admission.
		var identity := Registry.entry_key(rows[0])
		for field in ["path", "pack_sha256", "bytes", "pair_check"]:
			var valid: Dictionary = stage.download_verified_files[identity].duplicate(true)
			var invalid := valid.duplicate(true)
			invalid[field] = {} if field == "pair_check" else (0 if field == "bytes" else "wrong")
			stage.download_verified_files[identity] = invalid
			var entry: Dictionary = stage.catalog_entries[identity].duplicate(true)
			stage._reuse_checked_pair(entry)
			assert(not entry.has("_verified_runtime_hash"), "Reject mismatched " + field)
			stage.download_verified_files[identity] = valid
		stage._queue_needed_models()
		var deadline := Time.get_ticks_msec() + 30000
		var post_load_checks := 0
		var last_job: Object
		while stage._models_pending():
			stage._import_next_model()
			if stage.integrity_read != null and stage.integrity_read != last_job:
				assert(stage.loading_scene != null, "Fresh handoff replaces only the before-load check")
				last_job = stage.integrity_read
				post_load_checks += 1
			assert(Time.get_ticks_msec() < deadline, stage.catalog_problem)
			await process_frame
		assert(stage.packed.size() == 2 and stage.verified_pair_handoff_hits == 2)
		assert(stage.model_cache_hits == (0 if cycle == 0 else 2))
		assert(post_load_checks == (2 if cycle == 0 else 0), "Cold imports still inspect after loading; warm scenes require no duplicate reads")
		assert(stage.verified_model_cache_hits == (0 if cycle == 0 else 2))
		stage.free()
	Cache.clear()
	service.free()
	original.free()
	DirAccess.remove_absolute(catalog)
	print("SHARED_MODEL_HANDOFF_PASS real_pack=true normal_shiny=true mismatched_receipts_rejected=true cold_post_load_checks=true warm_ram_reuse=true")
	quit()
