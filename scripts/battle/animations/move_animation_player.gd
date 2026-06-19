extends Node2D

class_name MoveAnimationPlayer

signal animation_finished

@export_file("*.json") var data_path := ""
@export_file("*.png") var sheet_path := ""
@export_file("*.png") var background_path := ""
@export_file("*.png") var foreground_path := ""
@export var sound_paths: Dictionary = {}
@export var autoplay: bool = true
@export var loop: bool = false
@export var free_on_finish: bool = false
@export var show_timing_backgrounds: bool = false
@export var show_timing_foregrounds: bool = false
@export var show_pink_visual: bool = true
@export var show_sheet_sprites: bool = true
@export var overlay_fill_enabled: bool = true
@export var projectile_config: Dictionary = {}
@export var orb_config: Dictionary = {}
@export var orb_projectile_config: Dictionary = {}
@export var visual_color: Color = Color(1.0, 0.2, 0.75, 1.0)
@export var sprite_tint: Color = Color(1.0, 0.78, 1.0, 1.0)
@export var reverse_battlefield: bool = false
@export_range(0.0, 0.5, 0.01) var overlay_peak_alpha: float = 0.20
@export_range(0, 48, 1) var sparkle_count: int = 14
@export_range(0.25, 4.0, 0.05) var speed_scale: float = 1.0
@export_range(0.1, 2.0, 0.05) var sprite_zoom_multiplier: float = 1.0
@export_range(0.5, 4.0, 0.05) var sparkle_size_multiplier: float = 1.0
@export var sparkle_center: Vector2 = Vector2(256, 188)
@export_range(8.0, 180.0, 1.0) var sparkle_radius_min: float = 26.0
@export_range(8.0, 220.0, 1.0) var sparkle_radius_max: float = 78.0
@export_range(-8, 8, 1) var pattern_offset: int = 0
@export_range(-1, 999, 1) var pattern_override: int = -1

var data: Dictionary = {}
var sprites: Array[Sprite2D] = []
var frame_index: int = 0
var frame_time: float = 0.0
var is_playing: bool = false
var played_events: Dictionary = {}
var pink_overlay_alpha: float = 0.0
var bg_hide_frame: int = -1
var fg_hide_frame: int = -1
var sheet_texture: Texture2D
var sound_players: Dictionary = {}
var data_override: Dictionary = {}
var sheet_texture_override: Texture2D
var background_texture_override: Texture2D
var foreground_texture_override: Texture2D
var sound_streams: Dictionary = {}
var projectile_sprite: Sprite2D

@onready var bg: Sprite2D = Sprite2D.new()
@onready var fg: Sprite2D = Sprite2D.new()

const REVERSED_BATTLEFIELD_AXIS := Vector2(512.0, 320.0)


func _ready() -> void:
	_load_animation_data()
	_build_nodes()
	if autoplay:
		play()


func play() -> void:
	if data.is_empty() or not _animation_data_is_valid(data):
		animation_finished.emit()
		if free_on_finish:
			queue_free()
		return

	frame_index = 0
	frame_time = 0.0
	pink_overlay_alpha = 0.0
	bg_hide_frame = -1
	fg_hide_frame = -1
	played_events.clear()
	is_playing = true
	_apply_frame(frame_index)


func stop() -> void:
	is_playing = false
	for sprite: Sprite2D in sprites:
		sprite.visible = false
	bg.modulate.a = 0.0
	fg.modulate.a = 0.0
	bg_hide_frame = -1
	fg_hide_frame = -1
	pink_overlay_alpha = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not is_playing or data.is_empty():
		return

	pink_overlay_alpha = maxf(0.0, pink_overlay_alpha - delta * 0.42)
	queue_redraw()

	frame_time += delta
	var seconds_per_frame: float = 1.0 / (float(data.get("fps", 20)) * speed_scale)
	while frame_time >= seconds_per_frame:
		frame_time -= seconds_per_frame
		frame_index += 1
		if frame_index >= (data["frames"] as Array).size():
			if loop:
				frame_index = 0
				played_events.clear()
			else:
				stop()
				animation_finished.emit()
				if free_on_finish:
					queue_free()
				return
		_apply_frame(frame_index)


