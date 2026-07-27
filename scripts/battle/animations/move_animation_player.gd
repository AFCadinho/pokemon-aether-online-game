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
@export var timing_background_fill_canvas: bool = false
@export var timing_background_persist_until_clear: bool = false
@export var show_timing_foregrounds: bool = false
@export var timing_foreground_scale: Vector2 = Vector2.ONE
@export_range(0.0, 1.0, 0.01) var foreground_opacity_multiplier: float = 1.0
@export var show_pink_visual: bool = true
@export var show_sheet_sprites: bool = true
@export var mirror_sheet_sprites_on_reverse: bool = false
@export var overlay_fill_enabled: bool = true
@export var projectile_config: Dictionary = {}
@export var orb_config: Dictionary = {}
@export var orb_projectile_config: Dictionary = {}
@export var energy_blast_config: Dictionary = {}
@export var water_splash_config: Dictionary = {}
@export var electric_switch_config: Dictionary = {}
@export var fire_stream_config: Dictionary = {}
@export var heat_wave_config: Dictionary = {}
@export var draco_meteor_config: Dictionary = {}
@export var solar_beam_config: Dictionary = {}
@export var bloom_doom_config: Dictionary = {}
@export var solar_charge_config: Dictionary = {}
@export var celestial_charge_config: Dictionary = {}
@export var focus_aura_config: Dictionary = {}
@export var stat_change_config: Dictionary = {}
@export var heal_energy_config: Dictionary = {}
@export var dragon_dance_config: Dictionary = {}
@export var dragon_claw_config: Dictionary = {}
@export var thunder_punch_config: Dictionary = {}
@export var bullet_punch_config: Dictionary = {}
@export var dark_pulse_config: Dictionary = {}
@export var nasty_plot_config: Dictionary = {}
@export var court_change_config: Dictionary = {}
@export var sound_wave_config: Dictionary = {}
@export var leaf_rush_config: Dictionary = {}
@export var flash_config: Dictionary = {}
@export var shake_config: Dictionary = {}
@export var visual_color: Color = Color(1.0, 0.2, 0.75, 1.0)
@export var sprite_tint: Color = Color(1.0, 0.78, 1.0, 1.0)
@export var reverse_battlefield: bool = false
@export var reverse_battlefield_vertical: bool = true
@export_range(0.0, 0.5, 0.01) var overlay_peak_alpha: float = 0.20
@export_range(0, 48, 1) var sparkle_count: int = 14
@export_range(0.25, 4.0, 0.05) var speed_scale: float = 1.0
@export_range(0.1, 2.0, 0.05) var sprite_zoom_multiplier: float = 1.0
@export_range(0.25, 2.0, 0.05) var sprite_position_scale: float = 1.0
@export var sprite_position_anchor: Vector2 = Vector2(128, 224)
@export var sprite_position_offset: Vector2 = Vector2.ZERO
@export var sheet_visual_offset: Vector2 = Vector2.ZERO
@export var sheet_frame_offsets: Array = []
@export var sheet_pattern_visual_offsets: Dictionary = {}
@export_range(0.5, 4.0, 0.05) var sparkle_size_multiplier: float = 1.0
@export var sparkle_center: Vector2 = Vector2(256, 188)
@export_range(8.0, 180.0, 1.0) var sparkle_radius_min: float = 26.0
@export_range(8.0, 220.0, 1.0) var sparkle_radius_max: float = 78.0
@export_range(-8, 8, 1) var pattern_offset: int = 0
@export_range(-1, 999, 1) var pattern_override: int = -1
@export_range(-1, 999, 1) var reverse_pattern_override: int = -1
@export_range(0, 999, 1) var sheet_pattern_min: int = 0
@export_range(0, 999, 1) var sheet_pattern_max: int = 999
@export var sheet_pattern_exclude: Array = []
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
const ANIMATION_CANVAS_SIZE := Vector2(512.0, 384.0)


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
	if timing_background_fill_canvas:
		_fit_timing_background_to_canvas()
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


func _fit_timing_background_to_canvas() -> void:
	if bg.texture == null:
		return

	var texture_size := bg.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var cover_scale := maxf(
		ANIMATION_CANVAS_SIZE.x / texture_size.x,
		ANIMATION_CANVAS_SIZE.y / texture_size.y
	)
	bg.scale = Vector2(cover_scale, cover_scale)
	bg.position = (ANIMATION_CANVAS_SIZE - texture_size * cover_scale) * 0.5


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
	_draw_draco_meteor_visual()
	_draw_solar_beam_visual()
	_draw_bloom_doom_visual()
	_draw_solar_charge_visual()
	_draw_celestial_charge_visual()
	_draw_focus_aura_visual()
	_draw_stat_change_visual()
	_draw_heal_energy_visual()
	_draw_dragon_dance_visual()
	_draw_dragon_claw_visual()
	_draw_thunder_punch_visual()
	_draw_bullet_punch_visual()
	_draw_dark_pulse_visual()
	_draw_nasty_plot_visual()
	_draw_court_change_visual()
	_draw_sound_wave_visual()
	_draw_leaf_rush_visual()


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

	var travel_progress := _get_energy_blast_travel_progress(progress)
	var projectile_state: Dictionary = _get_projectile_state_from_config(travel_progress, energy_blast_config)
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
		var trail_progress: float = clampf(travel_progress - float(trail_index) * trail_spacing, 0.0, 1.0)
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

	var shadow_ray_count: int = maxi(0, int(energy_blast_config.get("shadow_ray_count", 0)))
	var shadow_ray_color: Color = _color_from_value(energy_blast_config.get("shadow_ray_color", [0.0, 0.0, 0.0, 1.0]), Color.BLACK)
	for shadow_ray_index: int in range(shadow_ray_count):
		var shadow_angle := -spin * 0.66 + float(shadow_ray_index) * TAU / float(shadow_ray_count) + sin(float(shadow_ray_index) * 2.4) * 0.16
		var shadow_inner := center + Vector2(cos(shadow_angle), sin(shadow_angle)) * radius * 0.42
		var shadow_outer := center + Vector2(cos(shadow_angle), sin(shadow_angle)) * radius * (1.02 + float(shadow_ray_index % 3) * 0.18)
		draw_line(shadow_inner, shadow_outer, _color_with_alpha(shadow_ray_color, alpha * 0.86), 2.0)

	var particle_count: int = maxi(0, int(energy_blast_config.get("particle_count", 0)))
	var particle_color: Color = _color_from_value(energy_blast_config.get("particle_color", [ring_color.r, ring_color.g, ring_color.b, ring_color.a]), ring_color)
	for particle_index: int in range(particle_count):
		var particle_angle := spin * (0.76 + float(particle_index % 3) * 0.09) + float(particle_index) * TAU / float(particle_count)
		var particle_radius := radius * (1.45 + 0.32 * sin(float(frame_index) * 0.18 + float(particle_index) * 1.7))
		var particle_center := center + Vector2(cos(particle_angle), sin(particle_angle)) * particle_radius
		var particle_size := 1.2 + float(particle_index % 3) * 0.55
		draw_circle(particle_center, particle_size, _color_with_alpha(particle_color, alpha * 0.78))

	_draw_energy_blast_launch_ring(progress, aura_color, ring_color)
	_draw_energy_blast_impact(progress, visible_end, aura_color, core_color, ring_color)


func _get_energy_blast_travel_progress(progress: float) -> float:
	var travel_start := clampf(float(energy_blast_config.get("travel_start", 0.0)), 0.0, 0.95)
	var travel_end := clampf(float(energy_blast_config.get("travel_end", 1.0)), travel_start + 0.001, 1.0)
	return clampf((progress - travel_start) / maxf(travel_end - travel_start, 0.001), 0.0, 1.0)


func _draw_energy_blast_launch_ring(progress: float, aura_color: Color, ring_color: Color) -> void:
	var ring_value: Variant = energy_blast_config.get("launch_ring", {})
	if not ring_value is Dictionary:
		return

	var ring_config := ring_value as Dictionary
	if not bool(ring_config.get("enabled", false)):
		return

	var start: float = clampf(float(ring_config.get("start", 0.3)), 0.0, 1.0)
	var end: float = clampf(float(ring_config.get("end", 0.7)), start + 0.001, 1.0)
	if progress < start or progress > end:
		return

	var fade_progress := clampf((progress - start) / maxf(end - start, 0.001), 0.0, 1.0)
	var alpha := (1.0 - fade_progress) * float(ring_config.get("alpha", 0.8))
	if alpha <= 0.02:
		return

	var launch_state: Dictionary = _get_projectile_state_from_config(0.0, energy_blast_config)
	var center: Vector2 = _projectile_battlefield_position(launch_state.get("position", Vector2.ZERO) as Vector2, energy_blast_config)
	var radius: float = float(ring_config.get("radius", 34.0)) * (0.72 + fade_progress * 0.58)
	var ring_color_override: Color = _color_from_value(ring_config.get("color", [ring_color.r, ring_color.g, ring_color.b, ring_color.a]), ring_color)
	var core_color: Color = _color_from_value(ring_config.get("core_color", [aura_color.r, aura_color.g, aura_color.b, aura_color.a]), aura_color)
	var spin := float(frame_index) * float(ring_config.get("spin_speed", 0.24))
	draw_arc(center, radius, spin, spin + PI * 1.55, 48, _color_with_alpha(ring_color_override, alpha), 2.8)
	draw_arc(center, radius * 0.72, -spin * 0.8, -spin * 0.8 + PI * 1.2, 40, _color_with_alpha(core_color, alpha * 0.78), 1.8)
	var ember_count := maxi(0, int(ring_config.get("ember_count", 0)))
	for ember_index in range(ember_count):
		var ember_angle := spin * 0.65 + float(ember_index) * TAU / float(maxi(ember_count, 1))
		var ember_center := center + Vector2(cos(ember_angle), sin(ember_angle)) * radius * (0.76 + 0.22 * sin(float(ember_index) + fade_progress * 4.0))
		draw_circle(ember_center, 1.5 + float(ember_index % 2), _color_with_alpha(core_color, alpha * 0.8))


