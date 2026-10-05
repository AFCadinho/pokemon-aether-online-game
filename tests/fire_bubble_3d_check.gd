extends "res://tests/battle_move_effects_3d_check.gd"
const Fire = preload("res://scripts/battle/battle_ui/fire_stream_move_effect_3d.gd")
const Bubbles = preload("res://scripts/battle/battle_ui/bubble_move_effect_3d.gd")
var seconds := 0.0
func _run() -> void:
	get_tree().create_timer(30).timeout.connect(func(): get_tree().quit(1))
	_setup()
	var camera := Camera3D.new()
	stage.world.add_child(camera)
	for move in ["flamethrower","bubble","bubblebeam"]:
		for paired in [false,true]:
			var points := {"source":Vector3(-2,1,0),"sources":[Vector3(-2,1,0)],"target":Vector3(2,1,0),"radius":0.8}
			if paired: points.sources=[Vector3(-2,1,-0.4),Vector3(-2,1,0.4)]
			for outcome in ["hit","miss","block"]:
				seconds = 0
				var effect: Node = Fire.new() if move=="flamethrower" else Bubbles.new()
				stage.world.add_child(effect)
				effect.view_camera = camera
				effect.start(move,{"frames":120.0,"launch_frame":20.0,"impact_frame":48.0},
					{"show_impact":outcome=="hit","result":outcome},func():return seconds,func():return points,func():return true)
				effect.set_process(false)
				for time in [0.0,0.32,0.4,0.6,0.8,0.85,1.0,1.2,1.6,1.95]:
					seconds = time
					effect._process(0)
					assert(effect.pieces.size()<=55,"Bounded stream/bubble pool")
					if time<effect.launch: assert(effect.cursor==0)
					for i in effect.cursor:
						assert(effect.pieces[i].transform.is_finite())
						if effect.pieces[i].mesh is QuadMesh and effect.sprite_keys[i] in ["flame_hit","flame_sparks","bubble_pop","bubble_splash"]:
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
		assert(router.has_3d_impact_damage("p2") and stage.move_contacts[0].is_empty())
		assert(not router.active_audio_nodes.is_empty(),"All three moves have existing audio")
		await router.finish_3d_impact_damage("p2")
		await get_tree().process_frame
		assert(stage.common_effects.is_empty())
		router.cancel_render()
	var catalog := Catalog.new()
	assert(catalog.get_plan("move","bubblebeam").is_empty(),"3D audio reuse must not alter the 2D catalog")
	assert(Effect.audio_source_key("Bubble Beam")=="bubble")
	for identity in ["charmander","charmander@shiny"]:
		var timing := Timing.profile(identity,"Flamethrower","special_attack_2",{"special_attack_2":{"frames":138.0,"loop":false}})
		assert(timing.launch_frame==40 and timing.impact_frame==64)
		assert(timing.emission_end_frame==78)
		assert(Stage.MoveAttachments.part_for(identity,"flamethrower")=="mouth")
		seconds = 0
		var fire := Fire.new()
		stage.world.add_child(fire)
		fire.start("flamethrower",timing,{"show_impact":true},func():return seconds,
			func():return {"source":Vector3(-2,1,0),"target":Vector3(2,1,0),"radius":0.8},func():return true)
		fire.set_process(false)
		seconds = 79.0/60.0
		fire._process(0)
		for i in fire.cursor:
			assert(fire.pieces[i].mesh is QuadMesh and fire.sprite_keys[i] in ["flame_hit","flame_sparks"],"Breath emission stops before head recovery")
		fire.cancel()
		await get_tree().process_frame
	assert(Stage.MoveAttachments.part_for("squirtle","bubble")=="mouth")
	assert(Stage.MoveAttachments.part_for("blastoise","bubblebeam")=="cannons")
	assert(Stage.MoveAttachments.part_for("blastoise","bubble")=="mouth")
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("FIRE_BUBBLE_3D_OK moves=3 outcomes=3 paired_origins=true bounded_pool=true pause_orbit=true audio=true impact_bridge=true")
	get_tree().quit()
