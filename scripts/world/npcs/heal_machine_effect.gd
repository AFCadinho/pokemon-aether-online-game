extends Node2D

@export_range(1, 6, 1) var indicator_count := 6
@export_range(1, 6, 1) var indicator_columns := 2
@export var indicator_column_spacing := 13.0
@export var indicator_row_spacing := 10.0
@export var active_color := Color(0.86, 0.98, 1.0, 1.0)
@export var glow_color := Color(0.24, 0.92, 1.0, 0.42)
@export var inactive_color := Color(0.10, 0.25, 0.31, 0.72)

var _duration_seconds := 0.8
var _elapsed_seconds := 0.0
var _is_playing := false
var _visible_indicator_count := 6


func _ready() -> void:
	visible = false
	set_process(false)


func play_heal_sequence(duration_seconds: float = 0.8, pokemon_count: int = 6) -> void:
	_duration_seconds = maxf(duration_seconds, 0.1)
	_visible_indicator_count = clampi(pokemon_count, 0, indicator_count)
	_elapsed_seconds = 0.0
	_is_playing = true
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not _is_playing:
		return

	_elapsed_seconds += delta
	if _elapsed_seconds >= _duration_seconds:
		_is_playing = false
		visible = false
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if not _is_playing or _visible_indicator_count <= 0:
		return

	var progress := clampf(_elapsed_seconds / _duration_seconds, 0.0, 1.0)
	var activation_progress := clampf(progress / 0.58, 0.0, 1.0)
	var active_indicators := mini(
		_visible_indicator_count,
		floori(activation_progress * float(_visible_indicator_count) + 0.001)
	)
	var final_pulse := 1.0
	if progress >= 0.58:
		var pulse_progress := (progress - 0.58) / 0.42
		final_pulse = 0.78 + 0.22 * sin(pulse_progress * TAU * 2.0)

	var fade_alpha := 1.0
	if progress >= 0.88:
		fade_alpha = 1.0 - ((progress - 0.88) / 0.12)

	var column_count := mini(indicator_columns, _visible_indicator_count)
	var row_count := ceili(float(_visible_indicator_count) / float(column_count))
	var first_y := -float(row_count - 1) * indicator_row_spacing * 0.5
	for index: int in range(_visible_indicator_count):
		var column := index % column_count
		var row := floori(float(index) / float(column_count))
		var indicators_before_row := row * column_count
		var indicators_in_row := mini(
			column_count,
			_visible_indicator_count - indicators_before_row
		)
		var row_first_x := -float(indicators_in_row - 1) * indicator_column_spacing * 0.5
		var center := Vector2(
			row_first_x + float(column) * indicator_column_spacing,
			first_y + float(row) * indicator_row_spacing
		)
		var is_active := index < active_indicators
		_draw_indicator(center, is_active, final_pulse, fade_alpha)


func _draw_indicator(center: Vector2, is_active: bool, pulse: float, fade_alpha: float) -> void:
	if not is_active:
		draw_circle(center, 2.5, Color(
			inactive_color.r,
			inactive_color.g,
			inactive_color.b,
			inactive_color.a * fade_alpha
		))
		return

	draw_circle(center, 5.5 * pulse, Color(
		glow_color.r,
		glow_color.g,
		glow_color.b,
		glow_color.a * fade_alpha
	))
	draw_circle(center, 3.25, Color(
		active_color.r,
		active_color.g,
		active_color.b,
		active_color.a * fade_alpha
	))
	draw_arc(center, 2.0, PI, TAU, 10, Color(0.95, 0.28, 0.35, fade_alpha), 2.4, true)
	draw_line(
		center + Vector2(-3.0, 0.0),
		center + Vector2(3.0, 0.0),
		Color(0.10, 0.16, 0.22, 0.92 * fade_alpha),
		1.0,
		true
	)
	draw_circle(center, 0.9, Color(0.94, 0.98, 1.0, fade_alpha))