func _draw_court_change_visual() -> void:
	if not bool(court_change_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(frame_index) / float(total_frames), 0.0, 1.0)
	var alpha := _get_timed_alpha(
		progress,
		float(court_change_config.get("visible_start", 0.02)),
		float(court_change_config.get("visible_end", 0.96)),
		court_change_config
	)
	if alpha <= 0.02:
		return

	var player_center := _battlefield_position(_vector2_from_value(court_change_config.get("player_center", [146.0, 232.0])))
	var enemy_center := _battlefield_position(_vector2_from_value(court_change_config.get("enemy_center", [366.0, 112.0])))
	var blue := _color_from_value(court_change_config.get("blue_color", [0.08, 0.76, 1.0, 1.0]), Color(0.08, 0.76, 1.0, 1.0))
	var white := _color_from_value(court_change_config.get("white_color", [0.84, 0.98, 1.0, 1.0]), Color(0.84, 0.98, 1.0, 1.0))
	var pulse := 0.82 + 0.18 * sin(float(frame_index) * 0.42)
	var ring_radius := float(court_change_config.get("ring_radius", 72.0)) * (0.9 + 0.1 * pulse)
	var ring_squash := float(court_change_config.get("ring_squash", 0.34))
	var spin := float(frame_index) * float(court_change_config.get("spin_speed", 0.18))

	_draw_court_change_ellipse(player_center, ring_radius, ring_squash, spin, blue, alpha * 0.38, 4.0)
	_draw_court_change_ellipse(enemy_center, ring_radius, ring_squash, -spin, blue, alpha * 0.38, 4.0)
	_draw_court_change_ellipse(player_center, ring_radius * 0.7, ring_squash, -spin * 1.3, white, alpha * 0.58, 2.0)
	_draw_court_change_ellipse(enemy_center, ring_radius * 0.7, ring_squash, spin * 1.3, white, alpha * 0.58, 2.0)

	var swap_start := clampf(float(court_change_config.get("swap_start", 0.2)), 0.0, 0.9)
	var swap_end := clampf(float(court_change_config.get("swap_end", 0.76)), swap_start + 0.001, 1.0)
	var swap_progress := clampf((progress - swap_start) / maxf(swap_end - swap_start, 0.001), 0.0, 1.0)
	if swap_progress <= 0.0:
		return

	var arc_height := float(court_change_config.get("arc_height", 42.0))
	var forward := player_center.lerp(enemy_center, swap_progress) + Vector2(0.0, -sin(swap_progress * PI) * arc_height)
	var backward := enemy_center.lerp(player_center, swap_progress) + Vector2(0.0, sin(swap_progress * PI) * arc_height)
	var trail_steps := maxi(2, int(court_change_config.get("trail_steps", 8)))
	for trail_index in range(trail_steps, 0, -1):
		var trail_progress := clampf(swap_progress - float(trail_index) * 0.045, 0.0, 1.0)
		var forward_trail := player_center.lerp(enemy_center, trail_progress) + Vector2(0.0, -sin(trail_progress * PI) * arc_height)
		var backward_trail := enemy_center.lerp(player_center, trail_progress) + Vector2(0.0, sin(trail_progress * PI) * arc_height)
		var trail_alpha := alpha * (1.0 - float(trail_index) / float(trail_steps + 1)) * 0.22
		draw_circle(forward_trail, 5.0, _color_with_alpha(blue, trail_alpha))
		draw_circle(backward_trail, 5.0, _color_with_alpha(white, trail_alpha))

	draw_circle(forward, 13.0 * pulse, _color_with_alpha(blue, alpha * 0.22))
	draw_circle(forward, 6.0, _color_with_alpha(white, alpha * 0.95))
	draw_circle(backward, 13.0 * pulse, _color_with_alpha(white, alpha * 0.2))
	draw_circle(backward, 6.0, _color_with_alpha(blue, alpha * 0.95))

	if swap_progress >= 0.48 and swap_progress <= 0.62:
		var center := (player_center + enemy_center) * 0.5
		var flash_alpha := alpha * (1.0 - absf(swap_progress - 0.55) / 0.07) * 0.48
		draw_circle(center, 48.0 * pulse, _color_with_alpha(white, flash_alpha * 0.22))
		draw_arc(center, 34.0 * pulse, 0.0, TAU, 48, _color_with_alpha(white, flash_alpha), 2.4)


func _draw_court_change_ellipse(center: Vector2, radius: float, squash: float, phase: float, color: Color, alpha: float, width: float) -> void:
	var segments := 48
	var previous := center + Vector2(cos(phase) * radius, sin(phase) * radius * squash)
	for segment in range(1, segments + 1):
		var angle := phase + TAU * float(segment) / float(segments)
		var point := center + Vector2(cos(angle) * radius, sin(angle) * radius * squash)
		draw_line(previous, point, _color_with_alpha(color, alpha), width)
		previous = point


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
	var impact_core_color: Color = _color_from_value(energy_blast_config.get("impact_core_color", [core_color.r, core_color.g, core_color.b, core_color.a]), core_color)
	draw_circle(center, impact_radius * 0.72, _color_with_alpha(aura_color, impact_alpha * 0.16))
	draw_circle(center, impact_radius * 0.42, _color_with_alpha(impact_core_color, impact_alpha * 0.45))
	for ring_index: int in range(3):
		draw_arc(center, impact_radius + float(ring_index) * 9.0, 0.0, TAU, 72, _color_with_alpha(ring_color, impact_alpha * (0.7 - float(ring_index) * 0.16)), 2.0)

	var burst_count: int = maxi(4, int(energy_blast_config.get("impact_ray_count", 10)))
	for burst_index: int in range(burst_count):
		var angle: float = float(burst_index) * TAU / float(burst_count) + float(frame_index) * 0.05
		var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * impact_radius * 0.34
		var end: Vector2 = center + Vector2(cos(angle), sin(angle)) * impact_radius * (1.02 + 0.24 * sin(float(burst_index) + float(frame_index) * 0.2))
		draw_line(start, end, _color_with_alpha(impact_core_color, impact_alpha * 0.68), 1.5)


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


func _draw_draco_meteor_visual() -> void:
	if not bool(draco_meteor_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var progress := clampf(float(frame_index) / float(maxi(frames.size() - 1, 1)), 0.0, 1.0)
	var rain_start := clampf(float(draco_meteor_config.get("rain_start", 0.47)), 0.0, 1.0)
	var rain_end := clampf(float(draco_meteor_config.get("rain_end", 0.92)), rain_start + 0.01, 1.0)
	if progress < rain_start or progress > rain_end:
		return

	var rain_progress := clampf((progress - rain_start) / maxf(rain_end - rain_start, 0.001), 0.0, 1.0)
	var center := _battlefield_position(_vector2_from_value(draco_meteor_config.get("center", [384.0, 96.0])))
	var meteor_count := clampi(int(draco_meteor_config.get("meteor_count", 11)), 5, 18)
	var spread_x := maxf(float(draco_meteor_config.get("spread_x", 74.0)), 24.0)
	var spread_y := maxf(float(draco_meteor_config.get("spread_y", 26.0)), 8.0)
	var flight_height := maxf(float(draco_meteor_config.get("flight_height", 190.0)), 80.0)
	var flight_duration := clampf(float(draco_meteor_config.get("flight_duration", 0.29)), 0.12, 0.48)
	var impact_duration := clampf(float(draco_meteor_config.get("impact_duration", 0.2)), 0.08, 0.36)
	var meteor_scale := maxf(float(draco_meteor_config.get("meteor_scale", 0.68)), 0.18)
	var aura_color := _color_from_value(draco_meteor_config.get("aura_color", [0.4, 0.16, 0.98, 1.0]), Color(0.4, 0.16, 0.98, 1.0))
	var trail_color := _color_from_value(draco_meteor_config.get("trail_color", [0.76, 0.32, 1.0, 1.0]), Color(0.76, 0.32, 1.0, 1.0))
	var core_color := _color_from_value(draco_meteor_config.get("core_color", [1.0, 0.84, 0.42, 1.0]), Color(1.0, 0.84, 0.42, 1.0))
	var impact_color := _color_from_value(draco_meteor_config.get("impact_color", [1.0, 0.22, 0.08, 1.0]), Color(1.0, 0.22, 0.08, 1.0))
	var approach_direction := -1.0 if reverse_battlefield else 1.0

	for meteor_index: int in range(meteor_count):
		var lane_seed := fmod(float(meteor_index) * 0.61803398875, 1.0)
		var lane := lane_seed * 2.0 - 1.0
		if meteor_index == 0:
			lane = 0.0
		var row_seed := fmod(float(meteor_index * 37), 7.0) / 6.0
		var impact_offset := Vector2(
			lane * spread_x,
			lerpf(-spread_y * 0.45, spread_y, row_seed) + 10.0
		)
		var impact_position := center + impact_offset
		var stagger := float(meteor_index) / float(maxi(meteor_count - 1, 1)) * 0.62
		stagger += sin(float(meteor_index) * 2.41) * 0.018
		var meteor_flight_duration := flight_duration * (0.88 + float(meteor_index % 4) * 0.055)
		var meteor_life := (rain_progress - stagger) / meteor_flight_duration

		if meteor_life >= 0.0 and meteor_life < 1.0:
			var fall := meteor_life * meteor_life * (3.0 - 2.0 * meteor_life)
			var diagonal_x := (-54.0 + float((meteor_index % 3) - 1) * 18.0) * approach_direction
			var start_position := impact_position + Vector2(diagonal_x, -flight_height - float(meteor_index % 4) * 14.0)
			var meteor_position := start_position.lerp(impact_position, fall)
			var velocity := (impact_position - start_position).normalized()
			var appear := clampf(meteor_life / 0.12, 0.0, 1.0)
			var meteor_alpha := appear * clampf((1.03 - meteor_life) / 0.08, 0.0, 1.0)
			var size_multiplier := 0.82 + float(meteor_index % 4) * 0.09
			_draw_draco_meteor_trail(
				meteor_position,
				velocity,
				meteor_scale * size_multiplier,
				meteor_alpha,
				aura_color,
				trail_color,
				core_color,
				meteor_index
			)
			_draw_draco_meteor_rock(
				meteor_position,
				6 + meteor_index % 4,
				meteor_scale * size_multiplier,
				meteor_alpha,
				sin(float(frame_index) * 0.08 + float(meteor_index)) * 0.09
			)

		var impact_progress := (meteor_life - 1.0) / impact_duration
		if impact_progress >= 0.0 and impact_progress <= 1.0:
			_draw_draco_meteor_impact(
				impact_position,
				impact_progress,
				meteor_index,
				aura_color,
				trail_color,
				core_color,
				impact_color
			)


func _draw_draco_meteor_trail(
	meteor_position: Vector2,
	velocity: Vector2,
	scale_value: float,
	alpha: float,
	aura_color: Color,
	trail_color: Color,
	core_color: Color,
	meteor_index: int
) -> void:
	var trail_length := (58.0 + float(meteor_index % 4) * 8.0) * scale_value
	var trail_end := meteor_position - velocity * trail_length
	var side := velocity.orthogonal()
	var wave := sin(float(frame_index) * 0.48 + float(meteor_index) * 1.7)
	trail_end += side * wave * 5.0
	draw_line(trail_end, meteor_position, _color_with_alpha(aura_color, alpha * 0.13), 22.0 * scale_value, true)
	draw_line(trail_end, meteor_position, _color_with_alpha(trail_color, alpha * 0.38), 10.0 * scale_value, true)
	draw_line(trail_end.lerp(meteor_position, 0.28), meteor_position, _color_with_alpha(core_color, alpha * 0.78), 3.2 * scale_value, true)

	for spark_index: int in range(4):
		var spark_t := fmod(float(frame_index) * 0.075 + float(spark_index) * 0.23 + float(meteor_index) * 0.17, 1.0)
		var spark_position := meteor_position.lerp(trail_end, spark_t)
		spark_position += side * sin(float(spark_index) * 2.7 + float(frame_index) * 0.31) * 8.0 * scale_value
		var spark_alpha := alpha * sin(PI * spark_t) * 0.72
		draw_circle(spark_position, (1.5 + float(spark_index % 2)) * scale_value, _color_with_alpha(core_color, spark_alpha))


func _draw_draco_meteor_rock(position: Vector2, pattern: int, scale_value: float, alpha: float, rotation: float) -> void:
	var pulse := 1.0 + sin(float(frame_index) * 0.46 + float(pattern)) * 0.07
	var shell_radius := 36.0 * scale_value * pulse
	var shell_purple := Color(0.56, 0.08, 0.96, alpha * 0.34)
	var shell_pink := Color(1.0, 0.22, 0.84, alpha * 0.82)
	var shell_core := Color(1.0, 0.76, 1.0, alpha * 0.66)
	draw_circle(position, shell_radius * 1.22, Color(0.32, 0.04, 0.72, alpha * 0.12))
	draw_circle(position, shell_radius, shell_purple)
	draw_arc(position, shell_radius * 1.03, rotation + float(frame_index) * 0.12, rotation + float(frame_index) * 0.12 + TAU * 0.8, 34, shell_pink, 3.8 * scale_value, true)
	draw_arc(position, shell_radius * 0.76, -rotation - float(frame_index) * 0.16, -rotation - float(frame_index) * 0.16 + TAU * 0.68, 30, shell_core, 1.8 * scale_value, true)

	if sheet_texture == null:
		draw_circle(position, 20.0 * scale_value, Color(0.18, 0.02, 0.28, alpha))
		draw_circle(position + Vector2(0.0, 5.0 * scale_value), 14.0 * scale_value, Color(1.0, 0.18, 0.62, alpha))
		return

	var tile_size_value := _vector2_from_value(data.get("tile_size", [192.0, 192.0]))
	var tile_size := Vector2(maxf(tile_size_value.x, 1.0), maxf(tile_size_value.y, 1.0))
	var sheet_columns := maxi(int(floor(float(sheet_texture.get_width()) / tile_size.x)), 1)
	var source_region := Rect2(
		Vector2(float(pattern % sheet_columns) * tile_size.x, floor(float(pattern) / float(sheet_columns)) * tile_size.y),
		tile_size
	)
	draw_set_transform(position, rotation, Vector2(scale_value, scale_value))
	draw_texture_rect_region(
		sheet_texture,
		Rect2(-tile_size * 0.5, tile_size),
		source_region,
		Color(1.0, 0.48, 1.0, alpha * 0.9)
	)
	draw_set_transform(Vector2.ZERO)
	draw_circle(position + Vector2(-7.0, -7.0) * scale_value, 5.0 * scale_value, Color(1.0, 0.84, 1.0, alpha * 0.72))


func _draw_draco_meteor_impact(
	position: Vector2,
	impact_progress: float,
	meteor_index: int,
	aura_color: Color,
	trail_color: Color,
	core_color: Color,
	impact_color: Color
) -> void:
	var impact_alpha := sin(PI * impact_progress)
	var burst := 1.0 - pow(1.0 - impact_progress, 2.0)
	var radius := (18.0 + float(meteor_index % 3) * 3.0) + burst * (35.0 + float(meteor_index % 4) * 4.0)
	draw_circle(position, radius * 0.86, _color_with_alpha(aura_color, impact_alpha * 0.13))
	draw_circle(position, radius * 0.5, _color_with_alpha(impact_color, impact_alpha * 0.3))
	draw_circle(position, radius * 0.22, _color_with_alpha(core_color, impact_alpha * 0.88))
	draw_arc(position, radius, float(meteor_index) * 0.71, float(meteor_index) * 0.71 + TAU * 0.86, 34, _color_with_alpha(trail_color, impact_alpha * 0.78), 2.4, true)

	var cloud_progress := clampf((impact_progress - 0.08) / 0.92, 0.0, 1.0)
	var cloud_alpha := impact_alpha * clampf(cloud_progress / 0.18, 0.0, 1.0)
	for cloud_index: int in range(7):
		var cloud_angle := float(cloud_index) * TAU / 7.0 + float(meteor_index) * 0.57
		var cloud_distance := radius * (0.14 + cloud_progress * (0.32 + float(cloud_index % 3) * 0.09))
		var cloud_position := position + Vector2(
			cos(cloud_angle) * cloud_distance,
			sin(cloud_angle) * cloud_distance * 0.62 - cloud_progress * (8.0 + float(cloud_index % 3) * 3.0)
		)
		var puff_radius := (8.0 + float(cloud_index % 3) * 3.5) * (0.48 + cloud_progress * 0.72)
		draw_circle(cloud_position, puff_radius * 1.24, _color_with_alpha(trail_color, cloud_alpha * 0.38))
		draw_circle(cloud_position, puff_radius, _color_with_alpha(aura_color, cloud_alpha * 0.62))
		draw_circle(cloud_position + Vector2(-puff_radius * 0.18, -puff_radius * 0.22), puff_radius * 0.42, _color_with_alpha(Color(1.0, 0.66, 1.0, 1.0), cloud_alpha * 0.66))

	var ray_count := 8
	for ray_index: int in range(ray_count):
		var angle := float(ray_index) * TAU / float(ray_count) + float(meteor_index) * 0.43
		var ray_start := position + Vector2.from_angle(angle) * radius * 0.24
		var ray_end := position + Vector2.from_angle(angle) * radius * (0.7 + float(ray_index % 3) * 0.16)
		draw_line(ray_start, ray_end, _color_with_alpha(core_color, impact_alpha * 0.72), 1.5, true)

	var ground := position + Vector2(0.0, 12.0)
	draw_set_transform(ground, 0.0, Vector2(1.0, 0.3))
	draw_arc(Vector2.ZERO, radius * 1.08, 0.0, TAU, 40, _color_with_alpha(impact_color, impact_alpha * 0.5), 2.2, true)
	draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 36, _color_with_alpha(aura_color, impact_alpha * 0.72), 1.4, true)
	draw_set_transform(Vector2.ZERO)