func _load_animation_data() -> void:
	if not data_override.is_empty():
		if _animation_data_is_valid(data_override):
			data = data_override
		else:
			push_error("Move animation data override is incomplete.")
		return

	if data_path == "":
		push_error("Move animation data_path is empty.")
		return

	var parsed_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if parsed_data == null or not parsed_data is Dictionary:
		push_error("Could not read %s" % data_path)
		return
	var parsed_dictionary: Dictionary = parsed_data as Dictionary
	if not _animation_data_is_valid(parsed_dictionary):
		push_error("Move animation data is incomplete: %s" % data_path)
		return
	data = parsed_dictionary


func _animation_data_is_valid(animation_data: Dictionary) -> bool:
	var frames_value: Variant = animation_data.get("frames", [])
	if not frames_value is Array or (frames_value as Array).is_empty():
		return false

	var tile_size_value: Variant = animation_data.get("tile_size", [])
	if not tile_size_value is Array or (tile_size_value as Array).size() < 2:
		return false

	if float(animation_data.get("fps", 20.0)) <= 0.0:
		return false

	return true


func _build_nodes() -> void:
	sheet_texture = sheet_texture_override
	if sheet_texture == null:
		sheet_texture = load(sheet_path) as Texture2D
	if sheet_texture == null:
		push_error("Could not load move animation sheet: %s" % sheet_path)
		return

	if background_texture_override != null:
		bg.texture = background_texture_override
	elif background_path != "":
		bg.texture = load(background_path) as Texture2D
	bg.centered = false
	bg.modulate.a = 0.0
	add_child(bg)

	for i: int in range(32):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = sheet_texture
		sprite.region_enabled = true
		sprite.visible = false
		sprite.centered = true
		sprites.append(sprite)
		add_child(sprite)

	if _projectile_enabled():
		projectile_sprite = Sprite2D.new()
		projectile_sprite.texture = sheet_texture
		projectile_sprite.region_enabled = true
		projectile_sprite.region_rect = _get_projectile_texture_region()
		projectile_sprite.centered = true
		projectile_sprite.visible = false
		add_child(projectile_sprite)

	if foreground_texture_override != null:
		fg.texture = foreground_texture_override
	elif foreground_path != "":
		fg.texture = load(foreground_path) as Texture2D
	fg.centered = false
	fg.modulate.a = 0.0
	add_child(fg)

	for sound_name: Variant in sound_paths.keys():
		var sound_key: String = str(sound_name)
		var stream: AudioStream = sound_streams.get(sound_key, null) as AudioStream
		var sound_path: String = str(sound_paths.get(sound_name, ""))
		if stream == null:
			stream = load(sound_path) as AudioStream
		if stream == null:
			push_warning("Could not load move animation sound: %s" % sound_path)
			continue

		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = stream
		player.bus = SettingsManager.SFX_BUS
		sound_players[sound_key] = player
		add_child(player)


func _draw() -> void:
	var should_draw_overlay: bool = show_pink_visual and pink_overlay_alpha > 0.0

	if should_draw_overlay and overlay_fill_enabled:
		draw_rect(Rect2(Vector2.ZERO, Vector2(512, 384)), Color(visual_color.r, visual_color.g, visual_color.b, pink_overlay_alpha), true)
	if should_draw_overlay:
		_draw_orb_visual()
		for i: int in range(sparkle_count):
			var angle: float = float(i) * 0.85 + float(frame_index) * 0.24
			var radius_span: float = maxf(sparkle_radius_max - sparkle_radius_min, 1.0)
			var radius: float = sparkle_radius_min + fmod(float(i * 17), radius_span)
			var center: Vector2 = sparkle_center + Vector2(cos(angle), sin(angle * 1.27)) * radius
			center = _battlefield_position(center)
			var sparkle_alpha: float = pink_overlay_alpha * (0.35 + 0.45 * absf(sin(angle)))
			var sparkle_size: float = (3.0 + float(i % 3)) * sparkle_size_multiplier
			var sparkle_color := Color(sprite_tint.r, sprite_tint.g, sprite_tint.b, sparkle_alpha)
			draw_line(center + Vector2(-sparkle_size, 0.0), center + Vector2(sparkle_size, 0.0), sparkle_color, 1.4)
			draw_line(center + Vector2(0.0, -sparkle_size), center + Vector2(0.0, sparkle_size), sparkle_color, 1.4)
			draw_line(center + Vector2(-sparkle_size * 0.7, -sparkle_size * 0.7), center + Vector2(sparkle_size * 0.7, sparkle_size * 0.7), sparkle_color, 1.0)
			draw_line(center + Vector2(-sparkle_size * 0.7, sparkle_size * 0.7), center + Vector2(sparkle_size * 0.7, -sparkle_size * 0.7), sparkle_color, 1.0)
			draw_circle(center, sparkle_size * 0.38, sparkle_color)
	_draw_orb_projectile_visual()


