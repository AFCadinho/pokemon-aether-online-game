extends SceneTree
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
var output: String

func _init() -> void:
	_run.call_deferred()

func _fixture(name: String, entries: Array) -> String:
	var path := output.path_join(name + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(entries))
	file.close()
	return path

func _run() -> void:
	var path := OS.get_environment("POKEAETHER_PHASE5_RUNTIME_REPORT")
	output = OS.get_environment("POKEAETHER_ADMISSION_TEST_OUTPUT")
	assert(path.is_absolute_path() and output.is_absolute_path() and not DirAccess.dir_exists_absolute(output))
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var raw_catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var catalog: Array = Registry.pack_entries(raw_catalog, path.get_base_dir()) if raw_catalog is Dictionary else raw_catalog
	if raw_catalog is Dictionary:
		for entry: Dictionary in catalog:
			assert(entry.runtime_path.begins_with(path.get_base_dir() + "/models/"))
			assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
			assert(ResourceLoader.get_dependencies(entry.runtime_path).is_empty())
		for bad_path in ["../outside.scn", "/outside.scn", "C:/outside.scn", "models\\outside.scn"]:
			var bad: Dictionary = raw_catalog.duplicate(true)
			bad.entries[0].runtime_path = bad_path
			assert(Registry.pack_entries(bad, path.get_base_dir()).is_empty())
		for field in ["godot", "qualification_sha256", "kind"]:
			var bad: Dictionary = raw_catalog.duplicate(true)
			bad[field] = "invalid"
			assert(Registry.pack_entries(bad, path.get_base_dir()).is_empty())
		for bytes: Variant in [-1, 0, 1.5, true, 134217729, "12"]:
			var bad: Dictionary = raw_catalog.duplicate(true)
			bad.entries[0].bytes = bytes
			assert(Registry.pack_entries(bad, path.get_base_dir()).is_empty())
		var duplicate: Dictionary = raw_catalog.duplicate(true)
		duplicate.entries[1] = duplicate.entries[0].duplicate(true)
		assert(Registry.pack_entries(duplicate, path.get_base_dir()).is_empty())
		print("PORTABLE_MODEL_PACK_OK self_contained=14 unsafe_paths/engine/qualification/size/duplicates rejected")
	assert(catalog.size() == 14 and Registry.DATA.data.models.size() == 14)
	for identity: String in Registry.DATA.data.models:
		var model: Dictionary = Registry.DATA.data.models[identity]
		for digest: String in [model.sha256] + model.get("previous_sha256", []):
			var profile := Registry.resolve(identity, digest)
			assert(not profile.is_empty() and profile.motion.sha256 == digest and profile.grounding.sha256 == digest)
		assert(Registry.resolve(identity, "unapproved").is_empty())
	for species in ["pikachu", "arcanine", "lucario", "snorlax", "articuno", "dragonite", "roaring-moon"]:
		assert(Renderer.supported(species, false, false, false))
		assert(Renderer.supported(species, true, false, false))
		assert(not Renderer.supported(species, false, true, false))
		assert(not Renderer.supported(species, true, false, true))
	for species in ["abra", "onix", "gastly", "arcanine-hisui", "pikachu-rock-star", "missing"]:
		assert(not Renderer.supported(species, false, false, false))
		assert(not Renderer.supported(species, true, false, false))
	assert(Registry.entry_key({"species": "pikachu@shiny", "variant": "normal"}).is_empty())
	var stage := Renderer.new()
	stage._load_catalog(path)
	assert(stage.catalog_entries.size() == 14)
	assert(stage._needed_species().is_empty() and not stage._models_pending())
	var normal: Dictionary = catalog.filter(func(e): return e.species == "pikachu" and e.variant == "normal")[0].duplicate(true)
	var corrupt := normal.duplicate(true)
	corrupt.placement = {"scale": 999, "yaw_degrees": 180}
	corrupt.action_timing = {}
	corrupt["_verified_runtime_hash"] = normal.runtime_sha256
	corrupt["_resource_cache_key"] = "forged"
	corrupt["_source_bytes"] = 1
	corrupt["_review_motion"] = {"clips": {}}
	stage._load_catalog(_fixture("authored-overrides", [corrupt]))
	var admitted: Dictionary = stage.catalog_entries.pikachu
	assert(not admitted.has("_verified_runtime_hash") and not admitted.has("_resource_cache_key"))
	assert(admitted.placement.scale != 999 and not admitted.action_timing.is_empty())
	assert(not stage._motion_profile("pikachu").clips.is_empty())
	stage._load_catalog(_fixture("duplicate", [normal, normal]))
	assert(stage.catalog_entries.is_empty())
	corrupt = normal.duplicate(true)
	corrupt.runtime_sha256 = "unapproved"
	stage._load_catalog(_fixture("unapproved-hash", [corrupt]))
	assert(stage.catalog_entries.is_empty())
	corrupt = normal.duplicate(true)
	corrupt.species = "gastly"
	stage._load_catalog(_fixture("held", [corrupt]))
	assert(stage.catalog_entries.is_empty())
	corrupt = normal.duplicate(true)
	corrupt.runtime_path = output.path_join("missing.scn")
	stage._load_catalog(_fixture("missing", [corrupt]))
	assert(stage.catalog_entries.is_empty())
	# Correct declared approval but different real bytes must fail before import.
	corrupt = normal.duplicate(true)
	corrupt.runtime_path = catalog.filter(func(e): return e.species == "snorlax" and e.variant == "normal")[0].runtime_path
	corrupt["_verified_runtime_hash"] = normal.runtime_sha256
	corrupt["_resource_cache_key"] = "forged"
	stage._load_catalog(_fixture("wrong-file", [corrupt]))
	stage.set_combatant(0, "pikachu")
	var deadline := Time.get_ticks_msec() + 10000
	while stage._models_pending():
		stage._import_next_model()
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	assert(stage.failed_models.has("pikachu") and stage.packed.is_empty())
	assert(stage.catalog_problem.contains("hash mismatch"))
	stage.free()
	print("REVIEWED_MODEL_ADMISSION_OK variants=14 held/forms/duplicates/missing/hash/cache-forgery rejected")
	quit()