func _draw_focus_aura_visual() -> void:
	if not bool(focus_aura_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var progress := clampf(float(frame_index) / float(maxi(frames.size() - 1, 1)), 0.0, 1.0)
	var visible_start := clampf(float(focus_aura_config.get("visible_start", 0.0)), 0.0, 1.0)
	var visible_end := clampf(float(focus_aura_config.get("visible_end", 0.94)), visible_start, 1.0)
	if progress < visible_start or progress > visible_end:
		return

	var alpha := _get_timed_alpha(progress, visible_start, visible_end, focus_aura_config)
	if alpha <= 0.02:
		return

	var local_progress := clampf((progress - visible_start) / maxf(visible_end - visible_start, 0.001), 0.0, 1.0)
	var appear := 1.0 - pow(1.0 - clampf(local_progress / 0.2, 0.0, 1.0), 3.0)
	var center := _battlefield_position(_vector2_from_value(focus_aura_config.get("center", [128.0, 224.0])))
	center += _vector2_from_value(focus_aura_config.get("center_offset", [0.0, -6.0]))
	var radius := maxf(float(focus_aura_config.get("radius", 56.0)), 12.0) * appear
	var squash := clampf(float(focus_aura_config.get("ring_squash", 0.55)), 0.18, 1.0)
	var rotation_speed := float(focus_aura_config.get("rotation_speed", 0.16))
	var phase := float(frame_index) * rotation_speed
	var glow_color := _color_from_value(focus_aura_config.get("glow_color", [0.42, 0.96, 0.72, 1.0]), Color(0.42, 0.96, 0.72, 1.0))
	var core_color := _color_from_value(focus_aura_config.get("core_color", [1.0, 1.0, 0.9, 1.0]), Color(1.0, 1.0, 0.9, 1.0))
	var ring_colors: Array[Color] = [
		_color_from_value(focus_aura_config.get("ring_color_green", [0.68, 1.0, 0.18, 1.0]), Color(0.68, 1.0, 0.18, 1.0)),
		_color_from_value(focus_aura_config.get("ring_color_cyan", [0.2, 0.92, 1.0, 1.0]), Color(0.2, 0.92, 1.0, 1.0)),
		_color_from_value(focus_aura_config.get("ring_color_pink", [1.0, 0.32, 0.82, 1.0]), Color(1.0, 0.32, 0.82, 1.0)),
		_color_from_value(focus_aura_config.get("ring_color_gold", [1.0, 0.9, 0.22, 1.0]), Color(1.0, 0.9, 0.22, 1.0)),
	]

	var pulse := 1.0 + sin(float(frame_index) * 0.42) * 0.055
	draw_circle(center, radius * 1.08 * pulse, _color_with_alpha(glow_color, alpha * 0.055))
	draw_circle(center, radius * 0.72 * pulse, _color_with_alpha(core_color, alpha * 0.035))

	var ring_count := clampi(int(focus_aura_config.get("ring_count", 4)), 2, 6)
	for ring_index: int in range(ring_count):
		var ring_progress := float(ring_index) / float(maxi(ring_count - 1, 1))
		var ring_radius := radius * (0.7 + ring_progress * 0.38)
		var rotation := -0.42 + ring_progress * 0.84 + sin(phase * 0.62 + float(ring_index)) * 0.08
		var ring_phase := phase * (1.0 if ring_index % 2 == 0 else -0.82) + float(ring_index) * 1.48
		var arc_length := PI * (1.28 + 0.18 * sin(float(ring_index) * 1.7 + phase))
		var ring_color: Color = ring_colors[ring_index % ring_colors.size()]
		var ring_alpha := alpha * (0.68 + (1.0 - ring_progress) * 0.2)
		draw_set_transform(center, rotation, Vector2(1.0, squash + ring_progress * 0.08))
		draw_arc(Vector2.ZERO, ring_radius + 1.4, ring_phase, ring_phase + arc_length, 42, _color_with_alpha(ring_color, ring_alpha * 0.2), 6.2, true)
		draw_arc(Vector2.ZERO, ring_radius, ring_phase, ring_phase + arc_length, 42, _color_with_alpha(ring_color, ring_alpha), 2.5, true)
		draw_arc(Vector2.ZERO, ring_radius - 1.0, ring_phase + 0.04, ring_phase + arc_length - 0.04, 42, _color_with_alpha(core_color, ring_alpha * 0.72), 0.9, true)
		draw_set_transform(Vector2.ZERO)

	var sparkle_count := maxi(8, int(focus_aura_config.get("sparkle_count", 20)))
	var sparkle_radius_min := maxf(float(focus_aura_config.get("sparkle_radius_min", 36.0)), 8.0)
	var sparkle_radius_max := maxf(float(focus_aura_config.get("sparkle_radius_max", 82.0)), sparkle_radius_min)
	for sparkle_index: int in range(sparkle_count):
		var life := fmod(local_progress * 1.9 + float(sparkle_index) * 0.137, 1.0)
		var sparkle_phase := float(sparkle_index) * 2.399 + phase * (0.62 + float(sparkle_index % 3) * 0.12)
		var sparkle_radius := lerpf(sparkle_radius_min, sparkle_radius_max, life)
		var sparkle_position := center + Vector2(
			cos(sparkle_phase) * sparkle_radius,
			sin(sparkle_phase) * sparkle_radius * 0.66 - life * 18.0
		)
		var sparkle_alpha := alpha * sin(PI * life) * (0.48 + float(sparkle_index % 3) * 0.13)
		var sparkle_size := 1.5 + float(sparkle_index % 4) * 0.65
		var sparkle_color: Color = ring_colors[sparkle_index % ring_colors.size()]
		_draw_focus_aura_sparkle(sparkle_position, sparkle_size, sparkle_color, core_color, sparkle_alpha)

	var focus_alpha := alpha * clampf((local_progress - 0.45) / 0.22, 0.0, 1.0) * clampf((0.98 - local_progress) / 0.18, 0.0, 1.0)
	if focus_alpha > 0.02:
		var focus_radius := radius * (0.22 + (1.0 - local_progress) * 0.12)
		draw_circle(center, focus_radius * 1.8, _color_with_alpha(glow_color, focus_alpha * 0.08))
		draw_arc(center, focus_radius, phase, phase + PI * 1.54, 28, _color_with_alpha(core_color, focus_alpha * 0.84), 1.8, true)


func _draw_focus_aura_sparkle(position: Vector2, size: float, color: Color, core_color: Color, alpha: float) -> void:
	if alpha <= 0.02:
		return
	var outer := _color_with_alpha(color, alpha * 0.42)
	var core := _color_with_alpha(core_color, alpha)
	draw_circle(position, size * 1.5, outer)
	draw_line(position + Vector2(-size * 2.4, 0.0), position + Vector2(size * 2.4, 0.0), core, 1.1, true)
	draw_line(position + Vector2(0.0, -size * 2.4), position + Vector2(0.0, size * 2.4), core, 1.1, true)
	draw_line(position + Vector2(-size, -size), position + Vector2(size, size), outer, 0.8, true)
	draw_line(position + Vector2(-size, size), position + Vector2(size, -size), outer, 0.8, true)


func _draw_stat_change_visual() -> void:
	if not bool(stat_change_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var progress := clampf(float(frame_index) / float(maxi(frames.size() - 1, 1)), 0.0, 1.0)
	var visible_start := clampf(float(stat_change_config.get("visible_start", 0.0)), 0.0, 1.0)
	var visible_end := clampf(float(stat_change_config.get("visible_end", 0.96)), visible_start, 1.0)
	if progress < visible_start or progress > visible_end:
		return

	var alpha := _get_timed_alpha(progress, visible_start, visible_end, stat_change_config)
	if alpha <= 0.02:
		return

	var local_progress := clampf((progress - visible_start) / maxf(visible_end - visible_start, 0.001), 0.0, 1.0)
	var center := _battlefield_position(_vector2_from_value(stat_change_config.get("center", [128.0, 224.0])))
	center += _vector2_from_value(stat_change_config.get("center_offset", [0.0, 0.0]))
	var direction_name := str(stat_change_config.get("direction", "up")).strip_edges().to_lower()
	var vertical_direction := -1.0 if direction_name != "down" else 1.0
	var particle_count := clampi(int(stat_change_config.get("particle_count", 15)), 6, 28)
	var spread := maxf(float(stat_change_config.get("spread", 58.0)), 12.0)
	var travel_distance := maxf(float(stat_change_config.get("travel_distance", 118.0)), 32.0)
	var primary_color := _color_from_value(stat_change_config.get("primary_color", [0.18, 0.78, 1.0, 1.0]), Color(0.18, 0.78, 1.0, 1.0))
	var secondary_color := _color_from_value(stat_change_config.get("secondary_color", [0.24, 0.4, 1.0, 1.0]), Color(0.24, 0.4, 1.0, 1.0))
	var core_color := _color_from_value(stat_change_config.get("core_color", [0.9, 1.0, 1.0, 1.0]), Color(0.9, 1.0, 1.0, 1.0))

	var aura_pulse := 0.86 + sin(float(frame_index) * 0.54) * 0.14
	var aura_center := center + Vector2(0.0, vertical_direction * -8.0)
	draw_circle(aura_center, spread * 0.72, _color_with_alpha(primary_color, alpha * 0.035 * aura_pulse))
	draw_set_transform(center + Vector2(0.0, vertical_direction * -travel_distance * 0.08), 0.0, Vector2(1.0, 0.28))
	draw_arc(Vector2.ZERO, spread * 0.64, 0.0, TAU, 44, _color_with_alpha(primary_color, alpha * 0.2), 3.4, true)
	draw_arc(Vector2.ZERO, spread * 0.48, 0.0, TAU, 36, _color_with_alpha(core_color, alpha * 0.3), 1.1, true)
	draw_set_transform(Vector2.ZERO)

	for particle_index: int in range(particle_count):
		var spawn_phase := float(particle_index) / float(particle_count)
		var life := fmod(local_progress * 1.7 + spawn_phase * 1.18, 1.0)
		var envelope := sin(PI * life) * alpha
		if envelope <= 0.025:
			continue

		var lane_seed := fmod(float(particle_index * 37), float(particle_count)) / float(maxi(particle_count - 1, 1))
		var lane_x := lerpf(-spread, spread, lane_seed)
		var sway := sin(life * PI * 2.0 + float(particle_index) * 1.73) * (4.0 + float(particle_index % 3) * 1.8)
		var start_y := center.y - vertical_direction * travel_distance * 0.48
		var tip := Vector2(
			center.x + lane_x + sway,
			start_y + vertical_direction * travel_distance * life
		)
		var velocity := Vector2(cos(float(particle_index) * 2.11) * 0.1, vertical_direction).normalized()
		var streak_length := (18.0 + float(particle_index % 5) * 4.6) * (0.7 + envelope * 0.45)
		var trail := tip - velocity * streak_length
		var particle_color := primary_color.lerp(secondary_color, float(particle_index % 4) / 3.0)

		draw_line(trail, tip, _color_with_alpha(particle_color, envelope * 0.14), 9.0, true)
		draw_line(trail, tip, _color_with_alpha(particle_color, envelope * 0.58), 4.0, true)
		draw_line(trail.lerp(tip, 0.2), tip, _color_with_alpha(core_color, envelope * 0.9), 1.35, true)

		var side := Vector2(-velocity.y, velocity.x)
		var tip_size := 2.2 + float(particle_index % 3) * 0.65
		var shard := PackedVector2Array([
			tip + velocity * tip_size * 2.3,
			tip + side * tip_size,
			tip - velocity * tip_size * 1.25,
			tip - side * tip_size,
		])
		draw_colored_polygon(shard, _color_with_alpha(core_color, envelope * 0.92))

		if particle_index % 3 == 0:
			var glint_position := tip - velocity * streak_length * 0.35
			var glint_size := 2.0 + envelope * 2.4
			draw_line(glint_position + Vector2(-glint_size, 0.0), glint_position + Vector2(glint_size, 0.0), _color_with_alpha(core_color, envelope * 0.72), 1.0, true)
			draw_line(glint_position + Vector2(0.0, -glint_size), glint_position + Vector2(0.0, glint_size), _color_with_alpha(core_color, envelope * 0.72), 1.0, true)

	var mote_count := maxi(8, int(stat_change_config.get("mote_count", 14)))
	for mote_index: int in range(mote_count):
		var mote_life := fmod(local_progress * 1.35 + float(mote_index) * 0.173, 1.0)
		var mote_alpha := alpha * sin(PI * mote_life) * 0.72
		var mote_x := center.x + sin(float(mote_index) * 2.47) * spread * (0.28 + float(mote_index % 4) * 0.16)
		var mote_y := center.y - vertical_direction * travel_distance * 0.42 + vertical_direction * travel_distance * mote_life
		var mote_position := Vector2(mote_x, mote_y)
		var mote_size := 1.4 + float(mote_index % 3) * 0.75
		draw_circle(mote_position, mote_size * 1.8, _color_with_alpha(primary_color, mote_alpha * 0.2))
		draw_circle(mote_position, mote_size, _color_with_alpha(core_color, mote_alpha))


func _draw_heal_energy_visual() -> void:
	if not bool(heal_energy_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var progress := clampf(float(frame_index) / float(maxi(frames.size() - 1, 1)), 0.0, 1.0)
	var visible_start := clampf(float(heal_energy_config.get("visible_start", 0.0)), 0.0, 1.0)
	var visible_end := clampf(float(heal_energy_config.get("visible_end", 0.98)), visible_start, 1.0)
	if progress < visible_start or progress > visible_end:
		return

	var alpha := _get_timed_alpha(progress, visible_start, visible_end, heal_energy_config)
	if alpha <= 0.02:
		return

	var local_progress := clampf((progress - visible_start) / maxf(visible_end - visible_start, 0.001), 0.0, 1.0)
	var center := _battlefield_position(_vector2_from_value(heal_energy_config.get("center", [128.0, 224.0])))
	center += _vector2_from_value(heal_energy_config.get("center_offset", [0.0, 0.0]))
	var radius := maxf(float(heal_energy_config.get("radius", 44.0)), 14.0)
	var rise_height := maxf(float(heal_energy_config.get("rise_height", 82.0)), 24.0)
	var particle_count := clampi(int(heal_energy_config.get("particle_count", 13)), 6, 24)
	var green := _color_from_value(heal_energy_config.get("primary_color", [0.24, 1.0, 0.48, 1.0]), Color(0.24, 1.0, 0.48, 1.0))
	var cyan := _color_from_value(heal_energy_config.get("secondary_color", [0.32, 1.0, 0.84, 1.0]), Color(0.32, 1.0, 0.84, 1.0))
	var core := _color_from_value(heal_energy_config.get("core_color", [0.9, 1.0, 0.84, 1.0]), Color(0.9, 1.0, 0.84, 1.0))

	var pulse := 1.0 + sin(float(frame_index) * 0.74) * 0.06
	draw_circle(center, radius * 0.88 * pulse, _color_with_alpha(green, alpha * 0.04))
	var ground := center + Vector2(0.0, radius * 0.48)
	draw_set_transform(ground, 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, radius * 0.92 * pulse, _color_with_alpha(green, alpha * 0.075))
	draw_arc(Vector2.ZERO, radius * 0.82 * pulse, 0.0, TAU, 40, _color_with_alpha(green, alpha * 0.48), 2.4, true)
	draw_arc(Vector2.ZERO, radius * 0.58 * pulse, float(frame_index) * 0.18, float(frame_index) * 0.18 + TAU * 0.78, 34, _color_with_alpha(cyan, alpha * 0.7), 1.25, true)
	draw_set_transform(Vector2.ZERO)

	for particle_index: int in range(particle_count):
		var life := fmod(local_progress * 1.42 + float(particle_index) * 0.137, 1.0)
		var particle_alpha := alpha * sin(PI * life)
		if particle_alpha <= 0.02:
			continue
		var angle := float(particle_index) * 2.399 + sin(float(frame_index) * 0.08 + float(particle_index)) * 0.18
		var orbit_radius := radius * (0.24 + float(particle_index % 5) * 0.13)
		var particle_position := center + Vector2(
			cos(angle) * orbit_radius,
			radius * 0.52 - life * rise_height + sin(angle * 1.7) * 4.0
		)
		var particle_size := 2.2 + float(particle_index % 3) * 1.0
		var particle_color := green.lerp(cyan, float(particle_index % 4) / 3.0)
		draw_circle(particle_position, particle_size * 2.1, _color_with_alpha(particle_color, particle_alpha * 0.17))
		draw_circle(particle_position, particle_size, _color_with_alpha(particle_color, particle_alpha * 0.82))
		draw_circle(particle_position + Vector2(-particle_size * 0.24, -particle_size * 0.3), particle_size * 0.42, _color_with_alpha(core, particle_alpha))

		if particle_index % 3 == 0:
			var glint_size := particle_size * (1.25 + sin(PI * life) * 0.45)
			draw_line(particle_position + Vector2(-glint_size, 0.0), particle_position + Vector2(glint_size, 0.0), _color_with_alpha(core, particle_alpha * 0.85), 1.0, true)
			draw_line(particle_position + Vector2(0.0, -glint_size), particle_position + Vector2(0.0, glint_size), _color_with_alpha(core, particle_alpha * 0.85), 1.0, true)

	var finish_alpha := alpha * clampf((local_progress - 0.46) / 0.28, 0.0, 1.0)
	if finish_alpha > 0.02:
		var finish_radius := radius * (0.22 + local_progress * 0.16)
		draw_arc(center, finish_radius, float(frame_index) * 0.2, float(frame_index) * 0.2 + TAU * 0.72, 28, _color_with_alpha(core, finish_alpha * 0.64), 1.5, true)


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


func _draw_dragon_claw_visual() -> void:
	if not bool(dragon_claw_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(frame_index) / float(total_frames), 0.0, 1.0)
	var visible_start: float = clampf(float(dragon_claw_config.get("visible_start", 0.0)), 0.0, 1.0)
	var visible_end: float = clampf(float(dragon_claw_config.get("visible_end", 0.75)), visible_start, 1.0)
	if progress < visible_start or progress > visible_end:
		return

	var alpha := _get_timed_alpha(progress, visible_start, visible_end, dragon_claw_config)
	if alpha <= 0.02:
		return

	var center := _battlefield_position(_vector2_from_value(dragon_claw_config.get("center", [384.0, 96.0])))
	center += _vector2_from_value(dragon_claw_config.get("center_offset", [0.0, 0.0]))
	var outer_color := _color_from_value(dragon_claw_config.get("outer_color", [0.44, 0.08, 0.82, 1.0]), Color(0.44, 0.08, 0.82, 1.0))
	var slash_color := _color_from_value(dragon_claw_config.get("slash_color", [0.88, 0.66, 1.0, 1.0]), Color(0.88, 0.66, 1.0, 1.0))
	var core_color := _color_from_value(dragon_claw_config.get("core_color", [1.0, 0.96, 1.0, 1.0]), Color(1.0, 0.96, 1.0, 1.0))
	var animation_progress := clampf((progress - visible_start) / maxf(visible_end - visible_start, 0.001), 0.0, 0.999)
	var strike_index := mini(1, int(animation_progress * 2.0))
	var impact_progress := fmod(animation_progress * 2.0, 1.0)
	center += Vector2(4.0, -4.0) if strike_index == 0 else Vector2(-4.0, -4.0)
	var slash_length := maxf(float(dragon_claw_config.get("slash_length", 94.0)), 16.0)
	var spread := maxf(float(dragon_claw_config.get("spread", 25.0)), 4.0)
	var direction := Vector2(0.62 if strike_index == 0 else -0.62, 0.78).normalized()
	var normal := direction.orthogonal()

	var burst_radius := 18.0 + impact_progress * 28.0
	draw_circle(center, burst_radius, _color_with_alpha(outer_color, alpha * (1.0 - impact_progress) * 0.16))
	draw_circle(center, burst_radius * 0.48, _color_with_alpha(slash_color, alpha * (1.0 - impact_progress) * 0.18))
	var ring_radius := maxf(float(dragon_claw_config.get("ring_radius", 48.0)), 12.0) * (0.84 + impact_progress * 0.16)
	var ring_alpha := alpha * (0.72 + (1.0 - impact_progress) * 0.18)
	var ring_phase := float(frame_index) * 0.18 + float(strike_index) * 0.9
	draw_arc(center, ring_radius + 3.0, ring_phase, ring_phase + TAU * 0.94, 64, _color_with_alpha(outer_color, ring_alpha * 0.28), 6.5)
	draw_arc(center, ring_radius, ring_phase, ring_phase + TAU * 0.94, 64, _color_with_alpha(outer_color, ring_alpha), 3.1)
	draw_arc(center, ring_radius - 1.4, ring_phase + 0.06, ring_phase + TAU * 0.94, 64, _color_with_alpha(core_color, ring_alpha * 0.92), 1.05)

	for slash_index: int in range(3):
		var offset := normal * (float(slash_index) - 1.0) * spread
		var slash_center := center + offset
		var slash_delay := float(slash_index) * 0.055
		var slash_alpha := alpha * clampf((impact_progress - slash_delay) / 0.16, 0.0, 1.0)
		if slash_alpha <= 0.02:
			continue
		var start := slash_center - direction * slash_length * 0.43
		var end := slash_center + direction * slash_length * 0.43
		var bend := normal * (5.0 if slash_index % 2 == 0 else -5.0)
		var middle := start.lerp(end, 0.5) + bend
		var tip := end + direction * 11.0
		var outer_points := PackedVector2Array([
			start - normal * 2.4,
			start + normal * 2.4,
			middle + normal * 5.4,
			end + normal * 3.8,
			tip,
			end - normal * 3.8,
			middle - normal * 5.4,
		])
		var inner_points := PackedVector2Array([
			start - normal * 0.9,
			start + normal * 0.9,
			middle + normal * 2.4,
			end + normal * 1.8,
			tip - direction * 3.0,
			end - normal * 1.8,
			middle - normal * 2.4,
		])
		draw_colored_polygon(outer_points, _color_with_alpha(outer_color, slash_alpha * 0.94))
		draw_colored_polygon(inner_points, _color_with_alpha(slash_color, slash_alpha))
		draw_polyline(PackedVector2Array([start, middle, end]), _color_with_alpha(core_color, slash_alpha * 0.9), 1.35, true)
		for spark_index: int in range(3):
			var spark_at := 0.2 + float(spark_index) * 0.28
			var spark_position := start.lerp(end, spark_at) + normal * sin(float(frame_index + spark_index * 4)) * 4.0
			draw_circle(spark_position, 1.6 + float(spark_index) * 0.5, _color_with_alpha(core_color, slash_alpha * 0.8))


func _draw_thunder_punch_visual() -> void:
	if not bool(thunder_punch_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(frame_index) / float(total_frames), 0.0, 1.0)
	var visible_start: float = clampf(float(thunder_punch_config.get("visible_start", 0.2)), 0.0, 1.0)
	var visible_end: float = clampf(float(thunder_punch_config.get("visible_end", 0.9)), visible_start, 1.0)
	if progress < visible_start or progress > visible_end:
		return

	var alpha := _get_timed_alpha(progress, visible_start, visible_end, thunder_punch_config)
	if alpha <= 0.02:
		return

	var center := _battlefield_position(_vector2_from_value(thunder_punch_config.get("center", [384.0, 96.0])))
	center += _vector2_from_value(thunder_punch_config.get("center_offset", [0.0, 0.0]))
	var bolt_color := _color_from_value(thunder_punch_config.get("bolt_color", [1.0, 0.76, 0.06, 1.0]), Color(1.0, 0.76, 0.06, 1.0))
	var core_color := _color_from_value(thunder_punch_config.get("core_color", [1.0, 1.0, 0.82, 1.0]), Color(1.0, 1.0, 0.82, 1.0))
	var bolt_height := maxf(float(thunder_punch_config.get("bolt_height", 62.0)), 16.0)
	var bolt_width := maxf(float(thunder_punch_config.get("bolt_width", 34.0)), 8.0)
	var phase := float(frame_index) * 0.74

	for bolt_index: int in range(2):
		var side := -1.0 if bolt_index == 0 else 1.0
		var start := center + Vector2(side * bolt_width, -bolt_height)
		var points := PackedVector2Array([start])
		for segment_index: int in range(1, 5):
			var t := float(segment_index) / 4.0
			var wobble := sin(phase + float(segment_index) * 2.17 + float(bolt_index) * 1.43) * bolt_width * (0.46 - t * 0.18)
			points.append(center.lerp(start, 1.0 - t) + Vector2(wobble, 0.0))
		points[points.size() - 1] = center + Vector2(side * 4.0, 1.0)
		draw_polyline(points, _color_with_alpha(bolt_color, alpha * 0.3), 7.2, true)
		draw_polyline(points, _color_with_alpha(bolt_color, alpha), 3.4, true)
		draw_polyline(points, _color_with_alpha(core_color, alpha * 0.9), 1.1, true)

	var pulse_radius := 18.0 + sin(phase * 0.7) * 3.0
	draw_circle(center, pulse_radius, _color_with_alpha(bolt_color, alpha * 0.12))
	draw_arc(center, pulse_radius * 1.16, phase, phase + PI * 1.48, 32, _color_with_alpha(core_color, alpha * 0.82), 1.5)


func _draw_dark_pulse_visual() -> void:
	if not bool(dark_pulse_config.get("enabled", false)):
		return
	var frames: Array = data.get("frames", []) as Array
	var progress := clampf(float(frame_index) / float(maxi(frames.size() - 1, 1)), 0.0, 1.0)
	var alpha := _get_timed_alpha(progress, float(dark_pulse_config.get("visible_start", 0.0)), float(dark_pulse_config.get("visible_end", 0.9)), dark_pulse_config)
	if alpha <= 0.02:
		return
	var source := _projectile_battlefield_position(_get_projectile_state_from_config(0.0, dark_pulse_config).get("position", Vector2.ZERO) as Vector2, dark_pulse_config)
	var target := _projectile_battlefield_position(_get_projectile_state_from_config(1.0, dark_pulse_config).get("position", Vector2.ZERO) as Vector2, dark_pulse_config)
	var direction := (target - source).normalized()
	var normal := direction.orthogonal()
	var purple := _color_from_value(dark_pulse_config.get("color", [0.72, 0.08, 0.92, 1.0]), Color(0.72, 0.08, 0.92, 1.0))
	var draw_layer := str(dark_pulse_config.get("draw_layer", "all")).strip_edges().to_lower()
	var charge_end := clampf(float(dark_pulse_config.get("charge_end", 0.32)), 0.0, 0.8)
	if progress < charge_end:
		var charge := clampf(progress / maxf(charge_end, 0.001), 0.0, 1.0)
		if draw_layer in ["all", "underlay"]:
			var ground := source + Vector2(0.0, 24.0)
			draw_set_transform(ground, 0.0, Vector2(1.0, 0.28))
			draw_circle(Vector2.ZERO, 68.0 + charge * 16.0, _color_with_alpha(Color(0.08, 0.26, 0.88, 1.0), alpha * 0.2))
			draw_arc(Vector2.ZERO, 58.0 + charge * 14.0, 0.0, TAU, 48, _color_with_alpha(Color.BLACK, alpha * 0.9), 5.2)
			draw_arc(Vector2.ZERO, 50.0 + charge * 12.0, float(frame_index) * 0.18, float(frame_index) * 0.18 + TAU * 0.86, 48, _color_with_alpha(purple, alpha), 2.6)
			draw_set_transform(Vector2.ZERO)
		for ring_index in range(11):
			var ring_angle := float(ring_index) * TAU / 11.0 + float(frame_index) * 0.11
			var outer_distance := 48.0 + float(ring_index % 4) * 16.0
			var gather_distance := 16.0 + float(ring_index % 3) * 5.0
			var ring_distance := lerpf(outer_distance, gather_distance, charge)
			var gather_point := source + direction * (18.0 + charge * 16.0) + Vector2(0.0, -16.0)
			var ring_center := gather_point + Vector2(cos(ring_angle) * ring_distance, sin(ring_angle) * ring_distance * 0.5)
			var ring_is_foreground := ring_center.y >= source.y - 4.0
			if draw_layer == "underlay" and ring_is_foreground:
				continue
			if draw_layer == "foreground" and not ring_is_foreground:
				continue
			var ring_radius := 8.0 + float(ring_index % 3) * 4.5
			draw_circle(ring_center, ring_radius, _color_with_alpha(purple, alpha * 0.12))
			draw_arc(ring_center, ring_radius, 0.0, TAU, 24, _color_with_alpha(Color(1.0, 0.12, 0.68, 1.0), alpha), 1.8)
		return
	if draw_layer == "underlay":
		return
	# The fired waves start at the same forward point where the charge rings converge.
	source += direction * 34.0 + Vector2(0.0, -16.0)
	direction = (target - source).normalized()
	normal = direction.orthogonal()
	var ring_count := maxi(3, int(dark_pulse_config.get("ring_count", 8)))
	for ring_index in range(ring_count):
		var t := ((progress - charge_end) / maxf(1.0 - charge_end, 0.001)) * 1.65 - float(ring_index) / float(ring_count)
		if t < 0.0 or t > 1.0:
			continue
		var center := source.lerp(target, t)
		var radius := 12.0 + t * 24.0
		draw_set_transform(center, atan2(direction.y, direction.x), Vector2(1.0, 0.46))
		draw_circle(Vector2.ZERO, radius + 7.0, _color_with_alpha(Color(0.08, 0.28, 0.96, 1.0), alpha * 0.13))
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 36, _color_with_alpha(Color(0.12, 0.42, 1.0, 1.0), alpha * 0.32), 6.4)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, _color_with_alpha(Color.BLACK, alpha * 0.68), 3.6)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, _color_with_alpha(purple, alpha), 2.7)
		draw_arc(Vector2.ZERO, radius - 1.2, 0.0, TAU, 36, _color_with_alpha(Color(1.0, 0.42, 0.82, 1.0), alpha * 0.8), 0.8)
		draw_set_transform(Vector2.ZERO)


