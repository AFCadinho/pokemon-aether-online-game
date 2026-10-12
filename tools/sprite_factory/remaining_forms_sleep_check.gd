extends SceneTree
## Independent 120 Hz attachment and two-instance eye-state regression.

func _initialize() -> void:
	process_frame.connect(func(): RenderingServer.force_draw(false))
	_run.call_deferred()

func _load(entry: Dictionary, approved: bool) -> Node3D:
	var path: String = entry.approved_runtime_path if approved else entry.runtime_path
	var expected: String = entry.approved_runtime_sha256 if approved else entry.runtime_sha256
	assert(FileAccess.get_sha256(path)==expected)
	var packed := ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var actor := packed.instantiate() as Node3D
	root.add_child(actor)
	return actor

func _player(actor: Node) -> AnimationPlayer:
	return actor.find_children("*","AnimationPlayer",true,false)[0]

func _skeleton(actor: Node) -> Skeleton3D:
	return actor.find_children("*","Skeleton3D",true,false)[0]

func _seek(actor: Node, action: String, time: float, reset: bool = true) -> void:
	var player := _player(actor)
	var skeleton := _skeleton(actor)
	if reset:
		player.stop()
		skeleton.reset_bone_poses()
	player.play(action)
	player.pause()
	player.seek(time,true)
	skeleton.force_update_all_bone_transforms()

func _image(texture: Texture2D) -> PackedByteArray:
	assert(texture!=null)
	var image := texture.get_image()
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)
	return image.get_data()

func _same_geometry(old: Node, actor: Node) -> int:
	var count := 0
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		var original: MeshInstance3D = old.get_node(actor.get_path_to(mesh))
		assert(mesh.mesh.get_surface_count()==original.mesh.get_surface_count())
		for surface in mesh.mesh.get_surface_count():
			assert(var_to_bytes(mesh.mesh.surface_get_arrays(surface))==var_to_bytes(original.mesh.surface_get_arrays(surface)))
			count += 1
		assert(mesh.skin.get_bind_count()==original.skin.get_bind_count())
		for bind in mesh.skin.get_bind_count():
			assert(mesh.skin.get_bind_pose(bind)==original.skin.get_bind_pose(bind))
			assert(mesh.skin.get_bind_bone(bind)==original.skin.get_bind_bone(bind))
			assert(mesh.skin.get_bind_name(bind)==original.skin.get_bind_name(bind))
	return count

func _eye(actor: Node, binding: Dictionary) -> StandardMaterial3D:
	var mesh: MeshInstance3D = actor.get_node(binding.mesh)
	return mesh.get_active_material(binding.surface)

func _prey_clearance(actor: Node) -> float:
	var bird_min := INF
	var prey_min := INF
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree(): continue
		var posed := mesh.bake_mesh_from_current_skeleton_pose()
		assert(posed!=null)
		var prey := "pikachu" in str(mesh.name) or "kawamasu" in str(mesh.name)
		for surface in posed.get_surface_count():
			for vertex: Vector3 in posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var y := (mesh.global_transform*vertex).y
				if prey: prey_min = minf(prey_min,y)
				else: bird_min = minf(bird_min,y)
	assert(is_finite(prey_min) and is_finite(bird_min))
	return prey_min-bird_min

