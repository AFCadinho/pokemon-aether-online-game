extends SceneTree
## The reviewed normal/shiny hashes must resolve through the real catalog.
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")

func _init() -> void:
	var appearance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tools/sprite_factory/catalog_shiny_151_first_32_appearance_review.json"))
	var admission: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tools/sprite_factory/catalog_shiny_151_first_32_admission.json"))
	assert(admission.runtime_approved and not admission.published)
	assert(appearance.entries.size() == 32 and admission.species.size() == 32)
	assert(FileAccess.get_sha256("res://scripts/battle/battle_ui/reviewed_model_catalog.json") ==
		FileAccess.get_sha256("res://launcher/data/reviewed_model_catalog.json"))
	var identities := {}
	for entry: Dictionary in appearance.entries:
		assert(entry.appearance_approved and entry.species in admission.species)
		for variant: String in ["normal", "shiny"]:
			var identity := Registry.key(entry.species, variant == "shiny")
			assert(not identities.has(identity))
			identities[identity] = true
			var digest: String = entry.variants[variant].scene_sha256
			var profile := Registry.resolve(identity, digest)
			assert(not profile.is_empty())
			assert(profile.motion.sha256 == digest and profile.grounding.sha256 == digest)
			assert(profile.action_timing.has("idle") and profile.action_timing.has("sleep"))
			assert(not profile.motion.clips.is_empty())
			assert(Registry.resolve(identity, "0".repeat(64)).is_empty())
	assert(identities.size() == 64)
	print("SHINY_RECOVERY_32_CATALOG_OK pairs=32 scenes=64 wrong_hash_rejected=true")
	quit()