func _draw_sound_wave_visual() -> void:
	if not bool(sound_wave_config.get("enabled", false)):
		return
	var frames: Array = data.get("frames", []) as Array
	var progress := clampf(float(frame_index) / float(maxi(frames.size() - 1, 1)), 0.0, 1.0)
	var visible_start := float(sound_wave_config.get("visible_start", 0.06))
	var visible_end := float(sound_wave_config.get("visible_end", 0.94))
	var alpha := _get_timed_alpha(progress, visible_start, visible_end, sound_wave_config)
	if alpha <= 0.02:
		return
	var source := _projectile_battlefield_position(_get_projectile_state_from_config(0.0, sound_wave_config).get("position", Vector2.ZERO) as Vector2, sound_wave_config)
	var target := _projectile_battlefield_position(_get_projectile_state_from_config(1.0, sound_wave_config).get("position", Vector2.ZERO) as Vector2, sound_wave_config)
	var direction := (target - source).normalized()
	var rotation := atan2(direction.y, direction.x)
	var wave_color := _color_from_value(sound_wave_config.get("wave_color", [0.18, 0.86, 1.0, 1.0]), Color(0.18, 0.86, 1.0, 1.0))
	var core_color := _color_from_value(sound_wave_config.get("core_color", [0.9, 0.98, 1.0, 1.0]), Color(0.9, 0.98, 1.0, 1.0))
	var aura_color := _color_from_value(sound_wave_config.get("aura_color", [0.72, 0.18, 0.96, 1.0]), Color(0.72, 0.18, 0.96, 1.0))
	var impact_color := _color_from_value(sound_wave_config.get("impact_color", [0.86, 0.12, 0.7, 1.0]), Color(0.86, 0.12, 0.7, 1.0))
	var launch_start := clampf(float(sound_wave_config.get("launch_start", 0.12)), visible_start, visible_end - 0.1)
	var impact_start := clampf(float(sound_wave_config.get("impact_start", 0.72)), launch_start + 0.1, visible_end)
	var ring_count := maxi(2, int(sound_wave_config.get("ring_count", 5)))
	var travel := clampf((progress - launch_start) / maxf(impact_start - launch_start, 0.001), 0.0, 1.0)
	for ring_index in range(ring_count):
		# The leading wave stays small while the two following wavefronts expand
		# behind it, matching Psychic Noise's stacked sonic portals.
		var ring_progress := travel - float(ring_index) * 0.19
		if ring_progress < 0.0 or ring_progress > 1.0:
			continue
		var center := source.lerp(target, ring_progress)
		var radius := lerpf(float(sound_wave_config.get("rear_radius", 36.0)), float(sound_wave_config.get("front_radius", 14.0)), ring_progress)
		var ring_alpha := alpha * (0.98 - float(ring_index) * 0.12)
		# Compress the wave along its travel axis, not vertically: this makes a
		# portal-like upright ellipse rather than a flat floor ring.
		draw_set_transform(center, rotation, Vector2(float(sound_wave_config.get("ring_depth", 0.38)), 1.0))
		draw_arc(Vector2.ZERO, radius + 12.0, 0.0, TAU, 48, _color_with_alpha(aura_color, ring_alpha * 0.12), 18.0)
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 48, _color_with_alpha(aura_color, ring_alpha * 0.34), 7.0)
		draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 48, _color_with_alpha(wave_color, ring_alpha * 0.2), 12.0)
		draw_arc(Vector2.ZERO, radius + 1.0, 0.0, TAU, 48, _color_with_alpha(wave_color, ring_alpha), 4.6)
		draw_arc(Vector2.ZERO, radius - 3.0, 0.14, TAU - 0.14, 48, _color_with_alpha(core_color, ring_alpha * 0.9), 1.6)
		for mote_index in range(3):
			var mote_angle := float(frame_index) * 0.21 + float(ring_index) * 1.8 + float(mote_index) * TAU / 3.0
			var mote_center := Vector2(cos(mote_angle), sin(mote_angle)) * (radius + 13.0)
			draw_circle(mote_center, 2.0 + float(mote_index % 2), _color_with_alpha(aura_color, ring_alpha * 0.86))
		draw_set_transform(Vector2.ZERO)

	if progress < impact_start:
		return
	var impact_progress := clampf((progress - impact_start) / maxf(visible_end - impact_start, 0.001), 0.0, 1.0)
	var impact_alpha := alpha * (1.0 - impact_progress)
	var impact_center := target + _vector2_from_value(sound_wave_config.get("impact_offset", [0.0, -8.0]))
	var impact_radius := lerpf(22.0, float(sound_wave_config.get("impact_radius", 68.0)), impact_progress)
	var impact_core := _color_from_value(sound_wave_config.get("impact_core_color", [0.34, 0.04, 0.58, 1.0]), Color(0.34, 0.04, 0.58, 1.0))
	var lightning := _color_from_value(sound_wave_config.get("lightning_color", [1.0, 0.72, 1.0, 1.0]), Color(1.0, 0.72, 1.0, 1.0))
	draw_circle(impact_center, impact_radius * 1.18, _color_with_alpha(impact_color, impact_alpha * 0.1))
	draw_circle(impact_center, impact_radius * 0.78, _color_with_alpha(impact_core, impact_alpha * 0.38))
	draw_circle(impact_center, impact_radius * 0.48, _color_with_alpha(impact_color, impact_alpha * 0.3))
	for impact_ring in range(3):
		var ring_phase := float(frame_index) * 0.16 + float(impact_ring) * 1.7
		draw_arc(impact_center, impact_radius * (0.42 + float(impact_ring) * 0.23), ring_phase, ring_phase + PI * 1.48, 42, _color_with_alpha(impact_color, impact_alpha * (0.92 - float(impact_ring) * 0.18)), 3.0)
	var ray_count := maxi(6, int(sound_wave_config.get("impact_ray_count", 12)))
	for ray_index in range(ray_count):
		var ray_angle := float(ray_index) * TAU / float(ray_count) + float(frame_index) * 0.07
		var inner := impact_center + Vector2(cos(ray_angle), sin(ray_angle)) * impact_radius * 0.18
		var outer := impact_center + Vector2(cos(ray_angle), sin(ray_angle)) * impact_radius * (0.88 + 0.28 * sin(float(ray_index) * 1.9 + float(frame_index) * 0.2))
		draw_line(inner, outer, _color_with_alpha(impact_color, impact_alpha * 0.62), 2.4)
	var bolt_count := maxi(3, int(sound_wave_config.get("impact_bolt_count", 5)))
	for bolt_index in range(bolt_count):
		var bolt_angle := float(bolt_index) * TAU / float(bolt_count) + float(frame_index) * 0.11
		var bolt_direction := Vector2(cos(bolt_angle), sin(bolt_angle))
		var bolt_normal := bolt_direction.orthogonal()
		var points := PackedVector2Array([impact_center + bolt_direction * impact_radius * 0.12])
		for segment_index in range(1, 4):
			var segment_progress := float(segment_index) / 3.0
			var jitter := sin(float(bolt_index) * 3.1 + float(segment_index) * 2.4 + float(frame_index) * 0.32) * impact_radius * 0.14
			points.append(impact_center + bolt_direction * impact_radius * (0.18 + segment_progress * 0.78) + bolt_normal * jitter)
		draw_polyline(points, _color_with_alpha(impact_color, impact_alpha * 0.72), 3.8, true)
		draw_polyline(points, _color_with_alpha(lightning, impact_alpha * 0.92), 1.25, true)


