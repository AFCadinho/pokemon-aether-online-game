extends "catalog_dlc_runtime_review.gd"
## Capture actual Linux renderer output and all clips; never catalog admission.

func _run() -> void:
	auto_accept_quit = false
	process_frame.connect(func(): RenderingServer.force_draw(false))
	await super._run()

func _review(entry: Dictionary, output: String) -> Dictionary:
	root.size = Vector2i(640,640)
	var result: Dictionary = await super._review(entry,output)
	var packed := ResourceLoader.load(entry.runtime_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var actor := packed.instantiate() as Node3D
	assert(actor.get_meta("remaining_forms_local_preview",false))
	world.add_child(actor)
	var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
	var caption := Label.new()
	caption.position = Vector2(16,12)
	caption.add_theme_font_size_override("font_size",18)
	root.add_child(caption)
	var union: AABB = await _sample(actor,player,"idle",0.0)
	var sequence := []
	for frame in 36: sequence.append({"action":"idle","fraction":float(frame%12)/12.0,"angle":TAU*frame/36.0})
	for action: String in entry.animations:
		for fraction in [0.0,0.25,0.5,0.75,1.0]:
			union = union.merge(await _sample(actor,player,action,fraction))
		var count := maxi(2,int(ceil(float(entry.animations[action].duration)*12.0)))
		for frame in count:
			sequence.append({"action":action,"fraction":float(frame)/(count-1),"angle":0.2})
	var frames := output.path_join(entry.species+"-frames")
	DirAccess.make_dir_recursive_absolute(frames)
	result["video_frames"] = sequence.size()
	result["visibility_samples"] = 0
	for index in sequence.size():
		var pose: Dictionary = sequence[index]
		await _sample(actor,player,pose.action,pose.fraction)
		if entry.has("visibility"):
			var time := player.get_animation(pose.action).length * float(pose.fraction)
			for track: Dictionary in entry.visibility.clips[pose.action].tracks:
				var expected: bool = track.keys[0][1]
				for key: Array in track.keys:
					if float(key[0]) <= time+0.000001: expected = key[1]
				var mesh := actor.find_child(track.mesh,true,false) as MeshInstance3D
				if mesh == null or mesh.visible != expected:
					result.errors.append("Visibility mismatch: "+pose.action+"/"+track.mesh)
				result.visibility_samples += 1
		var target := union.get_center()
		camera.size = union.size.length()*1.12
		camera.position = target + Vector3(sin(pose.angle),0.25,cos(pose.angle)).normalized()*camera.size*3
		camera.look_at(target)
		caption.text = entry.species+" — "+str(pose.action)+"\nLokale preview · nog niet goedgekeurd"
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(frames.path_join("%04d.png" % index))==OK)
	actor.free()
	caption.free()
	return result
