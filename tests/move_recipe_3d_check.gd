extends "res://tests/battle_move_effects_3d_check.gd"
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
const Staged = preload("res://scripts/battle/battle_ui/staged_move_effect_3d.gd")
const Inventory = preload("res://data/battle_move_animations.json")
var seconds := 0.0
func _run() -> void:
	get_tree().create_timer(90).timeout.connect(func():get_tree().quit(1))
	_setup()
	var categories := {}
	var samples := 0
	for move: String in Inventory.data.moves:
		assert(Effect.supports(move),"Uncovered 2D move: "+move)
	assert(not Effect.supports("not a real move"))
	for move: String in Recipes.DATA.data.moves:
		var recipe := Recipes.get_recipe(move)
		assert(Effect.supports(str(recipe.name)),"Display-name coverage: "+str(recipe.name))
		assert(move not in Effect.KEYS,"Approved renderers keep ownership")
		categories[recipe.family] = true
		for slot in 4:
			var actor := "p%d" % (slot+1)
			var target := "p%d" % ((slot+1)%4+1)
			stage.start_move_action(actor,move)
			var timing: Dictionary = stage.move_timing(move,actor)
			var rate: float = stage.players[slot].get_playing_speed()
			assert(is_equal_approx(timing.frames/60/rate,float(recipe.duration_seconds)))
			var plan := Effect.audio_plan(Catalog.new().get_plan("move",move),timing)
			assert(plan.cues.size()==recipe.audio.size() and plan.bounded_to_action)
			for cue: Dictionary in plan.cues:
				assert(cue.at_seconds>=0 and cue.event.end_seconds<=plan.duration_seconds)
				assert(FileAccess.file_exists(plan.sound_paths[cue.event.name]))
			var effect: Node = stage.create_move_effect(move,actor,target,{"show_impact":bool(recipe.damaging)})
			assert(is_instance_valid(effect) and effect.get_script()==(Stage.BattlefieldMoveEffect if move in Stage.BattlefieldMoveEffect.FIELD_KEYS else Stage.ZMoveEffect if recipe.has("z_choreography") else Staged),move)
			if recipe.contact: assert(not stage.move_contacts[slot].is_empty())
			var points: Dictionary = effect.anchors.call()
			if recipe.target=="actor":assert(points.actor_center.distance_to(points.target)<1.5)
			effect.cancel()
			await get_tree().process_frame
			assert(stage.move_contacts[slot].is_empty())
		for outcome in ["hit","miss","block"]:
			seconds = 0
			var points := {"source":Vector3(-2,1,0),"target":Vector3(2,1,0),"radius":0.6,
				"actor_center":Vector3(-2,1,0),"actor_ground":Vector3(-2,0.04,0),"target_ground":Vector3(2,0.04,0)}
			var effect: Node = Stage.BattlefieldMoveEffect.new() if move in Stage.BattlefieldMoveEffect.FIELD_KEYS else Stage.ZMoveEffect.new() if recipe.has("z_choreography") else Staged.new()
			stage.world.add_child(effect)
			effect.start(move,{"frames":60,"launch_frame":float(recipe.launch_fraction)*60,"impact_frame":float(recipe.impact_fraction)*60},
				{"show_impact":outcome=="hit" and bool(recipe.damaging),"result":outcome},func():return seconds,func():return points,func():return true)
			effect.set_process(false)
			var drawn := false
			var saw_hit := false
			for frame in range(1,60,2):
				seconds = frame/60.0
				effect._process(0)
				samples += 1
				drawn = drawn or effect.cursor>0
				saw_hit = saw_hit or effect.impact_drawn
				assert(effect.cursor<=90 and effect.pieces.size()<=90,move)
				for j in effect.cursor: assert(effect.pieces[j].transform.is_finite(),move)
				if effect.impact_drawn: assert(outcome=="hit" and recipe.damaging and seconds>=effect.impact)
			assert(drawn,move+" must have visible choreography")
			assert(saw_hit==(outcome=="hit" and bool(recipe.damaging)),move)
			effect.cancel()
			await get_tree().process_frame
	# Awaited router lifecycle: contact, ranged, status, self, field and Z.
	router.playback_speed = 6
	for move in ["Close Combat","Hyper Beam","Toxic","Swords Dance","Stealth Rock","Bloom Doom"]:
		await router.play_move_animation(move,"p1","p2",{"show_impact":true})
		await get_tree().process_frame
		assert(stage.common_effects.is_empty() and router.active_audio_nodes.is_empty(),move)
	for move in ["Recover","Protect","Grassy Terrain","Substitute"]:
		stage.start_move_action("p1",move)
		var effect: Node = stage.create_move_effect(move,"p1","",{})
		assert(is_instance_valid(effect),"Self and field casts work without target")
		effect.cancel()
		await get_tree().process_frame
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("MOVE_RECIPE_3D_OK new_moves=",Recipes.DATA.data.moves.size()," catalog=",Inventory.data.moves.size()," families=",categories.size()," slots=4 outcomes=3 samples=",samples," bounded=true lifecycle=true self_targets=true")
	get_tree().quit()
