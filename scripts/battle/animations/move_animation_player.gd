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
@export var timing_foreground_scale: Vector2 = Vector2.ONE
@export_range(0.0, 1.0, 0.01) var foreground_opacity_multiplier: float = 1.0
@export var show_pink_visual: bool = true
@export var show_sheet_sprites: bool = true
@export var overlay_fill_enabled: bool = true
@export var projectile_config: Dictionary = {}
@export var orb_config: Dictionary = {}
@export var orb_projectile_config: Dictionary = {}
@export var energy_blast_config: Dictionary = {}
@export var water_splash_config: Dictionary = {}
@export var electric_switch_config: Dictionary = {}
@export var fire_stream_config: Dictionary = {}
@export var heat_wave_config: Dictionary = {}
@export var solar_beam_config: Dictionary = {}
@export var solar_charge_config: Dictionary = {}
@export var celestial_charge_config: Dictionary = {}
@export var dragon_dance_config: Dictionary = {}
@export var flash_config: Dictionary = {}
@export var shake_config: Dictionary = {}
@export var visual_color: Color = Color(1.0, 0.2, 0.75, 1.0)
@export var sprite_tint: Color = Color(1.0, 0.78, 1.0, 1.0)
@export var reverse_battlefield: bool = false
@export_range(0.0, 0.5, 0.01) var overlay_peak_alpha: float = 0.20
@export_range(0, 48, 1) var sparkle_count: int = 14
@export_range(0.25, 4.0, 0.05) var speed_scale: float = 1.0
@export_range(0.1, 2.0, 0.05) var sprite_zoom_multiplier: float = 1.0
@export_range(0.25, 2.0, 0.05) var sprite_position_scale: float = 1.0
@export var sprite_position_anchor: Vector2 = Vector2(128, 224)
@export var sprite_position_offset: Vector2 = Vector2.ZERO
@export var sheet_visual_offset: Vector2 = Vector2.ZERO
@export_range(0.5, 4.0, 0.05) var sparkle_size_multiplier: float = 1.0
@export var sparkle_center: Vector2 = Vector2(256, 188)
@export_range(8.0, 180.0, 1.0) var sparkle_radius_min: float = 26.0
@export_range(8.0, 220.0, 1.0) var sparkle_radius_max: float = 78.0
@export_range(-8, 8, 1) var pattern_offset: int = 0
@export_range(-1, 999, 1) var pattern_override: int = -1
@export_range(0, 999, 1) var sheet_pattern_min: int = 0
@export_range(0, 999, 1) var sheet_pattern_max: int = 999
@export_range(0, 999, 1) var sheet_visible_start_frame: int = 0
@export_range(0, 999, 1) var animation_start_frame: int = 0
@export_range(-1, 999, 1) var animation_end_frame: int = -1

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
var base_position := Vector2.ZERO
var base_position_active := false
var shake_applied := false
var timing_background_detached := false

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

	frame_index = clampi(animation_start_frame, 0, maxi((data.get("frames", []) as Array).size() - 1, 0))
	frame_time = 0.0
	pink_overlay_alpha = 0.0
	bg_hide_frame = -1
	fg_hide_frame = -1
	base_position = position
	base_position_active = true
	shake_applied = false
	played_events.clear()
	is_playing = true
	_apply_frame(frame_index)
	_apply_shake_offset()


func stop() -> void:
	is_playing = false
	for sprite: Sprite2D in sprites:
		sprite.visible = false
	bg.modulate.a = 0.0
	fg.modulate.a = 0.0
	bg_hide_frame = -1
	fg_hide_frame = -1
	pink_overlay_alpha = 0.0
	_restore_base_position()
	_dispose_detached_timing_background()
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
		var final_frame: int = mini(
			(data["frames"] as Array).size() - 1,
			animation_end_frame if animation_end_frame >= 0 else (data["frames"] as Array).size() - 1
		)
		if frame_index > final_frame:
			if loop:
				frame_index = clampi(animation_start_frame, 0, final_frame)
				played_events.clear()
			else:
				stop()
				animation_finished.emit()
				if free_on_finish:
					queue_free()
				return
		_apply_frame(frame_index)
	_apply_shake_offset()


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
	if sheet_texture == null and (show_sheet_sprites or _projectile_enabled()):
		push_error("Could not load move animation sheet: %s" % sheet_path)
		return

	if background_texture_override != null:
		bg.texture = background_texture_override
	elif background_path != "":
		bg.texture = load(background_path) as Texture2D
	bg.centered = false
	bg.modulate.a = 0.0
	add_child(bg)

	if sheet_texture != null:
		for i: int in range(32):
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = sheet_texture
			sprite.region_enabled = true
			sprite.visible = false
			sprite.centered = true
			sprites.append(sprite)
			add_child(sprite)

	if _projectile_enabled() and sheet_texture != null:
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
	fg.scale = timing_foreground_scale
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


func move_timing_background_to(parent_node: Node, sibling_index: int) -> void:
	if bg.texture == null or bg.get_parent() != self or parent_node == null:
		return

	bg.reparent(parent_node, true)
	parent_node.move_child(bg, clampi(sibling_index, 0, parent_node.get_child_count() - 1))
	timing_background_detached = true


func _dispose_detached_timing_background() -> void:
	if not timing_background_detached:
		return
	if is_instance_valid(bg):
		bg.queue_free()
	timing_background_detached = false


func _draw() -> void:
	var should_draw_overlay: bool = show_pink_visual and pink_overlay_alpha > 0.0

	if should_draw_overlay and overlay_fill_enabled:
		draw_rect(Rect2(Vector2.ZERO, Vector2(512, 384)), Color(visual_color.r, visual_color.g, visual_color.b, pink_overlay_alpha), true)
	_draw_flash_visual()
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
	_draw_energy_blast_visual()
	_draw_water_splash_visual()
	_draw_electric_switch_visual()
	_draw_fire_stream_visual()
	_draw_heat_wave_visual()
	_draw_solar_beam_visual()
	_draw_solar_charge_visual()
	_draw_celestial_charge_visual()
	_draw_dragon_dance_visual()


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


func _draw_flash_visual() -> void:
	if not bool(flash_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(frame_index) / float(total_frames), 0.0, 1.0)
	var start: float = clampf(float(flash_config.get("start", 0.62)), 0.0, 1.0)
	var peak: float = clampf(float(flash_config.get("peak", 0.72)), start, 1.0)
	var end: float = clampf(float(flash_config.get("end", 0.9)), peak, 1.0)
	if progress < start or progress > end:
		return

	var alpha: float
	if progress <= peak:
		alpha = clampf((progress - start) / maxf(peak - start, 0.001), 0.0, 1.0)
	else:
		alpha = clampf((end - progress) / maxf(end - peak, 0.001), 0.0, 1.0)
	alpha *= float(flash_config.get("alpha", 0.16))
	if alpha <= 0.01:
		return

	var color := _color_from_value(flash_config.get("color", [0.72, 0.95, 1.0, 1.0]), Color(0.72, 0.95, 1.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, Vector2(512, 384)), _color_with_alpha(color, alpha), true)


