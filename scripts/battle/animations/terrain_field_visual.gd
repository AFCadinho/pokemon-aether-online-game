extends Node2D

class_name TerrainFieldVisual

@export_enum("grassy", "misty", "psychic", "electric") var terrain_type := "grassy"
@export var source_texture: Texture2D

const TILE_SIZE := Vector2(192.0, 192.0)
const PLAYER_FIELD_POINTS := [
	Vector2(95.0, 455.0),
	Vector2(150.0, 500.0),
	Vector2(235.0, 455.0),
	Vector2(325.0, 520.0),
	Vector2(420.0, 470.0),
	Vector2(500.0, 525.0),
	Vector2(535.0, 455.0),
]
const CENTER_FIELD_POINTS := [
	Vector2(545.0, 420.0),
	Vector2(590.0, 350.0),
	Vector2(640.0, 385.0),
	Vector2(685.0, 455.0),
	Vector2(730.0, 350.0),
	Vector2(805.0, 325.0),
	Vector2(820.0, 405.0),
]
const ENEMY_FIELD_POINTS := [
	Vector2(805.0, 285.0),
	Vector2(850.0, 275.0),
	Vector2(925.0, 235.0),
	Vector2(1005.0, 285.0),
	Vector2(1080.0, 225.0),
	Vector2(1140.0, 270.0),
	Vector2(1170.0, 210.0),
]
const MISTY_PATTERNS := [0, 1, 2, 4, 5]

var elapsed := 0.0
var was_visible := false


func _process(delta: float) -> void:
	var visible_now := is_visible_in_tree()
	if visible_now and not was_visible:
		elapsed = 0.0
	was_visible = visible_now
	if not visible_now:
		return

	elapsed += delta
	queue_redraw()


func _draw() -> void:
	if source_texture == null:
		return

	match terrain_type:
		"grassy":
			_draw_grassy_field()
		"misty":
			_draw_misty_field()
		"psychic":
			_draw_psychic_field()
		"electric":
			_draw_electric_field()


func _draw_grassy_field() -> void:
	var points := _all_field_points()
	var cycle := 3.2
	for index: int in range(points.size()):
		for wave_index: int in range(2):
			var phase := fposmod(
				(elapsed / cycle) + float(index) * 0.113 + float(wave_index) * 0.43,
				1.0
			)
			if phase >= 0.78:
				continue

			var progress := phase / 0.78
			var pattern := 9 + mini(3, floori(progress * 4.0))
			var spread := Vector2(
				sin(float(index) * 1.91 + float(wave_index) * 2.4) * 28.0,
				cos(float(index) * 1.37 + float(wave_index)) * 10.0
			)
			var drift := Vector2(
				sin(progress * PI * 1.6 + float(index)) * 22.0,
				-30.0 + progress * 64.0
			)
			var alpha := sin(progress * PI) * 0.88
			var scale_value := 0.78 + float((index + wave_index) % 4) * 0.1
			var rotation := -0.48 + progress * 0.96 + sin(float(index) * 1.7) * 0.26
			_draw_atlas_pattern(
				pattern,
				points[index] + spread + drift,
				scale_value,
				rotation,
				Color(0.82, 1.0, 0.5, alpha)
			)


func _draw_misty_field() -> void:
	var points := _all_field_points()
	var cycle := 5.6
	for index: int in range(points.size()):
		var phase := fposmod((elapsed / cycle) + float(index) * 0.109, 1.0)
		if phase >= 0.82:
			continue

		var progress := phase / 0.82
		var pattern: int = MISTY_PATTERNS[index % MISTY_PATTERNS.size()]
		var drift := Vector2(
			sin(progress * TAU + float(index) * 0.83) * 22.0,
			18.0 - progress * 76.0
		)
		var alpha := sin(progress * PI) * 0.55
		var scale_value := 0.72 + float(index % 3) * 0.18 + progress * 0.12
		var tint := Color(1.0, 0.72, 0.96, alpha)
		if index % 2 == 1:
			tint = Color(0.68, 0.9, 1.0, alpha * 0.9)
		_draw_atlas_pattern(pattern, points[index] + drift, scale_value, 0.0, tint)


func _draw_psychic_field() -> void:
	var points := _all_field_points()
	var cycle := 4.4
	for index: int in range(points.size()):
		var phase := fposmod((elapsed / cycle) + float(index) * 0.151, 1.0)
		if phase >= 0.58:
			continue

		var progress := phase / 0.58
		var pattern := 6 + mini(8, floori(progress * 9.0))
		var drift := Vector2(
			sin(progress * PI + float(index) * 1.31) * 13.0,
			8.0 - progress * 34.0
		)
		var alpha := sin(progress * PI) * 0.62
		var scale_value := 0.38 + float(index % 3) * 0.05
		_draw_atlas_pattern(
			pattern,
			points[index] + drift,
			scale_value,
			0.0,
			Color(1.0, 0.58, 1.0, alpha)
		)


func _draw_electric_field() -> void:
	var points := _all_field_points()
	var cycle := 3.8
	for index: int in range(points.size()):
		var phase_seconds := fposmod(elapsed + float(index) * 0.67, cycle)
		if phase_seconds >= 0.52:
			continue

		var progress := phase_seconds / 0.52
		var pattern := 48 if progress < 0.62 else 52
		var jitter := Vector2(
			sin(float(index) * 2.13) * 9.0,
			-20.0 + cos(float(index) * 1.41) * 8.0
		)
		var alpha := sin(progress * PI) * 0.82
		var scale_value := 0.72 + float(index % 3) * 0.09
		_draw_atlas_pattern(
			pattern,
			points[index] + jitter,
			scale_value,
			0.0,
			Color(1.0, 0.96, 0.46, alpha)
		)


func _draw_atlas_pattern(
	pattern: int,
	at: Vector2,
	scale_value: float,
	rotation: float,
	color: Color
) -> void:
	var columns := maxi(1, floori(float(source_texture.get_width()) / TILE_SIZE.x))
	var column := pattern % columns
	var row := floori(float(pattern) / float(columns))
	var source_rect := Rect2(Vector2(column, row) * TILE_SIZE, TILE_SIZE)
	var destination_rect := Rect2(-TILE_SIZE * 0.5, TILE_SIZE)

	draw_set_transform(at, rotation, Vector2.ONE * scale_value)
	draw_texture_rect_region(source_texture, destination_rect, source_rect, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _all_field_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	points.append_array(PLAYER_FIELD_POINTS)
	points.append_array(CENTER_FIELD_POINTS)
	points.append_array(ENEMY_FIELD_POINTS)
	return points
