extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guild_room_designs.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/guild_base/templates"))
	for template: Dictionary in data.templates:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(736, 608)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.transparent_bg = false
		root.add_child(viewport)
		viewport.add_child(preload("res://scripts/ui/guild_room_design_canvas.gd").build_art(str(template.roomKey), template.items))
		await process_frame
		RenderingServer.force_draw(false)
		var image := viewport.get_texture().get_image().get_region(Rect2i(96, 32, 544, 480))
		var result := image.save_png("res://assets/guild_base/templates/%s.png" % template.id)
		if result != OK:
			quit(1)
			return
		viewport.queue_free()
		await process_frame
	print("guild_room_templates: rendered ", data.templates.size(), " previews from runtime furniture")
	quit(0)
