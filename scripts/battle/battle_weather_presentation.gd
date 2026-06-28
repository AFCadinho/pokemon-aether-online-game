extends RefCounted

class_name BattleWeatherPresentation

var weather_particles: GPUParticles2D
var weather_tint: ColorRect
var battle_background: TextureRect
var sun_rays: Control
var sun_sparkles: GPUParticles2D
var desolate_land_layer: Control
var primordial_sea_layer: Control
var sandstorm_particles: GPUParticles2D
var sandstorm_swirls: Control
var snow_particles: GPUParticles2D
var terrain_tint: ColorRect
var grassy_terrain_layer: Control
var misty_terrain_layer: Control
var psychic_terrain_layer: Control
var electric_terrain_layer: Control
var trick_room_layer: Control

var sun_weather_time := 0.0
var desolate_land_time := 0.0
var primordial_sea_time := 0.0
var sandstorm_weather_time := 0.0
var grassy_terrain_time := 0.0
var trick_room_time := 0.0
var active_terrain_effect := ""

func setup(
	weather_particles_node: GPUParticles2D,
	weather_tint_node: ColorRect,
	battle_background_node: TextureRect,
	sun_rays_node: Control,
	sun_sparkles_node: GPUParticles2D,
	desolate_land_layer_node: Control,
	primordial_sea_layer_node: Control,
	sandstorm_particles_node: GPUParticles2D,
	sandstorm_swirls_node: Control,
	terrain_tint_node: ColorRect,
	grassy_terrain_layer_node: Control,
	misty_terrain_layer_node: Control,
	psychic_terrain_layer_node: Control,
	electric_terrain_layer_node: Control,
	trick_room_layer_node: Control,
	snow_particles_node: GPUParticles2D = null
) -> void:
	weather_particles = weather_particles_node
	weather_tint = weather_tint_node
	battle_background = battle_background_node
	sun_rays = sun_rays_node
	sun_sparkles = sun_sparkles_node
	desolate_land_layer = desolate_land_layer_node
	primordial_sea_layer = primordial_sea_layer_node
	sandstorm_particles = sandstorm_particles_node
	sandstorm_swirls = sandstorm_swirls_node
	snow_particles = snow_particles_node
	terrain_tint = terrain_tint_node
	grassy_terrain_layer = grassy_terrain_layer_node
	misty_terrain_layer = misty_terrain_layer_node
	psychic_terrain_layer = psychic_terrain_layer_node
	electric_terrain_layer = electric_terrain_layer_node
	trick_room_layer = trick_room_layer_node

func update_weather(weather_effect: String) -> void:
	if not SettingsManager.weather_effects:
		_hide_weather_effects()
		return

	_update_weather_tint(weather_effect)

	var weather_key := _normalize_weather_key(weather_effect)
	var should_emit_rain := _is_rain_weather_key(weather_key)
	if weather_particles != null:
		weather_particles.visible = should_emit_rain
		weather_particles.emitting = should_emit_rain
		weather_particles.amount = 1280 if weather_key == "primordialsea" else 980

	var should_show_primordial_sea := weather_key == "primordialsea"
	if primordial_sea_layer != null:
		primordial_sea_layer.visible = should_show_primordial_sea
		if not should_show_primordial_sea:
			primordial_sea_layer.modulate = Color.WHITE
			primordial_sea_time = 0.0

	var should_show_sun := _is_sun_weather_key(weather_key)
	if sun_rays != null:
		sun_rays.visible = should_show_sun
		if not should_show_sun:
			sun_rays.position = Vector2.ZERO
			sun_rays.modulate = Color.WHITE
			sun_weather_time = 0.0
	if sun_sparkles != null:
		sun_sparkles.visible = should_show_sun
		sun_sparkles.emitting = should_show_sun
		sun_sparkles.amount = 105 if weather_key == "desolateland" else 70

	var should_show_desolate_land := weather_key == "desolateland"
	if desolate_land_layer != null:
		desolate_land_layer.visible = should_show_desolate_land
		if not should_show_desolate_land:
			desolate_land_layer.position = Vector2.ZERO
			desolate_land_layer.modulate = Color.WHITE
			desolate_land_time = 0.0

	var should_emit_sandstorm := weather_key == "sandstorm"
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

	var should_emit_snow := _is_snow_weather_key(weather_key)
	if snow_particles != null:
		snow_particles.visible = should_emit_snow
		snow_particles.emitting = should_emit_snow

func animate(delta: float) -> void:
	if not SettingsManager.weather_effects and not SettingsManager.terrain_effects:
		return

	if sun_rays != null and sun_rays.visible:
		_animate_sun_weather(delta)
	if desolate_land_layer != null and desolate_land_layer.visible:
		_animate_desolate_land(delta)
	if primordial_sea_layer != null and primordial_sea_layer.visible:
		_animate_primordial_sea(delta)
	if sandstorm_swirls != null and sandstorm_swirls.visible:
		_animate_sandstorm_weather(delta)
	if terrain_tint != null and terrain_tint.visible:
		_animate_terrain_effects(delta)
	if trick_room_layer != null and trick_room_layer.visible:
		_animate_trick_room_effect(delta)

