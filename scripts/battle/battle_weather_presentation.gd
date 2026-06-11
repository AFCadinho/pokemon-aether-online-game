extends RefCounted

class_name BattleWeatherPresentation

var weather_particles: GPUParticles2D
var weather_tint: ColorRect
var sun_rays: Control
var sun_sparkles: GPUParticles2D
var sandstorm_particles: GPUParticles2D
var sandstorm_swirls: Control
var terrain_tint: ColorRect
var grassy_terrain_layer: Control
var misty_terrain_layer: Control
var psychic_terrain_layer: Control
var trick_room_layer: Control

var sun_weather_time := 0.0
var sandstorm_weather_time := 0.0
var grassy_terrain_time := 0.0
var trick_room_time := 0.0
var active_terrain_effect := ""

func setup(
	weather_particles_node: GPUParticles2D,
	weather_tint_node: ColorRect,
	sun_rays_node: Control,
	sun_sparkles_node: GPUParticles2D,
	sandstorm_particles_node: GPUParticles2D,
	sandstorm_swirls_node: Control,
	terrain_tint_node: ColorRect,
	grassy_terrain_layer_node: Control,
	misty_terrain_layer_node: Control,
	psychic_terrain_layer_node: Control,
	trick_room_layer_node: Control
) -> void:
	weather_particles = weather_particles_node
	weather_tint = weather_tint_node
	sun_rays = sun_rays_node
	sun_sparkles = sun_sparkles_node
	sandstorm_particles = sandstorm_particles_node
	sandstorm_swirls = sandstorm_swirls_node
	terrain_tint = terrain_tint_node
	grassy_terrain_layer = grassy_terrain_layer_node
	misty_terrain_layer = misty_terrain_layer_node
	psychic_terrain_layer = psychic_terrain_layer_node
	trick_room_layer = trick_room_layer_node

func update_weather(weather_effect: String) -> void:
	_update_weather_tint(weather_effect)

	var should_emit_rain := weather_effect == "RainDance"
	if weather_particles != null:
		weather_particles.visible = should_emit_rain
		weather_particles.emitting = should_emit_rain

	var should_show_sun := weather_effect == "SunnyDay"
	if sun_rays != null:
		sun_rays.visible = should_show_sun
		if not should_show_sun:
			sun_rays.position = Vector2.ZERO
			sun_rays.modulate = Color.WHITE
			sun_weather_time = 0.0
	if sun_sparkles != null:
		sun_sparkles.visible = should_show_sun
		sun_sparkles.emitting = should_show_sun

	var should_emit_sandstorm := weather_effect == "Sandstorm"
	if sandstorm_particles != null:
		sandstorm_particles.visible = should_emit_sandstorm
		sandstorm_particles.emitting = should_emit_sandstorm
	if sandstorm_swirls != null:
		sandstorm_swirls.visible = should_emit_sandstorm
		_set_child_particles_emitting(sandstorm_swirls, should_emit_sandstorm)
		if not should_emit_sandstorm:
			sandstorm_swirls.position = Vector2.ZERO
			sandstorm_swirls.modulate = Color.WHITE
			sandstorm_weather_time = 0.0

func animate(delta: float) -> void:
	if sun_rays != null and sun_rays.visible:
		_animate_sun_weather(delta)
	if sandstorm_swirls != null and sandstorm_swirls.visible:
		_animate_sandstorm_weather(delta)
	if terrain_tint != null and terrain_tint.visible:
		_animate_terrain_effects(delta)
	if trick_room_layer != null and trick_room_layer.visible:
		_animate_trick_room_effect(delta)