func _draw_leaf_rush_visual() -> void:
	if not bool(leaf_rush_config.get("enabled", false)):
		return
	var frames: Array = data.get("frames", []) as Array
	var progress := clampf(float(frame_index) / float(maxi(frames.size() - 1, 1)), 0.0, 1.0)
	var visible_start := float(leaf_rush_config.get("visible_start", 0.02))
	var visible_end := float(leaf_rush_config.get("visible_end", 0.94))
	var alpha := _get_timed_alpha(progress, visible_start, visible_end, leaf_rush_config)
	if alpha <= 0.02:
		return
	var source := _projectile_battlefield_position(_get_projectile_state_from_config(0.0, leaf_rush_config).get("position", Vector2.ZERO) as Vector2, leaf_rush_config)
	var target := _projectile_battlefield_position(_get_projectile_state_from_config(1.0, leaf_rush_config).get("position", Vector2.ZERO) as Vector2, leaf_rush_config)
	var travel_end := clampf(float(leaf_rush_config.get("travel_end", 0.7)), visible_start + 0.1, visible_end)
	var travel := clampf((progress - visible_start) / maxf(travel_end - visible_start, 0.001), 0.0, 1.0)
	var direction := (target - source).normalized()
	var normal := direction.orthogonal()
	var green := _color_from_value(leaf_rush_config.get("leaf_color", [0.38, 0.96, 0.18, 1.0]), Color(0.38, 0.96, 0.18, 1.0))
	var light_green := _color_from_value(leaf_rush_config.get("core_color", [0.88, 1.0, 0.58, 1.0]), Color(0.88, 1.0, 0.58, 1.0))
	var impact_color := _color_from_value(leaf_rush_config.get("impact_color", [0.98, 1.0, 0.74, 1.0]), Color(0.98, 1.0, 0.74, 1.0))
	var head := source.lerp(target, travel)
	var beam_start := source.lerp(target, maxf(travel - 0.42, 0.0))
	draw_line(beam_start, head, _color_with_alpha(green, alpha * 0.2), float(leaf_rush_config.get("beam_width", 34.0)))
	draw_line(beam_start, head, _color_with_alpha(light_green, alpha * 0.38), float(leaf_rush_config.get("beam_width", 34.0)) * 0.36)
	var slash_rotation := atan2(direction.y, direction.x)
	var slash_radius := float(leaf_rush_config.get("slash_radius", 27.0)) * (0.88 + 0.12 * sin(float(frame_index) * 0.6))
	draw_set_transform(head, slash_rotation, Vector2(1.6, 0.56))
	draw_circle(Vector2.ZERO, slash_radius * 1.28, _color_with_alpha(green, alpha * 0.18))
	draw_circle(Vector2.ZERO, slash_radius * 0.9, _color_with_alpha(green, alpha * 0.7))
	draw_circle(Vector2(-slash_radius * 0.12, 0.0), slash_radius * 0.48, _color_with_alpha(light_green, alpha * 0.95))
	draw_arc(Vector2.ZERO, slash_radius * 1.08, -PI * 0.72, PI * 0.72, 36, _color_with_alpha(light_green, alpha * 0.92), 3.4)
	draw_arc(Vector2.ZERO, slash_radius * 1.42, -PI * 0.64, PI * 0.54, 36, _color_with_alpha(green, alpha * 0.78), 4.6)
	draw_set_transform(Vector2.ZERO)
	var leaf_count := maxi(4, int(leaf_rush_config.get("leaf_count", 14)))
	for leaf_index in range(leaf_count):
		var delay := float(leaf_index) * 0.045
		var leaf_progress := clampf((travel - delay) / maxf(1.0 - delay, 0.001), 0.0, 1.0)
		if leaf_progress <= 0.0:
			continue
		var sway := sin(float(frame_index) * 0.38 + float(leaf_index) * 1.71) * (12.0 + float(leaf_index % 3) * 7.0)
		var center := source.lerp(target, leaf_progress) + normal * sway * sin(leaf_progress * PI)
		var rotation := atan2(direction.y, direction.x) + sin(float(leaf_index) * 1.9 + float(frame_index) * 0.3) * 0.65
		var size := 7.0 + float(leaf_index % 3) * 2.4
		draw_set_transform(center, rotation)
		draw_colored_polygon(PackedVector2Array([Vector2(-size, 0.0), Vector2(0.0, -size * 0.46), Vector2(size, 0.0), Vector2(0.0, size * 0.46)]), _color_with_alpha(green, alpha * 0.9))
		draw_line(Vector2(-size * 0.72, 0.0), Vector2(size * 0.72, 0.0), _color_with_alpha(light_green, alpha * 0.86), 1.1)
		draw_set_transform(Vector2.ZERO)
	if progress < travel_end:
		return
	var impact_progress := clampf((progress - travel_end) / maxf(visible_end - travel_end, 0.001), 0.0, 1.0)
	var impact_alpha := alpha * (1.0 - impact_progress)
	var impact_radius := lerpf(18.0, float(leaf_rush_config.get("impact_radius", 56.0)), impact_progress)
	draw_circle(target, impact_radius * 0.68, _color_with_alpha(green, impact_alpha * 0.2))
	for ray_index in range(10):
		var ray_angle := float(ray_index) * TAU / 10.0 + float(frame_index) * 0.08
		var ray_start := target + Vector2(cos(ray_angle), sin(ray_angle)) * impact_radius * 0.2
		var ray_end := target + Vector2(cos(ray_angle), sin(ray_angle)) * impact_radius * (0.72 + float(ray_index % 3) * 0.14)
		draw_line(ray_start, ray_end, _color_with_alpha(impact_color, impact_alpha * 0.9), 2.1)
	for burst_leaf_index in range(12):
		var burst_angle := float(burst_leaf_index) * TAU / 12.0 + float(frame_index) * 0.12
		var burst_center := target + Vector2(cos(burst_angle), sin(burst_angle)) * impact_radius * (0.42 + impact_progress * 0.5)
		var burst_size := 7.0 + float(burst_leaf_index % 3) * 2.6
		draw_set_transform(burst_center, burst_angle)
		draw_colored_polygon(PackedVector2Array([Vector2(-burst_size, 0.0), Vector2(0.0, -burst_size * 0.46), Vector2(burst_size, 0.0), Vector2(0.0, burst_size * 0.46)]), _color_with_alpha(green, impact_alpha * 0.94))
		draw_set_transform(Vector2.ZERO)


