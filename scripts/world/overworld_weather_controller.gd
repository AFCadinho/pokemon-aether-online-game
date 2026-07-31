extends CanvasLayer

class_name OverworldWeatherController

signal weather_changed(weather: String, debug_override_active: bool)

const WEATHER_CLEAR := "clear"
const WEATHER_RAIN := "rain"
const WEATHER_SNOW := "snow"
const SUPPORTED_WEATHER: Array[String] = [WEATHER_CLEAR, WEATHER_RAIN, WEATHER_SNOW]
const WEATHER_PROFILE_OUTDOOR := "outdoor"
const WEATHER_PROFILE_DISABLED := "disabled"
const RAIN_SURFACE_META := "pao_rain_surface"
const RAIN_SURFACE_NAMES: Array[String] = ["ground", "grass", "sand", "floor", "terrain"]
const RAIN_COVER_MASK_NAMES: Array[String] = ["water", "townsigns"]

@export_range(0.0, 2.0, 0.05) var transition_duration := 0.45

@onready var rain_particles: GPUParticles2D = $RainParticles
@onready var rain_ground_impacts: Node2D = $RainGroundImpacts
@onready var snow_particles: GPUParticles2D = $SnowParticles

var server_weather := WEATHER_CLEAR
var debug_weather_override := ""
var active_weather := WEATHER_CLEAR
var current_weather_profile := WEATHER_PROFILE_OUTDOOR
var _transition_tween: Tween
var _creator_weather_visibility_override := -1


func _ready() -> void:
	_move_ground_impacts_to_world_canvas.call_deferred()
	if get_viewport() != null:
		get_viewport().size_changed.connect(_update_viewport_layout)
	_update_viewport_layout()
	_apply_weather_immediately(get_effective_weather())
	set_process(true)


func _exit_tree() -> void:
	if (
		rain_ground_impacts != null
		and is_instance_valid(rain_ground_impacts)
		and rain_ground_impacts.get_parent() != self
	):
		rain_ground_impacts.queue_free()


func _process(_delta: float) -> void:
	_update_viewport_layout()


func set_server_weather(weather: String) -> void:
	var normalized_weather := _normalize_weather(weather)
	if server_weather == normalized_weather:
		return
	server_weather = normalized_weather
	if not is_debug_weather_active():
		_transition_to_weather(get_effective_weather())


func set_debug_weather(weather: String) -> void:
	var normalized_weather := _normalize_weather(weather)
	debug_weather_override = normalized_weather
	_transition_to_weather(get_effective_weather())


func clear_debug_weather() -> void:
	if not is_debug_weather_active():
		return
	debug_weather_override = ""
	_transition_to_weather(get_effective_weather())


func set_creator_weather_effects_visible(visible: bool) -> void:
	_creator_weather_visibility_override = 1 if visible else 0
	_transition_to_weather(get_effective_weather())


func clear_creator_weather_effects_override() -> void:
	if _creator_weather_visibility_override < 0:
		return
	_creator_weather_visibility_override = -1
	_transition_to_weather(get_effective_weather())


func is_debug_weather_active() -> bool:
	return debug_weather_override != ""


func get_effective_weather() -> String:
	if not is_weather_enabled_for_current_map():
		return WEATHER_CLEAR
	if _creator_weather_visibility_override == 0:
		return WEATHER_CLEAR
	return debug_weather_override if is_debug_weather_active() else server_weather


func apply_map(map_node: Node) -> void:
	_configure_rain_impact_surfaces(map_node)
	var profile := WEATHER_PROFILE_OUTDOOR
	if map_node != null and map_node.has_method("get_weather_profile"):
		profile = str(map_node.call("get_weather_profile"))
	elif map_node != null and map_node.has_method("get_lighting_profile"):
		var lighting_profile := str(map_node.call("get_lighting_profile")).strip_edges().to_lower()
		if lighting_profile != WEATHER_PROFILE_OUTDOOR:
			profile = WEATHER_PROFILE_DISABLED
	set_weather_profile(profile)


