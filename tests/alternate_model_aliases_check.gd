extends SceneTree
const Catalog = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Downloads = preload("res://scripts/services/on_demand_3d_bundle_service.gd")

func _initialize() -> void:
	assert(Catalog.FORM_NAME_ALIASES.size() == 8)
	for alias: String in Catalog.FORM_NAME_ALIASES:
		for suffix: String in ["", "@shiny"]:
			var name := alias + suffix
			var canonical: String = Catalog.FORM_NAME_ALIASES[alias] + suffix
			assert(Catalog.canonical_identity(name) == canonical)
			assert(Catalog.supports(name) and Catalog.aliases_for(canonical).has(name))
			assert(Downloads.asset_id_for_identity(name) == Downloads.asset_id_for_identity(canonical))
			var model: Dictionary = Catalog.DATA.data.models[canonical]
			assert(Catalog.resolve(name, model.sha256) == Catalog.resolve(canonical, model.sha256))
			assert(Catalog.resolve(name, "f".repeat(64)).is_empty())
			var entries := {canonical: {"species": canonical, "runtime_path": "shared.scn", "runtime_sha256": model.sha256}}
			Catalog.add_alias_entries(entries)
			assert(entries[name].runtime_path == "shared.scn" and entries[name].runtime_sha256 == model.sha256)
	# Similar names for distinct source forms must not collapse to the base model.
	for name: String in ["meloetta-pirouette", "landorus-therian", "charizard-mega", "zygarde-complete"]:
		assert(Catalog.canonical_identity(name) == name)
	print("ALTERNATE_MODEL_ALIASES_OK aliases=8 appearances=16 distinct_forms_preserved=true")
	quit()
