extends SceneTree
## Checked-in admission keeps both new and previously released digests valid.
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Placement = preload("res://scripts/battle/battle_ui/model_placement.gd")
const Motion = preload("res://scripts/battle/battle_ui/model_motion_placement.gd")

func _init() -> void:
	var work := OS.get_environment("POKEAETHER_OGERPON_REVISION_WORK")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(work.path_join("runtime-fixture.json")))
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(work.path_join("previous-registry.json")))
	var installed: Array = JSON.parse_string(FileAccess.get_file_as_string(work.path_join("installed/installed-catalog.json")))
	assert(installed.size() == 6)
	for row: Dictionary in installed:
		var identity := Registry.entry_key(row)
		var model: Dictionary = Registry.DATA.data.models[identity]
		assert(model.sha256 == row.runtime_sha256 and model.sha256 == fixture.models[identity].sha256)
		assert(Registry.approved_digest(model, FileAccess.get_sha256(row.runtime_path)))
		assert(Registry.approved_digest(model, previous.models[identity].sha256))
		assert(model.glb_sha256 == fixture.models[identity].glb_sha256)
		var profile: Dictionary = Registry.DATA.data.profiles[model.profile]
		assert(profile == previous.profiles[row.species])
		var grounding: Dictionary = profile.grounding.duplicate(true)
		grounding.sha256 = row.runtime_sha256
		var placement: Dictionary = Placement.resolve({"placement":profile.placement}, grounding, row.runtime_sha256)
		assert(placement.calibrated)
		var motion: Dictionary = profile.motion.duplicate(true)
		motion.sha256 = row.runtime_sha256
		assert(not Motion.resolve(motion, placement, row.runtime_sha256, profile.action_timing).is_empty())
	print("OGERPON_REGISTRY_REVISION_OK models=6 old_hashes_retained=true profiles_unchanged=true")
	quit()