func _draw_orb_visual() -> void:
	if not bool(orb_config.get("enabled", false)):
		return

	var center: Vector2 = _battlefield_position(_vector2_from_value(orb_config.get("center", [256.0, 188.0])))
	var base_radius: float = float(orb_config.get("radius", 96.0))
	var pulse: float = 0.08 * sin(float(frame_index) * 0.45)
	var radius: float = base_radius * (1.0 + pulse)
	var alpha_scale: float = float(orb_config.get("alpha", 1.0)) * pink_overlay_alpha
	var fill_color := Color(visual_color.r, visual_color.g, visual_color.b, 0.18 * alpha_scale)
	var ring_color := Color(sprite_tint.r, sprite_tint.g, sprite_tint.b, 0.75 * alpha_scale)
	var highlight_color := Color(1.0, 0.94, 1.0, 0.5 * alpha_scale)

	draw_circle(center, radius, fill_color)
	for ring_index: int in range(3):
		var ring_radius: float = radius + float(ring_index) * 7.0
		draw_arc(center, ring_radius, 0.0, TAU, 96, ring_color, 2.5 - float(ring_index) * 0.45)

	var sweep_start: float = float(frame_index) * 0.22
	draw_arc(center, radius * 0.82, sweep_start, sweep_start + PI * 0.85, 48, highlight_color, 3.0)
	draw_arc(center, radius * 1.08, -sweep_start, -sweep_start + PI * 0.65, 48, highlight_color, 2.0)
	_draw_dna_orb_visual(center, radius, alpha_scale)


func _draw_dna_orb_visual(center: Vector2, radius: float, alpha_scale: float) -> void:
	var dna_value: Variant = orb_config.get("dna", {})
	if not dna_value is Dictionary:
		return

	var dna_config: Dictionary = dna_value as Dictionary
	if not bool(dna_config.get("enabled", false)):
		return

	var segments: int = maxi(18, int(dna_config.get("segments", 72)))
	var strand_width: float = float(dna_config.get("strand_width", 3.2))
	var connector_width: float = float(dna_config.get("connector_width", 1.8))
	var vertical_squash: float = float(dna_config.get("vertical_squash", 0.72))
	var separation: float = float(dna_config.get("separation", 10.0))
	var wave_count: float = float(dna_config.get("wave_count", 3.0))
	var spin: float = float(frame_index) * float(dna_config.get("spin_speed", 0.12))
	var strand_alpha: float = float(dna_config.get("alpha", 1.0)) * alpha_scale
	var connector_alpha: float = strand_alpha * 0.42
	var strand_a: Color = _color_from_value(dna_config.get("strand_a", [0.02, 0.72, 1.0, 1.0]), Color(0.02, 0.72, 1.0, 1.0))
	var strand_b: Color = _color_from_value(dna_config.get("strand_b", [0.95, 0.22, 1.0, 1.0]), Color(0.95, 0.22, 1.0, 1.0))
	var connector_color: Color = _color_from_value(dna_config.get("connector_color", [0.94, 1.0, 0.32, 1.0]), Color(0.94, 1.0, 0.32, 1.0))
	strand_a.a *= strand_alpha
	strand_b.a *= strand_alpha
	connector_color.a *= connector_alpha

	var previous_outer := Vector2.ZERO
	var previous_inner := Vector2.ZERO
	for segment_index: int in range(segments + 1):
		var progress: float = float(segment_index) / float(segments)
		var angle: float = progress * TAU
		var wave: float = sin((angle * wave_count) + spin) * separation
		var outer: Vector2 = _ellipse_ring_point(center, angle, radius + wave, vertical_squash)
		var inner: Vector2 = _ellipse_ring_point(center, angle, radius - wave, vertical_squash)

		if segment_index > 0:
			draw_line(previous_outer, outer, strand_a, strand_width)
			draw_line(previous_inner, inner, strand_b, strand_width)

		if segment_index % 6 == 0:
			draw_line(inner, outer, connector_color, connector_width)

		previous_outer = outer
		previous_inner = inner


