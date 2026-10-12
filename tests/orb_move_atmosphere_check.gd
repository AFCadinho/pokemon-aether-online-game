extends "res://tests/battle_move_effects_3d_check.gd"
var seconds := 0.0
var arena: Environment

func _run() -> void:
	get_tree().create_timer(45).timeout.connect(func(): get_tree().quit(1))
	_setup()
	SettingsManager.battle_presentation_mode = "3d"
	SettingsManager.battle_3d_camera_motion = false
	SettingsManager.weather_effects = true
	stage.camera = Camera3D.new()
	stage.world.add_child(stage.camera)
	var world_environment := WorldEnvironment.new()
	arena = Environment.new()
	arena.background_mode = Environment.BG_SKY
	arena.sky = Sky.new()
	arena.sky.sky_material = ProceduralSkyMaterial.new()
	arena.ambient_light_color = Color("ddeeff")
	arena.ambient_light_energy = 0.7
	# Disabled adjustment settings must not suddenly become active with the move.
	arena.adjustment_contrast = 0.6
	world_environment.environment = arena
	stage.world.add_child(world_environment)
	for move in ["Shadow Ball", "Focus Blast", "Moonblast"]:
		for reverse in [false, true]:
			for outcome in ["hit", "miss", "block"]:
				var effect := _start(move, reverse, outcome)
				assert(stage.camera.environment == null)
				_sample(effect, effect.launch * 0.8)
				var atmosphere: Environment = stage.camera.environment
				var light: OmniLight3D = stage.move_atmosphere.orb_light
				assert(atmosphere != null and atmosphere != arena and light != null)
				assert(atmosphere.sky == arena.sky and not atmosphere.fog_enabled)
				assert(atmosphere.ambient_light_source == arena.ambient_light_source)
				assert(atmosphere.ambient_light_color != arena.ambient_light_color)
				assert(atmosphere.adjustment_contrast == 1.0)
				assert(light.light_energy > 0 and stage.move_atmosphere.pulse == 0)
				assert(light.position.is_equal_approx(effect.anchors.call().source))
				var color := atmosphere.ambient_light_color
				var pose := light.transform
				var energy := light.light_energy
				stage._update_camera(2.0)
				assert(atmosphere.ambient_light_color == color and light.transform == pose and light.light_energy == energy, "Native pause holds lighting")
				_sample(effect, lerpf(effect.launch, effect.impact, 0.5))
				assert(light.position.is_equal_approx(effect.launch_origin.lerp(effect.anchors.call().target, 0.5)))
				_sample(effect, effect.impact + effect.duration * 0.04)
				assert((stage.move_atmosphere.pulse > 0.0) == (outcome == "hit"), "Only hits have an impact light pulse")
				assert((light.light_energy > 0.0) == (outcome == "hit"))
				_sample(effect, effect.duration * 0.99)
				assert(stage.move_atmosphere.strength < 0.01)
				_sample(effect, effect.duration)
				assert(effect.done and stage.camera.environment == null and stage.move_atmosphere.orb_light == null)
				assert(not light.visible, "Cleanup hides light immediately before queued deletion")
				_assert_arena()
				await get_tree().process_frame
		# Weather swaps must unwrap the move before capturing their baseline.
		var effect := _start(move, false, "hit")
		_sample(effect, effect.launch * 0.8)
		for weather in ["RainDance", "SunnyDay", "Sandstorm", ""]:
			stage.set_weather_condition(weather)
			assert(stage.camera.environment == stage.move_atmosphere.atmosphere)
			if not weather.is_empty():
				assert(stage.move_atmosphere.source == stage.weather_effect.atmosphere)
				assert(stage.weather_effect.original_camera_environment == null)
			_assert_arena()
		effect.cancel()
		assert(stage.camera.environment == null and stage.move_atmosphere.orb_light == null)
		await get_tree().process_frame
		# Preserve an existing camera override and follow live ambient changes.
		var original := arena.duplicate()
		original.adjustment_enabled = true
		original.adjustment_brightness = 0.8
		stage.camera.environment = original
		for phase in [0.15, 0.6, 0.94]:
			effect = _start(move, false, "hit")
			_sample(effect, effect.duration * phase)
			assert(stage.move_atmosphere.source == original)
			assert(is_equal_approx(stage.camera.environment.adjustment_contrast, 0.6))
			original.ambient_light_energy = 0.3
			stage._update_camera(0)
			assert(stage.camera.environment.ambient_light_energy <= 0.31)
			effect.cancel()
			assert(stage.camera.environment == original and stage.move_atmosphere.orb_light == null)
			await get_tree().process_frame
		stage.camera.environment = null
	var old := _start("Shadow Ball", false, "hit")
	_sample(old, old.launch * 0.8)
	var current := _start("Moonblast", true, "hit")
	_sample(current, current.launch * 0.8)
	old.cancel()
	assert(stage.move_atmosphere.effect == current and stage.move_atmosphere.orb_light != null, "Old cleanup cannot clear a new move")
	SettingsManager.battle_presentation_mode = "2.5d"
	stage._update_camera(0)
	assert(stage.camera.environment == null and stage.move_atmosphere.orb_light == null)
	SettingsManager.battle_presentation_mode = "3d"
	stage._update_camera(0)
	assert(stage.move_atmosphere.orb_light != null)
	stage._set_active(false)
	assert(current.cancelled and stage.camera.environment == null and stage.move_atmosphere.orb_light == null)
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("ORB_MOVE_ATMOSPHERE_OK moves=3 directions=2 outcomes=3 native_pause=true local_light=true weather=true overrides=true cancellation=true ownership=true hybrid=true restore=true")
	get_tree().quit()

func _start(move: String, reverse: bool, outcome: String) -> Node:
	seconds = 0
	var actor := "p2" if reverse else "p1"
	var target := "p1" if reverse else "p2"
	stage.start_move_action(actor, move)
	var effect: Node = stage.create_move_effect(move, actor, target, {"show_impact":outcome == "hit", "result":outcome})
	effect.clock = func(): return seconds
	effect.set_process(false)
	return effect

func _sample(effect: Node, value: float) -> void:
	seconds = value
	effect._process(0)
	stage._update_camera(0)

func _assert_arena() -> void:
	assert(not arena.fog_enabled and not arena.adjustment_enabled)
	assert(arena.ambient_light_color == Color("ddeeff") and is_equal_approx(arena.ambient_light_energy, 0.7))
