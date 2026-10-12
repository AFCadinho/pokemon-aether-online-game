extends "res://tests/move_camera_choreography_check.gd"
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
const SkyPath = preload("res://scripts/battle/battle_ui/skystrike_path_3d.gd")

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
	for move in ["fierywrath","supersonicskystrike"]:
		for slot in 4:
			for outcome in ["hit","miss","block"]:
				var actor := "p%d" % (slot+1)
				var target := "p%d" % ((slot+1)%4+1)
				stage.start_move_action(actor,move)
				var timing: Dictionary = stage.move_timing(move,actor)
				assert(is_equal_approx(timing.frames/60/stage.players[slot].get_playing_speed(),float(Recipes.get_recipe(move).duration_seconds)))
				var effect: Node = stage.create_move_effect(move,actor,target,{"show_impact":outcome=="hit","result":outcome})
				effect.set_process(false)
				stage.players[slot].speed_scale = 0
				assert(stage.move_camera.effect==effect and stage.move_atmosphere.effect==effect)
				var saw_impact := false
				for frame in range(1,60):
					_sample(slot,effect,effect.duration*frame/60.0)
					assert(effect.cursor<40)
					for i in effect.cursor:
						assert(effect.pieces[i].transform.is_finite() and not effect.pieces[i].mesh is QuadMesh)
					if effect.impact_drawn:
						assert(outcome=="hit" and effect.elapsed>=effect.impact)
						saw_impact = true
					if move=="supersonicskystrike" and effect.elapsed>=effect.impact:
						assert((effect.cursor>=11)==(outcome=="hit"),"Solid explosion exists only on a confirmed hit")
						var after: float = (effect.elapsed-effect.impact)/(effect.duration-effect.impact)
						if outcome=="hit" and after<0.65:
							for i in range(1,effect.cursor):
								var piece: MeshInstance3D = effect.pieces[i]
								var bounds := piece.mesh.get_aabb()
								for corner in 8: _in_frame(piece.transform*(bounds.get_endpoint(corner)*1.12),"Explosion volume stays framed")
							var opacity: float = effect.skystrike_explosion.cloud.get_shader_parameter("opacity")
							effect._process(0)
							assert(effect.skystrike_explosion.cloud.get_shader_parameter("opacity")==opacity,"Explosion freezes with the native clock")
					if move=="supersonicskystrike" and effect.elapsed>=effect.launch and effect.elapsed<effect.impact:
						_in_frame(effect.anchors.call().actor_center, "Skystrike model stays framed during ascent and dive")
					var pose: Transform3D = stage.camera.transform
					var actor_pose: Transform3D = stage.actors[slot].transform
					stage._update_camera(1)
					assert(stage.camera.transform.is_equal_approx(pose) and stage.actors[slot].transform.is_equal_approx(actor_pose))
				assert(saw_impact==(outcome=="hit"))
				if move=="supersonicskystrike":
					_sample(slot,effect,lerpf(effect.launch,effect.impact*0.96,0.5))
					assert(stage.contact_offsets[slot].y>4, "Skystrike has a full ascent")
					_sample(slot,effect,effect.impact)
					assert(stage.contact_offsets[slot].is_equal_approx(stage.move_contacts[slot].displacement),"Dive arrives on the native impact beat")
				if slot==0 and outcome=="hit":
					SettingsManager.weather_effects = true
					stage.set_weather_condition("Sandstorm")
					stage._update_camera(0)
					assert(stage.move_atmosphere.source == stage.weather_effect.atmosphere)
					assert(stage.camera.environment.fog_density == stage.weather_effect.atmosphere.fog_density)
					stage.set_weather_condition("")
				effect.cancel()
				assert(stage.move_camera.effect==null and stage.camera.environment==null and stage.contact_offsets[slot].is_zero_approx())
				await get_tree().process_frame
	assert(SkyPath.offset(0,Vector3(4,0,0)).is_zero_approx())
	assert(SkyPath.offset(1,Vector3(4,0,0)).is_equal_approx(Vector3(4,0,0)))
	router.playback_speed = 8
	for move in ["fierywrath","supersonicskystrike"]:
		await router.play_move_animation(move,"p1","p2",{"stop_at_impact":true,"show_impact":true})
		await router.finish_3d_impact_damage("p2")
		assert(stage.common_effects.is_empty() and stage.move_camera.effect==null and stage.camera.environment==null)
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("WRATH_SKYSTRIKE_OK slots=4 outcomes=3 native_timing=true ascent_dive=true framing=true pause=true cancellation=true natural_completion=true")
	get_tree().quit()