func _ellipse_ring_point(center: Vector2, angle: float, radius: float, vertical_squash: float) -> Vector2:
	return center + Vector2(cos(angle) * radius, sin(angle) * radius * vertical_squash)


func _draw_orb_projectile_visual() -> void:
	if not _orb_projectile_enabled():
		return

	var frames: Array = data.get("frames", []) as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(frame_index) / float(total_frames), 0.0, 1.0)
	var projectile_state: Dictionary = _get_projectile_state_from_config(progress, orb_projectile_config)
	var center: Vector2 = _projectile_battlefield_position(projectile_state.get("position", Vector2.ZERO) as Vector2, orb_projectile_config)
	var scale_value: float = float(projectile_state.get("scale", 1.0))
	var base_radius: float = float(orb_projectile_config.get("radius", 18.0))
	var radius: float = base_radius * scale_value
	var alpha: float = _get_orb_projectile_alpha(progress)
	if alpha <= 0.02:
		return

	var trail_count: int = maxi(0, int(orb_projectile_config.get("trail_count", 4)))
	var trail_spacing: float = float(orb_projectile_config.get("trail_spacing", 0.035))
	for trail_index: int in range(trail_count, 0, -1):
		var trail_progress: float = clampf(progress - float(trail_index) * trail_spacing, 0.0, 1.0)
		var trail_visibility_alpha: float = _get_orb_projectile_visibility_alpha(trail_progress)
		if trail_visibility_alpha <= 0.02:
			continue
		var trail_state: Dictionary = _get_projectile_state_from_config(trail_progress, orb_projectile_config)
		var trail_center: Vector2 = _projectile_battlefield_position(trail_state.get("position", Vector2.ZERO) as Vector2, orb_projectile_config)
		var trail_scale: float = float(trail_state.get("scale", 1.0))
		var trail_alpha: float = alpha * trail_visibility_alpha * (0.12 / float(trail_index))
		var trail_radius: float = base_radius * trail_scale * (1.0 + float(trail_index) * 0.12)
		draw_circle(trail_center, trail_radius, Color(visual_color.r, visual_color.g, visual_color.b, trail_alpha))

	var fill_color := Color(visual_color.r, visual_color.g, visual_color.b, alpha * 0.82)
	var inner_color := Color(1.0, 1.0, 1.0, alpha * 0.78)
	var ring_color := Color(sprite_tint.r, sprite_tint.g, sprite_tint.b, alpha)
	var shadow_color := Color(0.08, 0.15, 0.22, alpha * 0.32)
	draw_circle(center + Vector2(radius * 0.12, radius * 0.18), radius * 1.06, shadow_color)
	draw_circle(center, radius, fill_color)
	draw_circle(center + Vector2(-radius * 0.24, -radius * 0.26), radius * 0.38, inner_color)
	draw_arc(center, radius * 1.08, 0.0, TAU, 64, ring_color, maxf(1.5, radius * 0.12))

	var sparkle_alpha: float = alpha * 0.8
	for sparkle_index: int in range(3):
		var angle: float = float(frame_index) * 0.22 + float(sparkle_index) * TAU / 3.0
		var projectile_sparkle_center: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 1.35
		var sparkle_size: float = maxf(2.0, radius * 0.16)
		var sparkle_color := Color(1.0, 1.0, 1.0, sparkle_alpha * (0.65 - float(sparkle_index) * 0.12))
		draw_line(projectile_sparkle_center + Vector2(-sparkle_size, 0.0), projectile_sparkle_center + Vector2(sparkle_size, 0.0), sparkle_color, 1.2)
		draw_line(projectile_sparkle_center + Vector2(0.0, -sparkle_size), projectile_sparkle_center + Vector2(0.0, sparkle_size), sparkle_color, 1.2)


