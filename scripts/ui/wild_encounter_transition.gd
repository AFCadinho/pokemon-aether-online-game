extends Control
class_name WildEncounterTransition

signal covered

const COVER_SECONDS := 0.38
const REVEAL_SECONDS := 0.24
const BAND_COUNT := 12
const BAND_STAGGER_SHARE := 0.28

var cover_progress := 0.0:
	set(value):
		cover_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

var animation_elapsed := 0.0
var active_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	animation_elapsed += delta
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func begin() -> void:
	_stop_active_tween()
	animation_elapsed = 0.0
	cover_progress = 0.0
	visible = true
	set_process(true)

	active_tween = create_tween()
	active_tween.tween_property(self, "cover_progress", 1.0, COVER_SECONDS) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN_OUT)
	active_tween.finished.connect(_on_cover_finished, CONNECT_ONE_SHOT)


func wait_until_covered() -> void:
	if cover_progress >= 0.999:
		return
	await covered


func reveal() -> void:
	if not visible:
		return

	_stop_active_tween()
	active_tween = create_tween()
	active_tween.tween_property(self, "cover_progress", 0.0, REVEAL_SECONDS) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	await active_tween.finished
	active_tween = null
	visible = false
	set_process(false)


func _draw() -> void:
	if cover_progress <= 0.0:
		return

	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	draw_rect(
		Rect2(Vector2.ZERO, viewport_size),
		Color(0.006, 0.012, 0.035, 0.72 * cover_progress)
	)
	_draw_bands(viewport_size)
	_draw_moving_streaks(viewport_size)
	_draw_encounter_flash(viewport_size)


func _draw_bands(viewport_size: Vector2) -> void:
	var band_height := ceilf(viewport_size.y / float(BAND_COUNT)) + 2.0
	for index in range(BAND_COUNT):
		var stagger := (float(index) / float(BAND_COUNT - 1)) * BAND_STAGGER_SHARE
		var band_progress := clampf(
			(cover_progress - stagger) / (1.0 - BAND_STAGGER_SHARE),
			0.0,
			1.0
		)
		band_progress = ease(band_progress, 0.72)
		var band_width := viewport_size.x * band_progress
		var band_x := 0.0 if index % 2 == 0 else viewport_size.x - band_width
		var blue_lift := 0.008 * float(index % 3)
		draw_rect(
			Rect2(
				Vector2(band_x, (float(index) * band_height) - 1.0),
				Vector2(band_width, band_height)
			),
			Color(0.003, 0.01 + blue_lift, 0.035 + blue_lift, 0.985)
		)


func _draw_moving_streaks(viewport_size: Vector2) -> void:
	var hold_strength := smoothstep(0.82, 1.0, cover_progress)
	if hold_strength <= 0.0:
		return

	var travel_width := viewport_size.x + 420.0
	var streak_x := fmod(animation_elapsed * 430.0, travel_width) - 260.0
	for index in range(3):
		var offset_x := streak_x + (float(index) * 145.0)
		var points := PackedVector2Array([
			Vector2(offset_x, 0.0),
			Vector2(offset_x + 46.0, 0.0),
			Vector2(offset_x - 150.0, viewport_size.y),
			Vector2(offset_x - 196.0, viewport_size.y),
		])
		draw_colored_polygon(
			points,
			Color(0.12, 0.48, 0.92, (0.055 - float(index) * 0.012) * hold_strength)
		)


func _draw_encounter_flash(viewport_size: Vector2) -> void:
	var flash_phase := clampf(cover_progress / 0.46, 0.0, 1.0)
	var flash_alpha := sin(flash_phase * PI) * 0.72
	if flash_alpha <= 0.001:
		return
	draw_rect(
		Rect2(Vector2.ZERO, viewport_size),
		Color(0.88, 0.96, 1.0, flash_alpha)
	)


func _on_cover_finished() -> void:
	active_tween = null
	covered.emit()


func _stop_active_tween() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = null
