# Run through slot-env with a real display. This uses the native renderer.
extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn"
var house_door := false
var origin := Vector2(1024, 1216)
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Door render check requires a display")
		quit(2)
		return
	if house_door:
		origin = Vector2(1440, 832)
	var world: Node = load("res://scripts/world/world.gd").new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(224,128) if house_door else Vector2i(224,288)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	viewport.canvas_transform.origin = -origin
	var city := (load(CITY) as PackedScene).instantiate()
	var visual := city.get_node("ViridianCity")
	city.remove_child(visual)
	city.free()
	var map := Node2D.new()
	viewport.add_child(map)
	map.add_child(visual)
	var door := visual.get_node(("House1HingedDoor" if house_door else "PokemonCenterSlidingDoor"))
	door.set_process(false)
	world.call("_normalize_map_depth_layer_z_indices", map)
	var output := "user://viridian-house-door-review" if house_door else "user://viridian-door-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	door.visible = false
	await process_frame
	RenderingServer.force_draw(true, 0.0)
	var reference := viewport.get_texture().get_image()
	door.visible = true
	var previous: Image
	var steps := 6 if house_door else 4
	for step in range(steps + 1):
		door.open_amount = float(step) / steps
		await process_frame
		RenderingServer.force_draw(true, 0.0)
		var frame := viewport.get_texture().get_image()
		frame.save_png(output + "/door_%d.png" % step)
		if step == 0:
			_check(frame.get_data() == reference.get_data(), "Closed door matches original map pixels")
		else:
			_check(frame.get_data() != previous.get_data(), "Opening step %d visibly changes" % step)
		var outside_changes := 0
		var aperture := (Rect2i(96,22,32,38) if house_door else Rect2i(92,200,40,44))
		for y in range(frame.get_height()):
			for x in range(frame.get_width()):
				if not aperture.has_point(Vector2i(x,y)) and frame.get_pixel(x,y) != reference.get_pixel(x,y):
					outside_changes += 1
		_check(outside_changes == 0, "Step %d preserves facade, frame, sidelights and threshold" % step)
		previous = frame
	_check((previous.get_pixel(112,44) if house_door else previous.get_pixel(112,220)).is_equal_approx(door.opening_color), "Fully open reveals dark doorway")
	if house_door:
		# Check the complete original leaf, including its six shaded top rows
		# and rightmost edge; checking only the center missed both remnants.
		var remaining_pixels := 0
		for y in range(22, 60):
			for x in range(96, 128):
				if not previous.get_pixel(x, y).is_equal_approx(door.opening_color):
					remaining_pixels += 1
		_check(remaining_pixels == 0, "Fully open house door leaves no original top strip or leaf edge")

	door.open_amount = 0.0
	await process_frame
	RenderingServer.force_draw(true,0.0)
	_check(viewport.get_texture().get_image().get_data() == reference.get_data(), "Closing restores exact original artwork")
	print("Door review images: ", ProjectSettings.globalize_path(output))
	viewport.free(); world.free()
	quit(1 if failed else 0)

func _check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	failed = failed or not ok