func _draw_energy_blast_visual() -> void:
	if not bool(energy_blast_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(frame_index) / float(total_frames), 0.0, 1.0)
	var visible_start: float = clampf(float(energy_blast_config.get("visible_start", 0.0)), 0.0, 1.0)
	var visible_end: float = clampf(float(energy_blast_config.get("visible_end", 1.0)), visible_start, 1.0)
	if progress < visible_start or progress > visible_end:
		return

	var alpha: float = _get_energy_blast_alpha(progress, visible_start, visible_end)
	if alpha <= 0.02:
		return

	var projectile_state: Dictionary = _get_projectile_state_from_config(progress, energy_blast_config)
	var center: Vector2 = _projectile_battlefield_position(projectile_state.get("position", Vector2.ZERO) as Vector2, energy_blast_config)
	var scale_value: float = float(projectile_state.get("scale", 1.0))
	var base_radius: float = float(energy_blast_config.get("radius", 18.0))
	var radius: float = base_radius * scale_value * (1.0 + 0.08 * sin(float(frame_index) * 0.72))
	var aura_color: Color = _color_from_value(energy_blast_config.get("aura_color", [0.08, 0.62, 1.0, 1.0]), Color(0.08, 0.62, 1.0, 1.0))
	var core_color: Color = _color_from_value(energy_blast_config.get("core_color", [0.92, 1.0, 1.0, 1.0]), Color(0.92, 1.0, 1.0, 1.0))
	var ring_color: Color = _color_from_value(energy_blast_config.get("ring_color", [0.28, 0.95, 1.0, 1.0]), Color(0.28, 0.95, 1.0, 1.0))
	var shadow_color: Color = _color_from_value(energy_blast_config.get("shadow_color", [0.02, 0.12, 0.24, 1.0]), Color(0.02, 0.12, 0.24, 1.0))

	var trail_count: int = maxi(0, int(energy_blast_config.get("trail_count", 5)))
	var trail_spacing: float = float(energy_blast_config.get("trail_spacing", 0.035))
	for trail_index: int in range(trail_count, 0, -1):
		var trail_progress: float = clampf(progress - float(trail_index) * trail_spacing, visible_start, visible_end)
		if trail_progress >= progress:
			continue
		var trail_state: Dictionary = _get_projectile_state_from_config(trail_progress, energy_blast_config)
		var trail_center: Vector2 = _projectile_battlefield_position(trail_state.get("position", Vector2.ZERO) as Vector2, energy_blast_config)
		var trail_scale: float = float(trail_state.get("scale", 1.0))
		var trail_alpha: float = alpha * (1.0 - (float(trail_index) / float(trail_count + 1))) * 0.24
		draw_line(trail_center, center, _color_with_alpha(aura_color, trail_alpha), maxf(1.0, radius * 0.22))
		draw_circle(trail_center, base_radius * trail_scale * 0.66, _color_with_alpha(aura_color, trail_alpha * 0.7))

	draw_circle(center + Vector2(radius * 0.16, radius * 0.18), radius * 1.75, _color_with_alpha(shadow_color, alpha * 0.18))
	draw_circle(center, radius * 1.85, _color_with_alpha(aura_color, alpha * 0.18))
	draw_circle(center, radius * 1.05, _color_with_alpha(aura_color, alpha * 0.46))
	draw_circle(center, radius * 0.54, _color_with_alpha(core_color, alpha * 0.9))

	var spin: float = float(frame_index) * 0.24
	draw_arc(center, radius * 1.24, spin, spin + PI * 1.15, 48, _color_with_alpha(ring_color, alpha * 0.85), maxf(1.7, radius * 0.11))
	draw_arc(center, radius * 1.58, -spin * 0.82, -spin * 0.82 + PI * 0.78, 48, _color_with_alpha(core_color, alpha * 0.55), maxf(1.2, radius * 0.07))

	var ray_count: int = maxi(0, int(energy_blast_config.get("ray_count", 7)))
	for ray_index: int in range(ray_count):
		var angle: float = spin + float(ray_index) * TAU / float(ray_count)
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.72
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * (1.25 + 0.18 * sin(spin + float(ray_index)))
		draw_line(inner, outer, _color_with_alpha(ring_color, alpha * 0.42), 1.3)

	_draw_energy_blast_impact(progress, visible_end, aura_color, core_color, ring_color)


func _draw_energy_blast_impact(progress: float, visible_end: float, aura_color: Color, core_color: Color, ring_color: Color) -> void:
	var impact_start: float = clampf(float(energy_blast_config.get("impact_start", 0.68)), 0.0, visible_end)
	if progress < impact_start:
		return

	var impact_progress: float = clampf((progress - impact_start) / maxf(visible_end - impact_start, 0.001), 0.0, 1.0)
	var impact_state: Dictionary = _get_projectile_state_from_config(1.0, energy_blast_config)
	var center: Vector2 = _projectile_battlefield_position(impact_state.get("position", Vector2.ZERO) as Vector2, energy_blast_config)
	var impact_alpha: float = (1.0 - impact_progress) * float(energy_blast_config.get("impact_alpha", 0.78))
	if impact_alpha <= 0.02:
		return

	var impact_radius: float = float(energy_blast_config.get("impact_radius", 46.0)) * (0.38 + impact_progress * 0.9)
	draw_circle(center, impact_radius * 0.72, _color_with_alpha(aura_color, impact_alpha * 0.16))
	for ring_index: int in range(3):
		draw_arc(center, impact_radius + float(ring_index) * 9.0, 0.0, TAU, 72, _color_with_alpha(ring_color, impact_alpha * (0.7 - float(ring_index) * 0.16)), 2.0)

	var burst_count: int = maxi(4, int(energy_blast_config.get("impact_ray_count", 10)))
	for burst_index: int in range(burst_count):
		var angle: float = float(burst_index) * TAU / float(burst_count) + float(frame_index) * 0.05
		var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * impact_radius * 0.34
		var end: Vector2 = center + Vector2(cos(angle), sin(angle)) * impact_radius * (1.02 + 0.24 * sin(float(burst_index) + float(frame_index) * 0.2))
		draw_line(start, end, _color_with_alpha(core_color, impact_alpha * 0.58), 1.5)


func _draw_solar_charge_visual() -> void:
	if not bool(solar_charge_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(frame_index) / float(total_frames), 0.0, 1.0)
	var alpha: float = _get_timed_alpha(progress, 0.0, 1.0, solar_charge_config)
	if alpha <= 0.02:
		return

	var center := _battlefield_position(_vector2_from_value(solar_charge_config.get("center", [128.0, 224.0])))
	var ray_count: int = maxi(3, int(solar_charge_config.get("ray_count", 7)))
	var ray_height: float = float(solar_charge_config.get("ray_height", 132.0))
	var ray_spread: float = float(solar_charge_config.get("ray_spread", 96.0))
	var outer_color := _color_from_value(solar_charge_config.get("outer_color", [0.58, 0.94, 0.16, 1.0]), Color(0.58, 0.94, 0.16, 1.0))
	var core_color := _color_from_value(solar_charge_config.get("core_color", [1.0, 1.0, 0.72, 1.0]), Color(1.0, 1.0, 0.72, 1.0))
	var phase: float = float(frame_index) * 0.28

	for ray_index: int in range(ray_count):
		var ray_ratio: float = (float(ray_index) / float(ray_count - 1)) * 2.0 - 1.0 if ray_count > 1 else 0.0
		var origin := center + Vector2(ray_ratio * ray_spread + sin(phase + float(ray_index)) * 7.0, -ray_height - float(ray_index % 3) * 12.0)
		var landing := center + Vector2(ray_ratio * 16.0, -10.0 + cos(phase + float(ray_index)) * 6.0)
		var ray_alpha: float = alpha * (0.28 + 0.3 * absf(sin(phase + float(ray_index) * 1.3)))
		draw_line(origin, landing, _color_with_alpha(outer_color, ray_alpha * 0.38), 8.0)
		draw_line(origin, landing, _color_with_alpha(core_color, ray_alpha), 2.2)

	var pulse: float = 0.84 + 0.16 * sin(phase * 1.5)
	var orb_radius: float = float(solar_charge_config.get("orb_radius", 21.0)) * pulse
	draw_circle(center, orb_radius * 1.7, _color_with_alpha(outer_color, alpha * 0.11))
	draw_circle(center, orb_radius * 0.9, _color_with_alpha(outer_color, alpha * 0.28))
	draw_circle(center, orb_radius * 0.42, _color_with_alpha(core_color, alpha * 0.9))
	for arc_index: int in range(3):
		var arc_radius: float = orb_radius * (1.15 + float(arc_index) * 0.42)
		var arc_start: float = phase + float(arc_index) * 2.05
		draw_arc(center, arc_radius, arc_start, arc_start + PI * 1.12, 24, _color_with_alpha(core_color, alpha * 0.72), 1.8)


