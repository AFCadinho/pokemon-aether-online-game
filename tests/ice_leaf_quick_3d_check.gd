extends "res://tests/battle_move_effects_3d_check.gd"
const Ice = preload("res://scripts/battle/battle_ui/ice_beam_move_effect_3d.gd")
const Leaves = preload("res://scripts/battle/battle_ui/leaf_move_effect_3d.gd")
const Quick = preload("res://scripts/battle/battle_ui/contact_move_effect_3d.gd")
var seconds := 0.0
func _run() -> void:
	get_tree().create_timer(30).timeout.connect(func(): get_tree().quit(1))
	_setup()
	var camera := Camera3D.new()
	stage.world.add_child(camera)
	for move in ["icebeam","razorleaf","quickattack"]:
		for paired in [false,true]:
			var points := {"source":Vector3(-2,1,0),"sources":[Vector3(-2,1,0)],"target":Vector3(2,1,0),"radius":0.8}
			if paired: points.sources=[Vector3(-2,1,-0.4),Vector3(-2,1,0.4)]
			for outcome in ["hit","miss","block"]:
				seconds = 0
				points.source = Vector3(-2,1,0)
				points.sources = [Vector3(-2,1,-0.4),Vector3(-2,1,0.4)] if paired else [points.source]
				var effect: Node = Ice.new() if move=="icebeam" else (Leaves.new() if move=="razorleaf" else Quick.new())
				stage.world.add_child(effect)
				effect.view_camera = camera
				effect.start(move,{"frames":120.0,"launch_frame":20.0,"impact_frame":48.0},
					{"show_impact":outcome=="hit","result":outcome},func():return seconds,func():return points,func():return true)
				effect.set_process(false)
				for time in [0.0,0.32,0.4,0.6,0.8,0.85,1.0,1.2,1.6,1.95]:
					seconds = time
					if move=="quickattack":
						points.source = Vector3(-2+minf(time*3,3),1,0)
						points.sources = [points.source]
					effect._process(0)
					assert(effect.pieces.size()<=55,"Bounded ice/leaf/dash pool")
					if time<effect.launch: assert(effect.cursor==0)
					for i in effect.cursor:
						assert(effect.pieces[i].transform.is_finite())
						if effect.pieces[i].mesh is QuadMesh and effect.sprite_keys[i] in ["ice_hit","leaf_hit","leaf_debris","quick_hit","quick_ring"]:
							assert(outcome=="hit" and time>=effect.impact,"No false impact on dodge/block")
					if is_equal_approx(time,0.6):
						var positions: Array[Vector3] = []
						for i in effect.cursor: positions.append(effect.pieces[i].position)
						camera.position = Vector3(4,3,-3)
						camera.look_at(Vector3(0,1,0))
						effect._process(0)
						assert(effect.elapsed==seconds and effect.cursor==positions.size())
						for i in effect.cursor: assert(effect.pieces[i].position.is_equal_approx(positions[i]),"Camera cannot move projectiles")
				effect.cancel()
				await get_tree().process_frame
		await router.play_move_animation(move,"p1","p2",{"stop_at_impact":true,"show_impact":true})
		assert(router.has_3d_impact_damage("p2"))
		assert(stage.move_contacts[0].is_empty() == (move!="quickattack"))
		assert(not router.active_audio_nodes.is_empty(),"All three moves have existing audio")
		await router.finish_3d_impact_damage("p2")
		await get_tree().process_frame
		assert(stage.common_effects.is_empty())
		router.cancel_render()
	assert(Stage.MoveAttachments.part_for("blastoise","icebeam")=="cannons")
	assert(Stage.MoveAttachments.part_for("squirtle","icebeam")=="mouth")
	assert(Stage.MoveAttachments.part_for("bulbasaur","razorleaf")=="body")
	assert(stage.attack_action_for("Razor Leaf","p1")=="special_attack")
	assert(stage.attack_action_for("Quick Attack","p1")=="physical_attack")
	assert(stage.attack_action_for("quickattack","p1")=="physical_attack")
	for identity in ["blastoise","blastoise@shiny"]:
		var timing := Timing.profile(identity,"Ice Beam","special_attack",{"special_attack":{"frames":407.5,"loop":false}})
		assert(timing.launch_frame==60 and timing.impact_frame==120)
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("ICE_LEAF_QUICK_3D_OK moves=3 outcomes=3 paired_origins=true bounded_pool=true pause_orbit=true audio=true impact_bridge=true")
	get_tree().quit()
