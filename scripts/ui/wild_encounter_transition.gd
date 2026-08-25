extends Control
class_name WildEncounterTransition

signal covered

const COVER_SECONDS := 0.38
const REVEAL_SECONDS := 0.24
const BAND_COUNT := 12
const BAND_STAGGER_SHARE := 0.28
const STYLE_WILD := "wild"
const STYLE_RANKED := "ranked"
const STYLE_TRAINER := "trainer"
const STYLE_SPECIAL_TRAINER := "special_trainer"

var cover_progress := 0.0:
	set(value):
		cover_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

var animation_elapsed := 0.0
var active_tween: Tween
var transition_style := STYLE_WILD


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


func begin(style: String = STYLE_WILD) -> void:
	_stop_active_tween()
	transition_style = style if style in [
		STYLE_WILD,
		STYLE_RANKED,
		STYLE_TRAINER,
		STYLE_SPECIAL_TRAINER,
	] else STYLE_WILD
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
	match transition_style:
		STYLE_RANKED:
			_draw_ranked_panels(viewport_size)
		STYLE_TRAINER:
			_draw_trainer_shutter(viewport_size)
		STYLE_SPECIAL_TRAINER:
			_draw_special_trainer_panels(viewport_size)
		_:
			_draw_bands(viewport_size)
	_draw_moving_streaks(viewport_size)
	_draw_encounter_flash(viewport_size)


func _draw_ranked_panels(viewport_size: Vector2) -> void:
	var panel_progress := ease(cover_progress, 0.72)
	var overlap := 3.0
	var skew := minf(viewport_size.x * 0.12, 150.0) * panel_progress
	var left_edge := (viewport_size.x * 0.5 + overlap) * panel_progress
	var right_edge := viewport_size.x - (viewport_size.x * 0.5 + overlap) * panel_progress
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(left_edge + skew, 0.0),
			Vector2(left_edge, viewport_size.y),
			Vector2(0.0, viewport_size.y),
		]),
		Color(0.015, 0.13, 0.3, 1.0)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(right_edge, 0.0),
			Vector2(viewport_size.x, 0.0),
			Vector2(viewport_size.x, viewport_size.y),
			Vector2(right_edge - skew, viewport_size.y),
		]),
		Color(0.28, 0.025, 0.18, 1.0)
	)

	var hold_strength := smoothstep(0.82, 1.0, cover_progress)
	if hold_strength <= 0.0:
		return
	var center_x := viewport_size.x * 0.5
	draw_line(
		Vector2(center_x + skew * 0.5, 0.0),
		Vector2(center_x - skew * 0.5, viewport_size.y),
		Color(0.62, 0.9, 1.0, 0.72 * hold_strength),
		3.0
	)
	draw_line(
		Vector2(center_x + skew * 0.5 + 8.0, 0.0),
		Vector2(center_x - skew * 0.5 + 8.0, viewport_size.y),
		Color(1.0, 0.32, 0.72, 0.55 * hold_strength),
		2.0
	)


func _draw_trainer_shutter(viewport_size: Vector2) -> void:
	var shutter_progress := ease(cover_progress, 0.72)
	var center_y := viewport_size.y * 0.5
	var half_cover := (center_y + 3.0) * shutter_progress
	draw_rect(
		Rect2(Vector2(0.0, 0.0), Vector2(viewport_size.x, half_cover)),
		Color(0.015, 0.055, 0.115, 1.0)
	)
	draw_rect(
		Rect2(
			Vector2(0.0, viewport_size.y - half_cover),
			Vector2(viewport_size.x, half_cover)
		),
		Color(0.025, 0.035, 0.075, 1.0)
	)
	var seam_strength := smoothstep(0.72, 1.0, cover_progress)
	if seam_strength > 0.0:
		draw_line(
			Vector2(0.0, center_y),
			Vector2(viewport_size.x, center_y),
			Color(0.98, 0.66, 0.18, 0.82 * seam_strength),
			3.0
		)


func _draw_special_trainer_panels(viewport_size: Vector2) -> void:
	var panel_progress := ease(cover_progress, 0.68)
	var center := viewport_size * 0.5
	var covered_width := (center.x + 4.0) * panel_progress
	var point_height := minf(viewport_size.y * 0.22, 150.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(covered_width, 0.0),
			Vector2(covered_width + point_height, center.y),
			Vector2(covered_width, viewport_size.y),
			Vector2(0.0, viewport_size.y),
		]),
		Color(0.18, 0.025, 0.035, 1.0)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(viewport_size.x, 0.0),
			Vector2(viewport_size.x - covered_width, 0.0),
			Vector2(viewport_size.x - covered_width - point_height, center.y),
			Vector2(viewport_size.x - covered_width, viewport_size.y),
			Vector2(viewport_size.x, viewport_size.y),
		]),
		Color(0.045, 0.035, 0.09, 1.0)
	)
	var crest_strength := smoothstep(0.78, 1.0, cover_progress)
	if crest_strength <= 0.0:
		return
	var crest_radius := minf(viewport_size.x, viewport_size.y) * 0.075
	draw_circle(center, crest_radius, Color(0.98, 0.7, 0.18, 0.92 * crest_strength))
	draw_circle(center, crest_radius * 0.72, Color(0.055, 0.04, 0.085, crest_strength))
	draw_line(
		Vector2(center.x - crest_radius, center.y),
		Vector2(center.x + crest_radius, center.y),
		Color(1.0, 0.86, 0.4, crest_strength),
		3.0
	)


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
