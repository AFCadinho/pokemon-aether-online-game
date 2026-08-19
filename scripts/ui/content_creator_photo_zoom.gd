extends RefCounted

const MIN_FACTOR := 0.25
const MAX_FACTOR := 3.0
const DEFAULT_FACTOR := 1.0


static func clamp_factor(value: float) -> float:
	return clampf(value, MIN_FACTOR, MAX_FACTOR)


static func resolve_zoom(baseline_zoom: Vector2, factor: float) -> Vector2:
	return baseline_zoom * clamp_factor(factor)
