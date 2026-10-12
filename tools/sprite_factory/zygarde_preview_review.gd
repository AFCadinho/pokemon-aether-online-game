extends "catalog_dlc_runtime_review.gd"
## Standalone prototype review, deliberately outside production model admission.

func _run() -> void:
	auto_accept_quit = false
	process_frame.connect(func(): RenderingServer.force_draw(false))
	await super._run()

func _review(entry: Dictionary, output: String) -> Dictionary:
	root.size = Vector2i(768,768)
	var result: Dictionary = await super._review(entry,output)
	var packed := ResourceLoader.load(entry.runtime_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var actor := packed.instantiate() as Node3D
	assert(actor.get_meta("zygarde_local_preview",false))
	world.add_child(actor)
	var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
	var caption := Label.new()
	caption.position = Vector2(20,16)
	caption.add_theme_font_size_override("font_size",22)
	root.add_child(caption)
	var box: AABB = await _sample(actor,player,"idle",0.0)
	var core: MeshInstance3D = actor.find_child("*core_mesh",true,false)
	assert(core != null)
	var core_box: AABB = core.global_transform * core.bake_mesh_from_current_skeleton_pose().get_aabb()
	var center := core_box.get_center()
	for angle in [-35.0,0.0,35.0]:
		caption.text = entry.variant + " — borst / " + str(int(angle)) + "°\nLokale reconstructie · nog niet goedgekeurd"
		camera.size = 0.24
		camera.position = center + Vector3(sin(deg_to_rad(angle)),0.15,cos(deg_to_rad(angle))) * 2.0
		camera.look_at(center)
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(entry.variant+"-core-"+str(int(angle))+".png"))==OK)
	var sequence := []
	for frame in 72: sequence.append({"action":"idle","fraction":float(frame%12)/12.0,"angle":TAU*frame/72.0,"turntable":true})
	for action: String in entry.animations:
		var count := maxi(2,int(ceil(float(entry.animations[action].duration)*12.0)))
		for frame in count:
			sequence.append({"action":action,"fraction":float(frame)/(count-1),"angle":0.4,"turntable":false})
	var frames := output.path_join(entry.variant+"-frames")
	DirAccess.make_dir_recursive_absolute(frames)
	result["visibility_samples"] = 0
	result["material_samples"] = 0
	result["video_frames"] = sequence.size()
	result["closeup_angles"] = [-35,0,35]
	# Frame the full union once so attack/faint motion is not hidden by autofit.
	var union := box
	for action: String in entry.animations:
		for fraction in [0.0,0.25,0.5,0.75,1.0]:
			union = union.merge(await _sample(actor,player,action,fraction))
	for index in sequence.size():
		var pose: Dictionary = sequence[index]
		await _sample(actor,player,pose.action,pose.fraction)
		var time := player.get_animation(pose.action).length * float(pose.fraction)
		for check: Dictionary in entry.material_checks:
			var values: Array = check.clips[pose.action]
			var expected := float(values[0][1])
			for key in range(1,values.size()):
				var lo: Array = values[key-1]
				var hi: Array = values[key]
				if time >= float(hi[0]): expected = hi[1]
				elif time >= float(lo[0]):
					expected = lerpf(lo[1],hi[1],(time-float(lo[0]))/(float(hi[0])-float(lo[0])))
					break
			var origin := player.get_node(player.root_node)
			var property_path := NodePath(check.path)
			var target := origin.get_node(NodePath(property_path.get_concatenated_names()))
			var value: Variant = target.get_indexed(NodePath(":"+str(property_path.get_concatenated_subnames())))
			var actual := float(value.a) if check.alpha else float(value)
			if absf(actual-expected)>0.0001:
				result.errors.append("Material curve mismatch: "+check.material+"/"+pose.action)
			result.material_samples += 1
		for track: Dictionary in entry.visibility.clips[pose.action].tracks:
			var expected: bool = track.keys[0][1]
			for key: Array in track.keys:
				if float(key[0]) <= time + 0.000001: expected = key[1]
			var mesh := actor.find_child(track.mesh,true,false) as MeshInstance3D
			if mesh == null or mesh.visible != expected:
				result.errors.append("Visibility mismatch: "+pose.action+"/"+track.mesh+"@"+str(time))
			result.visibility_samples += 1
		var target := union.get_center()
		camera.size = union.size.length()*1.08
		camera.position = target + Vector3(sin(pose.angle),0.3,cos(pose.angle)).normalized()*6.0
		camera.look_at(target)
		caption.text = entry.variant + " — " + ("rondom" if pose.turntable else str(pose.action)) + "\nLokale reconstructie · nog niet goedgekeurd"
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(frames.path_join("%04d.png" % index))==OK)
	actor.free()
	caption.free()
	return result
