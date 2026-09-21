extends RefCounted
## Asset placement, independent of lighting and actor identity rules.
## Compatibility defaults for the two reviewed legacy assets only.
const LEGACY := {
	"dragonite": {"scale": 1.0, "yaw_degrees": 0.0},
	"roaring-moon": {"scale": 0.65, "yaw_degrees": 0.0},
}

static func resolve(entry: Dictionary, calibration: Dictionary, runtime_hash: String) -> Dictionary:
	var defaults: Dictionary = LEGACY.get(entry.get("species", ""), {"scale": 1.0, "yaw_degrees": 0.0})
	var authored: Variant = entry.get("placement", defaults)
	if not authored is Dictionary:
		return {}
	var scale: Variant = authored.get("scale", 0.0)
	var yaw: Variant = authored.get("yaw_degrees", 0.0)
	if not _finite_number(scale) or float(scale) <= 0.0 or not _finite_number(yaw):
		return {}
	var result := {"scale": float(scale), "yaw_degrees": float(yaw), "lift": 0.0, "calibrated": false}
	if calibration.is_empty():
		return result
	var lift: Variant = calibration.get("lift", null)
	var calibrated_scale: Variant = calibration.get("scale", null)
	var calibrated_yaw: Variant = calibration.get("yaw_degrees", 0.0)
	if calibration.get("sha256", "") != runtime_hash or not _finite_number(lift) or float(lift) < 0.0 or not _finite_number(calibrated_scale) or not _finite_number(calibrated_yaw):
		return result
	if not is_equal_approx(float(calibrated_scale), result.scale) or not is_equal_approx(float(calibrated_yaw), result.yaw_degrees):
		return result
	result.lift = float(lift)
	result.calibrated = true
	return result

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