func _draw_celestial_charge_visual() -> void:
	if not bool(celestial_charge_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(frame_index) / float(total_frames), 0.0, 1.0)
	var visible_start: float = clampf(float(celestial_charge_config.get("visible_start", 0.0)), 0.0, 1.0)
	var visible_end: float = clampf(float(celestial_charge_config.get("visible_end", 0.45)), visible_start, 1.0)
	if progress < visible_start or progress > visible_end:
		return

	var alpha := _get_timed_alpha(progress, visible_start, visible_end, celestial_charge_config)
	if alpha <= 0.02:
		return

	var center := _battlefield_position(_vector2_from_value(celestial_charge_config.get("center", [128.0, 224.0])))
	var outer_color := _color_from_value(celestial_charge_config.get("outer_color", [0.58, 0.28, 1.0, 1.0]), Color(0.58, 0.28, 1.0, 1.0))
	var core_color := _color_from_value(celestial_charge_config.get("core_color", [1.0, 0.86, 1.0, 1.0]), Color(1.0, 0.86, 1.0, 1.0))
	var radius := maxf(float(celestial_charge_config.get("radius", 46.0)), 4.0)
	var ground_squash := clampf(float(celestial_charge_config.get("ground_squash", 0.32)), 0.1, 1.0)
	var phase := float(frame_index) * 0.22
	draw_set_transform(center, 0.0, Vector2(1.0, ground_squash))
	draw_circle(Vector2.ZERO, radius * 0.72, _color_with_alpha(outer_color, alpha * 0.09))
	for ring_index: int in range(3):
		var ring_radius := radius * (0.58 + float(ring_index) * 0.24)
		var start := phase * (0.76 + float(ring_index) * 0.13) + float(ring_index) * 1.8
		draw_arc(Vector2.ZERO, ring_radius, start, start + PI * 1.22, 32, _color_with_alpha(core_color, alpha * (0.72 - float(ring_index) * 0.14)), 1.8)
	draw_set_transform(Vector2.ZERO)

	var particle_count := maxi(3, int(celestial_charge_config.get("particle_count", 14)))
	var particle_height := maxf(float(celestial_charge_config.get("particle_height", 72.0)), 1.0)
	var particle_spread := maxf(float(celestial_charge_config.get("particle_spread", 52.0)), 1.0)
	for particle_index: int in range(particle_count):
		var life := fmod(float(particle_index) * 0.173 + progress * 2.6, 1.0)
		var particle_phase := phase + float(particle_index) * 1.91
		var position := center + Vector2(
			sin(particle_phase) * particle_spread * (0.28 + life * 0.72),
			-particle_height * life
		)
		var size := 1.4 + float(particle_index % 3) * 0.72
		var particle_alpha := alpha * (0.2 + 0.52 * (1.0 - life))
		draw_circle(position, size, _color_with_alpha(core_color, particle_alpha))
		draw_line(position + Vector2(-size * 1.6, 0.0), position + Vector2(size * 1.6, 0.0), _color_with_alpha(outer_color, particle_alpha * 0.74), 1.0)


func _draw_dragon_dance_visual() -> void:
	if not bool(dragon_dance_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(frame_index) / float(total_frames), 0.0, 1.0)
	var visible_start: float = clampf(float(dragon_dance_config.get("visible_start", 0.0)), 0.0, 1.0)
	var visible_end: float = clampf(float(dragon_dance_config.get("visible_end", 1.0)), visible_start, 1.0)
	if progress < visible_start or progress > visible_end:
		return

	var alpha := _get_timed_alpha(progress, visible_start, visible_end, dragon_dance_config)
	if alpha <= 0.02:
		return

	var center := _battlefield_position(_vector2_from_value(dragon_dance_config.get("center", [128.0, 224.0])))
	center += _vector2_from_value(dragon_dance_config.get("center_offset", [0.0, 0.0]))
	var ribbon_color := _color_from_value(dragon_dance_config.get("ribbon_color", [1.0, 0.28, 0.9, 1.0]), Color(1.0, 0.28, 0.9, 1.0))
	var core_color := _color_from_value(dragon_dance_config.get("core_color", [1.0, 0.82, 1.0, 1.0]), Color(1.0, 0.82, 1.0, 1.0))
	var ring_radius := maxf(float(dragon_dance_config.get("radius", 58.0)), 8.0)
	var ring_count := maxi(2, int(dragon_dance_config.get("ring_count", 4)))
	var phase := float(frame_index) * float(dragon_dance_config.get("rotation_speed", 0.34))

	for ring_index: int in range(ring_count):
		var ring_progress := float(ring_index) / float(maxi(ring_count - 1, 1))
		var radius := ring_radius * (0.68 + ring_progress * 0.42)
		var height := lerpf(18.0, -34.0, ring_progress) + sin(phase * 0.7 + float(ring_index) * 1.8) * 5.0
		var angle := phase * (1.0 if ring_index % 2 == 0 else -0.82) + float(ring_index) * 1.42
		var start := angle
		var end := start + PI * 1.42
		var ring_alpha := alpha * (0.52 + (1.0 - ring_progress) * 0.27)
		draw_set_transform(center + Vector2(0.0, height), 0.0, Vector2(1.0, 0.28))
		draw_arc(Vector2.ZERO, radius, start, end, 40, _color_with_alpha(ribbon_color, ring_alpha * 0.34), 5.2)
		draw_arc(Vector2.ZERO, radius, start, end, 40, _color_with_alpha(ribbon_color, ring_alpha), 2.2)
		draw_arc(Vector2.ZERO, radius - 2.0, start + 0.03, end - 0.03, 40, _color_with_alpha(core_color, ring_alpha * 0.82), 0.85)
		draw_set_transform(Vector2.ZERO)

	var spark_count := maxi(6, int(dragon_dance_config.get("spark_count", 18)))
	var spark_height := maxf(float(dragon_dance_config.get("spark_height", 84.0)), 12.0)
	var spark_spread := maxf(float(dragon_dance_config.get("spark_spread", 62.0)), 12.0)
	for spark_index: int in range(spark_count):
		var life := fmod(progress * 2.15 + float(spark_index) * 0.173, 1.0)
		var spark_phase := phase * 1.3 + float(spark_index) * 2.18
		var spark_position := center + Vector2(
			cos(spark_phase) * spark_spread * (0.24 + life * 0.76),
			-spark_height * life + sin(spark_phase * 1.6) * 8.0
		)
		var size := 1.2 + float(spark_index % 3) * 0.7
		var spark_alpha := alpha * (0.28 + (1.0 - life) * 0.5)
		draw_circle(spark_position, size, _color_with_alpha(core_color, spark_alpha))
		draw_line(spark_position + Vector2(-size * 1.8, 0.0), spark_position + Vector2(size * 1.8, 0.0), _color_with_alpha(ribbon_color, spark_alpha * 0.78), 0.9)


