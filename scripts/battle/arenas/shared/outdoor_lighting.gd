extends Node
## Per-arena lighting; both scenery and Pokémon irradiance use the world clock.
const Cycle = preload("res://scripts/world/day_night_controller.gd")
var _environment: Environment
var _sky: ProceduralSkyMaterial
var _lights: Array[DirectionalLight3D] = []
var _last_seconds := -1.0

func _ready() -> void:
	var world := get_parent().get_parent()
	for child in world.get_children():
		if child is WorldEnvironment:
			_environment = child.environment.duplicate()
			child.environment = _environment
		if child is DirectionalLight3D:
			_lights.append(child)
	for child in get_parent().get_children():
		if child is DirectionalLight3D:
			_lights.append(child)
	if _environment == null:
		set_process(false)
		return
	_sky = ProceduralSkyMaterial.new()
	_sky.sky_curve = 0.2
	_sky.ground_curve = 0.2
	_environment.sky = Sky.new()
	_environment.sky.radiance_size = Sky.RADIANCE_SIZE_128
	_environment.sky.sky_material = _sky
	_environment.background_mode = Environment.BG_SKY
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# The default reflected-light source follows the sky background.
	_process(0.0)

func _process(_delta: float) -> void:
	var clock := get_node_or_null("/root/WorldTimeService")
	var seconds: float = clock.get_seconds_since_midnight() if clock != null else fmod(Time.get_unix_time_from_system(), 86400.0)
	if seconds == _last_seconds:
		return
	_last_seconds = seconds
	apply_seconds(seconds)

func apply_seconds(seconds: float) -> void:
	if _environment == null:
		return
	var hour := wrapf(seconds / 3600.0, 0.0, 24.0)
	var night := Cycle.night_intensity_for_seconds(seconds)
	var twilight := 0.0
	if hour >= 5.0 and hour < 8.0:
		twilight = maxf(0.0, 1.0 - absf(hour - 6.0) / (1.0 if hour < 6.0 else 2.0))
	elif hour >= 17.5 and hour < 20.5:
		twilight = 1.0 - absf(hour - 19.0) / 1.5
	_sky.sky_top_color = Color("428bd0").lerp(Color("101f48"), night)
	_sky.sky_horizon_color = Color("c8e7fa").lerp(Color("3b527c"), night).lerp(Color("edac85"), twilight * 0.8)
	_sky.ground_horizon_color = _sky.sky_horizon_color
	_sky.ground_bottom_color = Color("536548").lerp(Color("202c42"), night)
	_environment.ambient_light_color = Color("e1edff").lerp(Color("b1c5ee"), night)
	_environment.ambient_light_energy = lerpf(0.3, 0.36, night)
	for index in _lights.size():
		var light := _lights[index]
		if index == 0:
			light.light_color = Color("fff3df").lerp(Color("adc9ff"), night).lerp(Color("ffd0a1"), twilight * 0.65)
			light.light_energy = lerpf(1.05, 0.48, night)
			# Keep a readable rim and stable shadows across dawn and dusk.
			light.rotation_degrees = Vector3(-45.0 + 15.0 * twilight, -30.0, 0.0)
		else:
			light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
			light.light_color = Color("d7e9ff").lerp(Color("a9c3f3"), night)
			light.light_energy = lerpf(0.25, 0.12, night) if index < 3 else lerpf(0.35, 0.16, night)
