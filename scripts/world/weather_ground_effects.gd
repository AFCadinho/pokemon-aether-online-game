extends Node2D

class_name WeatherGroundEffects

const EFFECT_RAIN := "rain"
const EFFECT_SNOW := "snow"

@export_enum("rain", "snow") var effect_type := EFFECT_RAIN
@export_range(1.0, 120.0, 1.0) var events_per_second := 54.0
@export_range(0.1, 2.5, 0.01) var lifetime_min := 0.34
@export_range(0.1, 2.5, 0.01) var lifetime_max := 0.52
@export_range(0.1, 2.0, 0.01) var size_min := 0.78
@export_range(0.1, 2.0, 0.01) var size_max := 1.18
@export var effect_color := Color(0.66, 0.84, 1.0, 0.86)

var emitting := false
var spawn_rect := Rect2()

var _events: Array[GroundEvent] = []
var _spawn_credit := 0.0
var _rng := RandomNumberGenerator.new()
var _surface_layers: Array[TileMapLayer] = []
var _cover_layers: Array[TileMapLayer] = []


class GroundEvent:
	var world_position := Vector2.ZERO
	var age := 0.0
	var lifetime := 0.4
	var size := 1.0
	var mirror := 1.0
	var rotation := 0.0


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
	set_process(emitting or not _events.is_empty())


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


func get_active_event_count() -> int:
	return _events.size()


func clear() -> void:
	_events.clear()
	_spawn_credit = 0.0
	queue_redraw()
	if not emitting:
		set_process(false)


func _process(delta: float) -> void:
	for event: GroundEvent in _events:
		event.age += delta
	for index in range(_events.size() - 1, -1, -1):
		if _events[index].age >= _events[index].lifetime:
			_events.remove_at(index)

	if emitting and spawn_rect.has_area():
		_spawn_credit += events_per_second * delta
		var spawn_count := mini(floori(_spawn_credit), 8)
		_spawn_credit -= float(spawn_count)
		for _index in spawn_count:
			_spawn_event()

	queue_redraw()
	if not emitting and _events.is_empty():
		set_process(false)


func _draw() -> void:
	for event: GroundEvent in _events:
		var progress := clampf(event.age / event.lifetime, 0.0, 1.0)
		if effect_type == EFFECT_SNOW:
			_draw_snow_landing(event, progress)
		else:
			_draw_rain_impact(event, progress)


func _draw_rain_impact(event: GroundEvent, progress: float) -> void:
	var fade := 1.0 - smoothstep(0.42, 1.0, progress)
	var ring_color := effect_color
	ring_color.a *= fade * sin(progress * PI)
	var ring_radius := lerpf(1.8, 8.4, progress) * event.size
	_draw_ellipse_arc(event.world_position, ring_radius, ring_radius * 0.32, ring_color, 1.05)
	if progress < 0.18:
		var contact_color := effect_color
		contact_color.a *= 1.0 - progress / 0.18
		draw_circle(event.world_position, 1.45 * event.size, contact_color)

	if progress >= 0.58:
		return
	var splash_progress := progress / 0.58
	var splash_height := sin(splash_progress * PI) * 6.2 * event.size
	var splash_width := lerpf(1.2, 4.4, splash_progress) * event.size
	var splash_color_now := effect_color
	splash_color_now.a *= (1.0 - splash_progress) * 0.9
	var center := event.world_position + Vector2(0.0, -0.5)
	draw_line(
		center + Vector2(-0.7, 0.0),
		center + Vector2(-splash_width * event.mirror, -splash_height),
		splash_color_now,
		1.1,
		true
	)
	draw_line(
		center + Vector2(0.7, 0.0),
		center + Vector2(splash_width * 0.72 * event.mirror, -splash_height * 0.72),
		splash_color_now,
		1.0,
		true
	)


func _draw_snow_landing(event: GroundEvent, progress: float) -> void:
	var fade_in := smoothstep(0.0, 0.12, progress)
	var fade_out := 1.0 - smoothstep(0.62, 1.0, progress)
	var color_now := effect_color
	color_now.a *= fade_in * fade_out
	var settle_progress := minf(progress / 0.2, 1.0)
	var center := event.world_position + Vector2(0.0, lerpf(-2.4, 0.0, settle_progress))
	var flake_radius := lerpf(1.25, 2.35, smoothstep(0.0, 0.22, progress)) * event.size
	draw_circle(center, 0.72 * event.size, color_now)
	for arm_index in 3:
		var angle := event.rotation + float(arm_index) * PI / 3.0
		var arm := Vector2(cos(angle), sin(angle)) * flake_radius
		draw_line(center - arm, center + arm, color_now, 0.72, true)


func _draw_ellipse_arc(center: Vector2, radius_x: float, radius_y: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var segments := 14
	for index in range(segments + 1):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_polyline(points, color, width, true)


func _prewarm() -> void:
	if not _events.is_empty() or not spawn_rect.has_area():
		return
	var initial_count := mini(ceili(events_per_second * lifetime_max * 0.45), 12)
	for _index in initial_count:
		var event := _spawn_event()
		if event == null:
			continue
		event.age = _rng.randf_range(0.0, event.lifetime * 0.85)


func _spawn_event() -> GroundEvent:
	var event_position := _find_event_position()
	if is_inf(event_position.x):
		return null
	var event := GroundEvent.new()
	event.world_position = event_position
	event.lifetime = _rng.randf_range(lifetime_min, lifetime_max)
	event.size = _rng.randf_range(size_min, size_max)
	event.mirror = -1.0 if _rng.randi() % 2 == 0 else 1.0
	event.rotation = _rng.randf_range(0.0, PI)
	_events.append(event)
	return event


func _find_event_position() -> Vector2:
	for _attempt in 18:
		var candidate := Vector2(
			_rng.randf_range(spawn_rect.position.x, spawn_rect.end.x),
			_rng.randf_range(spawn_rect.position.y, spawn_rect.end.y)
		)
		if _is_position_on_weather_surface(candidate):
			return candidate
	return Vector2(INF, INF)


func _is_position_on_weather_surface(world_position: Vector2) -> bool:
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
