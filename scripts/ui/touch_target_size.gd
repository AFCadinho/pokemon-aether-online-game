extends RefCounted
## Converts a comfortable touch size to local UI units, including viewport zoom.

const MINIMUM_SIZE := 48.0


static func size_for(control: Control, desktop_size: Vector2) -> Vector2:
	var window_fit := control.get_node_or_null("/root/WindowFit")
	if window_fit == null or not window_fit.is_touch_ui():
		return desktop_size
	var minimum := Vector2.ONE * MINIMUM_SIZE / screen_scale(control)
	return desktop_size.max(minimum.ceil())


static func font_size_for(control: Control, desktop_size: int, minimum: float = 24.0) -> int:
	var window_fit := control.get_node_or_null("/root/WindowFit")
	if window_fit == null or not window_fit.is_touch_ui():
		return desktop_size
	return maxi(desktop_size, ceili(minimum / screen_scale(control).y))


static func compact_button_style(button: Button, visual_size: Vector2 = Vector2(28, 28), alignment: Vector2 = Vector2(0.5, 0.5)) -> void:
	# Keep the full input rect, with the original surface aligned inside it.
	# Use the requested size: old theme margins can briefly keep the Control
	# larger while changing scale. Padding must not retain that stale size.
	var window_fit := button.get_node_or_null("/root/WindowFit")
	var compact: bool = window_fit != null and window_fit.is_touch_ui() and not window_fit.is_mobile_browser_ui()
	var padding := (button.custom_minimum_size - visual_size).max(Vector2.ZERO) if compact else Vector2.ZERO
	var inset := padding * alignment.clamp(Vector2.ZERO, Vector2.ONE)
	var end_inset := padding - inset
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := button.get_theme_stylebox(state) as StyleBoxFlat
		if style == null:
			continue
		if not button.has_theme_stylebox_override(state):
			style = style.duplicate() as StyleBoxFlat
			button.add_theme_stylebox_override(state, style)
		if not style.has_meta("touch_original_margins"):
			style.set_meta("touch_original_margins", Vector4(style.get_margin(SIDE_LEFT), style.get_margin(SIDE_TOP), style.get_margin(SIDE_RIGHT), style.get_margin(SIDE_BOTTOM)))
		var margins: Vector4 = style.get_meta("touch_original_margins")
		style.expand_margin_left = -inset.x
		style.expand_margin_right = -end_inset.x
		style.expand_margin_top = -inset.y
		style.expand_margin_bottom = -end_inset.y
		style.content_margin_left = margins.x + inset.x
		style.content_margin_top = margins.y + inset.y
		style.content_margin_right = margins.z + end_inset.x
		style.content_margin_bottom = margins.w + end_inset.y
	if compact:
		button.size = button.custom_minimum_size


static func screen_scale(control: Control) -> Vector2:
	# Screen scale converts physical pixels to Android dp / iOS points / web CSS
	# pixels; the viewport transform includes the player's chosen UI scale.
	var density := pixel_density()
	var transform := control.get_viewport().get_screen_transform() * control.get_global_transform_with_canvas()
	return transform.get_scale().abs().max(Vector2.ONE * 0.001) / maxf(density, 0.001)


static func pixel_density() -> float:
	if OS.has_feature("android"):
		# Godot clamps Android screen_get_scale() by the viewport dimensions.
		# Android dp uses the uncapped densityDpi / 160 instead.
		return maxf(float(DisplayServer.screen_get_dpi()) / 160.0, 0.001)
	return DisplayServer.screen_get_scale() if OS.has_feature("mobile") or OS.has_feature("web") else 1.0


static func fit_rect(desired: Rect2, bounds: Rect2, occupied: Array[Rect2], gap: float = 4.0) -> Rect2:
	# Try the nearest free spot beside existing surfaces. Enlarging a button must
	# not cover its neighbours or put it beyond the edge of the phone screen.
	var maximum := bounds.end - desired.size
	var origin := desired.position.clamp(bounds.position, maximum.max(bounds.position))
	var xs: Array[float] = [origin.x, bounds.position.x, maximum.x]
	var ys: Array[float] = [origin.y, bounds.position.y, maximum.y]
	for rect: Rect2 in occupied:
		xs.append(rect.position.x - desired.size.x - gap)
		xs.append(rect.end.x + gap)
		ys.append(rect.position.y - desired.size.y - gap)
		ys.append(rect.end.y + gap)
	var best := Rect2(origin, desired.size)
	var best_distance := INF
	for x: float in xs:
		for y: float in ys:
			var candidate := Rect2(Vector2(x, y), desired.size)
			if not bounds.encloses(candidate):
				continue
			var blocked := false
			for rect: Rect2 in occupied:
				if rect.grow(gap * 0.5).intersects(candidate):
					blocked = true
					break
			var distance := candidate.position.distance_squared_to(origin)
			if not blocked and distance < best_distance:
				best = candidate
				best_distance = distance
	return best
