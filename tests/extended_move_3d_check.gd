extends "res://tests/battle_move_effects_3d_check.gd"
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
const Extended = preload("res://scripts/battle/battle_ui/extended_move_effect_3d.gd")
const Summary = preload("res://data/move_summary_index.json")
const Lights = preload("res://scripts/battle/battle_ui/move_lighting_profiles_3d.gd")
var seconds := 0.0
func _run() -> void:
	get_tree().create_timer(180).timeout.connect(func():get_tree().quit(1))
	_setup()
	var names := {}
	for row: Dictionary in Summary.data.values():
		assert(Effect.supports(str(row.name)),"Uncovered gameplay name: "+str(row.name))
		assert(Effect.supports(str(row.id)),"Uncovered gameplay ID: "+str(row.id))
		names[Effect.move_key(row.name)] = true
	assert(names.size()==901)
	assert(Recipes.EXTENSIONS.data.moves.size()==707)
	assert(not Effect.supports("unrecognized future move"))
	var motifs := {}
	var samples := 0
	for move: String in Recipes.EXTENSIONS.data.moves:
		var recipe: Dictionary = Recipes.get_recipe(move)
		assert(not Recipes.DATA.data.moves.has(move) and move not in Effect.KEYS)
		assert(recipe.presentation_review=="implemented-pending-player-review")
		motifs[recipe.motif] = true
		for slot in 4:
			var actor := "p%d" % (slot+1)
			var target := "p%d" % ((slot+1)%4+1)
			stage.start_move_action(actor,move)
			var timing: Dictionary = stage.move_timing(move,actor)
			assert(is_equal_approx(timing.frames/60./stage.players[slot].get_playing_speed(),float(recipe.duration_seconds)),move)
			var plan := Effect.audio_plan({},timing)
			assert(not plan.cues.is_empty() and plan.bounded_to_action,move)
			for cue: Dictionary in plan.cues:
				assert(cue.at_seconds>=0 and cue.event.end_seconds<=plan.duration_seconds)
				assert(FileAccess.file_exists(plan.sound_paths[cue.event.name]))
			var effect: Node = stage.create_move_effect(move,actor,"" if recipe.target=="actor" else target,{"show_impact":bool(recipe.damaging)})
			assert(is_instance_valid(effect) and effect.get_script()==Extended,move)
			if recipe.contact: assert(not stage.move_contacts[slot].is_empty(),move)
			effect.cancel()
			await get_tree().process_frame
			assert(stage.move_contacts[slot].is_empty())
		for reverse in [false,true]:
			for outcome in ["hit","miss","block"]:
				seconds=0
				var sign_value := -1. if reverse else 1.
				var points := {"source":Vector3(-2*sign_value,1,0),"target":Vector3(2*sign_value,1,0),"radius":.6,"actor_center":Vector3(-2*sign_value,1,0),"actor_ground":Vector3(-2*sign_value,.04,0),"target_ground":Vector3(2*sign_value,.04,0)}
				var effect := Extended.new()
				stage.world.add_child(effect)
				effect.start(move,{"frames":60.,"launch_frame":float(recipe.launch_fraction)*60.,"impact_frame":float(recipe.impact_fraction)*60.},{"show_impact":outcome=="hit" and recipe.damaging,"result":outcome},func():return seconds,func():return points,func():return true)
				effect.set_process(false)
				var drawn := false
				var saw_hit := false
				for frame in range(1,60,3):
					seconds=frame/60.
					effect._process(0)
					drawn=drawn or effect.cursor>0
					saw_hit=saw_hit or effect.impact_drawn
					assert(effect.cursor<=90 and effect.pieces.size()<=90,move)
					for j in effect.cursor:assert(effect.pieces[j].transform.is_finite(),move)
					if effect.impact_drawn:assert(outcome=="hit" and recipe.damaging and seconds>=effect.impact)
					if Lights.supports(move):
						var sample := Lights.sample(effect,seconds)
						assert(sample.lights.size()<=3)
						if outcome!="hit":assert(is_zero_approx(sample.pulse))
						for light: Dictionary in sample.lights:assert(light.point.is_finite() and light.energy>=0)
					samples+=1
				assert(drawn,move+" must draw")
				assert(saw_hit==(outcome=="hit" and recipe.damaging),move)
				# Frozen clock and captured trajectory must be deterministic.
				var transforms: Array = []
				for j in effect.cursor:transforms.append(effect.pieces[j].transform)
				effect._process(1.)
				for j in effect.cursor:assert(effect.pieces[j].transform.is_equal_approx(transforms[j]),move)
				effect.cancel()
				await get_tree().process_frame
	await _presentation_checks()
	# Exercise the asynchronous router with no corresponding 2D catalogue entry.
	router.playback_speed=8
	for move in ["Hydro Pump","Gigaton Hammer","Aura Sphere","Hypnosis","Rain Dance","Trick Room","Revival Blessing"]:
		await router.play_move_animation(move,"p1","p2",{"show_impact":true})
		await get_tree().process_frame
		assert(stage.common_effects.is_empty() and router.active_audio_nodes.is_empty(),move)
	router.cancel_render()
	router.release_threaded_resource_requests()
	router=null
	stage.queue_free()
	await get_tree().process_frame
	print("EXTENDED_MOVES_OK unique=",names.size()," extensions=707 motifs=",motifs.size()," samples=",samples," slots=4 directions=2 outcomes=3 native_audio=true")
	get_tree().quit()

