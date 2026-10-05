extends "res://tools/sprite_factory/measure_model_grounding.gd"
var output := ""
func bounds(meshes: Array) -> AABB:
	var result := AABB()
	var found := false
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
		var posed: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
		for surface in posed.get_surface_count():
			for vertex: Vector3 in posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point := mesh.global_transform * vertex
				if not found:
					result = AABB(point,Vector3.ZERO)
					found = true
				else: result = result.expand(point)
	return result
func _run():
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2, "TARGET_SCN OUTPUT_DIRECTORY")
	output = args[1].trim_suffix("/") + "/"
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var world := Node3D.new()
	root.add_child(world)
	preload("res://scripts/battle/battle_ui/material_response.gd").apply_neutral_lighting(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position=Vector3(2,1.8,4)
	camera.look_at(Vector3(0,.9,0))
	camera.current=true
	var path: String = args[0]
	var actor: Node3D = load(path).instantiate()
	world.add_child(actor)
	var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
	player.remove_animation_library("")
	var lib: AnimationLibrary = load("res://resources/battle/model_animations/mega_garchomp_standing.res")
	player.add_animation_library("",lib)
	var skeletons := actor.find_children("*","Skeleton3D",true,false)
	var meshes := actor.find_children("*","MeshInstance3D",true,false)
	var result := {"action_timing":{},"bounds":{},"grounding":{"scale":1.0,"yaw_degrees":0.0,"lift":0.0},"placement":{"scale":1.0,"yaw_degrees":0.0},"motion":{"schema":1,"scale":1.0,"yaw_degrees":0.0,"lift":0.0,"clips":{}}}
	for action in ["idle", "physical_attack", "special_attack", "damage", "sleep", "faint_start", "faint_loop"]:
		var animation := lib.get_animation(action)
		player.play(action)
		player.pause()
		var duration := animation.length
		var envelope := AABB()
		var minima: Array = []
		for sample in ceili(duration*120.0)+1:
			player.seek(minf(sample/120.0,duration),true)
			for skeleton: Skeleton3D in skeletons: skeleton.force_update_all_bone_transforms()
			await process_frame
			RenderingServer.force_draw(false)
			var box := bounds(meshes)
			minima.append(box.position.y)
			envelope=box if sample==0 else envelope.merge(box)
			if sample == mini(ceili(duration*120*.4),ceili(duration*120.0)):
				root.get_texture().get_image().save_png(output+action+".png")
		result.action_timing[action]={"frames":duration*60.0,"loop":animation.loop_mode==Animation.LOOP_LINEAR,"speed":1.0}
		result.bounds[action]={"min":[envelope.position.x,envelope.position.y,envelope.position.z],"size":[envelope.size.x,envelope.size.y,envelope.size.z]}
		if action == "idle":
			result.grounding.lift = maxf(0.0, .03 - envelope.position.y)
			result.motion.lift = result.grounding.lift
		if action != "idle":
			var offsets: Array=[]
			for sample in ceili(duration*60.0)+1:
				var low:=INF
				for nearby in range(maxi(0,sample*2-2),mini(minima.size(),sample*2+3)):
					low=minf(low,float(minima[nearby]))
				offsets.append(maxf(0.0,.03-float(result.grounding.lift)-low))
			result.motion.clips[action]={"duration":duration,"intent":"grounded_rest" if action=="sleep" else "clearance_only","offsets":offsets}
		print("MEASURED ",action," min=",envelope.position.y," max=",envelope.end.y)
		if action=="idle": assert(envelope.position.y+result.grounding.lift>=.02)
	var file:=FileAccess.open(output+"profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t",true)+"\n")
	file.close()
	print("MEGA_GARCHOMP_STANDING_MEASURED")
	quit()
