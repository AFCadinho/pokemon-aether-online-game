extends "res://tests/battle_move_effects_3d_check.gd"
const Batch = preload("res://scripts/battle/battle_ui/batch_four_move_effect_3d.gd")
var seconds := 0.0
func _run() -> void:
	get_tree().create_timer(45).timeout.connect(func(): get_tree().quit(1))
	_setup()
	# Different native clip lengths must produce the same Moonblast beats.
	for frames in [60.0,120.0,407.5]:
		stage.entries.fixture.action_timing.special_attack.frames = frames
		stage.start_move_action("p1","Moonblast")
		var timing: Dictionary = stage.move_timing("Moonblast","p1")
		var rate: float = stage.players[0].get_playing_speed()
		assert(is_equal_approx(float(timing.frames)/60.0/rate,2.0))
		assert(is_equal_approx(float(timing.launch_frame)/60.0/rate,0.9))
		assert(is_equal_approx(float(timing.impact_frame-timing.launch_frame)/60.0/rate,0.35))
		var plan := Effect.audio_plan(Catalog.new().get_plan("move","moonblast"),timing)
		assert(is_equal_approx(plan.cues[0].event.end_seconds/rate,0.9))
		assert(is_equal_approx(plan.cues[1].at_seconds/rate,1.25))
		stage.hold_move_command("p1",true)
		assert(stage.players[0].get_playing_speed()==0)
		stage.hold_move_command("p1",false)
		assert(is_equal_approx(stage.players[0].get_playing_speed(),rate))
	stage.entries.fixture.action_timing.special_attack.frames = 60.0
	stage.start_move_action("p1","Shadow Ball")
	assert(is_equal_approx(stage.players[0].get_playing_speed(),1.5),"Moonblast pacing cannot leak to the next move")
	var camera := Camera3D.new()
	stage.world.add_child(camera)
	for move in Batch.MOVE_KEYS:
		for paired in [false,true]:
			for outcome in ["hit","miss","block"]:
				var points := {"source":Vector3(-2,1,0),"sources":[Vector3(-2,1,0)],"target":Vector3(2,1,0),"radius":0.8}
				if paired: points.sources=[Vector3(-2,1,-0.4),Vector3(-2,1,0.4)]
				seconds = 0
				var effect := Batch.new()
				stage.world.add_child(effect)
				effect.view_camera = camera
				effect.start(move,{"frames":120.0,"launch_frame":20.0,"impact_frame":48.0},
					{"show_impact":outcome=="hit","result":outcome},func():return seconds,func():return points,func():return true)
				effect.set_process(false)
				var seen_flight := false
				var seen_hit := false
				for time in [0.0,0.1,0.3,0.4,0.6,0.79,0.8,0.85,1.0,1.2,1.6,1.95]:
					seconds = time
					effect._process(0)
					assert(effect.pieces.size()<=48,"Bounded geometry for "+move)
					if time>effect.launch and time<effect.impact: seen_flight = seen_flight or effect.cursor>0
					for i in effect.cursor:
						assert(effect.pieces[i].transform.is_finite())
						if effect.pieces[i].mesh is QuadMesh:
							var id: String = effect.sprite_keys[i]
							if id.ends_with("_hit") or id in ["sludge_splash","poison_bubble","magic_debris"]:
								assert(outcome=="hit" and time>=effect.impact,"No premature or false impact: "+move)
								seen_hit = true
					if is_equal_approx(time,0.6):
						var positions: Array[Vector3] = []
						for i in effect.cursor: positions.append(effect.pieces[i].position)
						camera.position = Vector3(4,3,-3)
						camera.look_at(Vector3(0,1,0))
						effect._process(0)
						assert(effect.elapsed==seconds and effect.cursor==positions.size())
						for i in effect.cursor: assert(effect.pieces[i].position.is_equal_approx(positions[i]),"Orbit cannot move projectiles")
						if move!="flashcannon":
							points.source += Vector3(0,0.5,0.5)
							points.sources=[points.source]
							effect._process(0)
							for i in effect.cursor: assert(effect.pieces[i].position.is_equal_approx(positions[i]),"Released objects cannot follow later head motion")
				assert(seen_flight and seen_hit==(outcome=="hit"))
				effect.cancel()
				await get_tree().process_frame
		assert(stage.attack_action_for(move,"p1")=="special_attack","Ranged physical moves use a release clip")
		await router.play_move_animation(move,"p1","p2",{"stop_at_impact":true,"show_impact":true})
		assert(router.has_3d_impact_damage("p2") and stage.move_contacts[0].is_empty())
		assert(not router.active_audio_nodes.is_empty())
		await router.finish_3d_impact_damage("p2")
		await get_tree().process_frame
		assert(stage.common_effects.is_empty())
		router.cancel_render()
		print("BATCH_FOUR_MOVE_OK ",move)
	for identity in ["blastoise","blastoise@shiny"]:
		assert(Stage.MoveAttachments.part_for(identity,"flashcannon")=="cannons")
		var timing := Timing.profile(identity,"Flash Cannon","special_attack",{"special_attack":{"frames":407.5,"loop":false}})
		assert(timing.launch_frame==60 and timing.impact_frame==120)
	assert(Stage.MoveAttachments.part_for("squirtle","waterpulse")=="mouth")
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("BATCH_FOUR_MOVES_3D_OK moves=10 outcomes=3 paired=true bounded=true stable_flight=true pause_orbit=true audio=true recovery=true")
	get_tree().quit()