func _draw_nasty_plot_visual() -> void:
	if not bool(nasty_plot_config.get("enabled", false)):
		return
	var frames: Array = data.get("frames", []) as Array
	var progress := clampf(float(frame_index) / float(maxi(frames.size() - 1, 1)), 0.0, 1.0)
	var alpha := _get_timed_alpha(
		progress,
		float(nasty_plot_config.get("visible_start", 0.02)),
		float(nasty_plot_config.get("visible_end", 0.94)),
		nasty_plot_config
	)
	if alpha <= 0.02:
		return
	var center := _battlefield_position(_vector2_from_value(nasty_plot_config.get("center", [128.0, 174.0])))
	var cloud_radius := maxf(float(nasty_plot_config.get("cloud_radius", 25.0)), 8.0)
	var cloud_offsets := [Vector2(-43.0, 10.0), Vector2(0.0, -34.0), Vector2(43.0, 10.0)]
	for cloud_index: int in range(cloud_offsets.size()):
		var appear := clampf((progress - float(cloud_index) * 0.055) / 0.14, 0.0, 1.0)
		appear = 1.0 - pow(1.0 - appear, 3.0)
		var pulse := 1.0 + sin(float(frame_index) * 0.42 + float(cloud_index) * 1.7) * 0.035
		var bob := sin(float(frame_index) * 0.29 + float(cloud_index) * 2.1) * float(nasty_plot_config.get("bob_amount", 2.5))
		_draw_nasty_plot_cloud(center + cloud_offsets[cloud_index] + Vector2(0.0, bob), cloud_radius * pulse * appear, alpha)