func _presentation_checks() -> void:
	SettingsManager.battle_presentation_mode="3d"
	SettingsManager.battle_3d_camera_motion=true
	SettingsManager.weather_effects=true
	stage.camera=Camera3D.new()
	stage.world.add_child(stage.camera)
	var environment := WorldEnvironment.new()
	var original := Environment.new()
	original.ambient_light_color=Color("ddebff")
	environment.environment=original
	stage.world.add_child(environment)
	for move in ["Hydro Pump","Hydro Cannon","Aura Sphere","Blood Moon","Energy Ball","Eternabeam","Fire Blast","Meteor Beam","Prismatic Laser","Roar of Time","Spacial Rend","Rain Dance","Sunny Day","Trick Room"]:
		var recipe := Recipes.get_recipe(move)
		for doubles in [false,true]:
			stage.double_mode=doubles
			for reverse in [false,true]:
				var slot := 1 if reverse else 0
				var actor := "p2" if reverse else "p1"
				var target := "p1" if reverse else "p2"
				for outcome in ["hit","miss","block"]:
					stage.start_move_action(actor,move)
					var effect: Node=stage.create_move_effect(move,actor,target,{"show_impact":outcome=="hit" and recipe.damaging,"result":outcome})
					stage.players[slot].speed_scale=0
					assert(stage.move_camera.effect==effect if recipe.has("camera") else stage.move_camera.effect==null)
					for at in [effect.launch*.8,lerpf(effect.launch,effect.impact,.6),lerpf(effect.impact,effect.duration,.15)]:
						stage.players[slot].seek(at,true)
						effect._process(0.)
						stage._update_camera(0.)
						var pose: Transform3D=stage.camera.transform
						stage._update_camera(1.)
						assert(stage.camera.transform.is_equal_approx(pose),move+" paused camera")
						if recipe.has("camera"):
							var points: Dictionary=effect.anchors.call()
							var focus: Vector3=points.source if at<effect.launch else points.target
							assert(not stage.camera.is_position_behind(focus))
							assert(Rect2(Vector2.ZERO,stage.camera.get_viewport().get_visible_rect().size).has_point(stage.camera.unproject_position(focus)),move+" framed")
						if Lights.supports(effect.key):
							assert(stage.camera.environment!=original and stage.move_atmosphere.effect==effect)
							assert(stage.move_atmosphere.profile_lights.size()<=3)
							if outcome!="hit":assert(stage.move_atmosphere.pulse==0)
					effect.cancel()
					assert(stage.camera.environment==null and stage.move_atmosphere.profile_lights.is_empty())
					assert(stage.move_camera.effect==null)
					assert(original.ambient_light_color==Color("ddebff"))
					await get_tree().process_frame
	# Two cannons, cancellation during weather and native marker audio alignment.
	stage.start_move_action("p1","Hydro Pump")
	var beam: Node=stage.create_move_effect("Hydro Pump","p1","p2",{"result":"miss"})
	var points: Dictionary=beam.anchors.call()
	points.sources=[points.source+Vector3.LEFT*.25,points.source+Vector3.RIGHT*.25]
	beam.anchors=func():return points
	stage.players[0].seek(lerpf(beam.launch,beam.impact,.5),true)
	beam._process(0.)
	stage._update_camera(0.)
	assert(stage.move_atmosphere.profile_lights.size()==2)
	stage.set_weather_condition("RainDance")
	assert(stage.move_atmosphere.source==stage.weather_effect.atmosphere)
	SettingsManager.battle_presentation_mode="2.5d"
	stage._update_camera(0.)
	assert(stage.move_atmosphere.profile_lights.is_empty())
	beam.cancel()
	stage.set_weather_condition("")
	SettingsManager.battle_presentation_mode="3d"
	var plan := Recipes.audio_plan({"move_key":"hydropump","frames":120.,"launch_frame":50.,"impact_frame":90.})
	for cue: Dictionary in plan.cues:
		assert(is_equal_approx(cue.at_seconds,90./60. if cue.event.role=="impact" else 50./60.))
	await get_tree().process_frame
	print("EXTENDED_PRESENTATION_OK cameras=11 directions=2 singles_doubles=true outcomes=3 pause=true weather=true hybrid=true multicannon=true native_audio_markers=true")
