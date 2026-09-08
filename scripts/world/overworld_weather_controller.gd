extends CanvasLayer

class_name OverworldWeatherController

signal weather_changed(weather: String, debug_override_active: bool)

const WEATHER_CLEAR := "clear"
const WEATHER_RAIN := "rain"
const WEATHER_SNOW := "snow"
const SUPPORTED_WEATHER: Array[String] = [WEATHER_CLEAR, WEATHER_RAIN, WEATHER_SNOW]
const WEATHER_PROFILE_OUTDOOR := "outdoor"
const WEATHER_PROFILE_DISABLED := "disabled"
const GROUND_EFFECT_SURFACE_META := "pao_rain_surface"
const GROUND_EFFECT_SURFACE_NAMES: Array[String] = ["ground", "grass", "sand", "floor", "terrain"]
const GROUND_EFFECT_WATER_NAMES: Array[String] = ["water"]
const GROUND_EFFECT_COVER_MASK_NAMES: Array[String] = ["townsigns"]

@export_range(0.0, 2.0, 0.05) var transition_duration := 0.45

@onready var rain_particles: GPUParticles2D = $RainParticles
@onready var rain_ground_effects: Node2D = $RainGroundEffects
@onready var snow_particles: GPUParticles2D = $SnowParticles
@onready var snow_ground_effects: Node2D = $SnowGroundEffects

var server_weather := WEATHER_CLEAR
var debug_weather_override := ""
var active_weather := WEATHER_CLEAR
var current_weather_profile := WEATHER_PROFILE_OUTDOOR
var _transition_tween: Tween
var _creator_weather_visibility_override := -1
var _layout_signature: Array = []
var _settings: Node


func _ready() -> void:
	_settings = get_node_or_null("/root/SettingsManager")
	if _settings != null:
		_settings.settings_changed.connect(_on_settings_changed)
	_move_ground_effects_to_world_canvas.call_deferred()
	if get_viewport() != null:
		get_viewport().size_changed.connect(_update_viewport_layout)
	_update_viewport_layout()
	_apply_weather_immediately(get_effective_weather())


func _exit_tree() -> void:
	for ground_effects: Node2D in [rain_ground_effects, snow_ground_effects]:
		if ground_effects != null and is_instance_valid(ground_effects) and ground_effects.get_parent() != self:
			ground_effects.queue_free()


func _process(_delta: float) -> void:
	_update_viewport_layout()


func _on_settings_changed() -> void:
	_transition_to_weather(get_effective_weather())


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
	if _creator_weather_visibility_override < 0 and _settings != null and not bool(_settings.get("weather_effects")):
		return WEATHER_CLEAR
	return debug_weather_override if is_debug_weather_active() else server_weather


func apply_map(map_node: Node) -> void:
	_configure_ground_effect_surfaces(map_node)
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
	var previous_ground_effects := _ground_effects_for_weather(active_weather)
	var next_ground_effects := _ground_effects_for_weather(normalized_weather)
	active_weather = normalized_weather
	set_process(true)
	_update_viewport_layout()
	if transition_duration <= 0.0:
		_apply_weather_immediately(normalized_weather)
		weather_changed.emit(active_weather, is_debug_weather_active())
		return

	if next_particles != null:
		next_particles.visible = true
		next_particles.emitting = true
		next_particles.modulate.a = 0.0
	if next_ground_effects != null:
		next_ground_effects.visible = true
		next_ground_effects.set_emitting(true)
		next_ground_effects.modulate.a = 0.0
	_transition_tween = create_tween().set_parallel(true)
	if previous_particles != null and previous_particles != next_particles:
		_transition_tween.tween_property(previous_particles, "modulate:a", 0.0, transition_duration)
	if previous_ground_effects != null and previous_ground_effects != next_ground_effects:
		_transition_tween.tween_property(previous_ground_effects, "modulate:a", 0.0, transition_duration)
	if next_particles != null:
		_transition_tween.tween_property(next_particles, "modulate:a", 1.0, transition_duration)
	if next_ground_effects != null:
		_transition_tween.tween_property(next_ground_effects, "modulate:a", 1.0, transition_duration)
	_transition_tween.chain().tween_callback(_finish_weather_transition.bind(
		previous_particles,
		next_particles,
		previous_ground_effects,
		next_ground_effects
	))
	weather_changed.emit(active_weather, is_debug_weather_active())