func _draw_nasty_plot_cloud(center: Vector2, radius: float, alpha: float) -> void:
	if radius <= 1.0:
		return
	var outline := Color(0.42, 0.12, 0.62, alpha * 0.9)
	var shadow := Color(0.68, 0.72, 1.0, alpha)
	var white := Color(1.0, 1.0, 1.0, alpha)
	var lobes := [
		[Vector2(-0.64, 0.06), 0.5],
		[Vector2(-0.32, -0.4), 0.58],
		[Vector2(0.12, -0.52), 0.64],
		[Vector2(0.55, -0.18), 0.56],
		[Vector2(0.6, 0.28), 0.48],
		[Vector2(0.1, 0.34), 0.72],
		[Vector2(-0.42, 0.34), 0.58],
	]
	for lobe: Array in lobes:
		draw_circle(center + (lobe[0] as Vector2) * radius, float(lobe[1]) * radius + 2.0, outline)
	for lobe: Array in lobes:
		var lobe_center := center + (lobe[0] as Vector2) * radius
		var lobe_radius := float(lobe[1]) * radius
		draw_circle(lobe_center + Vector2(0.0, 2.0), lobe_radius, shadow)
		draw_circle(lobe_center, lobe_radius, white)
	var tail := center + Vector2(0.0, radius * 1.12)
	draw_circle(tail, radius * 0.22 + 1.5, outline)
	draw_circle(tail, radius * 0.22, white)
	draw_circle(tail + Vector2(0.0, radius * 0.38), radius * 0.11 + 1.0, outline)
	draw_circle(tail + Vector2(0.0, radius * 0.38), radius * 0.11, white)
	var question_color := Color(0.55, 0.08, 0.7, alpha)
	var question_center := center + Vector2(0.0, -radius * 0.12)
	draw_arc(question_center, radius * 0.34, -PI * 0.92, PI * 0.58, 20, question_color, maxf(2.5, radius * 0.17), true)
	draw_line(question_center + Vector2(radius * 0.19, radius * 0.26), question_center + Vector2(0.0, radius * 0.53), question_color, maxf(2.5, radius * 0.17), true)
	draw_circle(question_center + Vector2(0.0, radius * 0.78), maxf(2.0, radius * 0.09), question_color)


