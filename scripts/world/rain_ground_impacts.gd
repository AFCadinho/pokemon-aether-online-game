extends Node2D

class_name RainGroundImpacts

@export_range(1.0, 120.0, 1.0) var impacts_per_second := 54.0
@export_range(0.1, 1.0, 0.01) var lifetime_min := 0.34
@export_range(0.1, 1.0, 0.01) var lifetime_max := 0.52
@export var splash_color := Color(0.66, 0.84, 1.0, 0.86)

var emitting := false
var spawn_rect := Rect2()

var _impacts: Array[RainImpact] = []
var _spawn_credit := 0.0
var _rng := RandomNumberGenerator.new()
var _surface_layers: Array[TileMapLayer] = []
var _cover_layers: Array[TileMapLayer] = []


class RainImpact:
	var world_position := Vector2.ZERO
	var age := 0.0
	var lifetime := 0.4
	var size := 1.0
	var mirror := 1.0


func _ready() -> void:
	_rng.randomize()
	set_process(false)


func set_emitting(enabled: bool) -> void:
	if emitting == enabled:
		return
	emitting = enabled
	if emitting:
		visible = true
		_prewarm()
	set_process(emitting or not _impacts.is_empty())


func set_spawn_rect(rect: Rect2) -> void:
	spawn_rect = rect.abs()


func set_surface_layers(surface_layers: Array[TileMapLayer], cover_layers: Array[TileMapLayer]) -> void:
	_surface_layers = surface_layers
	_cover_layers = cover_layers
	clear()


func get_surface_layer_count() -> int:
	return _surface_layers.size()


func get_cover_layer_count() -> int:
	return _cover_layers.size()


func clear() -> void:
	_impacts.clear()
	_spawn_credit = 0.0
	queue_redraw()
	if not emitting:
		set_process(false)


func _process(delta: float) -> void:
	for impact: RainImpact in _impacts:
		impact.age += delta
	for index in range(_impacts.size() - 1, -1, -1):
		if _impacts[index].age >= _impacts[index].lifetime:
			_impacts.remove_at(index)

	if emitting and spawn_rect.has_area():
		_spawn_credit += impacts_per_second * delta
		var spawn_count := mini(floori(_spawn_credit), 8)
		_spawn_credit -= float(spawn_count)
		for _index in spawn_count:
			_spawn_impact()

	queue_redraw()
	if not emitting and _impacts.is_empty():
		set_process(false)


func _draw() -> void:
	for impact: RainImpact in _impacts:
		var progress := clampf(impact.age / impact.lifetime, 0.0, 1.0)
		_draw_impact(impact, progress)


func _draw_impact(impact: RainImpact, progress: float) -> void:
	var fade := 1.0 - smoothstep(0.42, 1.0, progress)
	var ring_color := splash_color
	ring_color.a *= fade * sin(progress * PI)
	var ring_radius := lerpf(1.8, 8.4, progress) * impact.size
	_draw_ellipse_arc(impact.world_position, ring_radius, ring_radius * 0.32, ring_color, 1.05)
	if progress < 0.18:
		var contact_color := splash_color
		contact_color.a *= 1.0 - progress / 0.18
		draw_circle(impact.world_position, 1.45 * impact.size, contact_color)

	if progress >= 0.58:
		return
	var splash_progress := progress / 0.58
	var splash_height := sin(splash_progress * PI) * 6.2 * impact.size
	var splash_width := lerpf(1.2, 4.4, splash_progress) * impact.size
	var splash_color_now := splash_color
	splash_color_now.a *= (1.0 - splash_progress) * 0.9
	var center := impact.world_position + Vector2(0.0, -0.5)
	draw_line(
		center + Vector2(-0.7, 0.0),
		center + Vector2(-splash_width * impact.mirror, -splash_height),
		splash_color_now,
		1.1,
		true
	)
	draw_line(
		center + Vector2(0.7, 0.0),
		center + Vector2(splash_width * 0.72 * impact.mirror, -splash_height * 0.72),
		splash_color_now,
		1.0,
		true
	)


func _draw_ellipse_arc(center: Vector2, radius_x: float, radius_y: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var segments := 14
	for index in range(segments + 1):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_polyline(points, color, width, true)


func _prewarm() -> void:
	if not _impacts.is_empty() or not spawn_rect.has_area():
		return
	var initial_count := mini(ceili(impacts_per_second * lifetime_max * 0.45), 12)
	for _index in initial_count:
		var impact := _spawn_impact()
		if impact == null:
			continue
		impact.age = _rng.randf_range(0.0, impact.lifetime * 0.85)


func _spawn_impact() -> RainImpact:
	var impact_position := _find_impact_position()
	if is_inf(impact_position.x):
		return null
	var impact := RainImpact.new()
	impact.world_position = impact_position
	impact.lifetime = _rng.randf_range(lifetime_min, lifetime_max)
	impact.size = _rng.randf_range(0.78, 1.18)
	impact.mirror = -1.0 if _rng.randi() % 2 == 0 else 1.0
	_impacts.append(impact)
	return impact


func _find_impact_position() -> Vector2:
	for _attempt in 18:
		var candidate := Vector2(
			_rng.randf_range(spawn_rect.position.x, spawn_rect.end.x),
			_rng.randf_range(spawn_rect.position.y, spawn_rect.end.y)
		)
		if _is_position_on_rain_surface(candidate):
			return candidate
	return Vector2(INF, INF)


func _is_position_on_rain_surface(world_position: Vector2) -> bool:
	# Maps without imported visual layers retain the legacy fallback. Imported
	# maps with no recognized surface fail closed until a layer is annotated.
	if _surface_layers.is_empty():
		return _cover_layers.is_empty()
	if not _has_tile_at_world_position(_surface_layers, world_position):
		return false
	return not _has_tile_at_world_position(_cover_layers, world_position)


func _has_tile_at_world_position(layers: Array[TileMapLayer], world_position: Vector2) -> bool:
	for layer: TileMapLayer in layers:
		if layer == null or not is_instance_valid(layer) or layer.tile_set == null:
			continue
		var cell := layer.local_to_map(layer.to_local(world_position))
		if layer.get_cell_source_id(cell) != -1:
			return true
	return false
