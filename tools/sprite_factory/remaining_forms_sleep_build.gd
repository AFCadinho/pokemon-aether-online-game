extends SceneTree
## Local repair proposal. Approved appearance and all non-sleep curves are retained.

func _initialize() -> void:
	_run.call_deferred()

func _hash(value: Variant) -> String:
	var context := HashingContext.new()
	assert(context.start(HashingContext.HASH_SHA256)==OK)
	assert(context.update(var_to_bytes(value))==OK)
	return context.finish().hex_encode()

func _tracks(animation: Animation) -> Dictionary:
	var result := {}
	for track in animation.get_track_count():
		var data := [animation.track_get_interpolation_type(track),animation.track_is_enabled(track),
			animation.track_get_interpolation_loop_wrap(track)]
		for key in animation.track_get_key_count(track):
			data.append([animation.track_get_key_time(track,key),animation.track_get_key_value(track,key),animation.track_get_key_transition(track,key)])
		var identity := str(animation.track_get_type(track))+"|"+str(animation.track_get_path(track))
		assert(not result.has(identity))
		result[identity] = _hash(data)
	return result

func _pose(player: AnimationPlayer, skeleton: Skeleton3D, action: String, time: float) -> void:
	player.stop()
	skeleton.reset_bone_poses()
	player.play(action)
	player.pause()
	player.seek(time,true)
	skeleton.force_update_all_bone_transforms()

func _attach(actor: Node, player: AnimationPlayer, spec: Dictionary) -> Dictionary:
	var skeletons := actor.find_children("*","Skeleton3D",true,false)
	assert(skeletons.size()==1)
	var skeleton: Skeleton3D = skeletons[0]
	var anchor := skeleton.find_bone(spec.anchor)
	assert(anchor>=0)
	_pose(player,skeleton,"idle",0)
	var head := skeleton.get_bone_global_pose(anchor)
	var relative := {}
	for name: String in spec.bones:
		var bone := skeleton.find_bone(name)
		assert(bone>=0)
		relative[bone] = head.affine_inverse()*skeleton.get_bone_global_pose(bone)
	var original := player.get_animation("sleep")
	var steps := maxi(1,int(ceil(original.length*60.0)))
	var samples := []
	for index in steps+1:
		var time := original.length*float(index)/steps
		_pose(player,skeleton,"sleep",time)
		var transform := skeleton.get_bone_global_pose(anchor)
		if spec.get("keep_idle_head_orientation",false): transform.basis = head.basis
		var desired := {}
		for bone: int in relative: desired[bone] = transform*relative[bone]
		var local := {}
		for bone: int in relative:
			var parent := skeleton.get_bone_parent(bone)
			var parent_pose: Transform3D = desired.get(parent,skeleton.get_bone_global_pose(parent)) if parent>=0 else Transform3D.IDENTITY
			local[bone] = parent_pose.affine_inverse()*desired[bone]
		samples.append({"time":time,"poses":local})
	var fixed := original.duplicate(true) as Animation
	for track in range(fixed.get_track_count()-1,-1,-1):
		var path := fixed.track_get_path(track)
		if path.get_subname_count()==1 and str(path.get_subname(0)) in spec.bones:
			assert(fixed.track_get_type(track) in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D])
			fixed.remove_track(track)
	var origin := player.get_node(player.root_node)
	for bone: int in relative:
		var path := NodePath(str(origin.get_path_to(skeleton))+":"+skeleton.get_bone_name(bone))
		for kind in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
			var track := fixed.add_track(kind)
			fixed.track_set_path(track,path)
			fixed.track_set_interpolation_type(track,Animation.INTERPOLATION_LINEAR)
			var previous := Quaternion.IDENTITY
			for index in samples.size():
				var sample: Dictionary = samples[index]
				var pose: Transform3D = sample.poses[bone]
				var value: Variant
				if kind==Animation.TYPE_POSITION_3D: value = pose.origin
				elif kind==Animation.TYPE_SCALE_3D: value = pose.basis.get_scale()
				else:
					var rotation := pose.basis.orthonormalized().get_rotation_quaternion()
					if index>0 and previous.dot(rotation)<0: rotation = -rotation
					value = rotation
					previous = rotation
				fixed.track_insert_key(track,sample.time,value)
	player.stop()
	var library := player.get_animation_library("")
	library.remove_animation("sleep")
	library.add_animation("sleep",fixed)
	return {"policy":spec.policy,"anchor":spec.anchor,"bones":spec.bones,
		"sample_count":samples.size(),"relative_transforms":relative,"pose_recipe_sha256":_hash(samples)}

