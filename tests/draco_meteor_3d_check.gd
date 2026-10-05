extends "res://tests/battle_move_effects_3d_check.gd"
const Draco = preload("res://scripts/battle/battle_ui/draco_meteor_effect_3d.gd")
var seconds := 0.0
func _run() -> void:
	get_tree().create_timer(45).timeout.connect(func(): get_tree().quit(1))
	_setup()
	for frames in [60.0,120.0,407.5]:
		stage.entries.fixture.action_timing.special_attack.frames = frames
		stage.start_move_action("p1","Draco Meteor")
		var timing: Dictionary = stage.move_timing("Draco Meteor","p1")
		var rate: float = stage.players[0].get_playing_speed()
		assert(is_equal_approx(timing.frames/60.0/rate,3.2))
		assert(is_equal_approx(timing.launch_frame/60.0/rate,0.7))
		assert(is_equal_approx(timing.impact_frame/60.0/rate,2.05))
		var plan := Effect.audio_plan(Catalog.new().get_plan("move","dracometeor"),timing)
		assert(plan.cues[0].at_seconds==0 and is_equal_approx(plan.cues[0].event.end_seconds/rate,1.376))
		assert(is_equal_approx(plan.cues[1].at_seconds/rate,2.05) and plan.cues[1].event.requires_hit)
	stage.entries.fixture.action_timing.special_attack.frames = 60.0
	for outcome in ["hit","miss","block"]:
		var points := {"source":Vector3(-2,1.5,0),"target":Vector3(2,1,0),"target_ground":Vector3(2,0.04,0),"radius":0.6}
		seconds = 0
		var effect := Draco.new()
		stage.world.add_child(effect)
		effect.start("Draco Meteor",{"frames":192,"launch_frame":42,"impact_frame":123},
			{"show_impact":outcome=="hit","result":outcome},func():return seconds,func():return points,func():return true)
		effect.set_process(false)
		var saw_impact := false
		for i in 63:
			seconds = i*0.05
			effect._process(0)
			assert(effect.cursor<90 and effect.pieces.size()<90,"Bounded Draco geometry")
			for j in effect.cursor:
				assert(effect.pieces[j].transform.is_finite())
				if j<effect.sprite_keys.size() and effect.pieces[j].mesh==effect.quad and effect.sprite_keys[j] in ["shock","smoke","sparks"]:
					assert(outcome=="hit" and seconds>=2.05,"No premature or false damage effect")
					saw_impact = true
			if i==30:
				var frozen_origin := effect.origin
				var frozen_aim := effect.aim
				var count := effect.cursor
				points.source += Vector3(1,0.5,1)
				points.target += Vector3(0.5,0,1)
				effect._process(0)
				assert(effect.origin==frozen_origin and effect.aim==frozen_aim and count==effect.cursor)
		assert(saw_impact==(outcome=="hit"))
		effect.cancel()
		await get_tree().process_frame
	await router.play_move_animation("Draco Meteor","p1","p2",{"stop_at_impact":true,"show_impact":true})
	assert(router.has_3d_impact_damage("p2"))
	await router.finish_3d_impact_damage("p2")
	await get_tree().process_frame
	assert(stage.common_effects.is_empty() and router.active_audio_nodes.is_empty())
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("DRACO_METEOR_3D_OK clips=3 outcomes=3 fixed_launch=true bounded=true impact_recovery=true")
	get_tree().quit()
