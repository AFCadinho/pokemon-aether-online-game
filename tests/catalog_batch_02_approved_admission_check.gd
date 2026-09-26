extends SceneTree
## Exact installed scenes and reviewed identities for the 69 batch-02 pairs.
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")


func _init() -> void:
	var path := OS.get_environment("POKEAETHER_BATCH02_INSTALLED_CATALOG")
	assert(path.is_absolute_path())
	var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(entries is Array and entries.size() == 138)
	assert(Registry.DATA.data.models.size() == 304)
	assert(Registry.DATA.data.profiles.size() == 152)
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
	for species in ["pupitar", "palkia", "zoroark"]:
		assert(Renderer.supported(species, false, false, false))
		assert(Renderer.supported(species, true, false, false))
	for species in ["shroomish", "kyogre", "dialga"]:
		assert(not Renderer.supported(species, false, false, false))
		assert(not Renderer.supported(species, true, false, false))
	print("CATALOG_BATCH_02_APPROVED_ADMISSION_OK pairs=69 scenes=138 held=12")
	quit()
