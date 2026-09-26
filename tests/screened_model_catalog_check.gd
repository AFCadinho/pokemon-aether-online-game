extends SceneTree
## The original local catalog now contains reviewed pairs and remaining holds.
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := OS.get_environment("POKEAETHER_SCREENED_MODEL_CATALOG")
	assert(path.is_absolute_path() and FileAccess.file_exists(path))
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(raw is Array and raw.size() == 75)
	var stage := Renderer.new()
	stage._load_catalog(path)
	assert(stage.catalog_problem.is_empty())
	assert(stage.catalog_entries.size() == raw.size())
	for entry: Dictionary in raw:
		assert(entry.variant == "normal")
		assert(stage.catalog_entries.has(entry.species))
		if Registry.SCREENED.data.models.has(entry.species):
			assert(stage.catalog_entries[entry.species].get("_screened_model", false))
			assert(not Registry.supports(Registry.key(entry.species, true)))
		else:
			assert(Registry.DATA.data.models.has(entry.species))
			assert(stage.catalog_entries[entry.species].get("_reviewed_model", false))
			assert(Registry.supports(Registry.key(entry.species, true)))
	# Exercise unrelated candidate scenes through the normal asynchronous
	# integrity/import path. No battle scene or arena-grounding claim is made.
	stage.set_combatant(0, "charizard")
	stage.set_combatant(1, "corviknight")
	var deadline := Time.get_ticks_msec() + 30000
	while stage._models_pending():
		stage._import_next_model()
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	assert(stage.packed.has("charizard") and stage.packed.has("corviknight"))
	assert(stage.failed_models.is_empty())
	assert(stage._screened_arena_review())
	stage.free()
	print("SCREENED_MODEL_CATALOG_OK original_entries=", raw.size(), " imported=charizard,corviknight")
	quit()