func _draw_solar_beam_visual() -> void:
	if not bool(solar_beam_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(frame_index) / float(total_frames), 0.0, 1.0)
	var visible_start: float = clampf(float(solar_beam_config.get("visible_start", 0.0)), 0.0, 1.0)
	var visible_end: float = clampf(float(solar_beam_config.get("visible_end", 1.0)), visible_start, 1.0)
	if progress < visible_start or progress > visible_end:
		return

	var alpha: float = _get_timed_alpha(progress, visible_start, visible_end, solar_beam_config)
	if alpha <= 0.02:
		return

	var source_state: Dictionary = _get_projectile_state_from_config(0.0, solar_beam_config)
	var target_state: Dictionary = _get_projectile_state_from_config(1.0, solar_beam_config)
	var source := _projectile_battlefield_position(source_state.get("position", Vector2.ZERO) as Vector2, solar_beam_config)
	var target := _projectile_battlefield_position(target_state.get("position", Vector2.ZERO) as Vector2, solar_beam_config)
	var beam_vector := target - source
	if beam_vector.length_squared() <= 1.0:
		return

	var direction := beam_vector.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var pulse := 0.78 + 0.22 * sin(float(frame_index) * 0.82)
	var outer_width := float(solar_beam_config.get("outer_width", 18.0)) * pulse
	var middle_width := float(solar_beam_config.get("middle_width", 10.0)) * pulse
	var core_width := float(solar_beam_config.get("core_width", 4.0)) * pulse
	var outer_color := _color_from_value(solar_beam_config.get("outer_color", [0.48, 0.92, 0.12, 1.0]), Color(0.48, 0.92, 0.12, 1.0))
	var middle_color := _color_from_value(solar_beam_config.get("middle_color", [0.84, 1.0, 0.22, 1.0]), Color(0.84, 1.0, 0.22, 1.0))
	var core_color := _color_from_value(solar_beam_config.get("core_color", [1.0, 1.0, 0.86, 1.0]), Color(1.0, 1.0, 0.86, 1.0))
	var beam_phase: float = float(frame_index) * 0.34
	var source_radius: float = float(solar_beam_config.get("source_radius", 24.0)) * pulse
	draw_circle(source, source_radius * 1.45, _color_with_alpha(outer_color, alpha * 0.13))
	draw_circle(source, source_radius * 0.82, _color_with_alpha(middle_color, alpha * 0.2))
	draw_circle(source, source_radius * 0.38, _color_with_alpha(core_color, alpha * 0.86))
	for arc_index: int in range(3):
		var arc_radius: float = source_radius * (0.9 + float(arc_index) * 0.36)
		var arc_start: float = beam_phase * (1.0 + float(arc_index) * 0.12) + float(arc_index) * 1.8
		draw_arc(source, arc_radius, arc_start, arc_start + PI * 1.18, 24, _color_with_alpha(middle_color, alpha * 0.72), 2.0)

	var beam_start: float = clampf(float(solar_beam_config.get("beam_start", visible_start)), visible_start, visible_end)
	if progress < beam_start:
		return
	var beam_fade_in: float = maxf(float(solar_beam_config.get("beam_fade_in", 0.08)), 0.001)
	var beam_alpha: float = alpha * clampf((progress - beam_start) / beam_fade_in, 0.0, 1.0)
	var segments: int = maxi(8, int(solar_beam_config.get("segments", 24)))
	var ribbon_count: int = maxi(1, int(solar_beam_config.get("ribbon_count", 3)))
	var curve_amplitude: float = float(solar_beam_config.get("curve_amplitude", 12.0))

	# The soft core keeps the attack legible, while the three offset ribbons give
	# Solar Beam the looping, gathered-light silhouette of the reference.
	var previous_core := source
	for segment_index: int in range(1, segments + 1):
		var t: float = float(segment_index) / float(segments)
		var envelope: float = sin(PI * t)
		var core_offset := perpendicular * sin(t * TAU * 1.12 + beam_phase) * curve_amplitude * 0.22 * envelope
		var core_point := source.lerp(target, t) + core_offset
		var segment_alpha: float = beam_alpha * (0.62 + 0.28 * sin(t * PI))
		draw_line(previous_core, core_point, _color_with_alpha(outer_color, segment_alpha * 0.34), outer_width)
		draw_line(previous_core, core_point, _color_with_alpha(middle_color, segment_alpha * 0.72), middle_width)
		draw_line(previous_core, core_point, _color_with_alpha(core_color, segment_alpha), core_width)
		previous_core = core_point

	for ribbon_index: int in range(ribbon_count):
		var ribbon_phase: float = beam_phase + float(ribbon_index) * TAU / float(ribbon_count)
		var previous_ribbon := source
		for segment_index: int in range(1, segments + 1):
			var t: float = float(segment_index) / float(segments)
			var envelope: float = sin(PI * t)
			var wave := sin(t * TAU * 1.25 + ribbon_phase) * curve_amplitude * envelope
			var ribbon_point := source.lerp(target, t) + perpendicular * wave
			var ribbon_alpha: float = beam_alpha * (0.34 + 0.22 * absf(sin(t * TAU + ribbon_phase)))
			draw_line(previous_ribbon, ribbon_point, _color_with_alpha(middle_color, ribbon_alpha), 2.3)
			if segment_index % 3 == 0:
				draw_circle(ribbon_point, 1.8, _color_with_alpha(core_color, ribbon_alpha * 0.9))
			previous_ribbon = ribbon_point

	var impact_progress: float = clampf((progress - float(solar_beam_config.get("impact_start", 0.66))) / maxf(visible_end - float(solar_beam_config.get("impact_start", 0.66)), 0.001), 0.0, 1.0)
	if impact_progress <= 0.0:
		return
	var impact_radius: float = float(solar_beam_config.get("impact_radius", 46.0)) * (0.35 + impact_progress * 0.9)
	var impact_alpha: float = beam_alpha * (1.0 - impact_progress) * float(solar_beam_config.get("impact_alpha", 0.8))
	draw_circle(target, impact_radius * 0.5, _color_with_alpha(middle_color, impact_alpha * 0.22))
	for ray_index: int in range(maxi(4, int(solar_beam_config.get("impact_ray_count", 12)))):
		var angle := float(ray_index) * TAU / float(maxi(4, int(solar_beam_config.get("impact_ray_count", 12)))) + float(frame_index) * 0.08
		var ray_start := target + Vector2(cos(angle), sin(angle)) * impact_radius * 0.2
		var ray_end := target + Vector2(cos(angle), sin(angle)) * impact_radius
		draw_line(ray_start, ray_end, _color_with_alpha(core_color, impact_alpha * 0.72), 1.8)

	_draw_solar_beam_impact_snowflakes(target, impact_radius, impact_alpha)


func _draw_solar_beam_impact_snowflakes(center: Vector2, impact_radius: float, impact_alpha: float) -> void:
	var snowflake_count := maxi(0, int(solar_beam_config.get("impact_snowflake_count", 0)))
	if snowflake_count <= 0:
		return

	var snowflake_color := _color_from_value(solar_beam_config.get("impact_snowflake_color", [0.86, 0.98, 1.0, 1.0]), Color(0.86, 0.98, 1.0, 1.0))
	var snowflake_size := maxf(float(solar_beam_config.get("impact_snowflake_size", 5.0)), 1.0)
	var snowflake_spread := maxf(float(solar_beam_config.get("impact_snowflake_spread", 1.0)), 0.1)
	var phase := float(frame_index) * 0.19
	for snowflake_index: int in range(snowflake_count):
		var ratio := fmod(float(snowflake_index) * 0.618 + phase * 0.11, 1.0)
		var angle := float(snowflake_index) * 2.399 + phase * (0.7 + float(snowflake_index % 3) * 0.08)
		var distance := impact_radius * snowflake_spread * (0.25 + ratio * 0.82)
		var snowflake_center := center + Vector2(cos(angle), sin(angle)) * distance
		var size := snowflake_size * (0.65 + 0.55 * ratio)
		var alpha := impact_alpha * (0.22 + 0.46 * (1.0 - ratio))
		for arm_index: int in range(3):
			var arm_angle := angle + float(arm_index) * PI / 3.0
			var arm := Vector2(cos(arm_angle), sin(arm_angle)) * size
			draw_line(snowflake_center - arm, snowflake_center + arm, _color_with_alpha(snowflake_color, alpha), 1.25)
		draw_circle(snowflake_center, size * 0.22, _color_with_alpha(snowflake_color, alpha * 0.8))