func set_weather_profile(profile: String) -> void:
	var normalized_profile := profile.strip_edges().to_lower()
	if normalized_profile != WEATHER_PROFILE_DISABLED:
		normalized_profile = WEATHER_PROFILE_OUTDOOR
	if current_weather_profile == normalized_profile:
		return
	current_weather_profile = normalized_profile
	_transition_to_weather(get_effective_weather())


func is_weather_enabled_for_current_map() -> bool:
	return current_weather_profile == WEATHER_PROFILE_OUTDOOR


func _transition_to_weather(weather: String) -> void:
	var normalized_weather := _normalize_weather(weather)
	if active_weather == normalized_weather:
		weather_changed.emit(active_weather, is_debug_weather_active())
		return
	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null

	var previous_particles := _particles_for_weather(active_weather)
	var next_particles := _particles_for_weather(normalized_weather)
	var previous_has_rain_impacts := active_weather == WEATHER_RAIN
	var next_has_rain_impacts := normalized_weather == WEATHER_RAIN
	active_weather = normalized_weather
	if transition_duration <= 0.0:
		_apply_weather_immediately(normalized_weather)
		weather_changed.emit(active_weather, is_debug_weather_active())
		return

	if next_particles != null:
		next_particles.visible = true
		next_particles.emitting = true
		next_particles.modulate.a = 0.0
	if next_has_rain_impacts:
		rain_ground_impacts.visible = true
		rain_ground_impacts.set_emitting(true)
		rain_ground_impacts.modulate.a = 0.0
	_transition_tween = create_tween().set_parallel(true)
	if previous_particles != null and previous_particles != next_particles:
		_transition_tween.tween_property(previous_particles, "modulate:a", 0.0, transition_duration)
	if previous_has_rain_impacts and not next_has_rain_impacts:
		_transition_tween.tween_property(rain_ground_impacts, "modulate:a", 0.0, transition_duration)
	if next_particles != null:
		_transition_tween.tween_property(next_particles, "modulate:a", 1.0, transition_duration)
	if next_has_rain_impacts:
		_transition_tween.tween_property(rain_ground_impacts, "modulate:a", 1.0, transition_duration)
	_transition_tween.chain().tween_callback(_finish_weather_transition.bind(
		previous_particles,
		next_particles,
		previous_has_rain_impacts,
		next_has_rain_impacts
	))
	weather_changed.emit(active_weather, is_debug_weather_active())


func _finish_weather_transition(
	previous_particles: GPUParticles2D,
	next_particles: GPUParticles2D,
	previous_has_rain_impacts: bool,
	next_has_rain_impacts: bool
) -> void:
	if previous_particles != null and previous_particles != next_particles:
		previous_particles.emitting = false
		previous_particles.visible = false
		previous_particles.modulate.a = 1.0
	if next_particles != null:
		next_particles.visible = true
		next_particles.emitting = true
		next_particles.modulate.a = 1.0
	if previous_has_rain_impacts and not next_has_rain_impacts:
		rain_ground_impacts.set_emitting(false)
		rain_ground_impacts.visible = false
		rain_ground_impacts.modulate.a = 1.0
	if next_has_rain_impacts:
		rain_ground_impacts.visible = true
		rain_ground_impacts.set_emitting(true)
		rain_ground_impacts.modulate.a = 1.0
	_transition_tween = null


func _apply_weather_immediately(weather: String) -> void:
	active_weather = _normalize_weather(weather)
	for particles: GPUParticles2D in [rain_particles, snow_particles]:
		var enabled := particles == _particles_for_weather(active_weather)
		particles.emitting = enabled
		particles.visible = enabled
		particles.modulate.a = 1.0
	var impacts_enabled := active_weather == WEATHER_RAIN
	rain_ground_impacts.set_emitting(impacts_enabled)
	rain_ground_impacts.visible = impacts_enabled
	rain_ground_impacts.modulate.a = 1.0
	if not impacts_enabled:
		rain_ground_impacts.clear()


func _particles_for_weather(weather: String) -> GPUParticles2D:
	match weather:
		WEATHER_RAIN:
			return rain_particles
		WEATHER_SNOW:
			return snow_particles
		_:
			return null


