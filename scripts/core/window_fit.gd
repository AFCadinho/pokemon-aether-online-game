extends Node

const DESIGN_WINDOW_SIZE := Vector2i(1920, 1080)
const MIN_WINDOW_SIZE := Vector2i(1280, 720)
const SCREEN_MARGIN := Vector2i(24, 24)

func _ready() -> void:
	if OS.has_feature("web"):
		return

	call_deferred("_fit_window_to_screen")

func _fit_window_to_screen() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return

	var screen_index: int = DisplayServer.window_get_current_screen()
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)
	var usable_size: Vector2i = usable_rect.size - SCREEN_MARGIN
	var target_size: Vector2i = _get_fitted_window_size(usable_size)

	DisplayServer.window_set_min_size(_get_minimum_window_size(usable_size))
	DisplayServer.window_set_size(target_size)
	DisplayServer.window_set_position(usable_rect.position + ((usable_rect.size - target_size) / 2))

func _get_fitted_window_size(usable_size: Vector2i) -> Vector2i:
	if DESIGN_WINDOW_SIZE.x <= usable_size.x and DESIGN_WINDOW_SIZE.y <= usable_size.y:
		return DESIGN_WINDOW_SIZE

	var scale: float = min(
		float(usable_size.x) / float(DESIGN_WINDOW_SIZE.x),
		float(usable_size.y) / float(DESIGN_WINDOW_SIZE.y)
	)

	var fitted_size := Vector2i(
		int(floor(float(DESIGN_WINDOW_SIZE.x) * scale)),
		int(floor(float(DESIGN_WINDOW_SIZE.y) * scale))
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
