extends "res://tests/battle_move_effects_3d_check.gd"
const Bolt = preload("res://scripts/battle/battle_ui/thunderbolt_move_effect_3d.gd")
var seconds := 0.0
func _run() -> void:
	get_tree().create_timer(25).timeout.connect(func(): get_tree().quit(1))
	_setup()
	var camera := Camera3D.new()
	stage.world.add_child(camera)
	var points := {"source":Vector3(-2,1,0), "target":Vector3(2,1,0), "radius":0.8}
	for outcome in ["hit", "miss", "block"]:
		seconds = 0
		var effect := Bolt.new()
		stage.world.add_child(effect)
		effect.view_camera = camera
		effect.start("Thunderbolt", {"frames":120.0,"launch_frame":20.0,"impact_frame":48.0},
			{"show_impact":outcome=="hit", "result":outcome},func(): return seconds,func(): return points,func(): return true)
		effect.set_process(false)
		for time in [0.0,0.32,0.4,0.6,0.799,0.81,0.93,1.08,1.3,1.9]:
			seconds = time
			effect._process(0)
			assert(effect.pieces.size() <= 11, "Bounded source ribbon pool")
			if time < effect.launch: assert(effect.cursor == 0)
			for i in effect.cursor:
				assert(effect.pieces[i].transform.is_finite())
				if effect.sprite_keys[i] in ["bolt_hit", "bolt_burst", "bolt_flash"]:
					assert(outcome=="hit" and time >= effect.impact)
			if is_equal_approx(time,0.6):
				var transforms := {}
				var frames := {}
				for i in effect.cursor:
					if effect.sprite_keys[i] in ["bolt_arc", "bolt_core"]:
						transforms[i] = effect.pieces[i].transform
						frames[i] = effect.sprite_materials[i].get_shader_parameter("frame_index")
				assert(transforms.size()==3)
				camera.position = Vector3(5,3,-3)
				camera.look_at(Vector3(0,1,0))
				effect._process(0)
				assert(effect.elapsed == seconds)
				for i in transforms:
					assert(effect.pieces[i].transform.is_equal_approx(transforms[i]))
					assert(effect.sprite_materials[i].get_shader_parameter("frame_index")==frames[i])
		effect.cancel()
		await get_tree().process_frame
	var source := Catalog.new().get_plan("move","thunderbolt")
	var original := source.duplicate(true)
	for identity in ["pikachu", "pikachu@shiny"]:
		var timing := Timing.profile(identity,"Thunderbolt","special_attack",{"special_attack":{"frames":120.0,"loop":false}})
		timing.move_key = "thunderbolt"
		var plan := Effect.audio_plan(source,timing)
		assert(plan.cues.size()==2 and source==original)
		assert(plan.cues[0].event.name=="PRSFX- Thunderbolt2.wav" and is_equal_approx(plan.cues[0].at_seconds,1.0/3.0))
		assert(plan.cues[1].event.name=="PRSFX- Thunderbolt1.wav" and is_equal_approx(plan.cues[1].at_seconds,0.8))
		assert(Stage.MoveAttachments.part_for(identity,"thunderbolt")=="electric_body")
	await router.play_move_animation("Thunderbolt","p1","p2",{"stop_at_impact":true,"show_impact":true})
	assert(router.has_3d_impact_damage("p2") and stage.common_effects[0].get_script()==Bolt)
	assert(stage.contact_offsets[0]==Vector3.ZERO and stage.move_contacts[0].is_empty())
	await router.finish_3d_impact_damage("p2")
	await get_tree().process_frame
	assert(stage.common_effects.is_empty())
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("THUNDERBOLT_3D_OK outcomes=3 bounded_pool=true pause_orbit=true two_audio_beats=true impact_bridge=true")
	get_tree().quit()
