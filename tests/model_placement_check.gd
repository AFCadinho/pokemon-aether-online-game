extends SceneTree
const Placement = preload("res://scripts/battle/battle_ui/model_placement.gd")
func _init() -> void:
	var calibration := {"sha256": "test", "scale": 0.65, "lift": 0.42}
	var legacy := Placement.resolve({"species": "roaring-moon"}, calibration, "test")
	assert(legacy.calibrated and legacy.scale == 0.65 and legacy.lift == 0.42)
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
	print("MODEL_PLACEMENT_OK")
	quit()