func _draw_water_splash_visual() -> void:
	if not bool(water_splash_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(frame_index) / float(total_frames), 0.0, 1.0)
	var visible_start: float = clampf(float(water_splash_config.get("visible_start", 0.0)), 0.0, 1.0)
	var visible_end: float = clampf(float(water_splash_config.get("visible_end", 1.0)), visible_start, 1.0)
	if progress < visible_start or progress > visible_end:
		return

	var alpha: float = _get_timed_alpha(progress, visible_start, visible_end, water_splash_config)
	if alpha <= 0.02:
		return

	var water_color: Color = _color_from_value(water_splash_config.get("water_color", [0.12, 0.7, 1.0, 1.0]), Color(0.12, 0.7, 1.0, 1.0))
	var foam_color: Color = _color_from_value(water_splash_config.get("foam_color", [0.84, 0.98, 1.0, 1.0]), Color(0.84, 0.98, 1.0, 1.0))
	var path_value: Variant = water_splash_config.get("reverse_path", []) if _uses_explicit_reverse_path(water_splash_config) else water_splash_config.get("path", [])
	if not path_value is Array or (path_value as Array).is_empty():
		return

	var current_state: Dictionary = _get_projectile_state_from_config(progress, water_splash_config)
	var current: Vector2 = _projectile_battlefield_position(current_state.get("position", Vector2.ZERO) as Vector2, water_splash_config)

	var trail_progress: float = clampf((progress - visible_start) / maxf(visible_end - visible_start, 0.001), 0.0, 1.0)
	var trail_start: float = clampf(trail_progress - float(water_splash_config.get("trail_length", 0.34)), 0.0, 1.0)
	var segments: int = maxi(8, int(water_splash_config.get("segments", 18)))
	var previous_state: Dictionary = _get_projectile_state_from_config(trail_start, water_splash_config)
	var previous: Vector2 = _projectile_battlefield_position(previous_state.get("position", Vector2.ZERO) as Vector2, water_splash_config)
	for segment_index: int in range(1, segments + 1):
		var t: float = lerpf(trail_start, trail_progress, float(segment_index) / float(segments))
		var point_state: Dictionary = _get_projectile_state_from_config(t, water_splash_config)
		var point: Vector2 = _projectile_battlefield_position(point_state.get("position", Vector2.ZERO) as Vector2, water_splash_config)
		var segment_alpha: float = alpha * (0.3 + 0.7 * float(segment_index) / float(segments))
		draw_line(previous, point, _color_with_alpha(water_color, segment_alpha * 0.62), float(water_splash_config.get("trail_width", 5.0)))
		draw_line(previous + Vector2(0.0, -2.0), point + Vector2(0.0, -2.0), _color_with_alpha(foam_color, segment_alpha * 0.36), 1.7)
		previous = point

	var droplet_count: int = maxi(0, int(water_splash_config.get("droplet_count", 8)))
	for droplet_index: int in range(droplet_count):
		var droplet_t: float = clampf(trail_progress - float(droplet_index) * 0.055, 0.0, 1.0)
		var droplet_state: Dictionary = _get_projectile_state_from_config(droplet_t, water_splash_config)
		var base: Vector2 = _projectile_battlefield_position(droplet_state.get("position", Vector2.ZERO) as Vector2, water_splash_config)
		var wave: float = sin(float(frame_index) * 0.42 + float(droplet_index) * 1.7)
		var offset := Vector2(wave * 8.0, -absf(wave) * 9.0 + float(droplet_index % 3) * 3.0)
		var droplet_alpha: float = alpha * (0.72 - float(droplet_index) / float(droplet_count + 2))
		draw_circle(base + offset, 2.5 + float(droplet_index % 2), _color_with_alpha(foam_color, droplet_alpha))

	_draw_water_splash_impact(progress, visible_end, current, water_color, foam_color)


func _draw_water_splash_impact(progress: float, visible_end: float, target: Vector2, water_color: Color, foam_color: Color) -> void:
	var impact_start: float = clampf(float(water_splash_config.get("impact_start", 0.58)), 0.0, visible_end)
	if progress < impact_start:
		return

	var impact_progress: float = clampf((progress - impact_start) / maxf(visible_end - impact_start, 0.001), 0.0, 1.0)
	var impact_alpha: float = (1.0 - impact_progress) * float(water_splash_config.get("impact_alpha", 0.86))
	if impact_alpha <= 0.02:
		return

	var impact_at: float = clampf(float(water_splash_config.get("impact_at", 1.0)), 0.0, 1.0)
	var impact_state: Dictionary = _get_projectile_state_from_config(impact_at, water_splash_config)
	target = _projectile_battlefield_position(impact_state.get("position", target) as Vector2, water_splash_config)
	var radius: float = float(water_splash_config.get("impact_radius", 44.0)) * (0.36 + impact_progress * 0.95)
	draw_arc(target, radius, 0.0, TAU, 72, _color_with_alpha(water_color, impact_alpha * 0.7), 2.4)
	draw_arc(target, radius * 0.68, 0.0, TAU, 56, _color_with_alpha(foam_color, impact_alpha * 0.52), 1.6)

	var splash_count: int = maxi(5, int(water_splash_config.get("impact_splash_count", 12)))
	for splash_index: int in range(splash_count):
		var angle: float = -PI * 0.85 + float(splash_index) * PI * 1.7 / float(splash_count - 1)
		var length: float = radius * (0.72 + 0.32 * sin(float(splash_index) * 1.31 + float(frame_index) * 0.12))
		var start: Vector2 = target + Vector2(cos(angle), sin(angle)) * radius * 0.28
		var end: Vector2 = target + Vector2(cos(angle), sin(angle)) * length
		var color := foam_color if splash_index % 2 == 0 else water_color
		draw_line(start, end, _color_with_alpha(color, impact_alpha * 0.62), 1.7)
		draw_circle(end, 2.0, _color_with_alpha(foam_color, impact_alpha * 0.46))


func _draw_electric_switch_visual() -> void:
	if not bool(electric_switch_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(frame_index) / float(total_frames), 0.0, 1.0)
	var visible_start: float = clampf(float(electric_switch_config.get("visible_start", 0.0)), 0.0, 1.0)
	var visible_end: float = clampf(float(electric_switch_config.get("visible_end", 1.0)), visible_start, 1.0)
	if progress < visible_start or progress > visible_end:
		return

	var alpha: float = _get_timed_alpha(progress, visible_start, visible_end, electric_switch_config)
	if alpha <= 0.02:
		return

	var bolt_color: Color = _color_from_value(electric_switch_config.get("bolt_color", [1.0, 0.88, 0.08, 1.0]), Color(1.0, 0.88, 0.08, 1.0))
	var core_color: Color = _color_from_value(electric_switch_config.get("core_color", [1.0, 1.0, 0.86, 1.0]), Color(1.0, 1.0, 0.86, 1.0))
	var shadow_color: Color = _color_from_value(electric_switch_config.get("shadow_color", [0.38, 0.12, 0.9, 1.0]), Color(0.38, 0.12, 0.9, 1.0))
	_draw_electric_switch_source_aura(progress, alpha, bolt_color, core_color, shadow_color)
	var trail_progress: float = clampf((progress - visible_start) / maxf(visible_end - visible_start, 0.001), 0.0, 1.0)
	var trail_start: float = clampf(trail_progress - float(electric_switch_config.get("trail_length", 0.18)), 0.0, 1.0)
	var segments: int = maxi(6, int(electric_switch_config.get("segments", 12)))
	var previous_state: Dictionary = _get_projectile_state_from_config(trail_start, electric_switch_config)
	var previous: Vector2 = _projectile_battlefield_position(previous_state.get("position", Vector2.ZERO) as Vector2, electric_switch_config)
	for segment_index: int in range(1, segments + 1):
		var t: float = lerpf(trail_start, trail_progress, float(segment_index) / float(segments))
		var point_state: Dictionary = _get_projectile_state_from_config(t, electric_switch_config)
		var point: Vector2 = _projectile_battlefield_position(point_state.get("position", Vector2.ZERO) as Vector2, electric_switch_config)
		var jitter: Vector2 = _electric_jitter(segment_index, t, float(electric_switch_config.get("jitter", 9.0)))
		var next_point := point + jitter
		var segment_alpha: float = alpha * (0.32 + 0.68 * float(segment_index) / float(segments))
		draw_line(previous, next_point, _color_with_alpha(shadow_color, segment_alpha * 0.34), float(electric_switch_config.get("width", 4.8)))
		draw_line(previous, next_point, _color_with_alpha(bolt_color, segment_alpha * 0.9), float(electric_switch_config.get("width", 3.0)))
		draw_line(previous, next_point, _color_with_alpha(core_color, segment_alpha * 0.72), 1.2)
		if segment_index % 3 == 0:
			var branch_direction := (next_point - previous).normalized().orthogonal()
			var branch_length: float = float(electric_switch_config.get("branch_length", 18.0)) * (0.65 + 0.35 * sin(float(frame_index + segment_index)))
			draw_line(next_point, next_point + branch_direction * branch_length, _color_with_alpha(bolt_color, segment_alpha * 0.45), 1.5)
		previous = next_point

	if bool(electric_switch_config.get("core_enabled", true)):
		_draw_electric_switch_core(progress, bolt_color, core_color, shadow_color, alpha)
	_draw_electric_switch_impact(progress, visible_end, bolt_color, core_color, shadow_color)


