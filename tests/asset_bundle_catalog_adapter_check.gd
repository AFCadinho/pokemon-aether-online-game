extends SceneTree
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var fixture := OS.get_environment("POKEAETHER_ASSET_BUNDLE_LOADER_CATALOG")
	var output := OS.get_environment("POKEAETHER_ASSET_BUNDLE_ADAPTER_OUTPUT")
	assert(fixture.is_absolute_path() and FileAccess.file_exists(fixture))
	assert(output.is_absolute_path() and not DirAccess.dir_exists_absolute(output))
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	assert(parsed is Array and parsed.size() == 6)
	var identities: Array[String] = []
	for entry: Dictionary in parsed:
		var identity := Registry.entry_key(entry)
		identities.append(identity)
		assert(identity in [
			"arcanine", "arcanine@shiny", "dragonite", "dragonite@shiny",
			"roaring-moon", "roaring-moon@shiny",
		])
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		assert(ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
	identities.sort()
	assert(identities == [
		"arcanine", "arcanine@shiny", "dragonite", "dragonite@shiny",
		"roaring-moon", "roaring-moon@shiny",
	])

	# The installed catalog structure is exactly what the production parser
	# consumes. Declare the checked-in approved digests to exercise that adapter;
	# the later byte check must still reject these deliberately tiny fixtures.
	var declared: Array = (parsed as Array).duplicate(true)
	for entry: Dictionary in declared:
		var identity := Registry.entry_key(entry)
		entry.runtime_sha256 = Registry.DATA.data.models[identity].sha256
	var declared_path := output.path_join("declared-approved-catalog.json")
	var declared_file := FileAccess.open(declared_path, FileAccess.WRITE)
	declared_file.store_string(JSON.stringify(declared))
	declared_file.close()
	var stage := Renderer.new()
	stage._load_catalog(declared_path)
	assert(stage.catalog_entries.size() == 6)
	for identity in identities:
		assert(stage.catalog_entries.has(identity))
		assert(not stage.catalog_entries[identity].action_timing.is_empty())
	stage.set_combatant(0, "arcanine")
	var deadline := Time.get_ticks_msec() + 10000
	while stage._models_pending():
		stage._import_next_model()
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	assert(stage.failed_models.has("arcanine"))
	assert(stage.packed.is_empty() and stage.catalog_problem.contains("hash mismatch"))
	stage.free()
	print("ASSET_BUNDLE_CATALOG_ADAPTER_OK entries=6 approved_profile=true changed_bytes_rejected=true")
	quit()
