extends SceneTree
const Motion = preload("res://scripts/battle/battle_ui/model_motion_placement.gd")

func _init() -> void:
	var placement := {"calibrated": true, "scale": 1.0, "yaw_degrees": 0.0, "lift": 1.5}
	var timing := {"damage": {"frames": 2}, "sleep": {"frames": 2}, "mega_appeal": {"frames": 2}}
	var profile := {"schema": 1, "sha256": "test", "scale": 1.0, "yaw_degrees": 0.0, "lift": 1.5,
		"clips": {"damage": {"duration": 2.0 / 60, "intent": "clearance_only", "offsets": [0.0, 0.1, 0.0]},
		"sleep": {"duration": 2.0 / 60, "intent": "grounded_rest", "offsets": [-1.0, -1.0, -1.0]},
		"mega_appeal": {"duration": 2.0 / 60, "intent": "clearance_only", "offsets": [1.5, 0.5, 0.0]}}}
	var clips := Motion.resolve(profile, placement, "test", timing)
	assert(not clips.is_empty())
	assert(is_equal_approx(Motion.offset(clips, "damage", .5 / 60), .05))
	assert(Motion.offset(clips, "damage", 100) == 0)
	assert(Motion.offset(clips, "idle", 0) == 0)
	assert(Motion.offset(clips, "faint_start", 0) == 0)
	assert(Motion.offset(clips, "sleep", 0) == -1)
	assert(Motion.offset(clips, "mega_appeal", 0) == 1.5)
	assert(Motion.resolve(profile, placement, "changed", timing).is_empty())
	for key in ["scale", "yaw_degrees", "lift"]:
		var wrong := placement.duplicate()
		wrong[key] += 1
		assert(Motion.resolve(profile, wrong, "test", timing).is_empty())
	var invalid := profile.duplicate(true)
	invalid.clips.damage.offsets[0] = -0.1
	assert(Motion.resolve(invalid, placement, "test", timing).is_empty())
	invalid.clips.damage.offsets[0] = NAN
	assert(Motion.resolve(invalid, placement, "test", timing).is_empty())
	invalid.clips.damage.offsets[0] = true
	assert(Motion.resolve(invalid, placement, "test", timing).is_empty())
	invalid = profile.duplicate(true)
	invalid.clips.damage.duration = 1
	assert(Motion.resolve(invalid, placement, "test", timing).is_empty())
	assert(Motion.advance(-1, .1, .016) == .1, "Clearance may not lag")
	var height := 0.1
	for frame in 120:
		var next := Motion.advance(height, -1, 1.0 / 60)
		assert(next >= -1 and next <= height)
		height = next
	assert(absf(height + 1) < 0.0001)
	print("MODEL_MOTION_PLACEMENT_OK")
	quit()