func _eyes(actor: Node, player: AnimationPlayer, entry: Dictionary) -> Array:
	var bindings := []
	var origin := player.get_node(player.root_node)
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			assert(original!=null)
			if not entry.eye_states.has(original.resource_name): continue
			var material := original.duplicate() as StandardMaterial3D
			material.resource_local_to_scene = true
			mesh.set_surface_override_material(surface,material)
			for property: String in entry.eye_states[original.resource_name]:
				var record: Dictionary = entry.eye_states[original.resource_name][property]
				var awake: Texture2D = original.get(property)
				# GLTF may omit an unused metallic/roughness texture for zero factors.
				if awake == null:
					assert(property in ["metallic_texture","roughness_texture"])
					continue
				assert(FileAccess.get_sha256(record.path)==record.sha256)
				var image := Image.load_from_file(record.path)
				assert(image.get_size()==Vector2i(record.size[0],record.size[1]))
				image.generate_mipmaps()
				var closed := ImageTexture.create_from_image(image)
				var path := NodePath(str(origin.get_path_to(mesh))+":surface_material_override/"+str(surface)+":"+property)
				for action in player.get_animation_list():
					var clip := player.get_animation(action)
					assert(clip.find_track(path,Animation.TYPE_VALUE)<0)
					var track := clip.add_track(Animation.TYPE_VALUE)
					clip.track_set_path(track,path)
					clip.value_track_set_update_mode(track,Animation.UPDATE_CONTINUOUS)
					clip.track_set_interpolation_type(track,Animation.INTERPOLATION_NEAREST)
					clip.track_insert_key(track,0.0,closed if action=="sleep" else awake)
				bindings.append({"mesh":str(origin.get_path_to(mesh)),"surface":surface,
					"property":property,"closed_sha256":record.sha256,"closed_path":record.path})
	assert(not bindings.is_empty())
	return bindings

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size()==2 and args[0].is_absolute_path() and args[1].is_absolute_path())
	var stage: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	assert(stage.runtime_approved==false and stage.entries.size()==12)
	var output: String = args[1]
	assert(not DirAccess.dir_exists_absolute(output))
	DirAccess.make_dir_recursive_absolute(output)
	var entries := []
	for entry: Dictionary in stage.entries:
		assert(FileAccess.get_sha256(entry.runtime_path)==entry.runtime_sha256)
		var source := ResourceLoader.load(entry.runtime_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		var actor := source.instantiate() as Node3D
		root.add_child(actor)
		var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
		var before := {}
		for action in player.get_animation_list(): before[action] = _tracks(player.get_animation(action))
		var proposal := {}
		if entry.has("sleep_attachment"): proposal = _attach(actor,player,entry.sleep_attachment)
		# Verify every old track except the explicitly reconstructed sleep bones.
		for action: String in before:
			var after := _tracks(player.get_animation(action))
			for key: String in before[action]:
				if action=="sleep" and not proposal.is_empty() and key.get_slice(":",1) in proposal.bones: continue
				assert(after.get(key)==before[action][key],"Source curve changed: "+action+"/"+key)
		var bindings := _eyes(actor,player,entry)
		var skeleton: Skeleton3D = actor.find_children("*","Skeleton3D",true,false)[0]
		_pose(player,skeleton,"idle",0.0)
		player.stop()
		actor.set_meta("remaining_sleep_proposal",true)
		var packed := PackedScene.new()
		assert(packed.pack(actor)==OK)
		var path := output.path_join(entry.species+".scn")
		assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
		assert(ResourceLoader.get_dependencies(path).is_empty())
		var result := entry.duplicate(true)
		result.runtime_path = path
		result.runtime_sha256 = FileAccess.get_sha256(path)
		result["sleep_eye_bindings"] = bindings
		result["sleep_pose_proposal"] = proposal
		result["preserved_track_signatures"] = before
		result["status"] = "exported_for_review"
		entries.append(result)
		actor.free()
	FileAccess.open(output.path_join("catalog.json"),FileAccess.WRITE).store_string(JSON.stringify({"runtime_approved":false,"entries":entries},"  "))
	print("SLEEP_PROPOSAL_BUILT ",entries.size())
	quit()
