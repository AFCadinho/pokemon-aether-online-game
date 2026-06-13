extends Node

const DESIGN_WINDOW_SIZE := Vector2i(1920, 1080)
const MIN_WINDOW_SIZE := Vector2i(1280, 720)
const WINDOWED_SAFE_MARGIN := Vector2i(80, 128)

func _ready() -> void:
	if OS.has_feature("web"):
		return

	call_deferred("_fit_window_to_screen")


func fit_window_to_screen(target_window_size: Vector2i = DESIGN_WINDOW_SIZE) -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return

	var screen_index: int = DisplayServer.window_get_current_screen()
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)
	var usable_size: Vector2i = _get_safe_usable_size(usable_rect.size)
	var target_size: Vector2i = _get_fitted_window_size(target_window_size, usable_size)

	DisplayServer.window_set_min_size(_get_minimum_window_size(usable_size))
	DisplayServer.window_set_size(target_size)
	DisplayServer.window_set_position(usable_rect.position + ((usable_rect.size - target_size) / 2))


func fit_window_to_screen_deferred(target_window_size: Vector2i = DESIGN_WINDOW_SIZE) -> void:
	call_deferred("fit_window_to_screen", target_window_size)


func apply_fullscreen() -> void:
	DisplayServer.window_set_min_size(Vector2i.ZERO)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func apply_fullscreen_deferred() -> void:
	call_deferred("apply_fullscreen")


func _fit_window_to_screen() -> void:
	var target_window_size: Vector2i = DESIGN_WINDOW_SIZE
	var settings_manager: Node = get_node_or_null("/root/SettingsManager")
	if settings_manager != null:
		var configured_resolution: Variant = settings_manager.get("window_resolution")
		if configured_resolution is Vector2i:
			target_window_size = configured_resolution as Vector2i

	fit_window_to_screen(target_window_size)


func _get_safe_usable_size(usable_size: Vector2i) -> Vector2i:
	return Vector2i(
		max(1, usable_size.x - WINDOWED_SAFE_MARGIN.x),
		max(1, usable_size.y - WINDOWED_SAFE_MARGIN.y)
	)

func _get_fitted_window_size(target_window_size: Vector2i, usable_size: Vector2i) -> Vector2i:
	if target_window_size.x <= usable_size.x and target_window_size.y <= usable_size.y:
		return target_window_size

	var scale: float = min(
		float(usable_size.x) / float(target_window_size.x),
		float(usable_size.y) / float(target_window_size.y)
	)

	var fitted_size: Vector2i = Vector2i(
		int(floor(float(target_window_size.x) * scale)),
		int(floor(float(target_window_size.y) * scale))
	)

	if usable_size.x >= MIN_WINDOW_SIZE.x and usable_size.y >= MIN_WINDOW_SIZE.y:
		fitted_size.x = max(fitted_size.x, MIN_WINDOW_SIZE.x)
		fitted_size.y = max(fitted_size.y, MIN_WINDOW_SIZE.y)

	return Vector2i(
		min(fitted_size.x, usable_size.x),
		min(fitted_size.y, usable_size.y)
	)

func _get_minimum_window_size(usable_size: Vector2i) -> Vector2i:
	return Vector2i(
		min(MIN_WINDOW_SIZE.x, usable_size.x),
		min(MIN_WINDOW_SIZE.y, usable_size.y)
	)