func _draw_electric_switch_source_aura(progress: float, alpha: float, bolt_color: Color, core_color: Color, shadow_color: Color) -> void:
	if not bool(electric_switch_config.get("source_aura_enabled", false)):
		return

	var start: float = clampf(float(electric_switch_config.get("source_aura_start", 0.0)), 0.0, 1.0)
	var end: float = clampf(float(electric_switch_config.get("source_aura_end", 0.42)), start, 1.0)
	if progress < start or progress > end:
		return

	var fade_in: float = maxf(float(electric_switch_config.get("source_aura_fade_in", 0.06)), 0.001)
	var fade_out: float = maxf(float(electric_switch_config.get("source_aura_fade_out", 0.14)), 0.001)
	var aura_alpha := alpha * minf(
		clampf((progress - start) / fade_in, 0.0, 1.0),
		clampf((end - progress) / fade_out, 0.0, 1.0)
	)
	if aura_alpha <= 0.02:
		return

	var state: Dictionary = _get_projectile_state_from_config(0.0, electric_switch_config)
	var center: Vector2 = _projectile_battlefield_position(state.get("position", Vector2.ZERO) as Vector2, electric_switch_config)
	var base_radius := maxf(float(electric_switch_config.get("source_aura_radius", 46.0)), 4.0)
	var pulse := 0.9 + 0.16 * sin(float(frame_index) * 0.72)
	var radius := base_radius * pulse
	var phase := float(frame_index) * 0.26
	draw_circle(center, radius * 0.78, _color_with_alpha(bolt_color, aura_alpha * 0.08))
	draw_circle(center, radius * 0.44, _color_with_alpha(core_color, aura_alpha * 0.12))

	var arc_count := maxi(2, int(electric_switch_config.get("source_aura_arc_count", 5)))
	for arc_index: int in range(arc_count):
		var arc_radius := radius * (0.62 + float(arc_index) * 0.16)
		var arc_start := phase * (1.0 + float(arc_index) * 0.1) + float(arc_index) * 1.31
		draw_arc(center, arc_radius, arc_start, arc_start + PI * 0.78, 24, _color_with_alpha(core_color, aura_alpha * 0.74), 1.8)

	var bolt_count := maxi(3, int(electric_switch_config.get("source_aura_bolt_count", 8)))
	for bolt_index: int in range(bolt_count):
		var angle := float(bolt_index) * TAU / float(bolt_count) + phase * (0.58 + float(bolt_index % 3) * 0.07)
		var direction := Vector2(cos(angle), sin(angle))
		var perpendicular := direction.orthogonal()
		var inner := center + direction * radius * 0.28
		var middle := center + direction * radius * 0.62 + perpendicular * sin(phase + float(bolt_index) * 1.7) * radius * 0.18
		var outer := center + direction * radius * (0.88 + 0.14 * sin(phase * 1.6 + float(bolt_index)))
		draw_line(inner, middle, _color_with_alpha(shadow_color, aura_alpha * 0.36), 4.4)
		draw_line(middle, outer, _color_with_alpha(shadow_color, aura_alpha * 0.36), 4.4)
		draw_line(inner, middle, _color_with_alpha(bolt_color, aura_alpha * 0.92), 2.3)
		draw_line(middle, outer, _color_with_alpha(bolt_color, aura_alpha * 0.92), 2.3)
		draw_line(inner, middle, _color_with_alpha(core_color, aura_alpha * 0.76), 0.9)
		draw_line(middle, outer, _color_with_alpha(core_color, aura_alpha * 0.76), 0.9)


func _draw_electric_switch_core(progress: float, bolt_color: Color, core_color: Color, shadow_color: Color, alpha: float) -> void:
	var state: Dictionary = _get_projectile_state_from_config(progress, electric_switch_config)
	var center: Vector2 = _projectile_battlefield_position(state.get("position", Vector2.ZERO) as Vector2, electric_switch_config)
	var base_radius: float = float(electric_switch_config.get("core_radius", 13.0))
	var radius: float = base_radius * (1.0 + 0.16 * sin(float(frame_index) * 0.74))
	draw_circle(center, radius * 1.72, _color_with_alpha(shadow_color, alpha * 0.18))
	draw_circle(center, radius * 1.34, _color_with_alpha(bolt_color, alpha * 0.3))
	draw_circle(center, radius * 0.84, _color_with_alpha(bolt_color, alpha * 0.72))
	draw_circle(center + Vector2(-radius * 0.18, -radius * 0.2), radius * 0.36, _color_with_alpha(core_color, alpha * 0.9))
	draw_arc(center, radius * 1.18, float(frame_index) * 0.22, float(frame_index) * 0.22 + PI * 1.35, 32, _color_with_alpha(core_color, alpha * 0.8), 1.7)

	var spark_count: int = maxi(3, int(electric_switch_config.get("core_spark_count", 5)))
	for spark_index: int in range(spark_count):
		var angle: float = float(frame_index) * 0.31 + float(spark_index) * TAU / float(spark_count)
		var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.88
		var end: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * (1.35 + 0.22 * sin(float(spark_index) + float(frame_index) * 0.2))
		draw_line(start, end, _color_with_alpha(core_color, alpha * 0.64), 1.2)


func _draw_electric_switch_impact(progress: float, visible_end: float, bolt_color: Color, core_color: Color, shadow_color: Color) -> void:
	var impact_start: float = clampf(float(electric_switch_config.get("impact_start", 0.28)), 0.0, visible_end)
	if progress < impact_start:
		return

	var impact_progress: float = clampf((progress - impact_start) / maxf(visible_end - impact_start, 0.001), 0.0, 1.0)
	var impact_alpha: float = (1.0 - impact_progress) * float(electric_switch_config.get("impact_alpha", 0.9))
	if impact_alpha <= 0.02:
		return

	var impact_at: float = clampf(float(electric_switch_config.get("impact_at", 0.42)), 0.0, 1.0)
	var impact_state: Dictionary = _get_projectile_state_from_config(impact_at, electric_switch_config)
	var center: Vector2 = _projectile_battlefield_position(impact_state.get("position", Vector2.ZERO) as Vector2, electric_switch_config)
	var radius: float = float(electric_switch_config.get("impact_radius", 40.0)) * (0.45 + impact_progress * 0.72)
	draw_circle(center, radius * 0.42, _color_with_alpha(core_color, impact_alpha * 0.16))
	draw_arc(center, radius, 0.0, TAU, 64, _color_with_alpha(bolt_color, impact_alpha * 0.76), 2.5)
	draw_arc(center, radius * 0.68, 0.0, TAU, 48, _color_with_alpha(shadow_color, impact_alpha * 0.32), 1.8)
	var spark_count: int = maxi(5, int(electric_switch_config.get("impact_spark_count", 10)))
	for spark_index: int in range(spark_count):
		var angle: float = float(spark_index) * TAU / float(spark_count) + float(frame_index) * 0.08
		var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.26
		var end: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * (0.9 + 0.24 * sin(float(spark_index) + float(frame_index) * 0.23))
		draw_line(start, end, _color_with_alpha(core_color, impact_alpha * 0.7), 1.5)