func _orb_projectile_enabled() -> bool:
	return bool(orb_projectile_config.get("enabled", false))


func _get_orb_projectile_alpha(progress: float) -> float:
	var fade_in: float = maxf(float(orb_projectile_config.get("fade_in", 0.10)), 0.001)
	var fade_out: float = maxf(float(orb_projectile_config.get("fade_out", 0.14)), 0.001)
	return minf(
		clampf(progress / fade_in, 0.0, 1.0),
		clampf((1.0 - progress) / fade_out, 0.0, 1.0)
	) * _get_orb_projectile_visibility_alpha(progress)


func _get_orb_projectile_visibility_alpha(progress: float) -> float:
	var windows_value: Variant = orb_projectile_config.get("visible_windows", [])
	if not windows_value is Array or (windows_value as Array).is_empty():
		return 1.0

	var windows: Array = windows_value as Array
	var feather: float = maxf(float(orb_projectile_config.get("visible_window_feather", 0.025)), 0.001)
	for window_value: Variant in windows:
		if not window_value is Array:
			continue
		var window: Array = window_value as Array
		if window.size() < 2:
			continue

		var start: float = clampf(float(window[0]), 0.0, 1.0)
		var end: float = clampf(float(window[1]), 0.0, 1.0)
		if progress < start or progress > end:
			continue

		var fade_in_alpha: float = clampf((progress - start) / feather, 0.0, 1.0)
		var fade_out_alpha: float = clampf((end - progress) / feather, 0.0, 1.0)
		return minf(fade_in_alpha, fade_out_alpha)

	return 0.0


func _color_from_value(value: Variant, fallback: Color) -> Color:
	if not value is Array:
		return fallback

	var channels: Array = value as Array
	if channels.size() < 3:
		return fallback

	var alpha: float = 1.0
	if channels.size() >= 4:
		alpha = float(channels[3])
	return Color(float(channels[0]), float(channels[1]), float(channels[2]), alpha)


func _apply_frame(index: int) -> void:
	_apply_timing_events(index)
	_expire_timing_layers(index)
	_update_pink_visual(index)

	var frames: Array = data["frames"] as Array
	var cells: Array = frames[index] as Array
	for sprite: Sprite2D in sprites:
		sprite.visible = false

	_update_projectile(index)
	if not show_sheet_sprites:
		return

	var tile_size: Array = data["tile_size"] as Array
	var tile_w: int = int(tile_size[0])
	var tile_h: int = int(tile_size[1])
	var columns: int = maxi(1, int(sheet_texture.get_width() / tile_w))
	var sprite_i: int = 0

	for cell_value: Variant in cells:
		if sprite_i >= sprites.size():
			break
		if not cell_value is Dictionary:
			continue

		var cell: Dictionary = cell_value as Dictionary
		if int(cell["source"]) < 0:
			continue

		var sprite: Sprite2D = sprites[sprite_i]
		var pattern: int = pattern_override if pattern_override >= 0 else maxi(0, int(cell["pattern"]) + pattern_offset)
		sprite.region_rect = Rect2(
			(pattern % columns) * tile_w,
			int(pattern / columns) * tile_h,
			tile_w,
			tile_h
		)
		sprite.position = _battlefield_position(Vector2(float(cell["x"]), float(cell["y"])))
		var zoom: float = (float(cell["zoom"]) / 100.0) * sprite_zoom_multiplier
		sprite.scale = Vector2(-zoom if bool(cell["mirror"]) else zoom, zoom)
		sprite.rotation_degrees = float(cell["angle"])
		var alpha: float = float(cell["opacity"]) / 255.0
		sprite.modulate = Color(sprite_tint.r, sprite_tint.g, sprite_tint.b, alpha) if show_pink_visual else Color(1.0, 1.0, 1.0, alpha)
		sprite.visible = true
		sprite_i += 1

func _projectile_enabled() -> bool:
	return bool(projectile_config.get("enabled", not projectile_config.is_empty()))

