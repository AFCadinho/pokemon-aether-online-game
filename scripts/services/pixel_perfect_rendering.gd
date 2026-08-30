extends RefCounted

class_name PixelPerfectRendering

const SCALE_OVERVIEW := 1.0
const SCALE_BALANCED := 1.5
const SCALE_CLOSE := 2.0
const DEFAULT_SCALE := SCALE_CLOSE
const AVAILABLE_SCALES: Array[float] = [SCALE_OVERVIEW, SCALE_BALANCED, SCALE_CLOSE]
const LARGE_VIEWPORT_THRESHOLD := Vector2i(1600, 900)


static func validate_scale(value: Variant) -> float:
	var scale := float(value)
	for available_scale: float in AVAILABLE_SCALES:
		if is_equal_approx(scale, available_scale):
			return available_scale
	return DEFAULT_SCALE


static func default_scale_for_viewport(viewport_size: Vector2i) -> float:
	if (
		viewport_size.x > LARGE_VIEWPORT_THRESHOLD.x
		and viewport_size.y > LARGE_VIEWPORT_THRESHOLD.y
	):
		return SCALE_CLOSE
	return SCALE_OVERVIEW


static func resolve_scale(configured_scale: Variant, _viewport_size: Vector2i) -> float:
	return validate_scale(configured_scale)


static func resolve_world_scale_for_area(configured_scale: Variant, area_type: String) -> float:
	if area_type.strip_edges().to_lower() == "interior":
		return SCALE_BALANCED
	return validate_scale(configured_scale)


static func camera_zoom_for_output_scale(output_scale: float, canvas_scale: Vector2) -> Vector2:
	var safe_canvas_scale := Vector2(
		canvas_scale.x if canvas_scale.x > 0.0 else 1.0,
		canvas_scale.y if canvas_scale.y > 0.0 else 1.0
	)
	return Vector2(output_scale, output_scale) / safe_canvas_scale


static func apply_to_camera(
	camera: Camera2D,
	configured_scale: float,
	output_size: Vector2i
) -> float:
	var resolved_scale := resolve_scale(configured_scale, output_size)
	if camera != null:
		var canvas_scale := camera.get_viewport().get_screen_transform().get_scale()
		camera.zoom = camera_zoom_for_output_scale(resolved_scale, canvas_scale)
		camera.reset_smoothing()
		camera.force_update_scroll()
	return resolved_scale