func _draw_bullet_punch_visual() -> void:
	if not bool(bullet_punch_config.get("enabled", false)) or sheet_texture == null:
		return

	var frames: Array = data.get("frames", []) as Array
	var total_frames: int = max(frames.size() - 1, 1)
	var progress: float = clampf(float(frame_index) / float(total_frames), 0.0, 1.0)
	var visible_start: float = clampf(float(bullet_punch_config.get("visible_start", 0.0)), 0.0, 1.0)
	var visible_end: float = clampf(float(bullet_punch_config.get("visible_end", 0.9)), visible_start, 1.0)
	if progress < visible_start or progress > visible_end:
		return

	var alpha := _get_timed_alpha(progress, visible_start, visible_end, bullet_punch_config)
	if alpha <= 0.02:
		return

	var local_progress := clampf((progress - visible_start) / maxf(visible_end - visible_start, 0.001), 0.0, 1.0)
	var punch_count := maxi(2, int(bullet_punch_config.get("punch_count", 6)))
	var interval := maxf(float(bullet_punch_config.get("punch_interval", 0.09)), 0.01)
	var travel_time := maxf(float(bullet_punch_config.get("punch_travel", 0.34)), 0.05)
	var fist_scale := maxf(float(bullet_punch_config.get("fist_scale", 0.56)), 0.1)
	var impact_center := _battlefield_position(_vector2_from_value(bullet_punch_config.get("center", [384.0, 96.0])))
	impact_center += _vector2_from_value(bullet_punch_config.get("center_offset", [0.0, 0.0]))
	var start_radius := maxf(float(bullet_punch_config.get("start_radius", 56.0)), 8.0)
	var impact_radius := maxf(float(bullet_punch_config.get("impact_radius", 10.0)), 0.0)
	var tile_size: Array = data.get("tile_size", [192, 192]) as Array
	if tile_size.size() < 2:
		return
	var tile_width := float(tile_size[0])
	var tile_height := float(tile_size[1])
	var source_rect := Rect2(tile_width, 0.0, tile_width, tile_height)

	for punch_index: int in range(punch_count):
		var launch_at := float(punch_index) * interval
		if local_progress < launch_at:
			continue
		var elapsed := local_progress - launch_at
		var punch_progress := clampf(elapsed / travel_time, 0.0, 1.0)
		var linger := clampf((travel_time + 0.13 - elapsed) / 0.13, 0.0, 1.0)
		if punch_progress >= 1.0 and linger <= 0.02:
			continue
		var angle := -PI * 0.78 + float(punch_index) * TAU / float(punch_count) + sin(float(punch_index) * 1.7) * 0.22
		var direction := Vector2(cos(angle), sin(angle))
		var radius := lerpf(start_radius, impact_radius, _ease_projectile_progress(punch_progress, "out_quad"))
		var fist_position := impact_center + direction * radius
		var scale := fist_scale * (0.82 + punch_progress * 0.22)
		var fist_size := Vector2(tile_width, tile_height) * scale
		var fist_alpha := alpha * (0.28 + 0.72 * minf(1.0, punch_progress * 3.0)) * maxf(linger, 0.35)
		var fist_rect := Rect2(fist_position - fist_size * 0.5, fist_size)
		draw_texture_rect_region(sheet_texture, fist_rect, source_rect, Color(0.9, 0.96, 1.0, fist_alpha))

		var impact_alpha := alpha * clampf((punch_progress - 0.62) / 0.28, 0.0, 1.0) * maxf(linger, 0.2)
		if impact_alpha <= 0.02:
			continue
		var glow_radius := 13.0 + impact_alpha * 16.0
		draw_circle(fist_position, glow_radius, Color(0.78, 0.88, 1.0, impact_alpha * 0.12))
		draw_circle(fist_position, glow_radius * 0.48, Color(1.0, 1.0, 1.0, impact_alpha * 0.18))
		for sparkle_index: int in range(4):
			var sparkle_angle := float(sparkle_index) * TAU / 4.0 + float(punch_index) * 0.71
			var sparkle_direction := Vector2(cos(sparkle_angle), sin(sparkle_angle))
			var sparkle_center := fist_position + sparkle_direction * glow_radius * 0.74
			var sparkle_size := 2.0 + float(sparkle_index % 2) * 1.25
			var sparkle_color := Color(1.0, 1.0, 1.0, impact_alpha * (0.68 + float(sparkle_index % 2) * 0.16))
			draw_line(sparkle_center - sparkle_direction * sparkle_size, sparkle_center + sparkle_direction * sparkle_size, sparkle_color, 1.2)
			var cross_direction := sparkle_direction.orthogonal()
			draw_line(sparkle_center - cross_direction * sparkle_size * 0.65, sparkle_center + cross_direction * sparkle_size * 0.65, sparkle_color, 0.9)


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


func _draw_bloom_doom_visual() -> void:
	if not bool(bloom_doom_config.get("enabled", false)):
		return

	var frames: Array = data.get("frames", []) as Array
	var progress := clampf(float(frame_index) / float(maxi(frames.size() - 1, 1)), 0.0, 1.0)
	var visible_start := float(bloom_doom_config.get("visible_start", 0.06))
	var visible_end := float(bloom_doom_config.get("visible_end", 0.78))
	if progress < visible_start or progress > visible_end:
		return
	var alpha := _get_timed_alpha(progress, visible_start, visible_end, bloom_doom_config)
	if alpha <= 0.02:
		return

	var source_state := _get_projectile_state_from_config(0.0, bloom_doom_config)
	var target_state := _get_projectile_state_from_config(1.0, bloom_doom_config)
	var source := _projectile_battlefield_position(source_state.get("position", Vector2.ZERO) as Vector2, bloom_doom_config)
	var target := _projectile_battlefield_position(target_state.get("position", Vector2.ZERO) as Vector2, bloom_doom_config)
	var ascent_end := float(bloom_doom_config.get("ascent_end", 0.42))
	var descent_end := float(bloom_doom_config.get("descent_end", 0.78))
	var apex := source + Vector2(0.0, float(bloom_doom_config.get("apex_height", -174.0)))
	var travel: float = clampf((progress - visible_start) / maxf(visible_end - visible_start, 0.001), 0.0, 1.0)
	var position: Vector2
	if travel < ascent_end:
		position = source.lerp(apex, ease(travel / maxf(ascent_end, 0.001), 0.75))
	else:
		position = apex.lerp(target, ease((travel - ascent_end) / maxf(descent_end - ascent_end, 0.001), 0.78))

	var leaf_color := _color_from_value(bloom_doom_config.get("leaf_color", [0.56, 1.0, 0.22, 1.0]), Color(0.56, 1.0, 0.22, 1.0))
	var petal_color := _color_from_value(bloom_doom_config.get("petal_color", [1.0, 0.38, 0.72, 1.0]), Color(1.0, 0.38, 0.72, 1.0))
	var core_color := _color_from_value(bloom_doom_config.get("core_color", [1.0, 0.88, 0.22, 1.0]), Color(1.0, 0.88, 0.22, 1.0))
	var phase := float(frame_index) * 0.46
	for trail_index: int in range(7):
		var trail_t := maxf(0.0, travel - float(trail_index) * 0.035)
		var trail_position := source.lerp(apex, ease(trail_t / maxf(ascent_end, 0.001), 0.75)) if trail_t < ascent_end else apex.lerp(target, ease((trail_t - ascent_end) / maxf(descent_end - ascent_end, 0.001), 0.78))
		var sway := Vector2(cos(phase + float(trail_index) * 1.7), sin(phase * 1.2 + float(trail_index))) * (5.0 + float(trail_index) * 1.5)
		draw_circle(trail_position + sway, 4.6 - float(trail_index) * 0.42, _color_with_alpha(leaf_color if trail_index % 2 == 0 else petal_color, alpha * (0.78 - float(trail_index) * 0.08)))

	for petal_index: int in range(5):
		var angle := phase + float(petal_index) * TAU / 5.0
		var radial := Vector2(cos(angle), sin(angle))
		var petal_center := position + radial * 13.0
		draw_line(position + radial * 4.0, petal_center, _color_with_alpha(petal_color, alpha * 0.76), 3.0)
		draw_circle(petal_center, 4.6, _color_with_alpha(petal_color, alpha * 0.9))
	draw_circle(position, 14.0, _color_with_alpha(leaf_color, alpha * 0.16))
	draw_circle(position, 7.0, _color_with_alpha(core_color, alpha * 0.92))

	if travel > descent_end * 0.82:
		var impact_progress := clampf((travel - descent_end * 0.82) / maxf(1.0 - descent_end * 0.82, 0.001), 0.0, 1.0)
		for burst_index: int in range(12):
			var angle := float(burst_index) * TAU / 12.0 + phase * 0.35
			var offset := Vector2(cos(angle), sin(angle)) * (14.0 + impact_progress * 42.0)
			draw_circle(target + offset, 3.6, _color_with_alpha(petal_color if burst_index % 2 else leaf_color, alpha * (1.0 - impact_progress) * 0.9))


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
		if sheet_pattern_exclude.has(cell_pattern):
			continue

		var sprite: Sprite2D = sprites[sprite_i]
		var active_pattern_override := reverse_pattern_override if reverse_battlefield and reverse_pattern_override >= 0 else pattern_override
		var pattern: int = active_pattern_override if active_pattern_override >= 0 else maxi(0, cell_pattern + pattern_offset)
		sprite.region_rect = Rect2(
			(pattern % columns) * tile_w,
			int(pattern / columns) * tile_h,
			tile_w,
			tile_h
		)
		var sheet_position := _scale_sprite_position(Vector2(float(cell["x"]), float(cell["y"]))) + sprite_position_offset
		sprite.position = _battlefield_position(sheet_position) + sheet_visual_offset + _get_sheet_pattern_visual_offset(cell_pattern) + _get_sheet_frame_offset(index)
		var zoom: float = (float(cell["zoom"]) / 100.0) * sprite_zoom_multiplier
		var mirror_sprite := bool(cell["mirror"])
		if reverse_battlefield and mirror_sheet_sprites_on_reverse:
			mirror_sprite = not mirror_sprite
		sprite.scale = Vector2(-zoom if mirror_sprite else zoom, zoom)
		sprite.rotation_degrees = float(cell["angle"])
		var alpha: float = float(cell["opacity"]) / 255.0
		sprite.modulate = Color(sprite_tint.r, sprite_tint.g, sprite_tint.b, alpha) if show_pink_visual else Color(1.0, 1.0, 1.0, alpha)
		sprite.visible = true
		sprite_i += 1


func _get_sheet_frame_offset(index: int) -> Vector2:
	for offset_value: Variant in sheet_frame_offsets:
		if not offset_value is Dictionary:
			continue
		var offset_config := offset_value as Dictionary
		var start_frame := int(offset_config.get("start_frame", 0))
		var end_frame := int(offset_config.get("end_frame", start_frame))
		if index >= start_frame and index <= end_frame:
			var offset := _vector2_from_value(offset_config.get("offset", [0.0, 0.0]))
			if reverse_battlefield and bool(offset_config.get("mirror_with_battlefield", false)):
				offset = -offset
			return offset
	return Vector2.ZERO


func _get_sheet_pattern_visual_offset(pattern: int) -> Vector2:
	var offset_value: Variant = sheet_pattern_visual_offsets.get(str(pattern), Vector2.ZERO)
	return offset_value as Vector2 if offset_value is Vector2 else Vector2.ZERO

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
		REVERSED_BATTLEFIELD_AXIS.y - position.y if reverse_battlefield_vertical else position.y
	)


func display_position_to_battlefield_source(position: Vector2) -> Vector2:
	# Battlefield mirroring is its own inverse. Dynamic projectile anchors arrive
	# in display coordinates, so convert them to the source coordinates that will
	# land on that display position after _battlefield_position() is applied.
	return _battlefield_position(position)


func battlefield_offset_to_display(offset: Vector2) -> Vector2:
	if not reverse_battlefield:
		return offset
	return Vector2(
		-offset.x,
		-offset.y if reverse_battlefield_vertical else offset.y
	)


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
					bg_hide_frame = -1 if timing_background_persist_until_clear else _timing_hide_frame(index, event)
			2:
				if show_timing_backgrounds:
					bg.modulate.a = float(event["opacity"]) / 255.0 if event["opacity"] != null else bg.modulate.a
					bg_hide_frame = (
						-1
						if timing_background_persist_until_clear or bg.modulate.a <= 0.0
						else _timing_hide_frame(index, event)
					)
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
