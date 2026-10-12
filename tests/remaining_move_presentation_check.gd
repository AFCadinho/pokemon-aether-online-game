extends "res://tests/move_camera_choreography_check.gd"
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
const Forms = preload("res://scripts/battle/battle_ui/move_cinematic_forms_3d.gd")
var samples := 0

func _run() -> void:
	get_tree().create_timer(180).timeout.connect(func(): get_tree().quit(1))
	var inventory := FileAccess.open("res://docs/3d/remaining-move-presentation-pass.csv",FileAccess.READ)
	assert(inventory != null)
	inventory.get_csv_line()
	var keys := {}
	while not inventory.eof_reached():
		var row := inventory.get_csv_line()
		if row.size()<2: continue
		assert(not keys.has(row[0]) and Effect.supports(row[0]),"unique supported inventory key")
		keys[row[0]]=true
	assert(keys.size()==901)
	assert(not Forms.SURFACE.code.contains("TIME"),"Native clock only")
	_setup()
	SettingsManager.battle_presentation_mode="3d"
	SettingsManager.battle_3d_camera_motion=true
	stage.camera=Camera3D.new()
	stage.world.add_child(stage.camera)
	stage.user_camera_yaw=.35
	stage.user_camera_zoom=.85
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	stage.world.add_child(environment)
	var changed := 0
	var cameras := 0
	var lights := 0
	var selected := OS.get_environment("POKEAETHER_TEST_MOVES").split(",",false)
	for move in Recipes.all_recipes():
		if not selected.is_empty() and move not in selected: continue
		var recipe := Recipes.get_recipe(move)
		if recipe.family=="z" or move=="fierywrath" or move in Stage.ElementalMoveEffect.MOVE_KEYS or Stage.ElementalBatchEffect.Profiles.DATA.has(move): continue
		changed+=1
		for doubles in [false,true]:
			stage.double_mode=doubles
			for outcome in ["hit","miss","block"]:
				var slot := 1 if doubles else 0
				var actor := "p%d" % (slot+1)
				var target := "p%d" % (2-slot)
				stage._update_camera(0)
				var overview: Transform3D=stage.camera.transform
				stage.start_move_action(actor,move)
				var effect: Node=stage.create_move_effect(move,actor,target,{"show_impact":outcome=="hit" and recipe.damaging,"result":outcome})
				effect.set_process(false)
				stage.players[slot].speed_scale=0
				assert(effect.forms != null,move)
				if move=="willowisp":
					assert(effect.forms.haze.get_shader_parameter("tint")==Color("996fff") and effect.forms.haze.get_shader_parameter("kind")==3,"violet ghost flame palette")
				# Mouth/wake width gets artistic scale once; measured travel length
				# must never overshoot when a recipe uses a magnification > 1.
				effect.forms.tail(effect,Vector3.ZERO,Vector3.BACK,.2,1.3)
				var tail: MeshInstance3D=effect.pieces[effect.cursor-1]
				assert(is_equal_approx(tail.basis.x.length(),.2*effect._geometry_scale()),move+" tail width")
				assert(is_equal_approx(tail.basis.y.length(),1.3),move+" tail world length")
				var has_camera: bool=stage.move_camera.effect==effect
				var has_light: bool=stage.move_atmosphere.effect==effect
				if has_camera: cameras+=1
				if has_light: lights+=1
				for seconds in [effect.launch*.8,lerpf(effect.launch,effect.impact,.25),lerpf(effect.launch,effect.impact,.75),lerpf(effect.impact,effect.duration,.2)]:
					_sample(slot,effect,seconds)
					assert(effect.cursor<=120,move)
					if outcome!="hit": assert(not effect.impact_drawn,move)
					for i in effect.cursor:
						var piece: MeshInstance3D=effect.pieces[i]
						assert(piece.transform.is_finite(),move)
						if piece.material_override is ShaderMaterial:
							assert(not piece.material_override.shader.code.contains("source_mask"),move+" ordinary source sprite survived")
					# New ranged cameras must frame the actual solid silhouettes, not
					# merely the target point. Soft atmosphere/floor planes are separate.
						if has_camera and piece.material_override==effect.forms.skin:
							for corner in 8: _in_frame(piece.transform*piece.mesh.get_aabb().get_endpoint(corner),move+" solid form")
					var pose: Transform3D=stage.camera.transform
					var shader_time: float=effect.forms.skin.get_shader_parameter("seconds")
					effect._process(1)
					stage._update_camera(1)
					assert(stage.camera.transform.is_equal_approx(pose),move)
					assert(effect.forms.skin.get_shader_parameter("seconds")==shader_time,move)
					if has_light:
						assert(stage.move_atmosphere.profile_lights.size()<=6)
						if outcome!="hit":assert(stage.move_atmosphere.pulse==0)
					samples+=1
				SettingsManager.battle_3d_camera_motion=false
				stage._update_camera(0)
				assert(stage.camera.transform.is_equal_approx(overview),move+" manual camera")
				SettingsManager.battle_3d_camera_motion=true
				_sample(slot,effect,effect.duration*.9999)
				assert(stage.camera.position.distance_to(overview.origin)<.01,move+" recovery")
				var ref: WeakRef = weakref(effect.forms)
				effect.cancel()
				await get_tree().process_frame
				assert(ref.get_ref()==null,move+" released volume materials")
				assert(stage.common_effects.is_empty() and stage.move_camera.effect==null and stage.move_atmosphere.effect==null and stage.camera.environment==null,move)
	# Weather ownership and both beam emitters already have focused regression
	# suites; this pass exercises every newly reachable material/camera route.
	router.cancel_render();router.release_threaded_resource_requests();router=null
	stage.queue_free()
	await get_tree().process_frame
	print("REMAINING_PRESENTATION_OK moves=",changed," camera_cases=",cameras," light_cases=",lights," samples=",samples," outcomes=3 singles_doubles=true material_cleanup=true no_source_sprites=true native_pause=true framing=true")
	get_tree().quit()