func _draw_fire_stream_visual() -> void:
	if not bool(fire_stream_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(frame_index) / float(total_frames), 0.0, 1.0)
	var visible_start: float = clampf(float(fire_stream_config.get("visible_start", 0.0)), 0.0, 1.0)
	var visible_end: float = clampf(float(fire_stream_config.get("visible_end", 1.0)), visible_start, 1.0)
	if progress < visible_start or progress > visible_end:
		return

	var alpha: float = _get_timed_alpha(progress, visible_start, visible_end, fire_stream_config)
	if alpha <= 0.02:
		return

	var flame_color: Color = _color_from_value(fire_stream_config.get("flame_color", [1.0, 0.22, 0.03, 1.0]), Color(1.0, 0.22, 0.03, 1.0))
	var hot_color: Color = _color_from_value(fire_stream_config.get("hot_color", [1.0, 0.88, 0.18, 1.0]), Color(1.0, 0.88, 0.18, 1.0))
	var core_color: Color = _color_from_value(fire_stream_config.get("core_color", [1.0, 0.98, 0.72, 1.0]), Color(1.0, 0.98, 0.72, 1.0))
	var smoke_color: Color = _color_from_value(fire_stream_config.get("smoke_color", [0.18, 0.08, 0.04, 1.0]), Color(0.18, 0.08, 0.04, 1.0))
	var stream_progress: float = clampf((progress - visible_start) / maxf(visible_end - visible_start, 0.001), 0.0, 1.0)
	var head_progress: float = clampf(stream_progress * float(fire_stream_config.get("travel_scale", 1.28)), 0.0, 1.0)
	var segments: int = maxi(8, int(fire_stream_config.get("segments", 18)))
	var start_width: float = float(fire_stream_config.get("start_width", 12.0))
	var end_width: float = float(fire_stream_config.get("end_width", 28.0))
	var jitter: float = float(fire_stream_config.get("jitter", 7.0))
	var wave_speed: float = float(fire_stream_config.get("wave_speed", 0.48))
	var draw_tongues: bool = bool(fire_stream_config.get("draw_tongues", true))
	var stream_direction: Vector2 = _fire_stream_direction()

	var previous: Vector2 = _fire_stream_point(0.0, jitter, wave_speed)
	for segment_index: int in range(1, segments + 1):
		var t: float = head_progress * float(segment_index) / float(segments)
		var current: Vector2 = _fire_stream_point(t, jitter, wave_speed)
		var local: float = float(segment_index) / float(segments)
		var width: float = lerpf(start_width, end_width, local) * (0.88 + 0.12 * sin(float(frame_index) * 0.42 + local * 9.0))
		var segment_alpha: float = alpha * (0.24 + 0.76 * local)
		draw_line(previous, current, _color_with_alpha(smoke_color, segment_alpha * 0.16), width * 0.9)
		draw_line(previous, current, _color_with_alpha(flame_color, segment_alpha * 0.24), width * 0.52)
		if draw_tongues and segment_index % 2 == 0:
			var tongue_phase: float = float(frame_index) * 0.34 + float(segment_index) * 1.19
			var side: float = sin(tongue_phase)
			var tongue_center: Vector2 = current + stream_direction.orthogonal() * side * width * 0.18
			var tongue_length: float = width * (1.45 + 0.22 * sin(tongue_phase * 1.7))
			_draw_flame_tongue(tongue_center, stream_direction, tongue_length * 1.18, width * 0.88, flame_color, segment_alpha * 0.78, side)
			_draw_flame_tongue(tongue_center + stream_direction * width * 0.12, stream_direction, tongue_length * 0.82, width * 0.52, hot_color, segment_alpha * 0.82, -side)
			_draw_flame_tongue(tongue_center + stream_direction * width * 0.25, stream_direction, tongue_length * 0.48, width * 0.24, core_color, segment_alpha * 0.68, side * 0.4)
		previous = current

	var ember_count: int = maxi(0, int(fire_stream_config.get("ember_count", 10)))
	for ember_index: int in range(ember_count):
		var ember_t: float = clampf(head_progress - float(ember_index) * 0.055, 0.0, head_progress)
		var base: Vector2 = _fire_stream_point(ember_t, jitter * 1.4, wave_speed * 0.8)
		var ember_phase: float = float(frame_index) * 0.36 + float(ember_index) * 1.73
		var ember_offset := Vector2(sin(ember_phase) * 8.0, cos(ember_phase * 0.7) * 5.0 - float(ember_index % 3) * 2.0)
		var ember_alpha: float = alpha * (0.68 - float(ember_index) / float(ember_count + 2))
		draw_circle(base + ember_offset, 1.8 + float(ember_index % 3) * 0.45, _color_with_alpha(hot_color, ember_alpha))

	_draw_fire_stream_impact(progress, visible_end, flame_color, hot_color, core_color)


func _draw_heat_wave_visual() -> void:
	if not bool(heat_wave_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(frame_index) / float(total_frames), 0.0, 1.0)
	var visible_start: float = clampf(float(heat_wave_config.get("visible_start", 0.0)), 0.0, 1.0)
	var visible_end: float = clampf(float(heat_wave_config.get("visible_end", 0.88)), visible_start, 1.0)
	if progress < visible_start or progress > visible_end:
		return

	var alpha: float = _get_timed_alpha(progress, visible_start, visible_end, heat_wave_config)
	if alpha <= 0.02:
		return

	var wave_progress: float = clampf((progress - visible_start) / maxf(visible_end - visible_start, 0.001), 0.0, 1.0)
	var head_progress: float = clampf(wave_progress * float(heat_wave_config.get("travel_scale", 1.25)), 0.0, 1.0)
	var start_state: Dictionary = _get_projectile_state_from_config(0.0, heat_wave_config)
	var end_state: Dictionary = _get_projectile_state_from_config(1.0, heat_wave_config)
	var start: Vector2 = _projectile_battlefield_position(start_state.get("position", Vector2.ZERO) as Vector2, heat_wave_config)
	var end: Vector2 = _projectile_battlefield_position(end_state.get("position", Vector2.ZERO) as Vector2, heat_wave_config)
	var direction: Vector2 = (end - start).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var perpendicular := direction.orthogonal()
	var wave_count: int = maxi(3, int(heat_wave_config.get("wave_count", 7)))
	var segments: int = maxi(8, int(heat_wave_config.get("segments", 22)))
	var spacing: float = float(heat_wave_config.get("spacing", 10.0))
	var amplitude: float = float(heat_wave_config.get("amplitude", 5.0))
	var frequency: float = float(heat_wave_config.get("frequency", 2.8))
	var wave_speed: float = float(heat_wave_config.get("wave_speed", 0.5))
	var outer_width: float = float(heat_wave_config.get("outer_width", 7.0))
	var inner_width: float = float(heat_wave_config.get("inner_width", 2.8))
	var outer_color: Color = _color_from_value(heat_wave_config.get("outer_color", [1.0, 0.2, 0.03, 1.0]), Color(1.0, 0.2, 0.03, 1.0))
	var inner_color: Color = _color_from_value(heat_wave_config.get("inner_color", [1.0, 0.82, 0.18, 1.0]), Color(1.0, 0.82, 0.18, 1.0))

	for wave_index: int in range(wave_count):
		var lane: float = (float(wave_index) - float(wave_count - 1) * 0.5) * spacing
		var phase: float = float(frame_index) * wave_speed + float(wave_index) * 0.92
		var previous := start + perpendicular * lane
		for segment_index: int in range(1, segments + 1):
			var t: float = head_progress * float(segment_index) / float(segments)
			var displacement: float = sin(t * TAU * frequency + phase) * amplitude * sin(t * PI)
			var current := start.lerp(end, t) + perpendicular * (lane + displacement)
			var segment_alpha: float = alpha * (0.28 + 0.72 * t)
			draw_line(previous, current, _color_with_alpha(outer_color, segment_alpha * 0.48), outer_width)
			draw_line(previous, current, _color_with_alpha(inner_color, segment_alpha * 0.72), inner_width)
			previous = current


func _fire_stream_point(t: float, jitter: float, wave_speed: float) -> Vector2:
	var state: Dictionary = _get_projectile_state_from_config(t, fire_stream_config)
	var base: Vector2 = _projectile_battlefield_position(state.get("position", Vector2.ZERO) as Vector2, fire_stream_config)
	var start_state: Dictionary = _get_projectile_state_from_config(0.0, fire_stream_config)
	var end_state: Dictionary = _get_projectile_state_from_config(1.0, fire_stream_config)
	var start: Vector2 = _projectile_battlefield_position(start_state.get("position", Vector2.ZERO) as Vector2, fire_stream_config)
	var end: Vector2 = _projectile_battlefield_position(end_state.get("position", Vector2.ZERO) as Vector2, fire_stream_config)
	var direction: Vector2 = (end - start).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var perpendicular := direction.orthogonal()
	var wave: float = sin(t * TAU * 2.2 + float(frame_index) * wave_speed) * jitter * sin(t * PI)
	return base + perpendicular * wave


func _fire_stream_direction() -> Vector2:
	var start_state: Dictionary = _get_projectile_state_from_config(0.0, fire_stream_config)
	var end_state: Dictionary = _get_projectile_state_from_config(1.0, fire_stream_config)
	var start: Vector2 = _projectile_battlefield_position(start_state.get("position", Vector2.ZERO) as Vector2, fire_stream_config)
	var end: Vector2 = _projectile_battlefield_position(end_state.get("position", Vector2.ZERO) as Vector2, fire_stream_config)
	var direction: Vector2 = (end - start).normalized()
	return Vector2.RIGHT if direction == Vector2.ZERO else direction


