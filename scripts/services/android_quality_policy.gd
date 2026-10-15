extends RefCounted
## Explicit presentation budgets. No device ranking or automatic downgrades.
const PRESETS := ["low", "medium", "high", "ultra"]
const DEFAULT_PRESET := "ultra"
const FPS_LIMITS := [30, 60]
const SCHEMA_VERSION := 1

static func validate_preset(value: Variant) -> String:
	return str(value) if str(value) in PRESETS else DEFAULT_PRESET

static func validate_fps(value: Variant) -> int:
	if (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)):
		return int(value) if int(value) in FPS_LIMITS else 60
	return 60

static func dimensions(target: Vector2i, preset: String) -> Vector2i:
	var native := target.max(Vector2i(2, 2))
	var short_edge: int = {"low": 540, "medium": 720, "high": 1080, "ultra": 0}[validate_preset(preset)]
	if short_edge == 0 or mini(native.x, native.y) <= short_edge:
		return native
	var factor := float(short_edge) / mini(native.x, native.y)
	return Vector2i(maxi(2, roundi(native.x * factor)), maxi(2, roundi(native.y * factor)))

static func msaa(preset: String) -> int:
	return {"low": Viewport.MSAA_DISABLED, "medium": Viewport.MSAA_2X,
		"high": Viewport.MSAA_2X, "ultra": Viewport.MSAA_4X}[validate_preset(preset)]

static func apply_viewport(viewport: Viewport, preset: String) -> void:
	viewport.msaa_3d = msaa(preset)

static func apply_lights(node: Node, preset: String) -> void:
	# Only the cheapest preset disables shadows; light colour/energy stay authored.
	if preset != "low":
		return
	if node is Light3D:
		node.shadow_enabled = false
	for child in node.get_children():
		apply_lights(child, preset)
