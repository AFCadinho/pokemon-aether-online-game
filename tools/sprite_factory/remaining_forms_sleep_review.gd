extends "catalog_dlc_runtime_review.gd"
## Additional all-around sleep capture, using the already verified candidate.

func _run() -> void:
	auto_accept_quit = false
	process_frame.connect(func(): RenderingServer.force_draw(false))
	await super._run()

func _review(entry: Dictionary, output: String) -> Dictionary:
	root.size = Vector2i(640,640)
	var result: Dictionary = await super._review(entry,output)
	var packed := ResourceLoader.load(entry.runtime_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var actor := packed.instantiate() as Node3D
	world.add_child(actor)
	var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
	var union: AABB = await _sample(actor,player,"sleep",0)
	for fraction in [0.25,0.5,0.75,1.0]: union = union.merge(await _sample(actor,player,"sleep",fraction))
	var caption := Label.new()
	caption.position = Vector2(16,12)
	caption.add_theme_font_size_override("font_size",18)
	caption.text = entry.species+" — slaap rondom\nBronogen · herstelde prooipositie"
	root.add_child(caption)
	var directory := output.path_join(entry.species+"-frames")
	DirAccess.make_dir_recursive_absolute(directory)
	for frame in 72:
		await _sample(actor,player,"sleep",float(frame%36)/36.0)
		var angle := TAU*float(frame)/72.0
		var target := union.get_center()
		camera.size = union.size.length()*1.12
		camera.position = target + Vector3(sin(angle),0.25,cos(angle)).normalized()*camera.size*3
		camera.look_at(target)
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(directory.path_join("%04d.png" % frame))==OK)
	result["sleep_frames"] = 72
	caption.free()
	actor.free()
	return result