func update_terrain(terrain_effect: String) -> void:
	if not SettingsManager.terrain_effects:
		_hide_terrain_effects()
		return

	var terrain_key := _normalize_field_effect_key(terrain_effect)
	var should_show_grassy_terrain := terrain_key == "grassyterrain"
	var should_show_misty_terrain := terrain_key == "mistyterrain"
	var should_show_psychic_terrain := terrain_key == "psychicterrain"
	var should_show_electric_terrain := terrain_key == "electricterrain"
	var should_show_terrain := should_show_grassy_terrain or should_show_misty_terrain or should_show_psychic_terrain or should_show_electric_terrain
	active_terrain_effect = terrain_effect

	if terrain_tint != null:
		terrain_tint.visible = should_show_terrain
		if should_show_terrain:
			terrain_tint.color = _get_terrain_tint_color(terrain_effect, _get_terrain_tint_alpha(terrain_effect, 0.0))
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
	if electric_terrain_layer != null:
		electric_terrain_layer.visible = should_show_electric_terrain
		_set_child_particles_emitting(electric_terrain_layer, should_show_electric_terrain)

func update_trick_room(is_active: bool) -> void:
	if trick_room_layer == null:
		return

	if not SettingsManager.terrain_effects:
		is_active = false

	trick_room_layer.visible = is_active
	if not is_active:
		trick_room_layer.position = Vector2.ZERO
		trick_room_layer.modulate = Color.WHITE
		trick_room_time = 0.0

func _update_weather_tint(weather_effect: String) -> void:
	if weather_tint == null and battle_background == null:
		return

	var tint_color := Color.TRANSPARENT
	var should_show_tint := true
	var weather_key := _normalize_weather_key(weather_effect)
	match weather_key:
		"raindance", "rain":
			tint_color = Color(0.24, 0.46, 0.9, 0.12)
		"primordialsea":
			tint_color = Color(0.03, 0.12, 0.36, 0.36)
		"sunnyday", "sun", "harshsun":
			tint_color = Color(1.0, 0.76, 0.18, 0.1)
		"desolateland":
			tint_color = Color(1.0, 0.54, 0.08, 0.15)
		"sandstorm":
			tint_color = Color(0.68, 0.47, 0.22, 0.14)
		"hail", "snow", "snowscape":
			tint_color = Color(0.72, 0.88, 1.0, 0.1)
		_:
			should_show_tint = false

	if weather_tint != null:
		weather_tint.visible = should_show_tint
		if should_show_tint:
			weather_tint.color = tint_color
	if battle_background != null:
		battle_background.modulate = _get_weather_background_modulate(weather_key)

func _hide_weather_effects() -> void:
	if weather_tint != null:
		weather_tint.visible = false
	if battle_background != null:
		battle_background.modulate = Color.WHITE
	if weather_particles != null:
		weather_particles.visible = false
		weather_particles.emitting = false
		weather_particles.amount = 980
	if sun_rays != null:
		sun_rays.visible = false
		sun_rays.position = Vector2.ZERO
		sun_rays.modulate = Color.WHITE
	if sun_sparkles != null:
		sun_sparkles.visible = false
		sun_sparkles.emitting = false
		sun_sparkles.amount = 70
	if desolate_land_layer != null:
		desolate_land_layer.visible = false
		desolate_land_layer.position = Vector2.ZERO
		desolate_land_layer.modulate = Color.WHITE
	if primordial_sea_layer != null:
		primordial_sea_layer.visible = false
		primordial_sea_layer.modulate = Color.WHITE
	if sandstorm_particles != null:
		sandstorm_particles.visible = false
		sandstorm_particles.emitting = false
	if sandstorm_swirls != null:
		sandstorm_swirls.visible = false
		_set_child_particles_emitting(sandstorm_swirls, false)
		sandstorm_swirls.position = Vector2.ZERO
		sandstorm_swirls.modulate = Color.WHITE
	if snow_particles != null:
		snow_particles.visible = false
		snow_particles.emitting = false
	sun_weather_time = 0.0
	desolate_land_time = 0.0
	primordial_sea_time = 0.0
	sandstorm_weather_time = 0.0

func _hide_terrain_effects() -> void:
	if terrain_tint != null:
		terrain_tint.visible = false
	if grassy_terrain_layer != null:
		grassy_terrain_layer.visible = false
		_set_child_particles_emitting(grassy_terrain_layer, false)
	if misty_terrain_layer != null:
		misty_terrain_layer.visible = false
		_set_child_particles_emitting(misty_terrain_layer, false)
	if psychic_terrain_layer != null:
		psychic_terrain_layer.visible = false
		_set_child_particles_emitting(psychic_terrain_layer, false)
	if electric_terrain_layer != null:
		electric_terrain_layer.visible = false
		_set_child_particles_emitting(electric_terrain_layer, false)
	if trick_room_layer != null:
		trick_room_layer.visible = false
		trick_room_layer.position = Vector2.ZERO
		trick_room_layer.modulate = Color.WHITE
	grassy_terrain_time = 0.0
	trick_room_time = 0.0

