extends SceneTree
## Check the exact installed 25 normal/shiny scenes against the local registry.
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")


func _init() -> void:
	var path := OS.get_environment("POKEAETHER_BATCH03_INSTALLED_CATALOG")
	assert(path.is_absolute_path())
	var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var decision: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tools/sprite_factory/catalog_production_batch_03_hold_recovery_approval.json"))
	assert(entries is Array and entries.size() == 50)
	assert(decision is Dictionary and decision.approved_species.size() == 25)
	assert(Registry.DATA.data.models.size() == 508)
	assert(Registry.DATA.data.profiles.size() == 254)
	var identities := {}
	for entry: Dictionary in entries:
		var identity := Registry.entry_key(entry)
		assert(not identity.is_empty() and not identities.has(identity))
		identities[identity] = true
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		var profile := Registry.resolve(identity, entry.runtime_sha256)
		assert(not profile.is_empty() and profile.motion.sha256 == entry.runtime_sha256)
		assert(profile.grounding.sha256 == entry.runtime_sha256)
		assert(profile.action_timing.has("physical_attack_2"))
		assert(Registry.resolve(identity, "unapproved").is_empty())
	for species: String in decision.approved_species:
		assert(identities.has(species) and identities.has(species + "@shiny"))
		assert(Renderer.supported(species, false, false, false))
		assert(Renderer.supported(species, true, false, false))
	print("CATALOG_BATCH_03_HOLD_RECOVERY_ADMISSION_OK pairs=25 scenes=50")
	quit()