func _update_viewport_layout() -> void:
	if rain_particles == null or rain_ground_impacts == null or snow_particles == null or get_viewport() == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var inverse_canvas_transform := get_viewport().get_canvas_transform().affine_inverse()
	var visible_top_left := inverse_canvas_transform * Vector2.ZERO
	var visible_bottom_right := inverse_canvas_transform * viewport_size
	var visible_world_size := (visible_bottom_right - visible_top_left).abs()
	var weather_origin := Vector2(
		(visible_top_left.x + visible_bottom_right.x) * 0.5,
		minf(visible_top_left.y, visible_bottom_right.y) - 48.0
	)
	var impact_margin := Vector2(16.0, 12.0)
	rain_ground_impacts.set_spawn_rect(Rect2(
		Vector2(minf(visible_top_left.x, visible_bottom_right.x), minf(visible_top_left.y, visible_bottom_right.y)) + impact_margin,
		(visible_world_size - impact_margin * 2.0).max(Vector2.ZERO)
	))
	for particles: GPUParticles2D in [rain_particles, snow_particles]:
		particles.position = weather_origin
		particles.visibility_rect = Rect2(
			-visible_world_size.x * 0.65,
			-96.0,
			visible_world_size.x * 1.3,
			visible_world_size.y + 240.0
		)
		var material := particles.process_material as ParticleProcessMaterial
		if material != null:
			material.emission_box_extents = Vector3(maxf(visible_world_size.x * 0.62, 480.0), 24.0, 1.0)


func _normalize_weather(weather: String) -> String:
	var normalized_weather := weather.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	return normalized_weather if normalized_weather in SUPPORTED_WEATHER else WEATHER_CLEAR


func _move_ground_impacts_to_world_canvas() -> void:
	var world_parent := get_parent()
	if rain_ground_impacts == null or world_parent == null or rain_ground_impacts.get_parent() == world_parent:
		return
	rain_ground_impacts.reparent(world_parent)
	rain_ground_impacts.z_as_relative = false
	rain_ground_impacts.position = Vector2.ZERO


func _configure_rain_impact_surfaces(map_node: Node) -> void:
	var surface_layers: Array[TileMapLayer] = []
	var cover_layers: Array[TileMapLayer] = []
	_collect_rain_impact_layers(map_node, surface_layers, cover_layers)
	rain_ground_impacts.set_surface_layers(surface_layers, cover_layers)
	var surface_z_index := 0
	for layer: TileMapLayer in surface_layers:
		surface_z_index = maxi(surface_z_index, layer.z_index)
	rain_ground_impacts.z_index = surface_z_index


func _collect_rain_impact_layers(
	node: Node,
	surface_layers: Array[TileMapLayer],
	cover_layers: Array[TileMapLayer]
) -> void:
	if node == null:
		return
	var layer := node as TileMapLayer
	if layer != null:
		var surface_policy := _rain_surface_policy(layer)
		if surface_policy == "ground":
			surface_layers.append(layer)
		elif surface_policy == "cover":
			cover_layers.append(layer)
	for child: Node in node.get_children():
		_collect_rain_impact_layers(child, surface_layers, cover_layers)


func _rain_surface_policy(layer: TileMapLayer) -> String:
	var explicit_policy := str(layer.get_meta(RAIN_SURFACE_META, "")).strip_edges().to_lower()
	if explicit_policy in ["ground", "surface", "allow"]:
		return "ground"
	if explicit_policy in ["cover", "none", "block", "water"]:
		return "cover"

	var tiled_name := str(layer.get_meta("tiled_name", layer.name))
	var normalized_name := tiled_name.to_lower().replace(" ", "").replace("_", "").replace("-", "")
	var is_visual_layer := bool(layer.get_meta("tiled_visual_layer", false))
	if is_visual_layer:
		if normalized_name.contains("tallgrass"):
			return "cover"
		for surface_name: String in RAIN_SURFACE_NAMES:
			if normalized_name.contains(surface_name):
				return "ground"
		return "cover"
	if normalized_name in RAIN_COVER_MASK_NAMES:
		return "cover"
	return ""