func _finish_weather_transition(
	previous_particles: GPUParticles2D,
	next_particles: GPUParticles2D,
	previous_ground_effects: Node2D,
	next_ground_effects: Node2D
) -> void:
	if previous_particles != null and previous_particles != next_particles:
		previous_particles.emitting = false
		previous_particles.visible = false
		previous_particles.modulate.a = 1.0
	if next_particles != null:
		next_particles.visible = true
		next_particles.emitting = true
		next_particles.modulate.a = 1.0
	if previous_ground_effects != null and previous_ground_effects != next_ground_effects:
		previous_ground_effects.set_emitting(false)
		previous_ground_effects.visible = false
		previous_ground_effects.modulate.a = 1.0
	if next_ground_effects != null:
		next_ground_effects.visible = true
		next_ground_effects.set_emitting(true)
		next_ground_effects.modulate.a = 1.0
	_transition_tween = null
	set_process(active_weather != WEATHER_CLEAR)


func _apply_weather_immediately(weather: String) -> void:
	active_weather = _normalize_weather(weather)
	set_process(active_weather != WEATHER_CLEAR)
	for particles: GPUParticles2D in [rain_particles, snow_particles]:
		var enabled := particles == _particles_for_weather(active_weather)
		particles.emitting = enabled
		particles.visible = enabled
		particles.modulate.a = 1.0
	var active_ground_effects := _ground_effects_for_weather(active_weather)
	for ground_effects: Node2D in [rain_ground_effects, snow_ground_effects]:
		var enabled := ground_effects == active_ground_effects
		ground_effects.set_emitting(enabled)
		ground_effects.visible = enabled
		ground_effects.modulate.a = 1.0
		if not enabled:
			ground_effects.clear()


func _particles_for_weather(weather: String) -> GPUParticles2D:
	match weather:
		WEATHER_RAIN:
			return rain_particles
		WEATHER_SNOW:
			return snow_particles
		_:
			return null


func _ground_effects_for_weather(weather: String) -> Node2D:
	match weather:
		WEATHER_RAIN:
			return rain_ground_effects
		WEATHER_SNOW:
			return snow_ground_effects
		_:
			return null


func _update_viewport_layout() -> void:
	if (
		rain_particles == null
		or rain_ground_effects == null
		or snow_particles == null
		or snow_ground_effects == null
		or get_viewport() == null
	):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var canvas_transform := get_viewport().get_canvas_transform()
	var signature: Array = [viewport_size, canvas_transform]
	if signature == _layout_signature:
		return
	_layout_signature = signature
	var inverse_canvas_transform := canvas_transform.affine_inverse()
	var visible_top_left := inverse_canvas_transform * Vector2.ZERO
	var visible_bottom_right := inverse_canvas_transform * viewport_size
	var visible_world_size := (visible_bottom_right - visible_top_left).abs()
	var weather_origin := Vector2(
		(visible_top_left.x + visible_bottom_right.x) * 0.5,
		minf(visible_top_left.y, visible_bottom_right.y) - 48.0
	)
	var impact_margin := Vector2(16.0, 12.0)
	var ground_effect_spawn_rect := Rect2(
		Vector2(minf(visible_top_left.x, visible_bottom_right.x), minf(visible_top_left.y, visible_bottom_right.y)) + impact_margin,
		(visible_world_size - impact_margin * 2.0).max(Vector2.ZERO)
	)
	for ground_effects: Node2D in [rain_ground_effects, snow_ground_effects]:
		ground_effects.set_spawn_rect(ground_effect_spawn_rect)
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


