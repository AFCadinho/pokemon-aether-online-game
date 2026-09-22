extends SceneTree
## Only generated visual scenes enter the capture viewport: no gameplay or HUD.

var route: Dictionary
var output: String
var preview := false
var composite: SubViewport
var views: Array[SubViewport] = []
var cameras: Array[Camera2D] = []
var pictures: Array[TextureRect] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Expected route JSON and output directory")
		quit(1)
		return
	route = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	output = args[1]
	preview = "--preview" in args
	composite = SubViewport.new()
	composite.size = Vector2i(int(route.width), int(route.height))
	composite.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	composite.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(composite)
	for shot: Dictionary in route.shots:
		var packed := load(str(shot.scene)) as PackedScene
		if packed == null:
			push_error("Missing visual scene: " + str(shot.scene))
			quit(1)
			return
		var map := packed.instantiate()
		if not _visual_only(map):
			map.free()
			push_error("Capture requires script-free generated visual scenes")
			quit(1)
			return
		var view := SubViewport.new()
		view.size = composite.size
		view.world_2d = World2D.new()
		view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		composite.add_child(view)
		view.add_child(map)
		var camera := Camera2D.new()
		camera.position_smoothing_enabled = false
		camera.zoom = Vector2.ONE * float(route.width) / float(shot.view_width)
		view.add_child(camera)
		camera.make_current()
		var picture := TextureRect.new()
		picture.texture = view.get_texture()
		picture.size = Vector2(composite.size)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		composite.add_child(picture)
		views.append(view)
		cameras.append(camera)
		pictures.append(picture)
	# Show exactly the recorded composition in the local preview window.
	var display := TextureRect.new()
	display.texture = composite.get_texture()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.add_child(display)
	var total := int(round(float(route.shot_seconds) * float(route.fps))) * views.size()
	var count := views.size() if preview else total
	for frame in count:
		var seconds := (float(frame) + 0.5) * float(route.shot_seconds) if preview else float(frame) / float(route.fps)
		_compose(seconds)
		await process_frame
		await RenderingServer.frame_post_draw
		var path := output.path_join("%06d.png" % frame)
		var error := composite.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Cannot save frame: " + error_string(error))
			quit(1)
			return
		if frame % int(route.fps) == 0:
			print("World tour frame %d/%d" % [frame + 1, count])
	print("World tour capture complete: %d frames" % count)
	quit()


func _visual_only(node: Node) -> bool:
	if node.get_script() != null or node is CanvasLayer or node is Control:
		return false
	for child in node.get_children():
		if not _visual_only(child):
			return false
	return true


func _position(index: int, progress: float) -> void:
	var shot: Dictionary = route.shots[index]
	var start := Vector2(float(shot.from[0]), float(shot.from[1]))
	var finish := Vector2(float(shot.to[0]), float(shot.to[1]))
	cameras[index].position = start.lerp(finish, smoothstep(0.0, 1.0, progress))
	cameras[index].force_update_scroll()


func _compose(seconds: float) -> void:
	var duration := float(route.shot_seconds)
	var fade := float(route.transition_seconds)
	var index := int(seconds / duration) % views.size()
	var next := (index + 1) % views.size()
	var local := fmod(seconds, duration)
	for i in views.size():
		pictures[i].visible = false
		views[i].render_target_update_mode = SubViewport.UPDATE_DISABLED
	views[index].render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pictures[index].visible = true
	pictures[index].modulate.a = 1.0
	composite.move_child(pictures[index], -1)
	_position(index, (local + fade) / (duration + fade))
	if local >= duration - fade:
		views[next].render_target_update_mode = SubViewport.UPDATE_ALWAYS
		pictures[next].visible = true
		pictures[next].modulate.a = smoothstep(0.0, 1.0, (local - duration + fade) / fade)
		composite.move_child(pictures[next], -1)
		_position(next, (local - duration + fade) / (duration + fade))
