extends "res://tests/move_camera_choreography_check.gd"
const Elemental = preload("res://scripts/battle/battle_ui/elemental_move_effect_3d.gd")
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")

func _test_moves() -> Array:
	return Elemental.MOVE_KEYS

func _test_renderer() -> Script:
	return Elemental

func _piece_budget() -> int:
	return 32

func _sample(slot: int, effect: Node, seconds: float) -> void:
	stage.players[slot].seek(seconds,true)
	stage._update_move_contacts()
	effect._process(0)
	stage._update_camera(0)

func _run() -> void:
	get_tree().create_timer(90).timeout.connect(func(): get_tree().quit(1))
	_setup()
	SettingsManager.battle_presentation_mode = "3d"
	SettingsManager.battle_3d_camera_motion = true
	stage.camera = Camera3D.new()
	stage.world.add_child(stage.camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	stage.world.add_child(environment)
	for doubles in [false,true]:
		stage.double_mode = doubles
		for move in _test_moves():
			for slot in (4 if doubles else 2):
				for outcome in ["hit","miss","block"]:
					stage._update_camera(0)
					var overview: Transform3D = stage.camera.transform
					var actor := "p%d" % (slot+1)
					var target := "p%d" % ((slot+1)%(4 if doubles else 2)+1)
					stage.start_move_action(actor,move)
					var timing: Dictionary = stage.move_timing(move,actor)
					assert(is_equal_approx(timing.frames/60/stage.players[slot].get_playing_speed(),float(Recipes.get_recipe(move).duration_seconds)))
					var effect: Node = stage.create_move_effect(move,actor,target,{"show_impact":outcome=="hit","result":outcome})
					assert(effect.get_script()==_test_renderer())
					effect.set_process(false)
					stage.players[slot].speed_scale = 0
					assert(stage.move_camera.effect==effect and stage.move_atmosphere.effect==effect)
					for seconds in [effect.launch*.7,lerpf(effect.launch,effect.impact,.25),lerpf(effect.launch,effect.impact,.75),lerpf(effect.impact,effect.duration,.1),lerpf(effect.impact,effect.duration,.35),lerpf(effect.impact,effect.duration,.65)]:
						_sample(slot,effect,seconds)
						assert(effect.cursor<_piece_budget())
						assert(effect.impact_drawn==(outcome=="hit" and seconds>=effect.impact))
						if seconds>=effect.impact and outcome!="hit":
							assert(effect.cursor==effect.impact_start_index,"No impact geometry on miss/block")
						for i in effect.cursor:
							var piece: MeshInstance3D = effect.pieces[i]
							assert(piece.transform.is_finite() and not piece.mesh is QuadMesh)
							if seconds/effect.duration < .88:
								for corner in 8: _in_frame(piece.transform*piece.mesh.get_aabb().get_endpoint(corner),move+" volume")
						var pose: Transform3D = stage.camera.transform
						var actor_pose: Transform3D = stage.actors[slot].transform
						var transforms: Array[Transform3D] = []
						for i in effect.cursor: transforms.append(effect.pieces[i].transform)
						var shader_clock: float = effect.surface.get_shader_parameter("seconds")
						effect._process(1)
						stage._update_camera(1)
						assert(stage.camera.transform.is_equal_approx(pose) and stage.actors[slot].transform.is_equal_approx(actor_pose))
						assert(effect.surface.get_shader_parameter("seconds")==shader_clock)
						for i in effect.cursor: assert(effect.pieces[i].transform.is_equal_approx(transforms[i]))
					SettingsManager.battle_3d_camera_motion = false
					stage._update_camera(0)
					assert(stage.camera.transform.is_equal_approx(overview))
					SettingsManager.battle_3d_camera_motion = true
					if slot==0 and outcome=="hit":
						SettingsManager.weather_effects = true
						stage.set_weather_condition("Sandstorm")
						stage._update_camera(0)
						assert(stage.move_atmosphere.source==stage.weather_effect.atmosphere)
						assert(stage.camera.environment.fog_density==stage.weather_effect.atmosphere.fog_density)
						stage.set_weather_condition("")
					_sample(slot,effect,effect.duration*.9999)
					assert(stage.camera.position.distance_to(overview.origin)<.01,"Recovery restores manual camera")
					effect.cancel()
					assert(stage.move_camera.effect==null and stage.camera.environment==null)
					assert(stage.camera.transform.is_equal_approx(overview))
					await get_tree().process_frame
	router.playback_speed = 8
	for move in _test_moves():
		await router.play_move_animation(move,"p1","p2",{"stop_at_impact":true,"show_impact":true})
		await router.finish_3d_impact_damage("p2")
		assert(stage.common_effects.is_empty() and stage.move_camera.effect==null and stage.camera.environment==null)
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("ELEMENTAL_FORMS_OK moves=",_test_moves().size()," singles_doubles=true outcomes=3 native_timing=true framing=true pause=true weather=true camera_toggle=true cleanup=true")
	get_tree().quit()