func _move_ground_effects_to_world_canvas() -> void:
	var world_parent := get_parent()
	if world_parent == null:
		return
	for ground_effects: Node2D in [rain_ground_effects, snow_ground_effects]:
		if ground_effects == null or ground_effects.get_parent() == world_parent:
			continue
		ground_effects.reparent(world_parent)
		ground_effects.z_as_relative = false
		ground_effects.position = Vector2.ZERO


func _configure_ground_effect_surfaces(map_node: Node) -> void:
	var surface_layers: Array[TileMapLayer] = []
	var water_layers: Array[TileMapLayer] = []
	var cover_layers: Array[TileMapLayer] = []
	_collect_ground_effect_layers(map_node, surface_layers, water_layers, cover_layers)
	var surface_z_index := _get_ground_effect_render_z_index(surface_layers, water_layers)
	for ground_effects: Node2D in [rain_ground_effects, snow_ground_effects]:
		ground_effects.set_surface_layers(surface_layers, water_layers, cover_layers)
		# Ground effects are appended after the map, so sharing the highest visible
		# surface depth keeps them above GroundDetail while leaving Objects and
		# depth-sorted actors in front. Hidden gameplay masks may still identify
		# valid surfaces, but must never lift visual effects to their technical z.
		ground_effects.z_index = surface_z_index


func _get_ground_effect_render_z_index(
	surface_layers: Array[TileMapLayer],
	water_layers: Array[TileMapLayer]
) -> int:
	var render_z_index := 0
	var found_visible_surface := false
	for layer: TileMapLayer in surface_layers + water_layers:
		if not _is_canvas_item_effectively_visible(layer):
			continue
		if not found_visible_surface:
			render_z_index = layer.z_index
			found_visible_surface = true
		else:
			render_z_index = maxi(render_z_index, layer.z_index)
	return render_z_index


func _is_canvas_item_effectively_visible(item: CanvasItem) -> bool:
	var current_item := item
	while current_item != null:
		if not current_item.visible:
			return false
		current_item = current_item.get_parent() as CanvasItem
	return true


func _collect_ground_effect_layers(
	node: Node,
	surface_layers: Array[TileMapLayer],
	water_layers: Array[TileMapLayer],
	cover_layers: Array[TileMapLayer]
) -> void:
	if node == null:
		return
	var layer := node as TileMapLayer
	if layer != null:
		var surface_policy := _ground_effect_surface_policy(layer)
		if surface_policy == "ground":
			surface_layers.append(layer)
		elif surface_policy == "water":
			water_layers.append(layer)
		elif surface_policy == "cover":
			cover_layers.append(layer)
	for child: Node in node.get_children():
		_collect_ground_effect_layers(child, surface_layers, water_layers, cover_layers)


func _ground_effect_surface_policy(layer: TileMapLayer) -> String:
	var explicit_policy := str(layer.get_meta(GROUND_EFFECT_SURFACE_META, "")).strip_edges().to_lower()
	if explicit_policy in ["ground", "surface", "allow"]:
		return "ground"
	if explicit_policy == "water":
		return "water"
	if explicit_policy in ["cover", "none", "block"]:
		return "cover"

	var tiled_name := str(layer.get_meta("tiled_name", layer.name))
	var normalized_name := tiled_name.to_lower().replace(" ", "").replace("_", "").replace("-", "")
	var is_visual_layer := bool(layer.get_meta("tiled_visual_layer", false))
	if is_visual_layer:
		for water_name: String in GROUND_EFFECT_WATER_NAMES:
			if normalized_name.contains(water_name):
				return "water"
		if normalized_name.contains("tallgrass"):
			return "cover"
		for surface_name: String in GROUND_EFFECT_SURFACE_NAMES:
			if normalized_name.contains(surface_name):
				return "ground"
		return "cover"
	if normalized_name in GROUND_EFFECT_WATER_NAMES:
		return "water"
	if normalized_name in GROUND_EFFECT_COVER_MASK_NAMES:
		return "cover"
	return ""