func _get_projectile_texture_region() -> Rect2:
	var region_value: Variant = projectile_config.get("texture_region", [0, 0, 96, 96])
	if not region_value is Array:
		return Rect2(0, 0, 96, 96)

	var region_array := region_value as Array
	if region_array.size() < 4:
		return Rect2(0, 0, 96, 96)

	return Rect2(
		float(region_array[0]),
		float(region_array[1]),
		float(region_array[2]),
		float(region_array[3])
	)

func _update_projectile(index: int) -> void:
	if projectile_sprite == null:
		return

	var frames: Array = data["frames"] as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(index) / float(total_frames), 0.0, 1.0)
	var projectile_state: Dictionary = _get_projectile_state(progress)
	var position: Vector2 = projectile_state.get("position", Vector2.ZERO) as Vector2
	var scale_value: float = float(projectile_state.get("scale", 1.0))
	projectile_sprite.position = _projectile_battlefield_position(position, projectile_config)
	projectile_sprite.scale = Vector2(scale_value, scale_value)
	var fade_in_seconds: float = maxf(float(projectile_config.get("fade_in", 0.12)), 0.001)
	var fade_out_seconds: float = maxf(float(projectile_config.get("fade_out", 0.18)), 0.001)
	var fade_in: float = clampf(progress / fade_in_seconds, 0.0, 1.0)
	var fade_out: float = clampf((1.0 - progress) / fade_out_seconds, 0.0, 1.0)
	var alpha: float = minf(fade_in, fade_out)
	projectile_sprite.modulate = Color(sprite_tint.r, sprite_tint.g, sprite_tint.b, alpha)
	projectile_sprite.visible = alpha > 0.02

func _get_projectile_state(progress: float) -> Dictionary:
	return _get_projectile_state_from_config(progress, projectile_config)


func _battlefield_position(position: Vector2) -> Vector2:
	if not reverse_battlefield:
		return position

	return Vector2(
		REVERSED_BATTLEFIELD_AXIS.x - position.x,
		REVERSED_BATTLEFIELD_AXIS.y - position.y
	)


func _projectile_battlefield_position(position: Vector2, config: Dictionary) -> Vector2:
	if _uses_explicit_reverse_path(config):
		return position

	return _battlefield_position(position)


func _uses_explicit_reverse_path(config: Dictionary) -> bool:
	if not reverse_battlefield:
		return false

	var reverse_path_value: Variant = config.get("reverse_path", [])
	return reverse_path_value is Array and not (reverse_path_value as Array).is_empty()


func _get_projectile_state_from_config(progress: float, config: Dictionary) -> Dictionary:
	var path_value: Variant = config.get("reverse_path", []) if _uses_explicit_reverse_path(config) else config.get("path", [])
	if not path_value is Array:
		return {"position": Vector2.ZERO, "scale": 1.0}

	var path := path_value as Array
	if path.is_empty():
		return {"position": Vector2.ZERO, "scale": 1.0}

	var first_point: Dictionary = _get_projectile_path_point(path[0])
	if path.size() == 1 or progress <= float(first_point.get("at", 0.0)):
		return {
			"position": first_point.get("position", Vector2.ZERO),
			"scale": float(first_point.get("scale", 1.0)),
		}

	for index in range(1, path.size()):
		var previous_point: Dictionary = _get_projectile_path_point(path[index - 1])
		var next_point: Dictionary = _get_projectile_path_point(path[index])
		var previous_at: float = float(previous_point.get("at", 0.0))
		var next_at: float = float(next_point.get("at", 1.0))
		if progress > next_at and index < path.size() - 1:
			continue

		var segment_length: float = maxf(next_at - previous_at, 0.001)
		var segment_progress: float = clampf((progress - previous_at) / segment_length, 0.0, 1.0)
		var eased_progress: float = _ease_projectile_progress(segment_progress, str(next_point.get("ease", "linear")))
		var previous_position: Vector2 = previous_point.get("position", Vector2.ZERO) as Vector2
		var next_position: Vector2 = next_point.get("position", Vector2.ZERO) as Vector2
		var previous_scale: float = float(previous_point.get("scale", 1.0))
		var next_scale: float = float(next_point.get("scale", 1.0))
		return {
			"position": previous_position.lerp(next_position, eased_progress),
			"scale": lerpf(previous_scale, next_scale, segment_progress),
		}

	var last_point: Dictionary = _get_projectile_path_point(path[path.size() - 1])
	return {
		"position": last_point.get("position", Vector2.ZERO),
		"scale": float(last_point.get("scale", 1.0)),
	}

