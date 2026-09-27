extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(1200,840)
	root.size = Vector2i(1200,840)
	root.title = "Pallet Town — animated tiles"
	root.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var packed: PackedScene = load("res://tools/pallet_animated_tiles_preview.tscn")
	var preview: Node = packed.instantiate()
	root.add_child(preview)
	if "--capture" in OS.get_cmdline_user_args():
		var directory := "user://pallet_animated_tiles_capture"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		for view in [0, 1, 2]:
			preview.set_view(view)
			await create_timer(0.1).timeout
			for frame in 90:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(directory.path_join("view_%d_%03d.png" % [view,frame]))
				await create_timer(1.0 / 15.0).timeout
		# Exercise off/on controls on the actual native TileSet animations.
		preview.set_animation_enabled(false)
		await create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join("paused_a.png"))
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join("paused_b.png"))
		preview.set_animation_enabled(true)
		print("PALLET_ANIMATED_TILES_PREVIEW sources=", preview.animations.size(), " capture=", ProjectSettings.globalize_path(directory))
		quit()