func _draw_flame_tongue(center: Vector2, direction: Vector2, length: float, width: float, color: Color, alpha: float, bend: float = 0.0) -> void:
	if alpha <= 0.02:
		return

	var normalized_direction: Vector2 = direction.normalized()
	if normalized_direction == Vector2.ZERO:
		normalized_direction = Vector2.RIGHT
	var perpendicular := normalized_direction.orthogonal()
	var tip: Vector2 = center + normalized_direction * length * 0.58 + perpendicular * bend * width * 0.28
	var shoulder: Vector2 = center + normalized_direction * length * 0.08
	var rear: Vector2 = center - normalized_direction * length * 0.42
	var points := PackedVector2Array([
		tip,
		shoulder + perpendicular * width * 0.48,
		rear + perpendicular * width * 0.22,
		rear - perpendicular * width * 0.22,
		shoulder - perpendicular * width * 0.48,
	])
	draw_colored_polygon(points, _color_with_alpha(color, alpha))


func _draw_fire_stream_impact(progress: float, visible_end: float, flame_color: Color, hot_color: Color, core_color: Color) -> void:
	var impact_start: float = clampf(float(fire_stream_config.get("impact_start", 0.54)), 0.0, visible_end)
	if progress < impact_start:
		return

	var impact_progress: float = clampf((progress - impact_start) / maxf(visible_end - impact_start, 0.001), 0.0, 1.0)
	var impact_alpha: float = (1.0 - impact_progress) * float(fire_stream_config.get("impact_alpha", 0.78))
	if impact_alpha <= 0.02:
		return

	var impact_at: float = clampf(float(fire_stream_config.get("impact_at", 1.0)), 0.0, 1.0)
	var impact_state: Dictionary = _get_projectile_state_from_config(impact_at, fire_stream_config)
	var center: Vector2 = _projectile_battlefield_position(impact_state.get("position", Vector2.ZERO) as Vector2, fire_stream_config)
	var radius: float = float(fire_stream_config.get("impact_radius", 38.0)) * (0.42 + impact_progress * 0.86)
	draw_circle(center, radius * 0.72, _color_with_alpha(flame_color, impact_alpha * 0.22))
	draw_arc(center, radius, 0.0, TAU, 64, _color_with_alpha(hot_color, impact_alpha * 0.72), 2.2)
	var burst_count: int = maxi(5, int(fire_stream_config.get("impact_burst_count", 9)))
	for burst_index: int in range(burst_count):
		var angle: float = float(burst_index) * TAU / float(burst_count) + float(frame_index) * 0.08
		var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.25
		var end: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * (0.86 + 0.22 * sin(float(burst_index) + float(frame_index) * 0.2))
		draw_line(start, end, _color_with_alpha(core_color, impact_alpha * 0.54), 1.4)

	var steam_count: int = maxi(0, int(fire_stream_config.get("steam_count", 0)))
	if steam_count <= 0:
		return

	var steam_color: Color = _color_from_value(fire_stream_config.get("steam_color", [0.94, 0.98, 1.0, 1.0]), Color(0.94, 0.98, 1.0, 1.0))
	var steam_height: float = maxf(float(fire_stream_config.get("steam_height", 48.0)), 1.0)
	var steam_spread: float = maxf(float(fire_stream_config.get("steam_spread", 28.0)), 0.0)
	for steam_index: int in range(steam_count):
		var steam_progress: float = fmod(float(steam_index) * 0.31 + impact_progress * 1.25, 1.0)
		var steam_phase: float = float(frame_index) * 0.16 + float(steam_index) * 1.71
		var steam_offset := Vector2(
			sin(steam_phase) * steam_spread * (0.32 + steam_progress * 0.68),
			-steam_height * steam_progress
		)
		var puff_radius: float = (4.5 + float(steam_index % 3) * 2.0) * (0.7 + steam_progress * 0.85)
		var puff_alpha: float = impact_alpha * (0.25 - steam_progress * 0.09)
		draw_circle(center + steam_offset, puff_radius, _color_with_alpha(steam_color, puff_alpha))


func _electric_jitter(index: int, t: float, amount: float) -> Vector2:
	var value: float = sin(float(index) * 11.17 + t * 23.0 + float(frame_index) * 0.41)
	var value_y: float = cos(float(index) * 7.83 + t * 19.0 + float(frame_index) * 0.36)
	return Vector2(value, value_y) * amount


func _get_energy_blast_alpha(progress: float, visible_start: float, visible_end: float) -> float:
	return _get_timed_alpha(progress, visible_start, visible_end, energy_blast_config)


func _get_timed_alpha(progress: float, visible_start: float, visible_end: float, config: Dictionary) -> float:
	var fade_in: float = maxf(float(config.get("fade_in", 0.08)), 0.001)
	var fade_out: float = maxf(float(config.get("fade_out", 0.16)), 0.001)
	return minf(
		clampf((progress - visible_start) / fade_in, 0.0, 1.0),
		clampf((visible_end - progress) / fade_out, 0.0, 1.0)
	)


func _quadratic_bezier(start: Vector2, control: Vector2, end: Vector2, t: float) -> Vector2:
	var inverse := 1.0 - t
	return (start * inverse * inverse) + (control * 2.0 * inverse * t) + (end * t * t)


func _color_with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)


func _apply_shake_offset() -> void:
	if not base_position_active:
		return
	if not bool(shake_config.get("enabled", false)):
		_restore_base_position()
		return

	var frames: Array = data.get("frames", []) as Array
	var last_frame: int = maxi(frames.size() - 1, 0)
	var start_frame: int = clampi(int(shake_config.get("start_frame", 0)), 0, last_frame)
	var end_frame: int = clampi(int(shake_config.get("end_frame", last_frame)), start_frame, last_frame)
	if frame_index < start_frame or frame_index > end_frame:
		_restore_base_position()
		return

	var duration: float = maxf(float(end_frame - start_frame), 1.0)
	var progress: float = clampf(float(frame_index - start_frame) / duration, 0.0, 1.0)
	var amplitude: float = maxf(float(shake_config.get("amplitude", 6.0)), 0.0)
	if bool(shake_config.get("decay", true)):
		amplitude *= 1.0 - progress

	var frequency_x: float = float(shake_config.get("frequency_x", 2.7))
	var frequency_y: float = float(shake_config.get("frequency_y", 3.9))
	var vertical_scale: float = float(shake_config.get("vertical_scale", 0.45))
	var frame_value: float = float(frame_index - start_frame + 1)
	var offset := Vector2(
		roundf(sin(frame_value * frequency_x) * amplitude),
		roundf(cos(frame_value * frequency_y) * amplitude * vertical_scale)
	)
	position = base_position + offset
	shake_applied = true


func _restore_base_position() -> void:
	if not base_position_active or not shake_applied:
		return

	position = base_position
	shake_applied = false


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
	if index < sheet_visible_start_frame:
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
		var cell_pattern: int = int(cell["pattern"])
		if cell_pattern < sheet_pattern_min or cell_pattern > sheet_pattern_max:
			continue

		var sprite: Sprite2D = sprites[sprite_i]
		var pattern: int = pattern_override if pattern_override >= 0 else maxi(0, cell_pattern + pattern_offset)
		sprite.region_rect = Rect2(
			(pattern % columns) * tile_w,
			int(pattern / columns) * tile_h,
			tile_w,
			tile_h
		)
		var sheet_position := _scale_sprite_position(Vector2(float(cell["x"]), float(cell["y"]))) + sprite_position_offset
		sprite.position = _battlefield_position(sheet_position) + sheet_visual_offset
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


func display_position_to_battlefield_source(position: Vector2) -> Vector2:
	# Battlefield mirroring is its own inverse. Dynamic projectile anchors arrive
	# in display coordinates, so convert them to the source coordinates that will
	# land on that display position after _battlefield_position() is applied.
	return _battlefield_position(position)


func _scale_sprite_position(position: Vector2) -> Vector2:
	if is_equal_approx(sprite_position_scale, 1.0):
		return position

	return sprite_position_anchor + (position - sprite_position_anchor) * sprite_position_scale


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
					fg.modulate.a = (float(event["opacity"]) / 255.0 if event["opacity"] != null else 1.0) * foreground_opacity_multiplier
					fg_hide_frame = _timing_hide_frame(index, event)
			4:
				if show_timing_foregrounds:
					fg.modulate.a = float(event["opacity"]) / 255.0 * foreground_opacity_multiplier if event["opacity"] != null else fg.modulate.a
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
