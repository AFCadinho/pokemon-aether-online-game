extends SceneTree

# Local, offline visual proof. Run with --script; no game services or login.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(1152, 768)
	root.size = Vector2i(1152, 768)
	root.title = "Viridian City — wateranimatie proef"
	root.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var packed := load("res://tools/viridian_water_preview.tscn") as PackedScene
	root.add_child(packed.instantiate())
	if "--capture" in OS.get_cmdline_user_args():
		var directory := "user://viridian_water_capture"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		await create_timer(0.4).timeout
		for frame in 16:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("frame_%02d.png" % frame))
			await create_timer(0.16).timeout
		print("Capture: ", ProjectSettings.globalize_path(directory))
		quit()
