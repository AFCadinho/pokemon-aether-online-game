extends RefCounted
## Shared artistic budgets; desktop resolution scales with the actual arena.
const Android := preload("res://scripts/services/android_quality_policy.gd")
const PRESETS := Android.PRESETS
const DEFAULT_PRESET := Android.DEFAULT_PRESET
const FPS_LIMITS := [0, 30, 60, 120]

static func validate_preset(value: Variant) -> String:
	return Android.validate_preset(value)

static func validate_fps(value: Variant) -> int:
	if (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and int(value) in FPS_LIMITS:
		return int(value)
	return 0

static func dimensions(target: Vector2i, preset: String, android := false) -> Vector2i:
	if android: return Android.dimensions(target, preset)
	var native := target.max(Vector2i(2, 2))
	var scale: float = {"low": .5, "medium": .75, "high": 1.0, "ultra": 1.0}[validate_preset(preset)]
	return Vector2i(maxi(2, roundi(native.x * scale)), maxi(2, roundi(native.y * scale)))

static func apply_viewport(viewport: Viewport, preset: String) -> void:
	Android.apply_viewport(viewport, preset)

static func apply_lights(node: Node, preset: String) -> void:
	Android.apply_lights(node, preset)
