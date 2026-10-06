extends "res://tests/battle_move_effects_3d_check.gd"
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
const Profiles = preload("res://data/battle_move_staging_3d.json")
var seconds := 0.0
func _run() -> void:
	get_tree().create_timer(120).timeout.connect(func():get_tree().quit(1))
	_setup()
	assert(Profiles.data.moves.size()==158)
	var ordinary := 0
	var z_moves := 0
	var maximum := 0
	for key: String in Recipes.DATA.data.moves:
		assert(Profiles.data.moves.has(key)==(key not in Stage.BattlefieldMoveEffect.FIELD_KEYS),key)
	for key: String in Profiles.data.moves:
		assert(key not in Effect.KEYS and key not in Stage.BattlefieldMoveEffect.FIELD_KEYS)
		var recipe := Recipes.get_recipe(key)
		var is_z := recipe.has("z_choreography")
		if is_z:z_moves+=1
		else:ordinary+=1
		seconds=0
		var points := {"source":Vector3(-2.8,1,1.5),"sources":[Vector3(-2.8,1,1.25),Vector3(-2.8,1,1.75)],
			"target":Vector3(2.8,1,-1.5),"radius":.7,"actor_radius":.8,"actor_center":Vector3(-2.8,1,1.5),
			"actor_ground":Vector3(-2.8,.04,1.5),"target_ground":Vector3(2.8,.04,-1.5),
			"field":{"center":Vector3(0,.055,0),"radius":5.8}}
		if recipe.target=="actor":
			points.target=points.actor_center
			points.target_ground=points.actor_ground
		var translation := Vector3(16,4,-23)
		var moved: Dictionary=points.duplicate(true)
		for name in ["source","target","actor_center","actor_ground","target_ground"]:moved[name]+=translation
		moved.sources=[points.sources[0]+translation,points.sources[1]+translation]
		moved.field.center+=translation
		var a: Node=_new_effect(key,is_z,recipe,points)
		var b: Node=_new_effect(key,is_z,recipe,moved)
		for frame in [6,15,27,40,51,58]:
			seconds=frame/60.
			a._process(0);b._process(0)
			assert(a.cursor==b.cursor and a.cursor<=90,key+" double-emitter budget")
			maximum=maxi(maximum,a.cursor)
			for j in a.cursor:
				assert(a.pieces[j].transform.is_finite() and b.pieces[j].transform.is_finite(),key)
				assert(a.pieces[j].position.is_equal_approx(b.pieces[j].position-translation),key+" translated/elevated arena")
				assert(a.pieces[j].basis.is_equal_approx(b.pieces[j].basis),key+" world-space scale")
			# Travel rings face along the attack path, so a sound wave is not a
			# flat ladder lying in that path. Camera orbit must not define it.
			if not is_z and recipe.family in ["beams","waves"] and seconds>=a.launch and seconds<a.impact:
				var direction: Vector3=(a.aim-a.origin).normalized()
				for j in a.cursor:
					var node: MeshInstance3D=a.pieces[j]
					if node.mesh==a.ring and node.basis.y.length()>.001:
						assert(absf(node.basis.y.normalized().dot(direction))>.999,key+" wave plane faces travel direction")
			var snapshot: Array=[]
			for j in a.cursor:snapshot.append(a.pieces[j].transform)
			a._process(0)
			assert(a.cursor==snapshot.size())
			for j in a.cursor:assert(a.pieces[j].transform.is_equal_approx(snapshot[j]),key+" frozen native clock")
		assert(a.field_center.is_equal_approx(points.field.center))
		assert(b.field_center.is_equal_approx(moved.field.center))
		var aim: Vector3=a.aim
		points.target+=Vector3(3,0,2)
		points.target_ground+=Vector3(3,0,2)
		points.field.center+=Vector3(1,0,1)
		a._process(0)
		assert(a.aim.is_equal_approx(aim),key+" dodge must not drag the aim")
		assert(a.field_center.is_equal_approx(Vector3(0,.055,0)),key+" fixed arena")
		a.cancel();b.cancel()
		await get_tree().process_frame
	assert(ordinary==124 and z_moves==34)
	# The new continuous beams must start at the near-body fallback, not at the
	# outermost tail/wing bounds reserved for charging orbs. Reviewed bones win.
	stage.start_move_action("p1","Hyper Beam")
	var beam: Dictionary=stage._move_anchors("p1","p2","Hyper Beam")
	var a_bounds: Dictionary=stage._move_bounds("p1")
	var from: Vector3=a_bounds.position+Vector3.UP*a_bounds.height*.82
	assert(beam.source.distance_to(from)<=a_bounds.radius*.55+.001)
	router.cancel_render();router.release_threaded_resource_requests();router=null
	stage.queue_free()
	await get_tree().process_frame
	print("COMPLETED_MOVE_STAGING_OK ordinary=124 z=34 protected=36 translated_elevated=true double_emitters=true pause=true dodge=true max_pieces=",maximum)
	get_tree().quit()

func _new_effect(key: String,is_z: bool,recipe: Dictionary,points: Dictionary) -> Node:
	var effect: Node=Stage.ZMoveEffect.new() if is_z else Stage.StagedMoveEffect.new()
	stage.world.add_child(effect)
	effect.start(key,{"frames":60,"launch_frame":recipe.launch_fraction*60,"impact_frame":recipe.impact_fraction*60},
		{"show_impact":recipe.damaging},func():return seconds,func():return points,func():return true)
	effect.set_process(false)
	return effect