func _get_projectile_path_point(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}

	var point := value as Dictionary
	return {
		"at": float(point.get("at", 0.0)),
		"position": _vector2_from_value(point.get("position", [0.0, 0.0])),
		"scale": float(point.get("scale", 1.0)),
		"ease": str(point.get("ease", "linear")),
	}

func _ease_projectile_progress(progress: float, ease: String) -> float:
	match ease:
		"ease_out_quad":
			return 1.0 - pow(1.0 - progress, 2.0)
		"smoothstep":
			return progress * progress * (3.0 - (2.0 * progress))
		_:
			return progress

func _vector2_from_value(value: Variant) -> Vector2:
	if value is Dictionary:
		var dictionary := value as Dictionary
		return Vector2(float(dictionary.get("x", 0.0)), float(dictionary.get("y", 0.0)))
	if value is Array:
		var array := value as Array
		if array.size() >= 2:
			return Vector2(float(array[0]), float(array[1]))

	return Vector2.ZERO


func _update_pink_visual(index: int) -> void:
	if not show_pink_visual:
		return

	if index < 8:
		pink_overlay_alpha = maxf(pink_overlay_alpha, overlay_peak_alpha * 0.6)
	elif index >= 28 and index <= 46:
		pink_overlay_alpha = maxf(pink_overlay_alpha, overlay_peak_alpha)
	elif index > 46:
		pink_overlay_alpha = maxf(pink_overlay_alpha, overlay_peak_alpha * 0.4)
	queue_redraw()


func _apply_timing_events(index: int) -> void:
	var timings: Array = data["timings"] as Array
	for event_value: Variant in timings:
		if not event_value is Dictionary:
			continue

		var event: Dictionary = event_value as Dictionary
		if int(event["frame"]) != index:
			continue

		var event_key: String = "%s:%s:%s" % [event["frame"], event["type"], event["name"]]
		if played_events.has(event_key):
			continue
		played_events[event_key] = true

		match int(event["type"]):
			0:
				_play_sound_event(event)
			1:
				if show_timing_backgrounds:
					bg.modulate.a = 1.0
					bg_hide_frame = _timing_hide_frame(index, event)
			2:
				if show_timing_backgrounds:
					bg.modulate.a = float(event["opacity"]) / 255.0 if event["opacity"] != null else bg.modulate.a
					bg_hide_frame = _timing_hide_frame(index, event) if bg.modulate.a > 0.0 else -1
			3:
				if show_timing_foregrounds:
					fg.modulate.a = float(event["opacity"]) / 255.0 if event["opacity"] != null else 1.0
					fg_hide_frame = _timing_hide_frame(index, event)
			4:
				if show_timing_foregrounds:
					fg.modulate.a = float(event["opacity"]) / 255.0 if event["opacity"] != null else fg.modulate.a
					fg_hide_frame = _timing_hide_frame(index, event) if fg.modulate.a > 0.0 else -1


func _expire_timing_layers(index: int) -> void:
	if bg_hide_frame >= 0 and index >= bg_hide_frame:
		bg.modulate.a = 0.0
		bg_hide_frame = -1
	if fg_hide_frame >= 0 and index >= fg_hide_frame:
		fg.modulate.a = 0.0
		fg_hide_frame = -1


func _timing_hide_frame(index: int, event: Dictionary) -> int:
	var duration: int = int(event.get("duration", 0))
	return index + maxi(1, duration) if duration > 0 else -1


func _play_sound_event(event: Dictionary) -> void:
	var player: AudioStreamPlayer = sound_players.get(str(event["name"]), null) as AudioStreamPlayer
	if player == null:
		return

	var volume: float = float(event["volume"]) / 100.0
	var pitch: float = float(event["pitch"]) / 100.0
	player.volume_db = linear_to_db(volume)
	player.pitch_scale = pitch
	player.play()
