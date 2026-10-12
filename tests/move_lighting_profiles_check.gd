extends "res://tests/orb_move_atmosphere_check.gd"
const Profiles = preload("res://scripts/battle/battle_ui/move_lighting_profiles_3d.gd")
const MOVES := ["Hyper Beam", "Solar Beam", "Flash Cannon", "Pyro Ball", "Flamethrower", "Thunderbolt", "Electro Shot", "Ice Beam", "Blizzard", "Hurricane"]

func _run() -> void:
	get_tree().create_timer(75).timeout.connect(func(): get_tree().quit(1))
	_setup()
	SettingsManager.battle_presentation_mode = "3d"
	SettingsManager.battle_3d_camera_motion = false
	SettingsManager.weather_effects = true
	stage.camera = Camera3D.new()
	stage.world.add_child(stage.camera)
	var environment := WorldEnvironment.new()
	arena = Environment.new()
	arena.background_mode = Environment.BG_SKY
	arena.sky = Sky.new()
	arena.sky.sky_material = ProceduralSkyMaterial.new()
	arena.ambient_light_color = Color("ddeeff")
	arena.ambient_light_energy = 0.7
	environment.environment = arena
	stage.world.add_child(environment)
	for move in MOVES:
		for doubles in [false, true]:
			stage.double_mode = doubles
			for reverse in [false, true]:
				for outcome in ["hit", "miss", "block"]:
					var effect := _start(move, reverse, outcome)
					var points: Dictionary = effect.anchors.call()
					if move == "Flash Cannon":
						points.sources = [points.source + Vector3(0, 0, -0.4), points.source + Vector3(0, 0, 0.4)]
					effect.anchors = func(): return points
					assert(stage.move_atmosphere.effect == effect)
					if move in ["Flamethrower", "Thunderbolt", "Ice Beam"]:
						assert(stage.move_camera.effect == null, "Lighting does not add a camera cut")
					_sample(effect, effect.launch * 0.8)
					assert(stage.camera.environment != null and stage.camera.environment != arena)
					assert(stage.camera.environment.sky == arena.sky)
					assert(stage.move_atmosphere.strength > 0 and stage.move_atmosphere.pulse == 0)
					assert(_visible_count() > 0)
					_assert_pause()
					_sample(effect, lerpf(effect.launch, effect.impact, 0.5))
					assert(_visible_count() > 0 and stage.move_atmosphere.profile_lights.size() <= 7)
					if move == "Pyro Ball":
						var light: OmniLight3D = stage.move_atmosphere.profile_lights[0]
						assert(light.position.is_equal_approx(effect.origin.lerp(effect.aim, 0.5) + Vector3.UP * effect.projectile_arc_height), "Fireball light follows the real arc")
					elif effect.key not in Profiles.FIELDS:
						var emitters: Array = points.sources
						var expected_aim: Vector3 = effect.aim if effect.key in Profiles.RECIPE_BEAMS else points.target
						for index in emitters.size():
							var light: OmniLight3D = stage.move_atmosphere.profile_lights[index * 3]
							assert(light.position.is_equal_approx(emitters[index]))
							assert(stage.move_atmosphere.profile_lights[index * 3 + 2].position.is_equal_approx(emitters[index].lerp(expected_aim, 0.5)), "Light never runs ahead of the beam tip")
					_assert_pause()
					_sample(effect, lerpf(effect.impact, effect.duration, 0.1))
					assert((stage.move_atmosphere.pulse > 0) == (outcome == "hit" and move != "Hurricane"))
					for light in stage.move_atmosphere.profile_lights:
						if light.visible and light.get_meta("move_light_role") == "impact": assert(outcome == "hit")
					if effect.key not in Profiles.FIELDS and move != "Pyro Ball":
						_sample(effect, minf(Profiles.emission_end(effect) + 0.001, effect.duration * 0.999))
						for light in stage.move_atmosphere.profile_lights:
							assert(not light.visible or light.get_meta("move_light_role") != "beam", "Light stops with native emission")
					_sample(effect, effect.duration)
					assert(effect.done and stage.camera.environment == null and stage.move_atmosphere.profile_lights.is_empty())
					_assert_arena()
					await get_tree().process_frame
		# Every profile restores weather overrides and can be interrupted at each phase.
		stage.double_mode = false
		for phase in [0.15, 0.55, 0.94]:
			var effect := _start(move, false, "hit")
			_sample(effect, effect.duration * phase)
			for weather in ["RainDance", "Sandstorm", ""]:
				stage.set_weather_condition(weather)
				if weather != "":
					assert(stage.move_atmosphere.source == stage.weather_effect.atmosphere)
					assert(stage.weather_effect.original_camera_environment == null)
				_assert_arena()
			SettingsManager.battle_presentation_mode = "2.5d"
			stage._update_camera(0)
			assert(stage.camera.environment == null and stage.move_atmosphere.profile_lights.is_empty())
			SettingsManager.battle_presentation_mode = "3d"
			stage._update_camera(0)
			effect.cancel()
			assert(stage.camera.environment == null and stage.move_atmosphere.profile_lights.is_empty())
			await get_tree().process_frame
		print("MOVE_LIGHTING_PROFILE_OK ", move)
	# A non-cinematic move may own lighting while an earlier shot cleans up.
	var old := _start("Hyper Beam", false, "hit")
	_sample(old, old.launch * 0.8)
	var current := _start("Ice Beam", true, "hit")
	_sample(current, lerpf(current.launch, current.impact, 0.5))
	old.cancel()
	assert(stage.move_atmosphere.effect == current and _visible_count() > 0)
	stage._set_active(false)
	assert(current.cancelled and stage.camera.environment == null and stage.move_atmosphere.profile_lights.is_empty())
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("MOVE_LIGHTING_PROFILES_OK moves=10 directions=2 singles_doubles=true outcomes=3 pause=true emission_cutoff=true multiple_emitters=true arc=true weather=true hybrid=true cancellation=true ownership=true bounded_lights=true")
	get_tree().quit()

func _visible_count() -> int:
	var count := 0
	for light in stage.move_atmosphere.profile_lights:
		if light.visible:
			count += 1
			assert(light.transform.is_finite() and light.light_energy > 0 and light.omni_range <= 10.0)
	return count

func _assert_pause() -> void:
	var snapshot: Array = []
	var atmosphere: Environment = stage.camera.environment
	var color := atmosphere.ambient_light_color
	var brightness := atmosphere.adjustment_brightness
	for light in stage.move_atmosphere.profile_lights:
		snapshot.append([light.transform, light.visible, light.light_color, light.light_energy])
	stage._update_camera(1.0)
	assert(stage.camera.environment == atmosphere and atmosphere.ambient_light_color == color and atmosphere.adjustment_brightness == brightness)
	for i in snapshot.size():
		var light: OmniLight3D = stage.move_atmosphere.profile_lights[i]
		assert([light.transform, light.visible, light.light_color, light.light_energy] == snapshot[i], "Pause freezes light pose, colour and pulse")
