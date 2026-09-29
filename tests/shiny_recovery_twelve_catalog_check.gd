extends SceneTree
## Exact local normal/shiny identities must resolve and reject wrong scene hashes.
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
func _init() -> void:
	var admission: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tools/sprite_factory/catalog_shiny_twelve_admission.json"))
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(
		"res://.tmp/shiny-151-recovery/twelve-delivery/runtime-catalog.json"))
	assert(admission.runtime_approved and not admission.published)
	assert(admission.species.size() == 12 and rows.size() == 24)
	assert(FileAccess.get_sha256("res://scripts/battle/battle_ui/reviewed_model_catalog.json") ==
		FileAccess.get_sha256("res://launcher/data/reviewed_model_catalog.json"))
	var identities := {}
	for row: Dictionary in rows:
		var identity := Registry.key(row.species, row.variant == "shiny")
		assert(not identities.has(identity))
		identities[identity] = true
		var profile := Registry.resolve(identity, row.runtime_sha256)
		assert(not profile.is_empty())
		assert(profile.motion.sha256 == row.runtime_sha256 and profile.grounding.sha256 == row.runtime_sha256)
		assert(profile.action_timing.has("idle") and profile.action_timing.has("sleep"))
		assert(not profile.motion.clips.is_empty())
		assert(Registry.resolve(identity, "0".repeat(64)).is_empty())
	assert(identities.size() == 24)
	print("SHINY_RECOVERY_TWELVE_CATALOG_OK pairs=12 scenes=24 wrong_hash_rejected=true")
	quit()
