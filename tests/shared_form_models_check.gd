extends SceneTree
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Forms = preload("res://scripts/battle/battle_ui/shared_form_models.gd")
const Downloads = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Dependencies = preload("res://scripts/battle/battle_ui/model_form_dependencies.gd")
const Placement = preload("res://scripts/battle/battle_ui/model_placement.gd")
const Motion = preload("res://scripts/battle/battle_ui/model_motion_placement.gd")

func _initialize() -> void:
	assert(Forms.FORMS.size() == 13)
	for form: String in Forms.FORMS:
		var base := str(Forms.FORMS[form][0])
		var ratio := float(Forms.FORMS[form][1])
		for suffix: String in ["", "@shiny"]:
			var identity := form + suffix
			var original := base + suffix
			var model: Dictionary = Registry.DATA.data.models[original]
			var before: Dictionary = Registry.DATA.data.profiles[model.profile].duplicate(true)
			assert(Registry.supports(identity))
			assert(Registry.canonical_identity(identity) == original)
			assert(Downloads.asset_id_for_identity(identity) == Downloads.asset_id_for_identity(original))
			assert(Registry.resolve(identity, "f".repeat(64)).is_empty())
			var source := Registry.resolve(original, model.sha256)
			var shared := Registry.resolve(identity, model.sha256)
			assert(shared.action_timing == source.action_timing and shared.get("bounds", {}) == source.get("bounds", {}))
			assert(is_equal_approx(shared.placement.scale / source.placement.scale, ratio))
			assert(is_equal_approx(shared.grounding.lift, source.grounding.lift * ratio))
			var position := Placement.resolve({"species":identity,"placement":shared.placement}, shared.grounding, model.sha256)
			assert(position.calibrated)
			var motion := Motion.resolve(shared.motion, position, model.sha256, shared.action_timing)
			assert(not motion.is_empty())
			for action: String in source.motion.clips:
				for i in source.motion.clips[action].offsets.size():
					assert(is_equal_approx(shared.motion.clips[action].offsets[i], source.motion.clips[action].offsets[i] * ratio))
			var entries := {original:{"species":base,"variant":"shiny" if suffix else "normal","runtime_path":"same.scn","runtime_sha256":model.sha256}}
			Registry.add_alias_entries(entries)
			assert(entries[identity].runtime_path == entries[original].runtime_path)
			assert(entries[identity].runtime_sha256 == model.sha256)
			assert(Registry.DATA.data.profiles[model.profile] == before)
	assert(Registry.canonical_identity("mimikyu-busted-totem@shiny") == "mimikyu-busted@shiny")
	assert(Dependencies.anticipated("mimikyu-totem@shiny").has("mimikyu-busted-totem@shiny"))
	assert(Registry.canonical_identity("pikachu-partner") == "pikachu-partner")
	assert(Registry.canonical_identity("lycanroc-dusk") == "lycanroc-dusk")
	print("SHARED_FORM_MODELS_OK forms=13 appearances=26 placement_and_motion_scaled=true")
	quit()