func update_terrain(terrain_effect: String) -> void:
	var should_show_grassy_terrain := terrain_effect == "GrassyTerrain"
	var should_show_misty_terrain := terrain_effect == "MistyTerrain"
	var should_show_psychic_terrain := terrain_effect == "PsychicTerrain"
	var should_show_terrain := should_show_grassy_terrain or should_show_misty_terrain or should_show_psychic_terrain
	active_terrain_effect = terrain_effect

	if terrain_tint != null:
		terrain_tint.visible = should_show_terrain
		if should_show_terrain:
			terrain_tint.color = _get_terrain_tint_color(terrain_effect, 0.025)
		else:
			terrain_tint.color = Color(0.22, 0.84, 0.16, 0.025)
			grassy_terrain_time = 0.0

	if grassy_terrain_layer != null:
		grassy_terrain_layer.visible = should_show_grassy_terrain
		_set_child_particles_emitting(grassy_terrain_layer, should_show_grassy_terrain)
	if misty_terrain_layer != null:
		misty_terrain_layer.visible = should_show_misty_terrain
		_set_child_particles_emitting(misty_terrain_layer, should_show_misty_terrain)
	if psychic_terrain_layer != null:
		psychic_terrain_layer.visible = should_show_psychic_terrain
		_set_child_particles_emitting(psychic_terrain_layer, should_show_psychic_terrain)

func update_trick_room(is_active: bool) -> void:
	if trick_room_layer == null:
		return

	trick_room_layer.visible = is_active
	if not is_active:
		trick_room_layer.position = Vector2.ZERO
		trick_room_layer.modulate = Color.WHITE
		trick_room_time = 0.0

func _update_weather_tint(weather_effect: String) -> void:
	if weather_tint == null:
		return

	var tint_color := Color.TRANSPARENT
	var should_show_tint := true
	match weather_effect:
		"RainDance":
			tint_color = Color(0.24, 0.46, 0.9, 0.12)
		"SunnyDay":
			tint_color = Color(1.0, 0.76, 0.18, 0.1)
		"Sandstorm":
			tint_color = Color(0.68, 0.47, 0.22, 0.14)
		"Hail", "Snow":
			tint_color = Color(0.72, 0.88, 1.0, 0.1)
		_:
			should_show_tint = false

	weather_tint.visible = should_show_tint
	if should_show_tint:
		weather_tint.color = tint_color

func _animate_sun_weather(delta: float) -> void:
	sun_weather_time += delta
	var drift_x := sin(sun_weather_time * 0.45) * 14.0
	var drift_y := sin(sun_weather_time * 0.32) * 5.0
	var alpha := 0.78 + (sin(sun_weather_time * 0.8) * 0.18)

	sun_rays.position = Vector2(drift_x, drift_y)
	sun_rays.modulate = Color(1.0, 1.0, 1.0, alpha)

func _animate_sandstorm_weather(delta: float) -> void:
	sandstorm_weather_time += delta
	var drift_x: float = sin(sandstorm_weather_time * 0.72) * 9.0
	var drift_y: float = sin(sandstorm_weather_time * 0.48) * 4.0
	var alpha: float = 0.82 + (sin(sandstorm_weather_time * 1.05) * 0.16)

	sandstorm_swirls.position = Vector2(drift_x, drift_y)
	sandstorm_swirls.modulate = Color(1.0, 1.0, 1.0, alpha)

func _get_terrain_tint_color(terrain_effect: String, alpha: float) -> Color:
	match terrain_effect:
		"GrassyTerrain":
			return Color(0.24, 0.88, 0.18, alpha)
		"MistyTerrain":
			return Color(0.9, 0.48, 0.95, alpha)
		"PsychicTerrain":
			return Color(0.72, 0.28, 1.0, alpha)

	return Color.TRANSPARENT

func _animate_terrain_effects(delta: float) -> void:
	grassy_terrain_time += delta
	var alpha: float = 0.022 + (sin(grassy_terrain_time * 0.9) * 0.008)
	terrain_tint.color = _get_terrain_tint_color(active_terrain_effect, alpha)

func _animate_trick_room_effect(delta: float) -> void:
	trick_room_time += delta
	var drift_x: float = sin(trick_room_time * 0.55) * 4.0
	var drift_y: float = sin(trick_room_time * 0.72) * 3.0
	var alpha: float = 0.72 + (sin(trick_room_time * 1.25) * 0.18)

	trick_room_layer.position = Vector2(drift_x, drift_y)
	trick_room_layer.modulate = Color(1.0, 1.0, 1.0, alpha)

func _set_child_particles_emitting(container: Node, emitting: bool) -> void:
	for child: Node in container.get_children():
		if child is GPUParticles2D:
			var particle_node: GPUParticles2D = child as GPUParticles2D
			particle_node.emitting = emitting