func _run() -> void:
	assert(DisplayServer.get_name()!="headless","Posed mesh clearance needs a rendering display")
	var args := OS.get_cmdline_user_args()
	assert(args.size()==2 and args[0].is_absolute_path() and args[1].is_absolute_path())
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	assert(not catalog.runtime_approved and catalog.entries.size()==12)
	var report := {"runtime_approved":false,"entries":[],"preserved_pose_checks":0,
		"eye_state_checks":0,"independent_instance_checks":0,"attachment_checks":0,"maximum_attachment_error":0.0,"prey_clearance_samples":0,"geometry_surfaces":0}
	for entry: Dictionary in catalog.entries:
		var old := _load(entry,true)
		var actor := _load(entry,false)
		# Instantiate twice from the SAME PackedScene to detect shared animated materials.
		var packed := ResourceLoader.load(entry.runtime_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		var a := packed.instantiate() as Node3D
		var b := packed.instantiate() as Node3D
		root.add_child(a);root.add_child(b)
		await process_frame
		var player := _player(actor)
		var skeleton := _skeleton(actor)
		var before := _skeleton(old)
		report.geometry_surfaces += _same_geometry(old,actor)
		assert(skeleton.get_bone_count()==before.get_bone_count())
		for bone in skeleton.get_bone_count():
			assert(skeleton.get_bone_rest(bone)==before.get_bone_rest(bone))
			assert(skeleton.get_bone_parent(bone)==before.get_bone_parent(bone))
		for action: String in entry.animations:
			var length := player.get_animation(action).length
			for fraction in [0.0,0.25,0.5,0.75,1.0]:
				_seek(old,action,length*fraction)
				_seek(actor,action,length*fraction)
				for bone in skeleton.get_bone_count():
					var name := skeleton.get_bone_name(bone)
					if action=="sleep" and entry.has("sleep_attachment") and name in entry.sleep_attachment.bones: continue
					assert(skeleton.get_bone_pose(bone).is_equal_approx(before.get_bone_pose(bone)),entry.species+" changed "+action+"/"+name)
					report.preserved_pose_checks += 1
				for binding: Dictionary in entry.sleep_eye_bindings:
					var texture: Texture2D = _eye(actor,binding).get(binding.property)
					if action=="sleep":
						var expected := Image.load_from_file(binding.closed_path)
						expected.convert(Image.FORMAT_RGBA8)
						assert(_image(texture)==expected.get_data(),"Closed eye lost on reload")
					else:
						assert(_image(texture)==_image(_eye(old,binding).get(binding.property)),"Awake texture changed")
					report.eye_state_checks += 1
		var sequence := ["sleep","idle","sleep","physical_attack","damage","sleep","special_attack","faint_start","idle"]
		for action in sequence:
			_seek(a,action,_player(a).get_animation(action).length*0.5,false)
			_seek(b,"idle",0.25,false)
			for binding: Dictionary in entry.sleep_eye_bindings:
				var ma := _eye(a,binding)
				var mb := _eye(b,binding)
				assert(ma!=mb and ma.resource_local_to_scene and mb.resource_local_to_scene)
				assert(_image(mb.get(binding.property))==_image(_eye(old,binding).get(binding.property)))
				if action=="sleep":
					var image := Image.load_from_file(binding.closed_path)
					image.convert(Image.FORMAT_RGBA8)
					assert(_image(ma.get(binding.property))==image.get_data())
				else: assert(_image(ma.get(binding.property))==_image(mb.get(binding.property)))
				report.independent_instance_checks += 1
		var maximum := 0.0
		var minimum_clearance := INF
		if entry.has("sleep_attachment"):
			var spec: Dictionary = entry.sleep_attachment
			var anchor := before.find_bone(spec.anchor)
			_seek(old,"idle",0)
			var idle_head_basis := before.get_bone_global_pose(anchor).basis
			var relative := {}
			for name: String in spec.bones:
				var bone := before.find_bone(name)
				relative[bone] = before.get_bone_global_pose(anchor).affine_inverse()*before.get_bone_global_pose(bone)
			var duration := player.get_animation("sleep").length
			var count := int(ceil(duration*120))
			for frame in count+1:
				_seek(actor,"sleep",duration*float(frame)/count)
				var head := skeleton.get_bone_global_pose(anchor)
				if spec.get("keep_idle_head_orientation",false): assert(head.basis.is_equal_approx(idle_head_basis))
				if frame%12==0 or frame==count:
					await RenderingServer.frame_post_draw
					var clearance := _prey_clearance(actor)
					assert(clearance>0,"Prey hangs below sleeping bird: "+str(clearance))
					minimum_clearance = minf(minimum_clearance,clearance)
					report.prey_clearance_samples += 1
				for bone: int in relative:
					var expected: Transform3D = head*relative[bone]
					var actual := skeleton.get_bone_global_pose(bone)
					var error := expected.origin.distance_to(actual.origin)
					for axis in 3: error = maxf(error,expected.basis[axis].distance_to(actual.basis[axis]))
					assert(error<0.001,"Prey/beak attachment drift "+str(error))
					maximum = maxf(maximum,error)
					report.attachment_checks += 1
			report.maximum_attachment_error = maxf(report.maximum_attachment_error,maximum)
		report.entries.append({"species":entry.species,"maximum_attachment_error":maximum,
			"minimum_prey_clearance":minimum_clearance if is_finite(minimum_clearance) else null,"passed":true})
		old.free();actor.free();a.free();b.free()
		print("SLEEP_CHECK ",entry.species," max_error=",maximum)
	FileAccess.open(args[1],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SLEEP_REPAIR_CHECK_PASSED")
	quit()
