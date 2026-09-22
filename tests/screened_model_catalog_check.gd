extends SceneTree
## The screened catalog is local test admission, not a portable reviewed pack.
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := OS.get_environment("POKEAETHER_SCREENED_MODEL_CATALOG")
	assert(path.is_absolute_path() and FileAccess.file_exists(path))
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(raw is Array and raw.size() == Registry.SCREENED.data.models.size())
	var stage := Renderer.new()
	stage._load_catalog(path)
	assert(stage.catalog_problem.is_empty())
	assert(stage.catalog_entries.size() == raw.size())
	for entry: Dictionary in raw:
		assert(entry.variant == "normal")
		assert(Registry.SCREENED.data.models.has(entry.species))
		assert(stage.catalog_entries.has(entry.species))
		assert(not stage.catalog_entries[entry.species].has("_reviewed_model"))
		assert(stage.catalog_entries[entry.species].get("_screened_model", false))
		assert(not Registry.supports(Registry.key(entry.species, true)))
	# Exercise two unrelated candidate scenes through the normal asynchronous
	# integrity/import path. No battle scene or arena-grounding claim is made.
	stage.set_combatant(0, "charizard")
	stage.set_combatant(1, "eevee")
	var deadline := Time.get_ticks_msec() + 30000
	while stage._models_pending():
		stage._import_next_model()
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	assert(stage.packed.has("charizard") and stage.packed.has("eevee"))
	assert(stage.failed_models.is_empty())
	stage.free()
	print("SCREENED_MODEL_CATALOG_OK entries=", raw.size(), " imported=charizard,eevee normal_only=true no_grounding_or_motion_calibration")
	quit()
