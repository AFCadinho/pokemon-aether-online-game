extends "res://tests/move_camera_choreography_check.gd"
const ZCinema = preload("res://scripts/battle/battle_ui/z_move_cinema_3d.gd")
const ZRecipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")

func _sample(slot: int, effect: Node, seconds: float) -> void:
	stage.players[slot].seek(seconds,true)
	stage._update_move_contacts()
	effect._process(0)
	stage._update_camera(0)

func _run() -> void:
	get_tree().create_timer(150).timeout.connect(func(): get_tree().quit(1))
	_setup()
	SettingsManager.battle_presentation_mode = "3d"
	SettingsManager.battle_3d_camera_motion = true
	stage.camera = Camera3D.new()
	stage.world.add_child(stage.camera)
	stage.camera.fov = 48
	var arena := Environment.new()
	arena.background_mode = Environment.BG_COLOR
	arena.background_color = Color("345678")
	arena.ambient_light_color = Color("ddeeff")
	var world_environment := WorldEnvironment.new()
	world_environment.environment = arena
	stage.world.add_child(world_environment)
	var count := 0
	for key: String in ZRecipes.DATA.data.moves:
		if not ZRecipes.get_recipe(key).has("z_choreography"): continue
		assert(ZCinema.supports(key), key)
		assert(key == "supersonicskystrike" or ZCinema.Climax.supports(key),key+" authored finale")
		count += 1
		for doubles in [false, true]:
			stage.double_mode = doubles
			for slot in (4 if doubles else 2):
				var actor := "p%d" % (slot + 1)
				var target := "p%d" % ((slot + 1) % (4 if doubles else 2) + 1)
				for outcome in ["", "miss", "immune"]:
					stage._update_camera(0)
					var overview: Transform3D = stage.camera.transform
					stage.start_move_action(actor, key)
					var effect: Node = stage.create_move_effect(key, actor, target, {"result":outcome, "show_impact":outcome.is_empty()})
					effect.set_process(false)
					stage.players[slot].speed_scale = 0
					assert(stage.move_camera.effect == effect and stage.move_atmosphere.effect == effect)
					var timing: Dictionary = stage.move_timing(key, actor)
					assert(is_equal_approx(effect.duration, timing.frames / 60.0), "Native duration preserved")
					for seconds in [effect.launch * 0.7, lerpf(effect.launch,effect.impact,0.65), lerpf(effect.impact,effect.duration,0.35)]:
						_sample(slot, effect, seconds)
						assert(not stage.camera.transform.is_equal_approx(overview), key)
						assert(stage.camera.environment != null and stage.camera.environment != arena)
						assert(stage.move_atmosphere.strength > 0)
						assert(stage.move_atmosphere.profile_lights.size() <= 2)
						var shot := ZCinema.shot(effect, stage.camera, stage.move_camera.z_context, seconds)
						for point: Vector3 in shot.points: _in_frame(point, key + " shot bounds")
						var anchors: Dictionary = effect.anchors.call()
						_in_frame(anchors.source if seconds < effect.launch else anchors.target, key + " combat anchor")
						assert(effect.cursor < 160 and (effect.cursor > 0 or seconds > effect.impact and not outcome.is_empty()), key + " bounded geometry")
						for i in effect.cursor:
							var piece: MeshInstance3D = effect.pieces[i]
							assert(piece.transform.is_finite(), key)
							if key != "bloomdoom": assert(not piece.mesh is QuadMesh, key + " has no billboard masks")
						var before: Transform3D = stage.camera.transform
						var light_before: Color = stage.camera.environment.ambient_light_color
						stage._update_camera(2.0)
						assert(stage.camera.transform.is_equal_approx(before), key + " pause")
						assert(stage.camera.environment.ambient_light_color == light_before)
						if seconds > effect.impact:
							assert((stage.move_atmosphere.pulse > 0) == (outcome.is_empty() and key != "extremeevoboost"), key + " outcome")
					var climax_ref: WeakRef
					if ZCinema.Climax.supports(key):
						var finale: RefCounted = effect.cinematic_climax
						climax_ref = weakref(finale)
						for after in [0.01,0.13,0.28,0.5,0.7]:
							_sample(slot,effect,lerpf(effect.impact,effect.duration,after))
							var shown: bool = outcome.is_empty() or key == "extremeevoboost"
							assert((finale.start_index>=0)==shown,key+" hit-gated finale")
							if not shown: continue
							for i in range(finale.start_index,finale.end_index):
								var piece: MeshInstance3D = effect.pieces[i]
								var bounds := piece.mesh.get_aabb()
								for corner in 8: _in_frame(piece.transform*bounds.get_endpoint(corner),key+" complete explosion volume")
							var opacity: float = finale.cloud.get_shader_parameter("opacity")
							effect._process(0)
							assert(finale.cloud.get_shader_parameter("opacity")==opacity,key+" paused shader")
						finale = null
					SettingsManager.battle_3d_camera_motion = false
					stage._update_camera(0)
					assert(stage.camera.transform.is_equal_approx(overview))
					SettingsManager.battle_3d_camera_motion = true
					_sample(slot, effect, effect.duration * 0.9999)
					assert(stage.camera.position.distance_to(overview.origin) < 0.01)
					effect.cancel()
					assert(stage.camera.environment == null and stage.move_atmosphere.profile_lights.is_empty())
					assert(stage.move_camera.effect == null and stage.camera.transform.is_equal_approx(overview))
					assert(arena.background_color == Color("345678") and not arena.fog_enabled)
					await get_tree().process_frame
					if climax_ref != null: assert(climax_ref.get_ref()==null,key+" finale resources released")
		print("Z_CINEMA_PROFILE_OK ", key)
	assert(count == 35 and ZCinema.DATA.data.moves.size() == count)
	assert(ZCinema.Climax.DATA.data.moves.size()==34)
	_check_portrait_framing()
	SettingsManager.weather_effects = true
	for key in ["hydrovortex", "blackholeeclipse", "bloomdoom"]:
		stage.start_move_action("p1", key)
		var effect: Node = stage.create_move_effect(key,"p1","p2",{"show_impact":true})
		effect.set_process(false)
		_sample(0, effect, lerpf(effect.launch,effect.impact,0.5))
		for weather in ["RainDance", "Sandstorm", ""]:
			stage.set_weather_condition(weather)
			stage._update_camera(0)
			if weather != "":
				var weather_environment: Environment = stage.weather_effect.atmosphere
				assert(stage.move_atmosphere.source == weather_environment)
				if weather_environment.fog_enabled:
					assert(stage.camera.environment.fog_density == weather_environment.fog_density)
			assert(arena.background_color == Color("345678") and not arena.fog_enabled)
		SettingsManager.battle_presentation_mode = "2.5d"
		stage._update_camera(0)
		assert(stage.camera.environment == null and stage.move_atmosphere.profile_lights.is_empty())
		SettingsManager.battle_presentation_mode = "3d"
		stage._update_camera(0)
		effect.cancel()
		assert(stage.camera.environment == null)
		await get_tree().process_frame
	# Exercise real router completion, including its split at the damage beat.
	router.playback_speed = 8.0
	for key: String in ZCinema.DATA.data.moves:
		await router.play_move_animation(key,"p1","p2",{"stop_at_impact":true,"show_impact":true})
		await router.finish_3d_impact_damage("p2")
		assert(stage.move_camera.effect == null and stage.camera.environment == null, key + " natural completion")
		await get_tree().process_frame
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("Z_CINEMA_OK moves=35 singles_doubles=true outcomes=3 native_clock=true solid_forms=true pause=true restoration=true natural_completion=true weather=true hybrid=true")
	get_tree().quit()
