extends RefCounted

class_name PixelPerfectRendering

const SCALE_AUTO := 0
const DEFAULT_SCALE := 2
const MIN_SCALE := 1
const MAX_SCALE := 3
const AUTO_REFERENCE_VIEW_SIZE := Vector2i(800, 450)
const AVAILABLE_SCALES: Array[int] = [SCALE_AUTO, 1, 2, 3]


static func validate_scale(value: Variant) -> int:
	var scale := int(value)
	return scale if scale in AVAILABLE_SCALES else DEFAULT_SCALE


static func resolve_scale(configured_scale: int, viewport_size: Vector2i) -> int:
	var validated_scale := validate_scale(configured_scale)
	if validated_scale != SCALE_AUTO:
		return validated_scale
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return DEFAULT_SCALE
	var horizontal_fit := floori(float(viewport_size.x) / float(AUTO_REFERENCE_VIEW_SIZE.x))
	var vertical_fit := floori(float(viewport_size.y) / float(AUTO_REFERENCE_VIEW_SIZE.y))
	return clampi(mini(horizontal_fit, vertical_fit), MIN_SCALE, MAX_SCALE)


static func camera_zoom_for_output_scale(output_scale: int, canvas_scale: Vector2) -> Vector2:
	var safe_canvas_scale := Vector2(
		canvas_scale.x if canvas_scale.x > 0.0 else 1.0,
		canvas_scale.y if canvas_scale.y > 0.0 else 1.0
	)
	return Vector2(output_scale, output_scale) / safe_canvas_scale


static func apply_to_camera(
	camera: Camera2D,
	configured_scale: int,
	output_size: Vector2i
) -> int:
	var resolved_scale := resolve_scale(configured_scale, output_size)
	if camera != null:
		var canvas_scale := camera.get_viewport().get_screen_transform().get_scale()
		camera.zoom = camera_zoom_for_output_scale(resolved_scale, canvas_scale)
		camera.reset_smoothing()
		camera.force_update_scroll()
	return resolved_scale
