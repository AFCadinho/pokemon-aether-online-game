extends "res://tests/battle_move_effects_3d_check.gd"
var arena_environment: Environment

func _run() -> void:
	get_tree().create_timer(25.0).timeout.connect(func(): get_tree().quit(1))
	_setup()
	SettingsManager.battle_presentation_mode = "3d"
	SettingsManager.battle_3d_camera_motion = false
	SettingsManager.weather_effects = true
	stage.camera = Camera3D.new()
	stage.world.add_child(stage.camera)
	var environment := WorldEnvironment.new()
	arena_environment = Environment.new()
	arena_environment.background_mode = Environment.BG_SKY
	arena_environment.background_color = Color("aceaff")
	arena_environment.ambient_light_color = Color("e1edff")
	arena_environment.sky = Sky.new()
	arena_environment.sky.sky_material = ProceduralSkyMaterial.new()
	arena_environment.sky.sky_material.sky_top_color = Color("428bd0")
	environment.environment = arena_environment
	stage.world.add_child(environment)
	stage._update_camera(0.0)
	var overview: Transform3D = stage.camera.transform
	var effect := _start_draco()
	assert(stage.camera.environment == null, "Frame zero retains the original sky")
	_sample_atmosphere(effect, 0.1)
	assert(stage.move_atmosphere.strength > 0.0 and stage.move_atmosphere.strength < 1.0)
	var atmosphere: Environment = stage.camera.environment
	assert(atmosphere != arena_environment and atmosphere.fog_enabled)
	assert(stage.camera.transform.is_equal_approx(overview), "Blue sky works with camera motion disabled")
	_sample_atmosphere(effect, 0.6)
	assert(is_equal_approx(stage.move_atmosphere.strength, 1.0))
	assert(atmosphere.fog_light_color.is_equal_approx(stage.move_atmosphere.BLUE))
	assert(atmosphere.fog_depth_begin >= 6.0, "The immediate foreground stays clear")
	assert(stage.camera.environment == atmosphere, "Reuse one private environment throughout the move")
	stage._set_active(true)
	assert(stage.camera.environment == atmosphere, "Repeated weather snapshots do not recreate the cinematic environment")
	stage.players[0].speed_scale = 0.0
	stage._update_camera(2.0)
	assert(stage.camera.environment == atmosphere and is_equal_approx(stage.move_atmosphere.strength, 1.0), "Pause holds the sky")
	# Follow live day/night changes without altering the source sky or fog.
	arena_environment.ambient_light_color = Color("b1c5ee")
	stage._update_camera(0.0)
	assert(atmosphere.ambient_light_color == arena_environment.ambient_light_color)
	_assert_arena_unchanged()
	_sample_atmosphere(effect, 0.96)
	assert(stage.move_atmosphere.strength > 0.0 and stage.move_atmosphere.strength < 0.3)
	_sample_atmosphere(effect, 1.0)
	assert(effect.done and stage.camera.environment == null and stage.move_atmosphere.effect == null, "Natural completion restores the original environment")
	await get_tree().process_frame
	# Weather can start, change or end while Draco owns the camera environment.
	effect = _start_draco()
	_sample_atmosphere(effect, 0.6)
	for weather in ["RainDance", "SunnyDay", "Sandstorm", ""]:
		stage.set_weather_condition(weather)
		assert(stage.camera.environment == stage.move_atmosphere.atmosphere)
		if weather.is_empty():
			assert(stage.move_atmosphere.source == arena_environment and stage.move_atmosphere.original == null)
		else:
			assert(stage.move_atmosphere.source == stage.weather_effect.atmosphere)
			assert(stage.weather_effect.original_camera_environment == null, "Weather never captures the cinematic override as its base")
		_assert_arena_unchanged()
	effect.cancel()
	assert(stage.camera.environment == null)
	await get_tree().process_frame
	# Existing camera overrides and weather survive cancellation at every phase.
	var original := arena_environment.duplicate()
	stage.camera.environment = original
	stage.set_weather_condition("RainDance")
	var rain: Environment = stage.weather_effect.atmosphere
	for phase in [0.12, 0.6, 0.94]:
		effect = _start_draco()
		_sample_atmosphere(effect, phase)
		assert(stage.camera.environment != rain)
		effect.cancel()
		assert(stage.camera.environment == rain and stage.move_atmosphere.effect == null)
		await get_tree().process_frame
	stage.set_weather_condition("")
	assert(stage.camera.environment == original)
	effect = _start_draco()
	_sample_atmosphere(effect, 0.6)
	stage.actor_shown[1] = false
	effect._process(0.0)
	assert(effect.cancelled and stage.camera.environment == original, "Losing the target restores the atmosphere")
	stage.actor_shown[1] = true
	effect = _start_draco()
	_sample_atmosphere(effect, 0.6)
	SettingsManager.battle_presentation_mode = "2.5d"
	stage._update_camera(0.0)
	assert(stage.camera.environment == original, "The flat background is never recoloured")
	SettingsManager.battle_presentation_mode = "3d"
	stage._update_camera(0.0)
	assert(stage.camera.environment != original)
	stage._set_active(false)
	assert(effect.cancelled and stage.camera.environment == original)
	_assert_arena_unchanged()
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("DRACO_METEOR_ATMOSPHERE_OK native_clock=true pause=true fade=true weather_changes=true original_override=true cancellation=true hybrid=true arena_unchanged=true")
	get_tree().quit()

func _start_draco() -> Node:
	stage.start_move_action("p1", "Draco Meteor")
	var effect: Node = stage.create_move_effect("Draco Meteor", "p1", "p2", {"show_impact":true})
	effect.set_process(false)
	return effect

func _sample_atmosphere(effect: Node, phase: float) -> void:
	stage.players[0].seek(effect.duration * phase, true)
	stage._update_camera(0.0)
	effect._process(0.0)

func _assert_arena_unchanged() -> void:
	assert(not arena_environment.fog_enabled)
	assert(arena_environment.background_color == Color("aceaff"))
	assert(arena_environment.sky.sky_material.sky_top_color == Color("428bd0"))
