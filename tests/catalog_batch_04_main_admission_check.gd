extends SceneTree
## Verify the exact locally approved 200 pairs and screened-catalog handoff.
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Approval = preload("res://tools/sprite_factory/catalog_production_batch_04_main_approval.json")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(Approval.data.runtime_approved and Approval.data.release_approved and not Approval.data.published)
	assert(Approval.data.approved_species.size() == 200)
	assert(Registry.DATA.data.models.size() == Registry.DATA.data.profiles.size() * 2)
	assert(Registry.DATA.data.profiles.size() >= 454)
	assert(Registry.SCREENED.data.models.keys() == ["murkrow"])
	var names := {}
	for species: String in Approval.data.approved_species:
		assert(not names.has(species))
		names[species] = true
		var profile: Dictionary = Registry.DATA.data.profiles.get(species, {})
		assert(not profile.is_empty() and profile.has("motion") and profile.has("action_timing"))
		for shiny in [false, true]:
			var identity := Registry.key(species, shiny)
			assert(Registry.DATA.data.models.has(identity))
			assert(not Registry.SCREENED.data.models.has(identity))
			assert(Renderer.supported(species, shiny, false, false))
			var model: Dictionary = Registry.DATA.data.models[identity]
			assert(model.profile == species)
			assert(not Registry.resolve(identity, model.sha256).is_empty())
			assert(Registry.resolve(identity, "invalid").is_empty())
	var catalog_path := OS.get_environment("POKEAETHER_BATCH04_INSTALLED_CATALOG")
	assert(catalog_path.is_absolute_path())
	var installed: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	assert(installed is Array and installed.size() == 400)
	var stage := Renderer.new()
	stage._load_catalog(catalog_path)
	assert(stage.catalog_problem.is_empty() and stage.catalog_entries.size() == 400)
	for entry: Dictionary in installed:
		var identity := Registry.key(entry.species, entry.variant == "shiny")
		assert(stage.catalog_entries.has(identity))
		assert(stage.catalog_entries[identity].get("_reviewed_model", false))
	stage.free()
	print("CATALOG_BATCH_04_MAIN_ADMISSION_OK pairs=200 scenes=400 screened=murkrow")
	quit()
