extends SceneTree
const Placement = preload("res://scripts/battle/battle_ui/model_placement.gd")
func _init() -> void:
	var calibration := {"sha256": "test", "scale": 0.65, "lift": 0.42}
	var legacy := Placement.resolve({"species": "roaring-moon"}, calibration, "test")
	assert(legacy.calibrated and legacy.scale == 0.65 and legacy.lift == 0.42)
	assert(legacy.hover_height == 0.0, "Existing grounded models gain no hover")
	var entry := {"species": "arbitrary-model", "placement": {"scale": 2.0, "yaw_degrees": 90.0}}
	var ground := {"sha256": "test", "scale": 2.0, "yaw_degrees": 90.0, "lift": 0.2}
	assert(Placement.resolve(entry, ground, "test").calibrated)
	assert(not Placement.resolve(entry, ground, "changed").calibrated)
	ground.yaw_degrees = 0.0
	assert(not Placement.resolve(entry, ground, "test").calibrated)
	ground.yaw_degrees = 90.0
	ground.scale = 1.0
	assert(not Placement.resolve(entry, ground, "test").calibrated)
	entry.placement.scale = -1
	assert(Placement.resolve(entry, {}, "test").is_empty())
	entry.placement.scale = true
	assert(Placement.resolve(entry, {}, "test").is_empty())
	entry.placement.scale = 1.0
	entry.placement.yaw_degrees = NAN
	assert(Placement.resolve(entry, {}, "test").is_empty())
	entry.placement.yaw_degrees = 0.0
	for bad: Variant in [-1, NAN, true]:
		entry.placement.hover_height = bad
		assert(Placement.resolve(entry, {}, "test").is_empty())
	var reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
	for species in ["gliscor", "weezing"]:
		for suffix in ["", "@shiny"]:
			var identity: String = species + suffix
			var digest: String = reviewed.DATA.data.models[identity].sha256
			var profile: Dictionary = reviewed.resolve(identity, digest)
			var hover := Placement.resolve(profile, profile.grounding, digest)
			assert(hover.calibrated)
			assert(hover.hover_height == 0.0 if species == "gliscor" else hover.hover_height > 0.4, "Gliscor's native flight replaces the artificial hover")
			for action in ["idle", "physical_attack", "physical_attack_2", "special_attack", "damage"]:
				assert(Placement.hover_target(hover, action, 0.5, 2.0) == hover.hover_height)
			for action in ["sleep", "faint_loop"]:
				assert(Placement.hover_target(hover, action, 0.5, 2.0) == 0.0)
			var height: float = hover.hover_height
			for frame in 121:
				var target := Placement.hover_target(hover, "faint_start", frame / 60.0, 2.0)
				var next := Placement.advance_hover(height, target, hover, 1.0 / 60.0)
				assert(next >= 0.0 and next <= height, "Faint descends without bouncing or sinking")
				height = next
			assert(is_zero_approx(height), "Faint lands before its resting loop")
			for frame in 30:
				var next := Placement.advance_hover(height, hover.hover_height, hover, 1.0 / 60.0)
				assert(next >= height and next - height < 0.05, "Wake rises smoothly without a height jump")
				height = next
			assert(is_equal_approx(height, hover.hover_height))
	print("MODEL_PLACEMENT_OK")
	quit()
