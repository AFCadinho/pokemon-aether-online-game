extends "res://tests/move_camera_choreography_check.gd"
const Extended = preload("res://scripts/battle/battle_ui/extended_move_effect_3d.gd")
var seconds := 0.0
var selected_move := ""

func _run() -> void:
	get_tree().create_timer(120).timeout.connect(func(): get_tree().quit(1))
	_setup()
	SettingsManager.battle_presentation_mode = "3d"
	SettingsManager.battle_3d_camera_motion = true
	stage.camera = Camera3D.new()
	stage.world.add_child(stage.camera)
	var samples := 0
	for key in Extended.RockGround.KEYS:
		selected_move = key
		for doubles in [false,true]:
			stage.double_mode = doubles
			for slot in (4 if doubles else 2):
				for outcome in ["hit","miss","block"]:
					var actor := "p%d" % (slot+1)
					var target := "p%d" % ((slot+1)%(4 if doubles else 2)+1)
					stage._update_camera(0)
					var overview: Transform3D = stage.camera.transform
					stage.start_move_action(actor,selected_move)
					var effect: Node = stage.create_move_effect(selected_move,actor,target,{"show_impact":outcome=="hit","result":outcome})
					effect.set_process(false)
					stage.players[slot].speed_scale = 0
					assert(effect.rock_ground!=null and stage.move_camera.effect==effect and stage.move_atmosphere.effect==effect)
					for frame in range(1,88,3):
						var time: float = effect.duration*frame/100.
						_sample(slot,effect,time)
						assert(effect.cursor<=48,"Small pooled geometry budget")
						if outcome!="hit": assert(effect.cursor==effect.rock_ground.impact_start_index,"No debris, cracks or dust on miss/block")
						for i in effect.cursor:
							var piece: MeshInstance3D = effect.pieces[i]
							assert(piece.transform.is_finite() and not piece.mesh is QuadMesh)
							for corner in 8: _in_frame(piece.transform*piece.mesh.get_aabb().get_endpoint(corner),"Rock/ground entire volume")
						var pose: Transform3D = stage.camera.transform
						var transforms: Array[Transform3D] = []
						for i in effect.cursor: transforms.append(effect.pieces[i].transform)
						effect._process(1)
						stage._update_camera(1)
						assert(stage.camera.transform.is_equal_approx(pose),"Recoil pauses with native time")
						for i in effect.cursor: assert(effect.pieces[i].transform.is_equal_approx(transforms[i]))
						samples += 1
					SettingsManager.battle_3d_camera_motion = false
					stage._update_camera(0)
					assert(stage.camera.transform.is_equal_approx(overview))
					SettingsManager.battle_3d_camera_motion = true
					_sample(slot,effect,effect.duration*.9999)
					assert(stage.camera.position.distance_to(overview.origin)<.01)
					effect.cancel()
					await get_tree().process_frame
					assert(stage.common_effects.is_empty() and stage.move_camera.effect==null and stage.move_atmosphere.effect==null)
		# Full stone bounds stay above translated/elevated floors while they tumble,
		# land, shrink and scatter; the airborne origin never replaces the floor.
		for shift in [Vector3.ZERO,Vector3(17,4.5,-12),Vector3(-8,-3,11)]:
			for heights in [Vector2(2,.4),Vector2(.08,.08),Vector2(3.5,4.)]:
				for reverse in [false,true]:
					seconds = 0
					var sign_value := -1. if reverse else 1.
					var points := {"source":shift+Vector3(-3*sign_value,heights.x,0),"target":shift+Vector3(3*sign_value,heights.y,0),"radius":.5,
						"actor_ground":shift+Vector3(-3*sign_value,.04,0),"target_ground":shift+Vector3(3*sign_value,.04,0)}
					var effect := Extended.new()
					stage.world.add_child(effect)
					effect.start(selected_move,{"frames":84.,"launch_frame":21.84,"impact_frame":54.6},{"show_impact":true},func(): return seconds,func(): return points,func(): return true)
					effect.set_process(false)
					var original_aim: Vector3 = points.target
					for frame in 84:
						seconds = frame/60.
						effect._process(0)
						for i in effect.cursor:
							var piece: MeshInstance3D = effect.pieces[i]
							for corner in 8:
								var point := piece.transform*piece.mesh.get_aabb().get_endpoint(corner)
								assert(point.y>=shift.y+.039,"Rock/ground clips floor: piece=%d time=%f y=%f floor=%f" % [i,seconds,point.y,shift.y+.04])
						if effect.launched:
							points.target += Vector3(.01,0,.01)
							assert(effect.aim.is_equal_approx(original_aim),"Dodge cannot move falling rocks")
						samples += 1
					effect.cancel()
					await get_tree().process_frame
	router.playback_speed = 8
	await router.play_move_animation(selected_move,"p1","p2",{"stop_at_impact":true,"show_impact":true})
	await router.finish_3d_impact_damage("p2")
	assert(stage.common_effects.is_empty() and stage.move_camera.effect==null)
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("ROCK_GROUND_OK samples=",samples," singles_doubles=true outcomes=3 framing=true native_pause=true recovery=true raised_floors=true dodge=true cleanup=true")
	get_tree().quit()
