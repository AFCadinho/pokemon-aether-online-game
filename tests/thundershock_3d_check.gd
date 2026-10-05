extends "res://tests/battle_move_effects_3d_check.gd"
const Electric = preload("res://scripts/battle/battle_ui/electric_move_effect_3d.gd")
var seconds := 0.0
var points := {"source":Vector3(-2,1,0), "target":Vector3(2,1,0), "radius":0.8}
func _run() -> void:
	get_tree().create_timer(25).timeout.connect(func(): get_tree().quit(1))
	_setup()
	var camera := Camera3D.new()
	stage.world.add_child(camera)
	camera.position = Vector3(0,3,6)
	camera.look_at(Vector3(0,1,0))
	for outcome in ["hit", "miss", "block"]:
		seconds = 0
		var effect := Electric.new()
		stage.world.add_child(effect)
		effect.view_camera = camera
		effect.start("Thunder Shock", {"frames":120.0,"launch_frame":20.0,"impact_frame":48.0},
			{"show_impact":outcome=="hit", "result":outcome},func(): return seconds,func(): return points,func(): return true)
		effect.set_process(false)
		for time in [0.0,0.32,0.4,0.6,0.799,0.81,0.93,1.08,1.3,1.9]:
			seconds = time
			effect._process(0)
			assert(effect.pieces.size() <= 46, "Bounded electrical mesh pool")
			if time < effect.launch: assert(effect.cursor == 0)
			if time > effect.launch and time < effect.impact: assert(effect.cursor > 2)
			for i in effect.cursor:
				assert(effect.pieces[i].transform.is_finite())
				if not effect.pieces[i].mesh is QuadMesh: continue
				if effect.sprite_keys[i] in ["electric_hit","electric_flash"]:
					assert(outcome=="hit" and time >= effect.impact, "No false contact during dodge/block")
			if is_equal_approx(time,0.6):
				var frozen := effect.elapsed
				var count := effect.pieces.size()
				var transforms: Array[Transform3D] = []
				for piece: MeshInstance3D in effect.pieces:
					if piece.visible and not piece.mesh is QuadMesh: transforms.append(piece.transform)
				camera.position = Vector3(5,3,-3)
				camera.look_at(Vector3(0,1,0))
				effect._process(0)
				assert(effect.elapsed == frozen and effect.pieces.size() == count)
				var index := 0
				for piece: MeshInstance3D in effect.pieces:
					if not piece.visible: continue
					if piece.mesh is QuadMesh:
						assert(absf(piece.global_basis.z.normalized().dot(camera.global_basis.z.normalized())) > 0.999)
					else:
						assert(piece.transform.is_equal_approx(transforms[index]), "World-space bolts stay fixed during camera orbit")
						index += 1
		effect.cancel()
		await get_tree().process_frame
	# Pikachu/shiny use the reviewed discharge beat; unrelated clips retain fallback.
	var timings := {"special_attack":{"frames":120.0,"speed":1.0,"loop":false}}
	for identity in ["pikachu","pikachu@shiny"]:
		var timing := Timing.profile(identity,"Thunder Shock","special_attack",timings)
		assert(timing.launch_frame==20.0 and timing.impact_frame==48.0)
		var source := Catalog.new().get_plan("move","thundershock")
		var original := source.duplicate(true)
		var plan := Effect.audio_plan(source,timing)
		assert(source==original and plan.cues.size()==1 and is_equal_approx(plan.cues[0].at_seconds,1.0/3.0))
	assert(Timing.profile("pikachu","Thunder Shock","physical_attack",timings).is_empty())
	# Live routing retains the impact bridge and never approaches for an electric move.
	await router.play_move_animation("Thunder Shock","p1","p2",{"stop_at_impact":true,"show_impact":true})
	assert(router.has_3d_impact_damage("p2") and stage.common_effects[0].get_script()==Electric)
	assert(stage.contact_offsets[0] == Vector3.ZERO and stage.move_contacts[0].is_empty())
	await router.finish_3d_impact_damage("p2")
	await get_tree().process_frame
	assert(stage.common_effects.is_empty())
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("THUNDERSHOCK_3D_OK outcomes=3 bounded_pool=true pause_orbit=true no_false_hits=true audio_launch=true impact_bridge=true no_approach=true")
	get_tree().quit()
