extends "res://tests/battle_move_effects_3d_check.gd"
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
var seconds := 0.0
func _run() -> void:
	get_tree().create_timer(120).timeout.connect(func():get_tree().quit(1))
	_setup()
	for arena in ["stadium","route_1_water","route_24_water"]:
		stage.arena_id=arena
		for doubles in [false,true]:
			stage.double_mode=doubles
			var field: Dictionary=stage._move_field()
			assert(field.radius>=5.8)
			for slot in stage._slot_count():assert(stage._position(slot).distance_to(field.center)<field.radius)
			for move in Stage.BattlefieldMoveEffect.FIELD_KEYS:
				for slot in stage._slot_count():
					var actor := "p%d" % (slot+1)
					var target := "p%d" % ((slot^1)+1)
					stage.start_move_action(actor,move)
					var effect: Node=stage.create_move_effect(move,actor,target,{"show_impact":true})
					assert(effect.get_script()==Stage.BattlefieldMoveEffect)
					assert(effect.field_center.is_equal_approx(field.center))
					effect.cancel()
					await get_tree().process_frame
	for move in Stage.BattlefieldMoveEffect.FIELD_KEYS:
		var recipe := Recipes.get_recipe(move)
		for result in ["hit","miss","block"]:
			seconds=0
			var effect: Node=Stage.BattlefieldMoveEffect.new()
			stage.world.add_child(effect)
			var points := {"source":Vector3(-3,1,0),"target":Vector3(3,1,0),"radius":.6,"field":{"center":Vector3(0,.055,0),"radius":5.8}}
			effect.start(move,{"frames":60,"launch_frame":recipe.launch_fraction*60,"impact_frame":recipe.impact_fraction*60},{"show_impact":result=="hit","result":result},func():return seconds,func():return points,func():return true)
			effect.set_process(false)
			var spans := false
			for frame in range(1,60):
				seconds=frame/60.0
				effect._process(0)
				assert(effect.cursor<=90,move+" geometry budget")
				var left := false
				var right := false
				for j in range(1,effect.cursor):
					var position: Vector3=effect.pieces[j].position
					assert(position.is_finite())
					left=left or position.x< -1.5
					right=right or position.x>1.5
				spans=spans or left and right
				if effect.impact_drawn:assert(result=="hit" and seconds>=effect.impact)
			assert(spans,move+" must use both halves of the arena, excluding the floor plane")
			points.target=Vector3(30,1,0)
			effect._process(0)
			assert(effect.aim==Vector3(3,1,0),"Camera/dodge must not drag the captured field choreography")
			effect.cancel()
			await get_tree().process_frame
	router.cancel_render()
	router.release_threaded_resource_requests()
	router=null
	stage.queue_free()
	await get_tree().process_frame
	print("BATTLEFIELD_MOVES_OK moves=12 arenas=3 singles_doubles=true outcomes=3 spans_field=true captured_aim=true budget=90")
	get_tree().quit()