func _animate_sun_weather(delta: float) -> void:
	sun_weather_time += delta
	var drift_x := sin(sun_weather_time * 0.45) * 14.0
	var drift_y := sin(sun_weather_time * 0.32) * 5.0
	var alpha := 0.78 + (sin(sun_weather_time * 0.8) * 0.18)
	if desolate_land_layer != null and desolate_land_layer.visible:
		alpha = 0.92 + (sin(sun_weather_time * 0.55) * 0.08)

	sun_rays.position = Vector2(drift_x, drift_y)
	sun_rays.modulate = Color(1.0, 1.0, 1.0, alpha)

func _animate_desolate_land(delta: float) -> void:
	desolate_land_time += delta
	var drift_x: float = sin(desolate_land_time * 0.28) * 10.0
	var drift_y: float = sin(desolate_land_time * 0.46) * 4.0
	var alpha: float = 0.86 + (sin(desolate_land_time * 0.72) * 0.1)

	desolate_land_layer.position = Vector2(drift_x, drift_y)
	desolate_land_layer.modulate = Color(1.0, 1.0, 1.0, alpha)

func _animate_primordial_sea(delta: float) -> void:
	primordial_sea_time += delta
	var alpha: float = 0.92 + (sin(primordial_sea_time * 0.55) * 0.08)

	primordial_sea_layer.modulate = Color(1.0, 1.0, 1.0, alpha)

func _animate_sandstorm_weather(delta: float) -> void:
	sandstorm_weather_time += delta
	var drift_x: float = sin(sandstorm_weather_time * 0.72) * 9.0
	var drift_y: float = sin(sandstorm_weather_time * 0.48) * 4.0
	var alpha: float = 0.82 + (sin(sandstorm_weather_time * 1.05) * 0.16)

	sandstorm_swirls.position = Vector2(drift_x, drift_y)
	sandstorm_swirls.modulate = Color(1.0, 1.0, 1.0, alpha)

func _get_weather_background_modulate(weather_key: String) -> Color:
	match weather_key:
		"raindance", "rain":
			return Color(0.78, 0.86, 1.0, 1.0)
		"primordialsea":
			return Color(0.55, 0.68, 0.92, 1.0)
		"sunnyday", "sun", "harshsun":
			return Color(1.0, 0.92, 0.76, 1.0)
		"desolateland":
			return Color(1.0, 0.78, 0.58, 1.0)
		"sandstorm":
			return Color(0.92, 0.82, 0.66, 1.0)
		"hail", "snow", "snowscape":
			return Color(0.86, 0.94, 1.0, 1.0)

	return Color.WHITE

func _get_terrain_tint_color(terrain_effect: String, alpha: float) -> Color:
	match _normalize_field_effect_key(terrain_effect):
		"grassyterrain":
			return Color(0.24, 0.88, 0.18, alpha)
		"mistyterrain":
			return Color(0.9, 0.48, 0.95, alpha)
		"psychicterrain":
			return Color(0.72, 0.28, 1.0, alpha)
		"electricterrain":
			return Color(1.0, 0.88, 0.12, alpha)

	return Color.TRANSPARENT

func _get_terrain_tint_alpha(terrain_effect: String, time: float) -> float:
	var pulse: float = sin(time * 0.9)
	match _normalize_field_effect_key(terrain_effect):
		"electricterrain":
			return 0.052 + (pulse * 0.012)
		"mistyterrain":
			return 0.046 + (pulse * 0.01)
		"psychicterrain":
			return 0.044 + (pulse * 0.01)
		"grassyterrain":
			return 0.04 + (pulse * 0.01)

	return 0.0

func _animate_terrain_effects(delta: float) -> void:
	grassy_terrain_time += delta
	var alpha: float = _get_terrain_tint_alpha(active_terrain_effect, grassy_terrain_time)
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

func _normalize_weather_key(weather_effect: String) -> String:
	return _normalize_field_effect_key(weather_effect)

func _normalize_field_effect_key(field_effect: String) -> String:
	var cleaned := field_effect.strip_edges()
	var separator_index := cleaned.find(":")
	if separator_index >= 0:
		cleaned = cleaned.substr(separator_index + 1).strip_edges()

	return cleaned.to_lower().replace(" ", "").replace("_", "").replace("-", "")

func _is_rain_weather_key(weather_key: String) -> bool:
	return weather_key == "raindance" or weather_key == "rain" or weather_key == "primordialsea"

func _is_sun_weather_key(weather_key: String) -> bool:
	return weather_key == "sunnyday" or weather_key == "sun" or weather_key == "harshsun" or weather_key == "desolateland"

func _is_snow_weather_key(weather_key: String) -> bool:
	return weather_key == "snow" or weather_key == "hail" or weather_key == "snowscape"
